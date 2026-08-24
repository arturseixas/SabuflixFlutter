import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';

class CatalogProvider extends ChangeNotifier {
  static const _catalogCacheKey = 'sabuflix_catalog_cache_v1';
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

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  DateTime? _lastUpdated;
  DateTime? get lastUpdated => _lastUpdated;

  bool get hasContent =>
      _trending.isNotEmpty ||
      _popularMovies.isNotEmpty ||
      _popularTV.isNotEmpty;

  CatalogProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _restoreCache();
    await loadCatalog();
  }

  Future<void> loadCatalog() async {
    _isLoading = !hasContent;
    _errorMessage = null;
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

      if (results.every((items) => items.isEmpty)) {
        throw StateError('O catálogo não retornou nenhum item.');
      }

      _trending = results[0];
      _popularMovies = results[1];
      _popularTV = results[2];
      _topRated = results[3];
      _actionMovies = results[4];
      _comedyMovies = results[5];
      _sciFiMovies = results[6];

      if (_trending.isNotEmpty) {
        // Pick first item with backdropPath for Hero Banner
        final selectedHero = _trending.firstWhere(
          (item) =>
              item.backdropPath != null &&
              item.overview != null &&
              item.overview!.isNotEmpty,
          orElse: () => _trending.first,
        );
        final logo = await _tmdbService.fetchLogoPath(
            selectedHero.id, selectedHero.mediaType);
        _heroItem = selectedHero.copyWith(logoPath: logo);
      }
      _lastUpdated = DateTime.now();
      await _saveCache();
    } catch (e) {
      debugPrint('Error loading catalog: $e');
      _errorMessage = hasContent
          ? 'Sem conexão. Exibindo o último catálogo disponível.'
          : 'Não foi possível carregar o catálogo.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setHeroItem(MediaItem item) {
    _heroItem = item;
    notifyListeners();
  }

  Future<void> _restoreCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_catalogCacheKey);
      if (raw == null || raw.isEmpty) return;
      final data = Map<String, dynamic>.from(json.decode(raw) as Map);
      _trending = _decodeItems(data['trending']);
      _popularMovies = _decodeItems(data['popularMovies']);
      _popularTV = _decodeItems(data['popularTV']);
      _topRated = _decodeItems(data['topRated']);
      _actionMovies = _decodeItems(data['actionMovies']);
      _comedyMovies = _decodeItems(data['comedyMovies']);
      _sciFiMovies = _decodeItems(data['sciFiMovies']);
      final rawHero = data['hero'];
      if (rawHero is Map) {
        _heroItem = MediaItem.fromJson(Map<String, dynamic>.from(rawHero));
      }
      final timestamp = data['updatedAt'] as int?;
      if (timestamp != null) {
        _lastUpdated = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      if (hasContent) {
        _isLoading = false;
        notifyListeners();
      }
    } catch (error) {
      debugPrint('Ignoring unreadable catalogue cache: $error');
    }
  }

  List<MediaItem> _decodeItems(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => MediaItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<Map<String, dynamic>> encode(List<MediaItem> items) =>
          items.take(20).map((item) => item.forStorage.toJson()).toList();
      await prefs.setString(
        _catalogCacheKey,
        json.encode({
          'trending': encode(_trending),
          'popularMovies': encode(_popularMovies),
          'popularTV': encode(_popularTV),
          'topRated': encode(_topRated),
          'actionMovies': encode(_actionMovies),
          'comedyMovies': encode(_comedyMovies),
          'sciFiMovies': encode(_sciFiMovies),
          'hero': _heroItem?.forStorage.toJson(),
          'updatedAt': _lastUpdated?.millisecondsSinceEpoch,
        }),
      );
    } catch (error) {
      debugPrint('Unable to cache catalogue: $error');
    }
  }
}
