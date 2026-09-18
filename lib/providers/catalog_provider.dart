import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';

/// One shelf on the home screen.
class CatalogSection {
  final String key;
  final String title;
  final List<MediaItem> items;

  /// `movie`, `tv` or `mixed`, so the Filmes / Séries filter knows what to keep.
  final String kind;

  /// Top 10 shelves draw ranking numbers.
  final bool ranked;

  /// Shelves that show future releases skip the "hide unreleased" filter.
  final bool allowUnreleased;

  /// Server catalogues: titles known to have sources right now.
  final bool fromServer;

  const CatalogSection({
    required this.key,
    required this.title,
    required this.items,
    required this.kind,
    this.ranked = false,
    this.allowUnreleased = false,
    this.fromServer = false,
  });
}

class CatalogProvider extends ChangeNotifier {
  static const _catalogCacheKey = 'sabuflix_catalog_cache_v4';
  static const int heroCount = 5;
  final TMDBService _tmdbService;
  final Map<String, List<MediaItem>> fenixCatalogs = {};
  static const _fenixSections = [
    ('Filmes em destaque', 'movie', 'populares_fenix'),
    ('Séries em destaque', 'series', 'populares_fenix'),
    ('Filmes recém-adicionados', 'movie', 'recentes_servidor'),
    ('Séries recém-adicionadas', 'series', 'recentes_servidor'),
  ];
  bool _loadingFenix = false;

  Future<void> _loadFenix() async {
    if (_loadingFenix) return;
    _loadingFenix = true;
    try {
      final newCatalogs = <String, List<MediaItem>>{};
      await Future.wait(
        _fenixSections.map((section) async {
          final items = await _tmdbService.fetchFenixCatalog(
            section.$2,
            section.$3,
          );
          if (_disposed || items.isEmpty) return;
          newCatalogs[section.$1] = items;
        }),
      );
      if (!_disposed) {
        fenixCatalogs.removeWhere(
          (k, _) => k.toLowerCase().contains('fenixflix'),
        );
        fenixCatalogs.addAll(newCatalogs);
        notifyListeners();
        await _saveCache();
      }
    } finally {
      _loadingFenix = false;
    }
  }

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  MediaItem? _heroItem;
  MediaItem? get heroItem => _heroItem;

  /// Trending titles with artwork and a logo, for the hero carousel.
  List<MediaItem> _heroes = [];
  List<MediaItem> get heroes => _heroes;

  List<MediaItem> _trending = [];
  List<MediaItem> get trending => _trending;

  List<MediaItem> _popularMovies = [];
  List<MediaItem> get popularMovies => _popularMovies;

  List<MediaItem> _popularTV = [];
  List<MediaItem> get popularTV => _popularTV;

  List<MediaItem> _topRated = [];
  List<MediaItem> get topRated => _topRated;

  List<MediaItem> _topRatedTV = [];
  List<MediaItem> get topRatedTV => _topRatedTV;

  List<MediaItem> _actionMovies = [];
  List<MediaItem> get actionMovies => _actionMovies;

  List<MediaItem> _comedyMovies = [];
  List<MediaItem> get comedyMovies => _comedyMovies;

  List<MediaItem> _sciFiMovies = [];
  List<MediaItem> get sciFiMovies => _sciFiMovies;

  List<MediaItem> _animation = [];
  List<MediaItem> get animation => _animation;

  List<MediaItem> _horror = [];
  List<MediaItem> get horror => _horror;

  List<MediaItem> _documentaries = [];
  List<MediaItem> get documentaries => _documentaries;

  List<MediaItem> _family = [];
  List<MediaItem> get family => _family;

  List<MediaItem> _upcoming = [];
  List<MediaItem> get upcoming => _upcoming;

  List<MediaItem> _nowPlaying = [];
  List<MediaItem> get nowPlaying => _nowPlaying;

  List<MediaItem> _onTheAir = [];
  List<MediaItem> get onTheAir => _onTheAir;

  List<MediaItem> _brazilian = [];
  List<MediaItem> get brazilian => _brazilian;

  /// "Porque você assistiu X" shelves, keyed by the seed title's storage key.
  final Map<String, ({MediaItem seed, List<MediaItem> items})>
      _becauseYouWatched = {};
  Map<String, ({MediaItem seed, List<MediaItem> items})>
      get becauseYouWatched => Map.unmodifiable(_becauseYouWatched);
  String _recommendationSeeds = '';

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  DateTime? _lastUpdated;
  DateTime? get lastUpdated => _lastUpdated;

  bool get hasContent =>
      _trending.isNotEmpty ||
      _popularMovies.isNotEmpty ||
      _popularTV.isNotEmpty ||
      fenixCatalogs.values.any((items) => items.isNotEmpty);

