import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';

/// Disk cache for the home screen's rows.
///
/// Without it every cold start blocks on eight TMDB calls behind a full-screen
/// spinner. With it the last catalog paints immediately and the network round
/// trip happens behind the already-visible screen.
class CatalogCache {
  static const String _prefsKey = 'sabuflix_catalog_cache_v1';

  /// Old enough to be worth showing, not old enough to be worth waiting for.
  static const Duration maxAge = Duration(hours: 6);

  Future<Map<String, List<MediaItem>>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored == null || stored.isEmpty) return null;

    try {
      final Map<String, dynamic> decoded = json.decode(stored);
      final savedAt = DateTime.fromMillisecondsSinceEpoch(decoded['saved_at'] ?? 0);
      if (DateTime.now().difference(savedAt) > maxAge) return null;

      final Map<String, dynamic> lists = Map<String, dynamic>.from(decoded['lists'] ?? {});
      return lists.map((name, items) {
        final decodedItems = (items as List)
            .map((item) => MediaItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        return MapEntry(name, decodedItems);
      });
    } catch (e) {
      debugPrint('Error decoding catalog cache: $e');
      return null;
    }
  }

  Future<void> save(Map<String, List<MediaItem>> lists) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.setString(
        _prefsKey,
        json.encode({
          'saved_at': DateTime.now().millisecondsSinceEpoch,
          'lists': lists.map(
            (name, items) => MapEntry(name, items.map((item) => item.toJson()).toList()),
          ),
        }),
      );
    } catch (e) {
      debugPrint('Error writing catalog cache: $e');
    }
  }
}
