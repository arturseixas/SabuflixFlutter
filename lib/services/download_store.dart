import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'download_service.dart';

/// Persists the download queue itself, as a JSON file next to the
/// downloaded videos.
///
/// This deliberately avoids `shared_preferences` on Android: that plugin
/// writes through `SharedPreferences.Editor.apply()`, which only queues
/// the disk write on a background thread — if the process is killed
/// shortly after (which Android does aggressively when an app is closed,
/// especially on some OEM battery managers), the write can be silently
/// lost even though it looked instant to the app. A plain file write,
/// staged through a temp file and renamed into place, gives every entry
/// (queued, downloading, completed) the same durability guarantee as the
/// video bytes themselves.
class DownloadStore {
  DownloadStore._();

  static const String _fileName = 'downloads.json';

  /// Chains writes so two overlapping saves can never interleave on the
  /// same temp file.
  static Future<void> _writeQueue = Future<void>.value();

  static Future<File> _targetFile() async {
    final dir = await DownloadService.directory();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  static Future<List<Map<String, dynamic>>> read() async {
    try {
      final file = await _targetFile();
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      if (raw.isEmpty) return [];
      final decoded = json.decode(raw) as List<dynamic>;
      return decoded.map((entry) => Map<String, dynamic>.from(entry as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> write(List<Map<String, dynamic>> items) {
    final task = _writeQueue.then((_) => _writeNow(items));
    // A failed write must not jam the queue for whatever is saved next.
    _writeQueue = task.catchError((_) {});
    return task;
  }

  static Future<void> _writeNow(List<Map<String, dynamic>> items) async {
    final target = await _targetFile();
    final tmp = File('${target.path}.tmp');

    final sink = tmp.openWrite();
    sink.write(json.encode(items));
    await sink.flush();
    await sink.close();

    if (await target.exists()) await target.delete();
    await tmp.rename(target.path);
  }
}
