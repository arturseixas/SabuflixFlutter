import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../models/watch_history_entry.dart';
import '../services/watch_history_service.dart';

class WatchHistoryProvider extends ChangeNotifier {
  final WatchHistoryService _service = WatchHistoryService();

  List<WatchHistoryEntry> _history = [];
  List<WatchHistoryEntry> get history => _history;

  /// Entries with meaningful progress, most recent first — for the "Continue Watching" row.
  List<WatchHistoryEntry> get continueWatching =>
      _history.where((e) => !e.isFinished && e.positionSeconds > 15).toList();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _currentProfileId;

  WatchHistoryProvider() {
    loadHistory(null);
  }

  Future<void> loadHistory(String? profileId) async {
    _currentProfileId = profileId;
    _isLoading = true;
    notifyListeners();

    _history = await _service.getHistory(_currentProfileId);

    _isLoading = false;
    notifyListeners();
  }

  WatchHistoryEntry? entryFor(int mediaId) {
    try {
      return _history.firstWhere((e) => e.media.id == mediaId);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProgress({
    required MediaItem media,
    int? season,
    int? episode,
    required double positionSeconds,
    required double durationSeconds,
  }) async {
    if (durationSeconds <= 0) return;
    await _service.upsert(
      media: media,
      season: season,
      episode: episode,
      positionSeconds: positionSeconds,
      durationSeconds: durationSeconds,
      profileId: _currentProfileId,
    );
    _history = await _service.getHistory(_currentProfileId);
    notifyListeners();
  }

  Future<void> removeEntry(int mediaId) async {
    await _service.remove(mediaId, _currentProfileId);
    await loadHistory(_currentProfileId);
  }

  Future<void> clearHistory() async {
    await _service.clear(_currentProfileId);
    await loadHistory(_currentProfileId);
  }
}
