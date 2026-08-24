import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_item.dart';

/// Local, profile-aware watched history inspired by Nuvio's watch-state
/// actions. Only small metadata snapshots are persisted.
class WatchedProvider extends ChangeNotifier {
  static const _keyPrefix = 'sabuflix_watched_';
  static const _maxEntries = 500;

  final Map<int, MediaItem> _items = {};
  String _profileKey = 'default';
  bool _isLoading = true;

  WatchedProvider() {
    loadForProfile(null);
  }

  bool get isLoading => _isLoading;
  List<MediaItem> get items =>
      List.unmodifiable(_items.values.toList().reversed);

  bool isWatched(int mediaId) => _items.containsKey(mediaId);

  Future<void> loadForProfile(String? profileId) async {
    final key = profileId ?? 'default';
    _profileKey = key;
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$key');
    if (key != _profileKey) return;
    _items.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is List) {
          for (final value in decoded) {
            try {
              final item =
                  MediaItem.fromJson(Map<String, dynamic>.from(value as Map));
              _items[item.id] = item;
            } catch (error) {
              debugPrint('Skipping unreadable watched item: $error');
            }
          }
        }
      } catch (error) {
        debugPrint('Error decoding watched history: $error');
      }
    }

    if (key != _profileKey) return;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> toggle(MediaItem media) async {
    if (_items.containsKey(media.id)) {
      _items.remove(media.id);
    } else {
      _items[media.id] = media.forStorage;
      while (_items.length > _maxEntries) {
        _items.remove(_items.keys.first);
      }
    }
    notifyListeners();
    await _persist();
  }

  Future<void> markWatched(MediaItem media) async {
    if (_items.containsKey(media.id)) return;
    _items[media.id] = media.forStorage;
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_keyPrefix$_profileKey',
      json.encode(
          _items.values.map((item) => item.forStorage.toJson()).toList()),
    );
  }
}