  CatalogProvider({TMDBService? service})
      : _tmdbService = service ?? TMDBService() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _restoreCache();
    await loadCatalog();
  }

  bool _refreshing = false;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> loadCatalog() async {
    if (_refreshing || _disposed) return;
    _loadFenix();
    _refreshing = true;
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
        _tmdbService.fetchTopRatedTV(),
        _tmdbService.fetchUpcomingMovies(),
        _tmdbService.fetchNowPlayingMovies(),
        _tmdbService.fetchOnTheAirTV(),
        _tmdbService.fetchBrazilian(),
        _safe(() =>
            _tmdbService.fetchByGenre(16, mediaType: 'movie')), // Animation
        _safe(
            () => _tmdbService.fetchByGenre(27, mediaType: 'movie')), // Horror
        _safe(() =>
            _tmdbService.fetchByGenre(99, mediaType: 'movie')), // Documentaries
        _safe(() =>
            _tmdbService.fetchByGenre(10751, mediaType: 'movie')), // Family
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
      _topRatedTV = results[7];
      _upcoming = results[8];
      _nowPlaying = results[9];
      _onTheAir = results[10];
      _brazilian = results[11];
      _animation = results[12];
      _horror = results[13];
      _documentaries = results[14];
      _family = results[15];

      await _pickHeroes();
      _lastUpdated = DateTime.now();
      await _saveCache();
    } catch (e) {
      debugPrint('Error loading catalog: $e');
      _errorMessage = hasContent
          ? 'Sem conexão. Exibindo o último catálogo disponível.'
          : 'Não foi possível carregar o catálogo.';
    } finally {
      _refreshing = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<MediaItem>> _safe(Future<List<MediaItem>> Function() call) async {
    try {
      return await call();
    } catch (_) {
      return [];
    }
  }

  /// The first few trending titles with a backdrop and a synopsis, each with
  /// its logo so the hero can render a proper title treatment.
  Future<void> _pickHeroes() async {
    if (_trending.isEmpty) return;
    final candidates = _trending
        .where((item) =>
            item.backdropPath != null &&
            item.overview != null &&
            item.overview!.isNotEmpty)
        .take(heroCount)
        .toList();
    if (candidates.isEmpty) candidates.add(_trending.first);
    final previous = {for (final hero in _heroes) hero.storageKey: hero};
    final heroes = await Future.wait(candidates.map((item) async {
      final cached = previous[item.storageKey];
      if (cached?.logoPath != null) {
        return item.copyWith(logoPath: cached!.logoPath);
      }
      try {
        final logo = await _tmdbService.fetchLogoPath(item.id, item.mediaType);
        return item.copyWith(logoPath: logo);
      } catch (_) {
        return item;
      }
    }));
    if (_disposed) return;
    _heroes = heroes;
    _heroItem = heroes.first;
  }

  /// Builds "Porque você assistiu …" shelves for up to [max] seeds. Cheap to
  /// call repeatedly: it only refetches when the seeds change.
  Future<void> loadRecommendations(List<MediaItem> seeds, {int max = 2}) async {
    final picked = <MediaItem>[];
    final seen = <String>{};
    for (final seed in seeds) {
      if (seen.add(seed.storageKey)) picked.add(seed);
      if (picked.length >= max) break;
    }
    final signature = picked.map((s) => s.storageKey).join(',');
    if (signature == _recommendationSeeds) return;
    _recommendationSeeds = signature;
    if (picked.isEmpty) {
      if (_becauseYouWatched.isNotEmpty) {
        _becauseYouWatched.clear();
        notifyListeners();
      }
      return;
    }
    final results = await Future.wait(picked.map((seed) async {
      try {
        return (
          seed: seed,
          items: await _tmdbService.fetchRecommendationsFor(seed)
        );
      } catch (_) {
        return (seed: seed, items: <MediaItem>[]);
      }
    }));
    if (_disposed || signature != _recommendationSeeds) return;
    _becauseYouWatched
      ..clear()
      ..addEntries([
        for (final result in results)
          if (result.items.isNotEmpty) MapEntry(result.seed.storageKey, result),
      ]);
    notifyListeners();
  }

  /// Every home shelf in display order.
  List<CatalogSection> sections({bool kids = false}) {
    final list = <CatalogSection>[
      if (_trending.isNotEmpty)
        CatalogSection(
          key: 'top10',
          title: 'Top 10 no Brasil hoje',
          items: _trending.take(10).toList(),
          kind: 'mixed',
          ranked: true,
        ),
      for (final entry in fenixCatalogs.entries)
        CatalogSection(
          key: 'server_${entry.key}',
          title: entry.key,
          items: entry.value,
          kind: entry.key.toLowerCase().contains('séries') ? 'tv' : 'movie',
          fromServer: true,
        ),
      for (final entry in _becauseYouWatched.values)
        CatalogSection(
          key: 'because_${entry.seed.storageKey}',
          title: 'Porque você assistiu ${entry.seed.title}',
          items: entry.items,
          kind: entry.seed.mediaType,
        ),
      if (kids)
        CatalogSection(
            key: 'family',
            title: 'Para a família',
            items: _family,
            kind: 'movie'),
      if (kids)
        CatalogSection(
            key: 'animation',
            title: 'Animações',
            items: _animation,
            kind: 'movie'),
      CatalogSection(
          key: 'now_playing',
          title: 'Em cartaz nos cinemas',
          items: _nowPlaying,
          kind: 'movie'),
      CatalogSection(
          key: 'on_the_air',
          title: 'Séries com episódios novos',
          items: _onTheAir,
          kind: 'tv'),
      CatalogSection(
          key: 'popular_movies',
          title: 'Filmes populares',
          items: _popularMovies,
          kind: 'movie'),
      CatalogSection(
          key: 'popular_tv',
          title: 'Séries populares',
          items: _popularTV,
          kind: 'tv'),
      CatalogSection(
          key: 'top_rated',
          title: 'Filmes aclamados pela crítica',
          items: _topRated,
          kind: 'movie'),
      CatalogSection(
          key: 'top_rated_tv',
          title: 'Séries aclamadas pela crítica',
          items: _topRatedTV,
          kind: 'tv'),
      CatalogSection(
          key: 'brazilian',
          title: 'Produções brasileiras',
          items: _brazilian,
          kind: 'mixed'),
      CatalogSection(
          key: 'action',
          title: 'Ação e aventura',
          items: _actionMovies,
          kind: 'movie'),
      CatalogSection(
          key: 'comedy',
          title: 'Comédias',
          items: _comedyMovies,
          kind: 'movie'),
      CatalogSection(
          key: 'scifi',
          title: 'Ficção científica',
          items: _sciFiMovies,
          kind: 'movie'),
      if (!kids)
        CatalogSection(
            key: 'animation',
            title: 'Animações',
            items: _animation,
            kind: 'movie'),
      if (!kids)
        CatalogSection(
            key: 'family',
            title: 'Para a família',
            items: _family,
            kind: 'movie'),
      if (!kids)
        CatalogSection(
            key: 'horror',
            title: 'Terror e suspense',
            items: _horror,
            kind: 'movie'),
      CatalogSection(
          key: 'docs',
          title: 'Documentários',
          items: _documentaries,
          kind: 'movie'),
      CatalogSection(
        key: 'upcoming',
        title: 'Em breve nos cinemas',
        items: _upcoming,
        kind: 'movie',
        allowUnreleased: true,
      ),
    ];
    return list.where((section) => section.items.isNotEmpty).toList();
  }

  void setHeroItem(MediaItem item) {
    _heroItem = item;
    notifyListeners();
  }

  Future<void> _restoreCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final legacy in const [
        'sabuflix_catalog_cache_v1',
        'sabuflix_catalog_cache_v2',
        'sabuflix_catalog_cache_v3',
      ]) {
        await prefs.remove(legacy);
      }
      final raw = prefs.getString(_catalogCacheKey);
      if (raw == null || raw.isEmpty) return;
      final data = Map<String, dynamic>.from(json.decode(raw) as Map);
      final fenix = data['fenix'];
      if (fenix is Map) {
        for (final entry in fenix.entries) {
          fenixCatalogs[entry.key.toString()] = _decodeItems(entry.value);
        }
      }
      _trending = _decodeItems(data['trending']);
      _popularMovies = _decodeItems(data['popularMovies']);
      _popularTV = _decodeItems(data['popularTV']);
      _topRated = _decodeItems(data['topRated']);
      _topRatedTV = _decodeItems(data['topRatedTV']);
      _actionMovies = _decodeItems(data['actionMovies']);
      _comedyMovies = _decodeItems(data['comedyMovies']);
      _sciFiMovies = _decodeItems(data['sciFiMovies']);
      _animation = _decodeItems(data['animation']);
      _horror = _decodeItems(data['horror']);
      _documentaries = _decodeItems(data['documentaries']);
      _family = _decodeItems(data['family']);
      _upcoming = _decodeItems(data['upcoming']);
      _nowPlaying = _decodeItems(data['nowPlaying']);
      _onTheAir = _decodeItems(data['onTheAir']);
      _brazilian = _decodeItems(data['brazilian']);
      _heroes = _decodeItems(data['heroes']);
      final rawHero = data['hero'];
      if (rawHero is Map) {
        _heroItem = MediaItem.fromJson(Map<String, dynamic>.from(rawHero));
      } else if (_heroes.isNotEmpty) {
        _heroItem = _heroes.first;
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
          'fenix': fenixCatalogs.map(
            (key, items) => MapEntry(key, encode(items)),
          ),
          'trending': encode(_trending),
          'popularMovies': encode(_popularMovies),
          'popularTV': encode(_popularTV),
          'topRated': encode(_topRated),
          'topRatedTV': encode(_topRatedTV),
          'actionMovies': encode(_actionMovies),
          'comedyMovies': encode(_comedyMovies),
          'sciFiMovies': encode(_sciFiMovies),
          'animation': encode(_animation),
          'horror': encode(_horror),
          'documentaries': encode(_documentaries),
          'family': encode(_family),
          'upcoming': encode(_upcoming),
          'nowPlaying': encode(_nowPlaying),
          'onTheAir': encode(_onTheAir),
          'brazilian': encode(_brazilian),
          'heroes': encode(_heroes),
          'hero': _heroItem?.forStorage.toJson(),
          'updatedAt': _lastUpdated?.millisecondsSinceEpoch,
        }),
      );
    } catch (error) {
      debugPrint('Unable to cache catalogue: $error');
    }
  }
}
