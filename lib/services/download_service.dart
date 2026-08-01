import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

  /// Tests exercise multiple mocked "app support directories" in the same
  /// process — this drops the cache so `directory()` re-resolves instead
  /// of reusing whatever the previous test's mock returned.
  @visibleForTesting
  static void resetCacheForTesting() => _cachedDir = null;

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

  static const String _logFileName = 'debug.log';
  static const int _maxLogLines = 300;
  static Future<void> _logQueue = Future<void>.value();

  /// Appends a timestamped line to a small on-disk trail of what the
  /// download system did and when. There is no other window into a
  /// user's real device once something goes wrong, so this is the only
  /// way to tell, after the fact, whether e.g. a save actually ran or
  /// the resolved storage path changed between launches.
  static Future<void> log(String message) {
    final line = '${DateTime.now().toIso8601String()} $message';
    final task = _logQueue.then((_) async {
      try {
        final dir = await directory();
        final file = File('${dir.path}${Platform.pathSeparator}$_logFileName');
        final existing = await file.exists() ? await file.readAsLines() : <String>[];
        existing.add(line);
        final trimmed = existing.length > _maxLogLines
            ? existing.sublist(existing.length - _maxLogLines)
            : existing;
        await file.writeAsString(trimmed.join('\n'));
      } catch (_) {
        // A logging failure must never take down the actual feature.
      }
    });
    _logQueue = task;
    return task;
  }

  static Future<String> readLog() async {
    try {
      final dir = await directory();
      final file = File('${dir.path}${Platform.pathSeparator}$_logFileName');
      if (!await file.exists()) return '(sem log ainda)';
      return await file.readAsString();
    } catch (e) {
      return '(erro ao ler log: $e)';
    }
  }

  /// Plain-text snapshot of the download storage — resolved directory,
  /// whether the persisted queue file is there, and what's actually on
  /// disk. Meant to be copy-pasted by a user reporting a bug, since we
  /// have no other window into their device's real filesystem state.
  static Future<String> diagnostics() async {
    final buffer = StringBuffer();
    try {
      final dir = await directory();
      buffer.writeln('Pasta: ${dir.path}');
      buffer.writeln('Pasta existe: ${await dir.exists()}');

      final entries = await dir.exists() ? await dir.list().toList() : <FileSystemEntity>[];
      buffer.writeln('Arquivos na pasta (${entries.length}):');
      for (final entry in entries) {
        if (entry is File) {
          final size = await entry.length();
          buffer.writeln('  - ${entry.path.split(Platform.pathSeparator).last}  ($size bytes)');
        } else {
          buffer.writeln('  - ${entry.path.split(Platform.pathSeparator).last}/ (pasta)');
        }
      }

      final storeFile = File('${dir.path}${Platform.pathSeparator}downloads.json');
      buffer.writeln('downloads.json existe: ${await storeFile.exists()}');
      if (await storeFile.exists()) {
        final content = await storeFile.readAsString();
        buffer.writeln('downloads.json tamanho: ${content.length} caracteres');
        buffer.writeln('downloads.json conteúdo:');
        buffer.writeln(content);
      }

      buffer.writeln();
      buffer.writeln('--- log de eventos ---');
      buffer.writeln(await readLog());
    } catch (e, st) {
      buffer.writeln('Erro ao coletar diagnóstico: $e');
      buffer.writeln(st.toString());
    }
    return buffer.toString();
  }

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
