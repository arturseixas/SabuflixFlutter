import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';

class FavoritesService {
  String _getPrefsKey(String? profileId) => 'sabuflix_favorites_${profileId ?? "default"}';

  Future<List<MediaItem>> getFavorites(String? profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? favoritesJson = prefs.getString(_getPrefsKey(profileId));

    if (favoritesJson != null && favoritesJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = json.decode(favoritesJson);
        return decoded.map((item) => MediaItem.fromJson(item)).toList();
      } catch (e) {
        print('Error decoding favorites: $e');
        return [];
      }
    }
    return [];
  }

  Future<void> saveFavorites(List<MediaItem> favorites, String? profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(favorites.map((item) => item.toJson()).toList());
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
