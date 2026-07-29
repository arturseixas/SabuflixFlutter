import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/favorites_service.dart';

class FavoritesProvider extends ChangeNotifier {
  final FavoritesService _favoritesService = FavoritesService();

  List<MediaItem> _favorites = [];
  List<MediaItem> get favorites => _favorites;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  FavoritesProvider() {
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    _isLoading = true;
    notifyListeners();

    _favorites = await _favoritesService.getFavorites();

    _isLoading = false;
    notifyListeners();
  }

  bool isFavorite(int mediaId) {
    return _favorites.any((item) => item.id == mediaId);
  }

  Future<void> toggleFavorite(MediaItem media) async {
    await _favoritesService.toggleFavorite(media);
    await loadFavorites();
  }
}
