import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';

class FavoritesService {
  String _getPrefsKey(String? profileId) =>
      'sabuflix_favorites_${profileId ?? "default"}';

  Future<List<MediaItem>> getFavorites(String? profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? favoritesJson = prefs.getString(_getPrefsKey(profileId));

    if (favoritesJson != null && favoritesJson.isNotEmpty) {
      final restored = <MediaItem>[];
      try {
        final decoded = json.decode(favoritesJson);
        if (decoded is List) {
          for (final entry in decoded) {
            // Decode entry by entry: a single malformed record must never
            // take the whole list down with it.
            try {
              restored.add(
                  MediaItem.fromJson(Map<String, dynamic>.from(entry as Map)));
            } catch (e) {
              debugPrint('Skipping unreadable favorite: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('Error decoding favorites: $e');
      }
      return restored;
    }
    return [];
  }

  Future<void> saveFavorites(
      List<MediaItem> favorites, String? profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded =
        json.encode(favorites.map((item) => item.forStorage.toJson()).toList());
    await prefs.setString(_getPrefsKey(profileId), encoded);
  }

  Future<bool> isFavorite(int mediaId, String? profileId) async {
    final favorites = await getFavorites(profileId);
    return favorites.any((item) => item.id == mediaId);
  }

  Future<void> toggleFavorite(MediaItem media, String? profileId) async {
    final favorites = await getFavorites(profileId);
    final existingIndex = favorites.indexWhere((item) => item.id == media.id);

    if (existingIndex >= 0) {
      favorites.removeAt(existingIndex);
    } else {
      favorites.add(media);
    }

    await saveFavorites(favorites, profileId);
  }
}
