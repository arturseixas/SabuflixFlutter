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
  Future<void> _pending = Future.value();

  FavoritesProvider() {
    loadFavorites(null);
  }

  Future<void> loadFavorites(String? profileId) async {
    _currentProfileId = profileId;
    _isLoading = true;
    notifyListeners();

    final favorites = await _favoritesService.getFavorites(profileId);
    if (_currentProfileId != profileId) return;
    _favorites = favorites;

    _isLoading = false;
    notifyListeners();
  }

  bool isFavorite(int mediaId, {String? mediaType}) {
    return _favorites.any((item) =>
        item.id == mediaId &&
        (mediaType == null || item.mediaType == mediaType));
  }

  Future<void> toggleFavorite(MediaItem media) {
    final profile = _currentProfileId;
    final operation = _pending.then((_) async {
      await _favoritesService.toggleFavorite(media, profile);
      if (_currentProfileId == profile) await loadFavorites(profile);
    });
    _pending = operation.catchError((Object _) {});
    return operation;
  }
}
