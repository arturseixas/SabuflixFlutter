import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Low-level byte pump behind the downloads feature.
///
/// Bytes always land in `<downloads>/<fileName>.part` and the file is only
/// renamed to its final name once the transfer finishes, so a half-written
/// file can never be mistaken for a playable one. Resuming re-requests the
/// remainder with a `Range` header, which is what makes a download survive
/// a pause — or the app being closed mid-transfer.
class DownloadService {
  DownloadService._();

  static const String folderName = 'sabuflix_downloads';
  static const String partSuffix = '.part';

  static const Set<String> _videoExtensions = {
    '.mp4', '.mkv', '.avi', '.webm', '.m4v', '.mov', '.ts', '.mpg', '.mpeg',
  };

  static Directory? _cachedDir;

  static Future<Directory> directory() async {
    final cached = _cachedDir;
    if (cached != null) return cached;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}$folderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cachedDir = dir;
    return dir;
  }

  static Future<String> filePath(String fileName) async {
    final dir = await directory();
    return '${dir.path}${Platform.pathSeparator}$fileName';
  }

  static Future<int> fileSize(String fileName) async {
    try {
      final file = File(await filePath(fileName));
      if (await file.exists()) return await file.length();
    } catch (_) {}
    return 0;
  }

  static Future<bool> fileExists(String fileName) async {
    try {
      return await File(await filePath(fileName)).exists();
    } catch (_) {
      return false;
    }
  }

  static Future<int> partialSize(String fileName) => fileSize('$fileName$partSuffix');

  /// Removes both the finished file and any leftover `.part`.
  static Future<void> deleteFiles(String fileName) async {
    for (final name in [fileName, '$fileName$partSuffix']) {
      try {
        final file = File(await filePath(name));
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  /// Derives a filesystem-safe name from the download id, keeping the
  /// container extension advertised by the source URL when we recognise it.
  static String buildFileName({required String downloadId, required String url}) {
    final safeId = downloadId.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    String extension = '.mp4';
    try {
      final segments = Uri.parse(url).pathSegments;
      if (segments.isNotEmpty) {
        final last = segments.last.toLowerCase();
        final dot = last.lastIndexOf('.');
        if (dot > 0) {
          final candidate = last.substring(dot);
          if (_videoExtensions.contains(candidate)) extension = candidate;
        }
      }
    } catch (_) {}
    return '$safeId$extension';
  }

  /// Starts (or resumes) a transfer. The returned handle cancels it.
  static DownloadHandle start({
    required String url,
    required String fileName,
    required void Function(int received, int total) onProgress,
    required void Function(String path) onComplete,
    required void Function(Object error) onError,
  }) {
    final handle = DownloadHandle._();
    handle._run(
      url: url,
      fileName: fileName,
      onProgress: onProgress,
      onComplete: onComplete,
      onError: onError,
    );
    return handle;
  }
}

/// Controls one in-flight transfer.
class DownloadHandle {
  DownloadHandle._();

  static const int _flushEvery = 4 * 1024 * 1024;

  final http.Client _client = http.Client();
  StreamSubscription<List<int>>? _subscription;
  IOSink? _sink;
  bool _canceled = false;

  bool get isCanceled => _canceled;

  /// Stops the transfer and closes the file. Bytes already written stay on
  /// disk so the download can be resumed later.
  Future<void> cancel() async {
    if (_canceled) return;
    _canceled = true;
    try {
      await _subscription?.cancel();
    } catch (_) {}
    _subscription = null;
    await _closeSink();
    _client.close();
  }

  Future<void> _closeSink() async {
    final sink = _sink;
    _sink = null;
    if (sink == null) return;
    try {
      await sink.flush();
      await sink.close();
    } catch (_) {}
  }

  Future<void> _run({
    required String url,
    required String fileName,
    required void Function(int received, int total) onProgress,
    required void Function(String path) onComplete,
    required void Function(Object error) onError,
  }) async {
    try {
      final partFile = File(await DownloadService.filePath('$fileName${DownloadService.partSuffix}'));
      int alreadyHave = await partFile.exists() ? await partFile.length() : 0;

      final request = http.Request('GET', Uri.parse(url));
      // Compressed transfer would make Content-Length meaningless for a
      // progress bar, and video containers gain nothing from it.
      request.headers['Accept-Encoding'] = 'identity';
      if (alreadyHave > 0) request.headers['Range'] = 'bytes=$alreadyHave-';

      final response = await _client.send(request);
      if (_canceled) return;

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException('O servidor respondeu ${response.statusCode}', uri: Uri.parse(url));
      }

      // A 200 to a ranged request means the server ignored the range, so
      // whatever we had is stale and the file restarts from zero.
      final bool append = response.statusCode == 206 && alreadyHave > 0;
      if (!append) alreadyHave = 0;

      int total = 0;
      final contentRange = response.headers['content-range'];
      if (append && contentRange != null) {
        final match = RegExp(r'/(\d+)\s*$').firstMatch(contentRange);
        if (match != null) total = int.tryParse(match.group(1)!) ?? 0;
      }
      if (total == 0 && response.contentLength != null) {
        total = response.contentLength! + alreadyHave;
      }

      int received = alreadyHave;
      int sinceFlush = 0;
      onProgress(received, total);

      _sink = partFile.openWrite(
        mode: append ? FileMode.writeOnlyAppend : FileMode.writeOnly,
      );

      final completer = Completer<void>();
      _subscription = response.stream.listen(
        (chunk) {
          final sink = _sink;
          if (_canceled || sink == null) return;
          sink.add(chunk);
          received += chunk.length;
          sinceFlush += chunk.length;
          onProgress(received, total);

          // Keep memory flat when the disk is slower than the network:
          // stop reading until the buffered bytes are actually written.
          if (sinceFlush >= _flushEvery) {
            sinceFlush = 0;
            final subscription = _subscription;
            subscription?.pause();
            sink.flush().then((_) {
              if (!_canceled) subscription?.resume();
            }).catchError((Object error) {
              if (!completer.isCompleted) completer.completeError(error);
            });
          }
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (Object error) {
          if (!completer.isCompleted) completer.completeError(error);
        },
        cancelOnError: true,
      );

      await completer.future;
      if (_canceled) return;

      await _closeSink();

      if (total > 0 && received < total) {
        throw const HttpException('A transferência terminou antes do esperado');
      }

      final finalPath = await DownloadService.filePath(fileName);
      final finished = File(finalPath);
      if (await finished.exists()) await finished.delete();
      await partFile.rename(finalPath);

      if (_canceled) return;
      onComplete(finalPath);
    } catch (error) {
      try {
        await _subscription?.cancel();
      } catch (_) {}
      _subscription = null;
      await _closeSink();
      if (_canceled) return;
      onError(error);
    } finally {
      if (!_canceled) {
        _canceled = true;
        _client.close();
      }
    }
  }
}
