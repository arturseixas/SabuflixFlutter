import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/download_item.dart';

/// Thrown when a transfer is stopped on purpose (pause / remove).
class DownloadCancelled implements Exception {
  const DownloadCancelled();
  @override
  String toString() => 'DownloadCancelled';
}

typedef DownloadProgress = void Function(int received, int total);

class _ActiveTask {
  final http.Client client;
  final IOSink sink;
  final Completer<void> completer = Completer<void>();
  StreamSubscription<List<int>>? subscription;
  bool cancelled = false;

  _ActiveTask(this.client, this.sink);
}

/// Streams a remote file into the app's private storage, with byte-range
/// resume so an interrupted transfer picks up where it stopped instead of
/// starting over.
class DownloadService {
  DownloadService(
      {Future<Directory> Function()? documentsDirectory,
      http.Client Function()? clientFactory})
      : _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory,
        _clientFactory = clientFactory ?? http.Client.new;
  final Future<Directory> Function() _documentsDirectory;
  final http.Client Function() _clientFactory;
  final Map<String, http.Client> _pendingClients = {};

  static const String _userAgent = 'Sabuflix/1.0';

  /// Flush to disk every few megabytes and hold the socket while we do, so a
  /// fast connection cannot outrun the filesystem and balloon memory.
  static const int _flushEvery = 4 * 1024 * 1024;

  final Map<String, _ActiveTask> _active = {};

  bool isRunning(String id) =>
      _active.containsKey(id) || _pendingClients.containsKey(id);

