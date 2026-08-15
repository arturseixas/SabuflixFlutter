import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/favorites_service.dart';

class FavoritesProvider extends ChangeNotifier {
  final FavoritesService _favoritesService = FavoritesService();

  List<MediaItem> _favorites = [];
  List<MediaItem> get favorites => _favorites;

  bool _isLoading = true;
  bool get isLoading => _isLoading;
  
  String? _currentProfileId;

  FavoritesProvider() {
    loadFavorites(null);
  }

  Future<void> loadFavorites(String? profileId) async {
    _currentProfileId = profileId;
    _isLoading = true;
    notifyListeners();

    _favorites = await _favoritesService.getFavorites(_currentProfileId);

    _isLoading = false;
    notifyListeners();
  }

  bool isFavorite(int mediaId) {
    return _favorites.any((item) => item.id == mediaId);
  }

  Future<void> toggleFavorite(MediaItem media) async {
    await _favoritesService.toggleFavorite(media, _currentProfileId);
    await loadFavorites(_currentProfileId);
  }
}
