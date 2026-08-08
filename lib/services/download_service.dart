import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/download_item.dart';

/// Filesystem + persistence layer for offline downloads.
///
/// Files live in the app's support directory (never the user's Documents
/// folder), namespaced per profile so two profiles never collide:
/// `<support>/sabuflix_downloads/<profileId>/<downloadId>.<ext>`
class DownloadService {
  static const String _folderName = 'sabuflix_downloads';

  /// Replaces the platform support directory in tests, where the
  /// path_provider plugin has no host implementation to answer.
  @visibleForTesting
  static String? debugRootOverride;

  String _prefsKey(String? profileId) => 'sabuflix_downloads_${profileId ?? "default"}';

  /// Creates (if needed) and returns the downloads directory for a profile.
  Future<Directory> ensureDirectory(String? profileId) async {
    final support = debugRootOverride != null
        ? Directory(debugRootOverride!)
        : await getApplicationSupportDirectory();
    final dir = Directory('${support.path}${Platform.pathSeparator}$_folderName'
        '${Platform.pathSeparator}${profileId ?? "default"}');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  File fileFor(String directoryPath, DownloadItem item) {
    return File('$directoryPath${Platform.pathSeparator}${item.fileName}');
  }

  /// Picks a safe, collision-free file name for a download, keeping the
  /// container extension of the source stream when we can read it.
  String buildFileName(String id, String url) {
    var extension = 'mp4';
    try {
      final segments = Uri.parse(url).path.split('.');
      if (segments.length > 1) {
        final candidate = segments.last.toLowerCase();
        if (RegExp(r'^[a-z0-9]{2,4}$').hasMatch(candidate) &&
            const ['mp4', 'mkv', 'avi', 'mov', 'webm', 'm4v', 'ts'].contains(candidate)) {
          extension = candidate;
        }
      }
    } catch (_) {
      // Malformed URL — fall back to the default container.
    }
    final safeId = id.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    return '$safeId.$extension';
  }

  Future<List<DownloadItem>> load(String? profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey(profileId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> decoded = json.decode(raw);
      return decoded.map((d) => DownloadItem.fromJson(Map<String, dynamic>.from(d))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> save(List<DownloadItem> items, String? profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey(profileId),
      json.encode(items.map((i) => i.toJson()).toList()),
    );
  }

  Future<void> deleteFile(String directoryPath, DownloadItem item) async {
    try {
      final file = fileFor(directoryPath, item);
      if (await file.exists()) await file.delete();
    } catch (e) {
      // A missing or locked file must never block removing the entry.
    }
  }

  /// Human readable size, used all over the downloads UI.
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final decimals = value >= 100 || unit <= 1 ? 0 : 1;
    return '${value.toStringAsFixed(decimals)} ${units[unit]}';
  }
}
