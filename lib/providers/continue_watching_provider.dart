import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_item.dart';
import '../models/watch_progress.dart';

/// Keeps the "Continuar Assistindo" shelf: what is half-watched, where it
/// stopped, and which source it was playing from.
class ContinueWatchingProvider extends ChangeNotifier {
  static const String _keyPrefix = 'sabuflix_continue_';

  /// Below this the viewer barely started — not worth a shelf slot.
  static const int _minimumSeconds = 30;

  /// How many titles the shelf holds before the oldest drops off.
  static const int _maxEntries = 20;

  List<WatchProgress> _entries = [];
  String _profileKey = 'default';
  bool _isLoading = true;
  bool _hydrated = false;

  ContinueWatchingProvider() {
    loadForProfile(null);
  }

  bool get isLoading => _isLoading;

  /// Most recently watched first.
  List<WatchProgress> get entries => List.unmodifiable(_entries);

  bool get isEmpty => _entries.isEmpty;

  WatchProgress? forMedia(int mediaId) {
    for (final entry in _entries) {
      if (entry.media.id == mediaId) return entry;
    }
    return null;
  }

  Future<void> loadForProfile(String? profileId) async {
    final key = profileId ?? 'default';
    if (_hydrated && key == _profileKey) return;
    _profileKey = key;
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$key');
    if (key != _profileKey) return;
    final restored = <WatchProgress>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is List) {
          for (final entry in decoded) {
            // Skip only the broken record, never the whole shelf.
            try {
              restored.add(WatchProgress.fromJson(
                  Map<String, dynamic>.from(entry as Map)));
            } catch (e) {
              debugPrint('Skipping unreadable watch progress: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('Error decoding watch progress: $e');
      }
    }

    restored.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (key != _profileKey) return;
    _entries = restored;
    _isLoading = false;
    _hydrated = true;
    notifyListeners();
  }

  /// Records playback position. Finished titles drop off the shelf, and a new
  /// episode replaces the previous one from the same series.
  Future<void> record({
    required MediaItem media,
    required int positionSeconds,
    required int durationSeconds,
    int? season,
    int? episode,
    String? episodeTitle,
    String? sourceUrl,
  }) async {
    if (durationSeconds <= 0) return;

    final entry = WatchProgress(
      media: media.forStorage,
      season: season,
      episode: episode,
      episodeTitle: episodeTitle,
      positionSeconds: positionSeconds,
      durationSeconds: durationSeconds,
      sourceUrl: sourceUrl,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    _entries.removeWhere((current) => current.media.id == media.id);

    final tooEarly = positionSeconds < _minimumSeconds;
    if (!entry.isFinished && !tooEarly) {
      _entries.insert(0, entry);
      if (_entries.length > _maxEntries) {
        _entries = _entries.sublist(0, _maxEntries);
      }
    }

    await _persist();
    notifyListeners();
  }

  Future<void> remove(int mediaId) async {
    final before = _entries.length;
    _entries.removeWhere((entry) => entry.media.id == mediaId);
    if (_entries.length == before) return;
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    if (_entries.isEmpty) return;
    _entries = [];
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded =
          json.encode(_entries.map((entry) => entry.toJson()).toList());
      await prefs.setString('$_keyPrefix$_profileKey', encoded);
    } catch (e) {
      debugPrint('Error saving watch progress: $e');
    }
  }
}
