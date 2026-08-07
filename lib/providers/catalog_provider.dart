import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/catalog_cache.dart';
import '../services/tmdb_service.dart';

class CatalogProvider extends ChangeNotifier {
  final TMDBService _tmdbService = TMDBService();
  final CatalogCache _cache = CatalogCache();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  /// True while a background refresh runs over already-visible cached rows.
  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

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

  List<MediaItem> _topRanked = [];
  List<MediaItem> get topRanked => _topRanked;

  CatalogProvider() {
    loadCatalog();
  }

  /// Paints the cached catalog first when there is one, then refreshes behind
  /// it. [forceRefresh] skips the cache — what pull-to-refresh wants.
  Future<void> loadCatalog({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _cache.load();
      if (cached != null && cached['trending']?.isNotEmpty == true) {
        _applyLists(cached);
        _isLoading = false;
        notifyListeners();

        _isRefreshing = true;
        await _fetchAndStore();
        _isRefreshing = false;
        notifyListeners();
        return;
      }
    }

    _isLoading = true;
    notifyListeners();

    await _fetchAndStore();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _fetchAndStore() async {
    try {
      final results = await Future.wait([
        _tmdbService.fetchTrending(mediaType: 'all', timeWindow: 'day'),
        _tmdbService.fetchPopularMovies(),
        _tmdbService.fetchPopularTV(),
        _tmdbService.fetchTopRatedMovies(),
        _tmdbService.fetchByGenre(28, mediaType: 'movie'), // Action
        _tmdbService.fetchByGenre(35, mediaType: 'movie'), // Comedy
        _tmdbService.fetchByGenre(878, mediaType: 'movie'), // Sci-Fi
        _tmdbService.fetchTopRankedInBrazil(),
      ]);

      // A failed fetch comes back empty; keep whatever the cache already
      // painted rather than blanking the screen.
      if (results[0].isEmpty && _trending.isNotEmpty) return;

      _applyLists({
        'trending': results[0],
        'popularMovies': results[1],
        'popularTV': results[2],
        'topRated': results[3],
        'actionMovies': results[4],
        'comedyMovies': results[5],
        'sciFiMovies': results[6],
        'topRanked': results[7],
      });

      if (_trending.isNotEmpty) {
        // Pick first item with backdropPath for Hero Banner
        final selectedHero = _trending.firstWhere(
          (item) => item.backdropPath != null && item.overview != null && item.overview!.isNotEmpty,
          orElse: () => _trending.first,
        );
        final logo = await _tmdbService.fetchLogoPath(selectedHero.id, selectedHero.mediaType);
        _heroItem = selectedHero.copyWith(logoPath: logo);
      }

      await _cache.save({
        'trending': _trending,
        'popularMovies': _popularMovies,
        'popularTV': _popularTV,
        'topRated': _topRated,
        'actionMovies': _actionMovies,
        'comedyMovies': _comedyMovies,
        'sciFiMovies': _sciFiMovies,
        'topRanked': _topRanked,
        if (_heroItem != null) 'hero': [_heroItem!],
      });
    } catch (e) {
      debugPrint('Error loading catalog: $e');
    }
  }

  void _applyLists(Map<String, List<MediaItem>> lists) {
    _trending = lists['trending'] ?? _trending;
    _popularMovies = lists['popularMovies'] ?? _popularMovies;
    _popularTV = lists['popularTV'] ?? _popularTV;
    _topRated = lists['topRated'] ?? _topRated;
    _actionMovies = lists['actionMovies'] ?? _actionMovies;
    _comedyMovies = lists['comedyMovies'] ?? _comedyMovies;
    _sciFiMovies = lists['sciFiMovies'] ?? _sciFiMovies;
    _topRanked = lists['topRanked'] ?? _topRanked;

    final hero = lists['hero'];
    if (hero != null && hero.isNotEmpty) _heroItem = hero.first;
  }

  void setHeroItem(MediaItem item) {
    _heroItem = item;
    notifyListeners();
  }
}
