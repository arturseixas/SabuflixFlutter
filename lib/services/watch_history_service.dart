import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';
import '../models/watch_history_entry.dart';

class WatchHistoryService {
  static const int maxEntries = 40;

  String _getPrefsKey(String? profileId) => 'sabuflix_watch_history_${profileId ?? "default"}';

  Future<List<WatchHistoryEntry>> getHistory(String? profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString(_getPrefsKey(profileId));

    if (historyJson != null && historyJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = json.decode(historyJson);
        final entries = decoded.map((item) => WatchHistoryEntry.fromJson(item)).toList();
        entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return entries;
      } catch (e) {
        print('Error decoding watch history: $e');
        return [];
      }
    }
    return [];
  }

  Future<void> _saveHistory(List<WatchHistoryEntry> entries, String? profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(entries.map((item) => item.toJson()).toList());
    await prefs.setString(_getPrefsKey(profileId), encoded);
  }

  Future<void> upsert({
    required MediaItem media,
    int? season,
    int? episode,
    required double positionSeconds,
    required double durationSeconds,
    String? profileId,
  }) async {
    final entries = await getHistory(profileId);
    entries.removeWhere((e) => e.media.id == media.id);

    entries.insert(
      0,
      WatchHistoryEntry(
        media: media,
        season: season,
        episode: episode,
        positionSeconds: positionSeconds,
        durationSeconds: durationSeconds,
        updatedAt: DateTime.now(),
      ),
    );

    if (entries.length > maxEntries) {
      entries.removeRange(maxEntries, entries.length);
    }

    await _saveHistory(entries, profileId);
  }

  Future<void> remove(int mediaId, String? profileId) async {
    final entries = await getHistory(profileId);
    entries.removeWhere((e) => e.media.id == mediaId);
    await _saveHistory(entries, profileId);
  }

  Future<void> clear(String? profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getPrefsKey(profileId));
  }
}
