import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';

class CatalogProvider extends ChangeNotifier {
  final TMDBService _tmdbService = TMDBService();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  MediaItem? _heroItem;
  MediaItem? get heroItem => _heroItem;

  List<MediaItem> _trending = [];
  List<MediaItem> get trending => _trending;

  List<MediaItem> _popularMovies = [];
  List<MediaItem> get popularMovies => _popularMovies;

  List<MediaItem> _popularTV = [];
  List<MediaItem> get popularTV => _popularTV;

  List<MediaItem> _topRated = [];
  List<MediaItem> get topRated => _topRated;

  List<MediaItem> _actionMovies = [];
  List<MediaItem> get actionMovies => _actionMovies;

  List<MediaItem> _comedyMovies = [];
  List<MediaItem> get comedyMovies => _comedyMovies;

  List<MediaItem> _sciFiMovies = [];
  List<MediaItem> get sciFiMovies => _sciFiMovies;

  CatalogProvider() {
    loadCatalog();
  }

  Future<void> loadCatalog() async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _tmdbService.fetchTrending(mediaType: 'all', timeWindow: 'day'),
        _tmdbService.fetchPopularMovies(),
        _tmdbService.fetchPopularTV(),
        _tmdbService.fetchTopRatedMovies(),
        _tmdbService.fetchByGenre(28, mediaType: 'movie'), // Action
        _tmdbService.fetchByGenre(35, mediaType: 'movie'), // Comedy
        _tmdbService.fetchByGenre(878, mediaType: 'movie'), // Sci-Fi
      ]);

      _trending = results[0];
      _popularMovies = results[1];
      _popularTV = results[2];
      _topRated = results[3];
      _actionMovies = results[4];
      _comedyMovies = results[5];
      _sciFiMovies = results[6];

      if (_trending.isNotEmpty) {
        // Pick first item with backdropPath for Hero Banner
        _heroItem = _trending.firstWhere(
          (item) => item.backdropPath != null && item.overview != null && item.overview!.isNotEmpty,
          orElse: () => _trending.first,
        );
      }
    } catch (e) {
      print('Error loading catalog: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setHeroItem(MediaItem item) {
    _heroItem = item;
    notifyListeners();
  }
}
