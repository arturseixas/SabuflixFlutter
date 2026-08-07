import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../models/watch_progress.dart';
import '../services/watch_history_service.dart';

class WatchHistoryProvider extends ChangeNotifier {
  final WatchHistoryService _service = WatchHistoryService();

  List<WatchProgress> _entries = [];

  /// Most recently watched first.
  List<WatchProgress> get entries => List.unmodifiable(_entries);

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _currentProfileId;

  WatchHistoryProvider() {
    loadForProfile(null);
  }

  Future<void> loadForProfile(String? profileId) async {
    _currentProfileId = profileId;
    _isLoading = true;
    notifyListeners();

    _entries = await _service.load(profileId);
    _entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    _isLoading = false;
    notifyListeners();
  }

  WatchProgress? progressFor(int mediaId) {
    for (final entry in _entries) {
      if (entry.media.id == mediaId) return entry;
    }
    return null;
  }

  /// Records where playback stopped. A title that was barely started or was
  /// watched to the end is dropped instead of stored, so the row only ever
  /// holds things actually worth resuming.
  Future<void> record({
    required MediaItem media,
    required Duration position,
    required Duration duration,
    int? season,
    int? episode,
    String? videoUrl,
  }) async {
    final entry = WatchProgress(
      media: media,
      position: position,
      duration: duration,
      season: season,
      episode: episode,
      videoUrl: videoUrl,
      updatedAt: DateTime.now(),
    );

    final hadEntry = _entries.any((e) => e.media.id == media.id);
    if (!entry.isWorthResuming && !hadEntry) return;

    _entries.removeWhere((e) => e.media.id == media.id);
    if (entry.isWorthResuming) _entries.insert(0, entry);

    await _service.save(_entries, _currentProfileId);
    notifyListeners();
  }

  Future<void> remove(int mediaId) async {
    final before = _entries.length;
    _entries.removeWhere((entry) => entry.media.id == mediaId);
    if (_entries.length == before) return;

    await _service.save(_entries, _currentProfileId);
    notifyListeners();
  }

  Future<void> clear() async {
    if (_entries.isEmpty) return;
    _entries = [];
    await _service.save(_entries, _currentProfileId);
    notifyListeners();
  }
}
