import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/download_task.dart';

/// Thrown internally when a transfer stops because the user paused it, so the
/// queue can tell a deliberate pause apart from a genuine failure.
class DownloadPausedException implements Exception {
  const DownloadPausedException();
  @override
  String toString() => 'Download pausado';
}

/// What the downloads directory actually contains, independent of whatever
/// the app thinks it has. Shown in the Downloads tab so a mismatch between
/// disk and library is visible instead of having to be guessed at.
class DownloadDiagnostics {
  final String directory;
  final int mediaFiles;
  final int metadataFiles;
  final int mediaBytes;
  final String? error;

  const DownloadDiagnostics({
    required this.directory,
    required this.mediaFiles,
    required this.metadataFiles,
    required this.mediaBytes,
    this.error,
  });
}

/// A transfer currently in flight, kept so it can be stopped cleanly.
class _ActiveTransfer {
  final http.Client client;
  final IOSink sink;
  final Completer<void> completer = Completer<void>();
  StreamSubscription<List<int>>? subscription;
  bool pausedByUser = false;

  _ActiveTransfer(this.client, this.sink);
}

/// Disk and network side of offline downloads.
///
/// Files live in an app-private directory, which means no storage permission
/// is needed on any platform and the OS reclaims everything if the app is
/// uninstalled. Partial files are kept on disk so an interrupted transfer
/// resumes with an HTTP range request instead of starting over.
class DownloadService {
  /// Only read now, to migrate libraries saved by the previous version.
  static const String _indexKey = 'sabuflix_downloads_index';
  static const String _dirName = 'sabuflix_downloads';
  static const String _indexFileName = 'index.json';
  static const String _metaSuffix = '.meta.json';

  final Map<String, _ActiveTransfer> _transfers = {};

  Directory? _cachedDir;

  /// Directory holding the downloaded media files, created on first use.
  Future<Directory> downloadsDirectory() async {
    final cached = _cachedDir;
    if (cached != null && await cached.exists()) return cached;

    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _dirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cachedDir = dir;
    return dir;
  }

  /// Absolute path of a task's file. Resolved on demand rather than stored,
  /// because the app container path can change between launches.
  Future<String> filePathFor(DownloadTask task) async {
    final dir = await downloadsDirectory();
    return p.join(dir.path, task.fileName);
  }

  Future<File> fileFor(DownloadTask task) async =>
      File(await filePathFor(task));

  /// Picks a file name from the source URL, falling back to .mp4 when the URL
  /// carries no usable extension (common with tokenised CDN links).
  static String buildFileName(String id, String url) {
    var extension = '';
    try {
      final path = Uri.parse(url).path;
      final ext = p.extension(path);
      // Guard against query-string junk being read as an extension.
      if (ext.isNotEmpty && ext.length <= 5 && RegExp(r'^\.[A-Za-z0-9]+$').hasMatch(ext)) {
        extension = ext.toLowerCase();
      }
    } catch (_) {
      // Malformed URL: fall through to the default extension.
    }
    if (extension.isEmpty) extension = '.mp4';
    return '$id$extension';
  }

  /// Downloads [task] to disk, resuming from whatever is already there.
  ///
  /// [onProgress] fires as bytes land. Completes normally when the file is
  /// fully written, throws [DownloadPausedException] if the user paused, and
  /// rethrows any transport error otherwise.
  Future<void> start(
    DownloadTask task, {
    required void Function(int received, int total) onProgress,
  }) async {
    // A stale transfer for the same task would fight over the same file.
    await pause(task.id);

    final file = await fileFor(task);
    int existing = 0;
    if (await file.exists()) {
      existing = await file.length();
    }

    final client = http.Client();
    late final http.StreamedResponse response;

    try {
      final request = http.Request('GET', Uri.parse(task.url));
      if (existing > 0) {
        request.headers['range'] = 'bytes=$existing-';
      }
      response = await client.send(request);
    } catch (e) {
      client.close();
      rethrow;
    }

    if (response.statusCode != HttpStatus.ok &&
        response.statusCode != HttpStatus.partialContent) {
      client.close();
      throw HttpException(
        'O servidor respondeu ${response.statusCode}',
        uri: Uri.tryParse(task.url),
      );
    }

    // Only a 206 honours our range request. A 200 means the server ignored it
    // and is sending the whole file, so the partial bytes must be discarded.
    final resuming =
        response.statusCode == HttpStatus.partialContent && existing > 0;
    if (!resuming) existing = 0;

    final total = _resolveTotalBytes(response, existing);

    final sink = file.openWrite(
      mode: resuming ? FileMode.append : FileMode.write,
    );

    final transfer = _ActiveTransfer(client, sink);
    _transfers[task.id] = transfer;

    var received = existing;
    onProgress(received, total);

    transfer.subscription = response.stream.listen(
      (chunk) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      },
      onDone: () async {
        await _closeTransfer(task.id, transfer);
        if (!transfer.completer.isCompleted) transfer.completer.complete();
      },
      onError: (Object error, StackTrace stackTrace) async {
        await _closeTransfer(task.id, transfer);
        if (!transfer.completer.isCompleted) {
          transfer.completer.completeError(error, stackTrace);
        }
      },
      cancelOnError: true,
    );

