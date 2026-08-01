import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_item.dart';

/// Handles the actual bytes-to-disk transfer plus the persisted metadata list.
/// Downloads are resumable: partial data is kept in a "<file>.part" sidecar and
/// continued with a HTTP Range request when the user resumes.
class DownloadService {
  final http.Client _client = http.Client();

  String _getPrefsKey(String? profileId) => 'sabuflix_downloads_${profileId ?? "default"}';

  /// App-private folder — no storage permission needed on any platform.
  Future<Directory> getDownloadsDirectory() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}downloads');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Builds the destination path for a title, deriving the extension from the
  /// source URL (falling back to .mp4 when the URL carries no useful hint).
  Future<String> buildFilePath({required String id, required String sourceUrl}) async {
    final dir = await getDownloadsDirectory();
    String extension = '.mp4';
    try {
      final urlPath = Uri.parse(sourceUrl).path;
      final dotIndex = urlPath.lastIndexOf('.');
      if (dotIndex != -1 && urlPath.length - dotIndex <= 5) {
        extension = urlPath.substring(dotIndex);
      }
    } catch (_) {
      // keep the default
    }
    final safeId = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return '${dir.path}${Platform.pathSeparator}$safeId$extension';
  }

  Future<List<DownloadItem>> getDownloads(String? profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? downloadsJson = prefs.getString(_getPrefsKey(profileId));

    if (downloadsJson != null && downloadsJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = json.decode(downloadsJson);
        return decoded.map((item) => DownloadItem.fromJson(item)).toList();
      } catch (e) {
        print('Error decoding downloads: $e');
        return [];
      }
    }
    return [];
  }

  Future<void> saveDownloads(List<DownloadItem> downloads, String? profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(downloads.map((item) => item.toJson()).toList());
    await prefs.setString(_getPrefsKey(profileId), encoded);
  }

  /// Deletes both the finished file and any partial data for [item].
  Future<void> deleteFiles(DownloadItem item) async {
    for (final path in [item.filePath, '${item.filePath}.part']) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (e) {
        print('Error deleting download file $path: $e');
      }
    }
  }

  /// Streams [item]'s source into its .part file, resuming from whatever was
  /// already fetched. Returns true when the file finished, false when the
  /// transfer was interrupted by [isCancelled] (progress is kept for a resume).
  /// Throws on network/server errors so the caller can mark it as failed.
  Future<bool> download({
    required DownloadItem item,
    required void Function(int received, int total) onProgress,
    required bool Function() isCancelled,
  }) async {
    final partialFile = File('${item.filePath}.part');
    int alreadyHave = await partialFile.exists() ? await partialFile.length() : 0;

    final request = http.Request('GET', Uri.parse(item.sourceUrl));
    if (alreadyHave > 0) {
      request.headers['Range'] = 'bytes=$alreadyHave-';
    }

    final response = await _client.send(request);

    if (response.statusCode != 200 && response.statusCode != 206) {
      throw HttpException('Servidor respondeu ${response.statusCode}');
    }

    // Server ignored our Range request — start over from byte zero.
    if (response.statusCode == 200 && alreadyHave > 0) {
      await partialFile.delete();
      alreadyHave = 0;
    }

    final total = (response.contentLength ?? 0) + alreadyHave;
    final sink = partialFile.openWrite(mode: alreadyHave > 0 ? FileMode.append : FileMode.write);

    int received = alreadyHave;
    bool cancelled = false;

    try {
      await for (final chunk in response.stream) {
        if (isCancelled()) {
          cancelled = true;
          break;
        }
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      }
    } finally {
      await sink.close();
    }

    if (cancelled) return false;

    await partialFile.rename(item.filePath);
    return true;
  }

  void dispose() {
    _client.close();
  }
}
