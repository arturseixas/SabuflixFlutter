import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';

/// What the results should be restricted to.
enum SearchType { all, movie, tv }

/// Ordering for genre browsing.
enum BrowseSort { popular, rating, newest }

extension BrowseSortLabel on BrowseSort {
  String get label => switch (this) {
        BrowseSort.popular => 'Populares',
        BrowseSort.rating => 'Melhor avaliados',
        BrowseSort.newest => 'Lançamentos',
      };

  String get tmdb => switch (this) {
        BrowseSort.popular => 'popularity.desc',
        BrowseSort.rating => 'vote_average.desc',
        BrowseSort.newest => 'primary_release_date.desc',
      };

  String tmdbFor(String mediaType) =>
      this == BrowseSort.newest && mediaType == 'tv'
          ? 'first_air_date.desc'
          : tmdb;
}

class SearchProvider extends ChangeNotifier {
  static const _recentSearchesKey = 'sabuflix_recent_searches';
  final TMDBService _tmdbService;
  bool _disposed = false;
  Timer? _debounce;
  int _requestGeneration = 0;

  String _query = '';
  String get query => _query;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  List<MediaItem> _searchResults = [];
  List<MediaItem> get searchResults => _searchResults;

  int? _selectedGenreId;
  int? get selectedGenreId => _selectedGenreId;

  SearchType _type = SearchType.all;
  SearchType get type => _type;

  BrowseSort _sort = BrowseSort.popular;
  BrowseSort get sort => _sort;

  int? _year;
  int? get year => _year;

  int _page = 1;
  bool _hasMore = false;
  bool get hasMore => _hasMore;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<String> _recentSearches = [];
  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  SearchProvider({TMDBService? service})
      : _tmdbService = service ?? TMDBService() {
    _loadRecentSearches();
  }

  bool get isBrowsing => _selectedGenreId != null || _year != null;
  bool get isIdle => _query.trim().isEmpty && !isBrowsing;

  /// Results narrowed by the type filter (search results are mixed).
  List<MediaItem> get visibleResults {
    if (_type == SearchType.all) return _searchResults;
    final wanted = _type == SearchType.movie ? 'movie' : 'tv';
    return _searchResults.where((item) => item.mediaType == wanted).toList();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    _recentSearches = prefs.getStringList(_recentSearchesKey) ?? [];
    notifyListeners();
  }

  void scheduleSearch(String text) {
    _debounce?.cancel();
    _requestGeneration++;
    _query = text;
    _selectedGenreId = null;
    _year = null;
    _errorMessage = null;
    if (text.trim().isEmpty) {
      _requestGeneration++;
      _searchResults = [];
      _isSearching = false;
      _hasMore = false;
      notifyListeners();
      return;
    }
    _isSearching = true;
    notifyListeners();
    _debounce = Timer(const Duration(milliseconds: 350), () => search(text));
  }