    return transfer.completer.future;
  }

  /// Reads the true total size, preferring Content-Range because on a resumed
  /// transfer Content-Length only covers the remaining slice.
  int _resolveTotalBytes(http.StreamedResponse response, int existing) {
    final contentRange = response.headers['content-range'];
    if (contentRange != null) {
      final match = RegExp(r'/(\d+)\s*$').firstMatch(contentRange);
      if (match != null) {
        final parsed = int.tryParse(match.group(1)!);
        if (parsed != null && parsed > 0) return parsed;
      }
    }
    final length = response.contentLength;
    if (length != null && length > 0) return length + existing;
    return 0;
  }

  Future<void> _closeTransfer(String id, _ActiveTransfer transfer) async {
    _transfers.remove(id);
    try {
      await transfer.sink.flush();
    } catch (_) {
      // Sink already broken; closing below is what matters.
    }
    try {
      await transfer.sink.close();
    } catch (_) {
      // Nothing actionable — the file keeps whatever reached the disk.
    }
    transfer.client.close();
  }

  /// Stops an in-flight transfer but keeps the partial file for resuming.
  Future<void> pause(String id) async {
    final transfer = _transfers[id];
    if (transfer == null) return;

    transfer.pausedByUser = true;
    await transfer.subscription?.cancel();
    await _closeTransfer(id, transfer);

    // Cancelling the subscription means onDone never fires, so the future
    // waiting on this transfer has to be settled here.
    if (!transfer.completer.isCompleted) {
      transfer.completer.completeError(const DownloadPausedException());
    }
  }

  bool isTransferring(String id) => _transfers.containsKey(id);

  /// Stops the transfer and removes both the media file and its metadata.
  Future<void> deleteFile(DownloadTask task) async {
    await pause(task.id);
    try {
      final file = await fileFor(task);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // A file we cannot delete should not block removing the entry.
    }
    await deleteTaskMeta(task);
  }

  /// Total bytes occupied by every file in the downloads directory, including
  /// partial ones, so the figure matches what the OS reports.
  Future<int> usedBytes() async {
    try {
      final dir = await downloadsDirectory();
      var total = 0;
      await for (final entity in dir.list(followLinks: false)) {
        // Metadata is bookkeeping, not media; counting it would misreport
        // what the downloads actually cost the user.
        if (entity is File) {
          final name = p.basename(entity.path);
          if (!name.startsWith(_indexFileName) && !name.endsWith(_metaSuffix)) {
            total += await entity.length();
          }
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<File> _indexFile() async {
    final dir = await downloadsDirectory();
    return File(p.join(dir.path, _indexFileName));
  }

  /// Metadata file sitting next to a task's media file.
  Future<File> _metaFileFor(DownloadTask task) async {
    final dir = await downloadsDirectory();
    return File(p.join(dir.path, '${task.id}$_metaSuffix'));
  }

  /// Rebuilds the library by scanning the downloads directory.
  ///
  /// Each download carries its own metadata file beside its media file, so the
  /// directory itself is the source of truth. Two earlier attempts to fix
  /// downloads disappearing kept a single index — one key in SharedPreferences,
  /// then one index.json — and losing that one object still lost everything.
  /// Per-item metadata cannot fail that way: whatever files survived describe
  /// themselves, and anything unreadable costs only its own entry.
  Future<List<DownloadTask>> loadIndex() async {
    final scanned = await _scanMetaFiles();
    if (scanned.isNotEmpty) return scanned;

    // Nothing scanned: adopt whatever the older single-index versions left
    // behind, then write it out as per-item metadata.
    final migrated = await _readIndexFile() ?? await _readLegacyIndex();
    if (migrated.isNotEmpty) {
      await saveIndex(migrated);
    }
    return migrated;
  }

  Future<List<DownloadTask>> _scanMetaFiles() async {
    final tasks = <DownloadTask>[];
    try {
      final dir = await downloadsDirectory();
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File || !entity.path.endsWith(_metaSuffix)) continue;
        try {
          final raw = await entity.readAsString();
          final decoded = json.decode(raw);
          if (decoded is Map) {
            tasks.add(DownloadTask.fromJson(Map<String, dynamic>.from(decoded)));
          }
        } catch (_) {
          // One damaged metadata file must not cost the whole library.
        }
      }
    } catch (_) {
      return tasks;
    }
    tasks.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return tasks;
  }

  /// Returns null when there is no readable legacy index file.
  Future<List<DownloadTask>?> _readIndexFile() async {
    try {
      final file = await _indexFile();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      return _decodeTasks(raw);
    } catch (_) {
      return null;
    }
  }

  Future<List<DownloadTask>> _readLegacyIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_indexKey);
      if (raw == null || raw.isEmpty) return [];
      return _decodeTasks(raw);
    } catch (_) {
      return [];
    }
  }

  List<DownloadTask> _decodeTasks(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => DownloadTask.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      // A corrupt index must not brick the screen.
      return [];
    }
  }

  /// Writes one metadata file per task and removes the ones that no longer
  /// have a task, so the directory always mirrors the library exactly.
  ///
  /// Each write goes through a temporary file that is renamed into place, so
  /// an interrupted write leaves the previous metadata intact rather than a
  /// truncated file.
  Future<void> saveIndex(List<DownloadTask> tasks) async {
    final dir = await downloadsDirectory();

    for (final task in tasks) {
      await saveTask(task);
    }

    final live = tasks.map((t) => '${t.id}$_metaSuffix').toSet();
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.endsWith(_metaSuffix) && !live.contains(name)) {
        try {
          await entity.delete();
        } catch (_) {
          // A stale metadata file is harmless; it is filtered on the next scan.
        }
      }
    }
  }

  /// Persists a single task's metadata.
  Future<void> saveTask(DownloadTask task) async {
    final file = await _metaFileFor(task);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(json.encode(task.toJson()), flush: true);
    await temp.rename(file.path);
  }

  /// Removes a task's metadata file.
  Future<void> deleteTaskMeta(DownloadTask task) async {
    try {
      final file = await _metaFileFor(task);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Nothing to do; a leftover entry is dropped on the next full save.
    }
  }

  /// Facts about what is actually on disk, for the diagnostics panel.
  Future<DownloadDiagnostics> diagnostics() async {
    try {
      final dir = await downloadsDirectory();
      var media = 0;
      var metas = 0;
      var bytes = 0;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (name.endsWith(_metaSuffix)) {
          metas++;
        } else if (!name.startsWith(_indexFileName)) {
          media++;
          bytes += await entity.length();
        }
      }
      return DownloadDiagnostics(
        directory: dir.path,
        mediaFiles: media,
        metadataFiles: metas,
        mediaBytes: bytes,
      );
    } catch (e) {
      return DownloadDiagnostics(
        directory: 'indisponível',
        mediaFiles: 0,
        metadataFiles: 0,
        mediaBytes: 0,
        error: e.toString(),
      );
    }
  }

  /// Realigns the index with what is actually on disk.
  ///
  /// Entries are never dropped here. An earlier version deleted completed
  /// tasks whose file was missing, which meant a single bad path resolution
  /// silently wiped the whole library on launch. A missing file is now
  /// surfaced as a failed download the user can see and retry, because losing
  /// the file should never also lose the record of it.
  Future<List<DownloadTask>> reconcileWithDisk(List<DownloadTask> tasks) async {
    for (final task in tasks) {
      try {
        final file = await fileFor(task);
        if (await file.exists()) {
          final length = await file.length();
          task.bytesReceived = length;
          // A completed file that shrank was truncated; make it resumable.
          if (task.status == DownloadStatus.completed &&
              task.totalBytes > 0 &&
              length < task.totalBytes) {
            task.status = DownloadStatus.paused;
          }
        } else if (task.status == DownloadStatus.completed) {
          task.status = DownloadStatus.failed;
          task.bytesReceived = 0;
          task.error = 'Arquivo não encontrado no dispositivo';
        } else {
          // Never started, or the partial file is gone: restart from zero.
          task.bytesReceived = 0;
        }
      } catch (_) {
        // Unreadable path: leave the entry exactly as stored.
      }
    }
    return tasks;
  }
}
