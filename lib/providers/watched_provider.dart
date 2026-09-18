import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_item.dart';

/// Local, profile-aware watched history. Whole titles are stored as small
/// metadata snapshots; individual episodes are tracked separately so a series
/// can show which episodes are done and offer the next one.
class WatchedProvider extends ChangeNotifier {
  static const _keyPrefix = 'sabuflix_watched_';
  static const _episodesKeyPrefix = 'sabuflix_watched_eps_';
  static const _maxEntries = 500;

  final Map<String, MediaItem> _items = {};

  /// `tvId -> { "s1e2", "s1e3", ... }`
  final Map<int, Set<String>> _episodes = {};
  String _profileKey = 'default';
  bool _isLoading = true;

  WatchedProvider() {
    loadForProfile(null);
  }

  bool get isLoading => _isLoading;
  List<MediaItem> get items =>
      List.unmodifiable(_items.values.toList().reversed);

  bool isWatched(int mediaId, {String? mediaType}) =>
      _items.values.any((item) =>
          item.id == mediaId &&
          (mediaType == null || item.mediaType == mediaType));

  static String episodeKey(int season, int episode) => 's${season}e$episode';

  bool isEpisodeWatched(int tvId, int season, int episode) =>
      _episodes[tvId]?.contains(episodeKey(season, episode)) ?? false;

  /// Number of watched episodes in one season.
  int watchedCountInSeason(int tvId, int season) {
    final set = _episodes[tvId];
    if (set == null) return 0;
    return set.where((key) => key.startsWith('s${season}e')).length;
  }

  int watchedEpisodeCount(int tvId) => _episodes[tvId]?.length ?? 0;

  /// The highest watched episode of a series, or `null` when none was marked.
  ({int season, int episode})? lastWatchedEpisode(int tvId) {
    final set = _episodes[tvId];
    if (set == null || set.isEmpty) return null;
    ({int season, int episode})? best;
    for (final key in set) {
      final parsed = _parseKey(key);
      if (parsed == null) continue;
      if (best == null ||
          parsed.season > best.season ||
          (parsed.season == best.season && parsed.episode > best.episode)) {
        best = parsed;
      }
    }
    return best;
  }

  static ({int season, int episode})? _parseKey(String key) {
    final match = RegExp(r'^s(\d+)e(\d+)$').firstMatch(key);
    if (match == null) return null;
    return (
      season: int.parse(match.group(1)!),
      episode: int.parse(match.group(2)!)
    );
  }

  Future<void> loadForProfile(String? profileId) async {
    final key = profileId ?? 'default';
    _profileKey = key;
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$key');
    final rawEpisodes = prefs.getString('$_episodesKeyPrefix$key');
    if (key != _profileKey) return;
    _items.clear();
    _episodes.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is List) {
          for (final value in decoded) {
            try {
              final item =
                  MediaItem.fromJson(Map<String, dynamic>.from(value as Map));
              _items[item.storageKey] = item;
            } catch (error) {
              debugPrint('Skipping unreadable watched item: $error');
            }
          }
        }
      } catch (error) {
        debugPrint('Error decoding watched history: $error');
      }
    }
    if (rawEpisodes != null && rawEpisodes.isNotEmpty) {
      try {
        final decoded = json.decode(rawEpisodes);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final id = int.tryParse(entry.key.toString());
            final list = entry.value;
            if (id == null || list is! List) continue;
            _episodes[id] = list.map((e) => e.toString()).toSet();
          }
        }
      } catch (error) {
        debugPrint('Error decoding watched episodes: $error');
      }
    }

    if (key != _profileKey) return;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> toggle(MediaItem media) async {
    if (_items.containsKey(media.storageKey)) {
      _items.remove(media.storageKey);
    } else {
      _items[media.storageKey] = media.forStorage;
      while (_items.length > _maxEntries) {
        _items.remove(_items.keys.first);
      }
    }
    notifyListeners();
    await _persist();
  }

  Future<void> markWatched(MediaItem media) async {
    if (_items.containsKey(media.storageKey)) return;
    _items[media.storageKey] = media.forStorage;
    notifyListeners();
    await _persist();
  }

  Future<void> markEpisodeWatched(int tvId, int season, int episode) async {
    final set = _episodes.putIfAbsent(tvId, () => <String>{});
    if (!set.add(episodeKey(season, episode))) return;
    notifyListeners();
    await _persistEpisodes();
  }

  Future<void> toggleEpisode(int tvId, int season, int episode) async {
    final set = _episodes.putIfAbsent(tvId, () => <String>{});
    final key = episodeKey(season, episode);
    if (!set.remove(key)) set.add(key);
    if (set.isEmpty) _episodes.remove(tvId);
    notifyListeners();
    await _persistEpisodes();
  }

  /// Marks every episode of a season, e.g. from the season header menu.
  Future<void> markSeasonWatched(int tvId, int season, Iterable<int> episodes,
      {bool watched = true}) async {
    final set = _episodes.putIfAbsent(tvId, () => <String>{});
    for (final episode in episodes) {
      final key = episodeKey(season, episode);
      watched ? set.add(key) : set.remove(key);
    }
    if (set.isEmpty) _episodes.remove(tvId);
    notifyListeners();
    await _persistEpisodes();
  }

  Future<void> clear() async {
    if (_items.isEmpty && _episodes.isEmpty) return;
    _items.clear();
    _episodes.clear();
    notifyListeners();
    await _persist();
    await _persistEpisodes();
  }

  Future<void> _persist() async {
    final key = '$_keyPrefix$_profileKey';
    final encoded = json
        .encode(_items.values.map((item) => item.forStorage.toJson()).toList());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, encoded);
  }

  Future<void> _persistEpisodes() async {
    final key = '$_episodesKeyPrefix$_profileKey';
    final encoded = json.encode({
      for (final entry in _episodes.entries)
        entry.key.toString(): entry.value.toList()..sort(),
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, encoded);
  }
}