  Future<void> search(String text) async {
    _debounce?.cancel();
    final generation = ++_requestGeneration;
    _query = text;
    _selectedGenreId = null;
    _year = null;
    _errorMessage = null;
    _page = 1;

    if (text.trim().isEmpty) {
      _searchResults = [];
      _isSearching = false;
      _hasMore = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      final results = await _tmdbService.searchMedia(text);
      if (generation != _requestGeneration) return;
      _searchResults = results;
      _hasMore = results.length >= 20;
      if (results.isNotEmpty) await _remember(text.trim());
    } catch (e) {
      debugPrint('Search error: $e');
      if (generation != _requestGeneration) return;
      _errorMessage = 'Não foi possível concluir a busca.';
      _searchResults = [];
      _hasMore = false;
    } finally {
      if (generation == _requestGeneration) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  Future<void> filterByGenre(int genreId) => browse(genreId: genreId);

  /// Genre / year browsing through TMDB discover, honouring type and sort.
  Future<void> browse(
      {int? genreId, int? year, bool keepFilters = true}) async {
    _debounce?.cancel();
    final generation = ++_requestGeneration;
    _selectedGenreId = genreId ?? (keepFilters ? _selectedGenreId : null);
    _year = year ?? (keepFilters ? _year : null);
    _query = '';
    _errorMessage = null;
    _page = 1;
    _isSearching = true;
    notifyListeners();

    try {
      final results = await _fetchBrowsePage(1);
      if (generation != _requestGeneration) return;
      _searchResults = results;
      _hasMore = results.length >= 20;
    } catch (e) {
      debugPrint('Browse error: $e');
      if (generation != _requestGeneration) return;
      _errorMessage = 'Não foi possível carregar este gênero.';
      _searchResults = [];
      _hasMore = false;
    } finally {
      if (generation == _requestGeneration) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  Future<List<MediaItem>> _fetchBrowsePage(int page) async {
    if (_type == SearchType.all) {
      if (_selectedGenreId != null &&
          _year == null &&
          _sort == BrowseSort.popular) {
        // Same request the original browse made; keeps the fallback simple.
        final movies =
            await _tmdbService.fetchByGenre(_selectedGenreId!, page: page);
        final series = await _tmdbService
            .fetchByGenre(_selectedGenreId!, mediaType: 'tv', page: page)
            .catchError((_) => <MediaItem>[]);
        return _interleave(movies, series);
      }
      final results = await Future.wait([
        _tmdbService.discover(
            mediaType: 'movie',
            genreId: _selectedGenreId,
            year: _year,
            sortBy: _sort.tmdbFor('movie'),
            page: page),
        _tmdbService
            .discover(
                mediaType: 'tv',
                genreId: _selectedGenreId,
                year: _year,
                sortBy: _sort.tmdbFor('tv'),
                page: page)
            .catchError((_) => <MediaItem>[]),
      ]);
      return _interleave(results[0], results[1]);
    }
    final mediaType = _type == SearchType.movie ? 'movie' : 'tv';
    return _tmdbService.discover(
      mediaType: mediaType,
      genreId: _selectedGenreId,
      year: _year,
      sortBy: _sort.tmdbFor(mediaType),
      page: page,
    );
  }

  static List<MediaItem> _interleave(List<MediaItem> a, List<MediaItem> b) {
    final merged = <MediaItem>[];
    for (var i = 0; i < a.length || i < b.length; i++) {
      if (i < a.length) merged.add(a[i]);
      if (i < b.length) merged.add(b[i]);
    }
    return merged;
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || _isSearching || !_hasMore) return;
    final generation = _requestGeneration;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final next = _page + 1;
      final results = isBrowsing
          ? await _fetchBrowsePage(next)
          : await _tmdbService.searchMedia(_query, page: next);
      if (generation != _requestGeneration) return;
      final seen = _searchResults.map((item) => item.storageKey).toSet();
      _searchResults = [
        ..._searchResults,
        ...results.where((item) => seen.add(item.storageKey)),
      ];
      _page = next;
      _hasMore = results.length >= 20 && _page < 10;
    } catch (e) {
      debugPrint('Load more failed: $e');
      _hasMore = false;
    } finally {
      if (generation == _requestGeneration) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> setType(SearchType value) async {
    if (_type == value) return;
    _type = value;
    notifyListeners();
    if (isBrowsing) await browse();
  }

  Future<void> setSort(BrowseSort value) async {
    if (_sort == value) return;
    _sort = value;
    notifyListeners();
    if (isBrowsing) await browse();
  }

  Future<void> setYear(int? value) async {
    if (_year == value) return;
    if (value == null && _selectedGenreId == null) {
      clearSearch();
      return;
    }
    await browse(year: value, keepFilters: true);
    if (value == null) {
      _year = null;
      notifyListeners();
    }
  }

  Future<void> _remember(String value) async {
    if (value.isEmpty) return;
    _recentSearches
        .removeWhere((item) => item.toLowerCase() == value.toLowerCase());
    _recentSearches.insert(0, value);
    if (_recentSearches.length > 8) {
      _recentSearches = _recentSearches.take(8).toList();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, _recentSearches);
  }

  Future<void> clearRecentSearches() async {
    _recentSearches = [];
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
  }

  void clearSearch() {
    _debounce?.cancel();
    _requestGeneration++;
    _query = '';
    _selectedGenreId = null;
    _year = null;
    _searchResults = [];
    _isSearching = false;
    _isLoadingMore = false;
    _hasMore = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _disposed = true;
    _requestGeneration++;
    super.dispose();
  }
}
