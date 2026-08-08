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
  static const String _indexKey = 'sabuflix_downloads_index';
  static const String _dirName = 'sabuflix_downloads';

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

  /// Stops the transfer and removes the file from disk.
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
  }

  /// Total bytes occupied by every file in the downloads directory, including
  /// partial ones, so the figure matches what the OS reports.
  Future<int> usedBytes() async {
    try {
      final dir = await downloadsDirectory();
      var total = 0;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<List<DownloadTask>> loadIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_indexKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => DownloadTask.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      // A corrupt index must not brick the screen; start clean instead.
      return [];
    }
  }

  Future<void> saveIndex(List<DownloadTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _indexKey,
      json.encode(tasks.map((t) => t.toJson()).toList()),
    );
  }

  /// Drops index entries whose file vanished (OS cleanup, manual deletion) and
  /// repairs sizes that drifted from what is actually on disk.
  Future<List<DownloadTask>> reconcileWithDisk(List<DownloadTask> tasks) async {
    final kept = <DownloadTask>[];
    for (final task in tasks) {
      try {
        final file = await fileFor(task);
        if (await file.exists()) {
          final length = await file.length();
          if (task.status == DownloadStatus.completed) {
            // A completed file that shrank was truncated; make it resumable.
            if (task.totalBytes > 0 && length < task.totalBytes) {
              task.status = DownloadStatus.paused;
            }
            task.bytesReceived = length;
          } else {
            task.bytesReceived = length;
          }
          kept.add(task);
        } else if (task.status != DownloadStatus.completed) {
          // Never started, or the partial file is gone: keep it queued from 0.
          task.bytesReceived = 0;
          kept.add(task);
        }
        // A completed task with no file left is dropped entirely.
      } catch (_) {
        kept.add(task);
      }
    }
    return kept;
  }
}
