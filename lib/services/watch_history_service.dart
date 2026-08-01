import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';
import '../models/watch_history_item.dart';

class WatchHistoryService {
  static const int maxEntries = 50;

  String _getPrefsKey(String? profileId) => 'sabuflix_history_${profileId ?? "default"}';

  Future<List<WatchHistoryItem>> getHistory(String? profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString(_getPrefsKey(profileId));

    if (historyJson != null && historyJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = json.decode(historyJson);
        return decoded.map((item) => WatchHistoryItem.fromJson(item)).toList();
      } catch (e) {
        print('Error decoding watch history: $e');
        return [];
      }
    }
    return [];
  }

  Future<void> _saveHistory(List<WatchHistoryItem> history, String? profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(history.map((item) => item.toJson()).toList());
    await prefs.setString(_getPrefsKey(profileId), encoded);
  }

  /// Adds or updates the playback progress for [media], moving it to the
  /// front of the history (most recently watched first).
  Future<List<WatchHistoryItem>> updateProgress({
    required MediaItem media,
    required double positionSeconds,
    required double durationSeconds,
    int? season,
    int? episode,
    required String? profileId,
  }) async {
    final history = await getHistory(profileId);
    history.removeWhere((item) => item.media.id == media.id);
    history.insert(
      0,
      WatchHistoryItem(
        media: media,
        season: season,
        episode: episode,
        positionSeconds: positionSeconds,
        durationSeconds: durationSeconds,
        watchedAt: DateTime.now(),
      ),
    );

    final trimmed = history.length > maxEntries ? history.sublist(0, maxEntries) : history;
    await _saveHistory(trimmed, profileId);
    return trimmed;
  }

  /// Removes a single title from the watch history.
  Future<List<WatchHistoryItem>> removeFromHistory(int mediaId, String? profileId) async {
    final history = await getHistory(profileId);
    history.removeWhere((item) => item.media.id == mediaId);
    await _saveHistory(history, profileId);
    return history;
  }

  /// Apaga todo o histórico de reprodução do perfil informado.
  Future<void> clearHistory(String? profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getPrefsKey(profileId));
  }
}