  /// Per-profile folder inside the app's own documents directory. Nothing here
  /// needs storage permissions, and it is removed when the app is uninstalled.
  Future<Directory> folderFor(String profileKey) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(profileKey)) {
      throw const FileSystemException('Perfil de download inválido');
    }
    final base = await _documentsDirectory();
    final separator = Platform.pathSeparator;
    final directory = Directory(
        '${base.path}${separator}sabuflix_downloads$separator$profileKey');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<File> fileFor(String profileKey, String fileName) async {
    if (fileName.isEmpty ||
        fileName.contains('/') ||
        fileName.contains('\\') ||
        fileName == '..') {
      throw const FileSystemException('Nome de arquivo inválido');
    }
    final directory = await folderFor(profileKey);
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  /// Resolved absolute path, or `null` when the file is not on disk.
  Future<String?> existingPath(String profileKey, String fileName) async {
    try {
      final file = await fileFor(profileKey, fileName);
      if (await file.exists()) return file.path;
    } catch (e) {
      debugPrint('Could not resolve download path: $e');
    }
    return null;
  }

  Future<int> bytesOnDisk(String profileKey, String fileName) async {
    try {
      final file = await fileFor(profileKey, fileName);
      if (await file.exists()) return await file.length();
    } catch (e) {
      debugPrint('Could not stat download: $e');
    }
    return 0;
  }

  Future<void> deleteFile(String profileKey, String fileName) async {
    try {
      final file = await fileFor(profileKey, fileName);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('Could not delete download: $e');
    }
  }

  /// Runs the transfer to completion. Throws [DownloadCancelled] when stopped
  /// by [stop], and any other exception when the transfer genuinely failed.
  Future<void> download({
    required String profileKey,
    required DownloadItem item,
    required DownloadProgress onProgress,
  }) async {
    if (item.url.isEmpty) {
      throw const HttpException('Fonte indisponível para este download.');
    }

    final file = await fileFor(profileKey, item.fileName);
    var received = (await file.exists()) ? await file.length() : 0;

    final client = _clientFactory();
    _pendingClients[item.id] = client;
    http.StreamedResponse response;
    try {
      final request = http.Request('GET', Uri.parse(item.url));
      request.headers['user-agent'] = _userAgent;
      request.headers['accept'] = '*/*';
      if (received > 0) request.headers['range'] = 'bytes=$received-';
      response =
          await client.send(request).timeout(const Duration(seconds: 20));
    } catch (_) {
      client.close();
      if (_pendingClients.remove(item.id) == null) {
        throw const DownloadCancelled();
      }
      rethrow;
    }
    if (_pendingClients.remove(item.id) == null) {
      client.close();
      throw const DownloadCancelled();
    }

    // 416 means the server has nothing past what we already hold: the file is
    // already complete on disk.
    if (response.statusCode == 416) {
      client.close();
      final total = int.tryParse(
          (response.headers['content-range'] ?? '').split('/').last);
      if (received <= 0 || total != received) {
        throw const HttpException(
            'Download incompleto. Remova e baixe novamente.');
      }
      onProgress(received, received);
      return;
    }
    if (response.statusCode != 200 && response.statusCode != 206) {
      client.close();
      throw HttpException('O servidor respondeu ${response.statusCode}.');
    }

    final contentType = (response.headers['content-type'] ?? '').toLowerCase();
    if (contentType.contains('text/html') ||
        contentType.contains('mpegurl') ||
        contentType.contains('dash+xml')) {
      client.close();
      throw const HttpException(
          'Esta fonte não permite download direto. Escolha outra fonte.');
    }
    if (response.statusCode == 206) {
      final match = RegExp(r'^bytes (\d+)-(\d+)/(\d+|\*)$')
          .firstMatch(response.headers['content-range'] ?? '');
      if (match == null || int.tryParse(match.group(1)!) != received) {
        client.close();
        throw const HttpException(
            'O servidor retornou uma parte inválida do arquivo.');
      }
    }

    // A server that ignores our Range header restarts the body from zero, so
    // the partial file has to be overwritten rather than appended to.
    final append = response.statusCode == 206 && received > 0;
    if (!append) received = 0;

    final total = _totalBytesFrom(response, append ? received : 0);
    final sink = file.openWrite(
        mode: append ? FileMode.writeOnlyAppend : FileMode.writeOnly);
    final task = _ActiveTask(client, sink);
    _active[item.id] = task;
    sink.done.then<void>((_) {}, onError: (Object error, StackTrace stack) {
      if (!task.completer.isCompleted) {
        task.completer.completeError(error, stack);
      }
    });

    var sinceFlush = 0;
    task.subscription =
        response.stream.timeout(const Duration(seconds: 30)).listen(
      (chunk) {
        sink.add(chunk);
        received += chunk.length;
        sinceFlush += chunk.length;
        onProgress(received, total);
        if (sinceFlush >= _flushEvery) {
          sinceFlush = 0;
          task.subscription?.pause(sink.flush());
        }
      },
      onError: (Object error) {
        if (!task.completer.isCompleted) task.completer.completeError(error);
      },
      onDone: () {
        if (!task.completer.isCompleted) task.completer.complete();
      },
      cancelOnError: true,
    );

    try {
      await task.completer.future;
      if (!task.cancelled) await sink.flush();
    } finally {
      _active.remove(item.id);
      try {
        await sink.flush();
      } catch (_) {
        // The sink may already be torn down after a cancel; nothing to do.
      }
      try {
        await sink.close();
      } catch (_) {
        // Same as above.
      }
      client.close();
    }

    if (task.cancelled) throw const DownloadCancelled();
    if (received == 0 || (total > 0 && received != total)) {
      throw const HttpException(
          'O download foi interrompido antes de terminar.');
    }
    onProgress(received, total > 0 ? total : received);
  }

  /// Stops an in-flight transfer. The partial file is kept so it can resume.
  Future<void> stop(String id) async {
    _pendingClients.remove(id)?.close();
    final task = _active.remove(id);
    if (task == null) return;
    task.cancelled = true;
    try {
      await task.subscription?.cancel();
    } catch (e) {
      debugPrint('Could not cancel download stream: $e');
    }

    // Release the file handle here rather than leaving it to the download
    // future: Windows refuses to delete a file that is still open, so a
    // "remove" right after a cancel would otherwise leave the bytes behind.
    try {
      await task.sink.flush();
    } catch (_) {
      // Already torn down.
    }
    try {
      await task.sink.close();
    } catch (_) {
      // Already closed.
    }
    task.client.close();

    // Cancelling the subscription means neither onDone nor onError will ever
    // fire, so the waiting future has to be released by hand.
    if (!task.completer.isCompleted) task.completer.complete();
  }

  Future<void> stopAll() async {
    for (final id in {..._active.keys, ..._pendingClients.keys}.toList()) {
      await stop(id);
    }
  }

  int _totalBytesFrom(http.StreamedResponse response, int alreadyOnDisk) {
    final contentRange = response.headers['content-range'];
    if (contentRange != null) {
      final slash = contentRange.lastIndexOf('/');
      if (slash != -1) {
        final parsed = int.tryParse(contentRange.substring(slash + 1).trim());
        if (parsed != null && parsed > 0) return parsed;
      }
    }
    final length = response.contentLength;
    if (length != null && length > 0) return length + alreadyOnDisk;
    return 0;
  }
}
