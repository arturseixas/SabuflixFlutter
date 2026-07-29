import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';

class FavoritesService {
  static const String _storageKey = 'sabuflix_favorites';

  Future<List<MediaItem>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final String? favoritesJson = prefs.getString(_storageKey);
    if (favoritesJson != null && favoritesJson.isNotEmpty) {
      try {
        final List decoded = json.decode(favoritesJson);
        return decoded.map((item) => MediaItem.fromJson(item)).toList();
      } catch (e) {
        print('Error reading favorites: $e');
      }
    }
    return [];
  }

  Future<bool> isFavorite(int mediaId) async {
    final favorites = await getFavorites();
    return favorites.any((item) => item.id == mediaId);
  }

  Future<void> toggleFavorite(MediaItem media) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavorites();
    final index = favorites.indexWhere((item) => item.id == media.id);

    if (index >= 0) {
      favorites.removeAt(index);
    } else {
      favorites.add(media);
    }

    final String encoded = json.encode(favorites.map((item) => item.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
