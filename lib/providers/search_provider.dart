import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';

class SearchProvider extends ChangeNotifier {
  final TMDBService _tmdbService = TMDBService();

  /// Long enough to swallow a burst of typing, short enough to feel instant.
  static const Duration _debounceDelay = Duration(milliseconds: 350);

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

  int _page = 1;
  bool _hasMore = false;
  bool get hasMore => _hasMore;

  Timer? _debounce;

  /// Bumped on every new query so a slow in-flight response for an abandoned
  /// query cannot overwrite the results of a newer one.
  int _requestId = 0;

  Future<void> search(String text) async {
    _query = text;
    _selectedGenreId = null;
    _debounce?.cancel();

    if (text.trim().isEmpty) {
      _requestId++;
      _searchResults = [];
      _isSearching = false;
      _hasMore = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    _debounce = Timer(_debounceDelay, () => _runSearch(text));
  }

  Future<void> _runSearch(String text) async {
    final requestId = ++_requestId;
    _page = 1;

    try {
      final results = await _tmdbService.searchMedia(text, page: _page);
      if (requestId != _requestId) return;
      _searchResults = results;
      _hasMore = results.isNotEmpty;
    } catch (e) {
      debugPrint('Search error: $e');
      if (requestId != _requestId) return;
      _searchResults = [];
      _hasMore = false;
    } finally {
      if (requestId == _requestId) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  Future<void> filterByGenre(int genreId) async {
    _debounce?.cancel();
    final requestId = ++_requestId;

    _selectedGenreId = genreId;
    _query = '';
    _page = 1;
    _isSearching = true;
    notifyListeners();

    try {
      final results = await _tmdbService.fetchByGenre(genreId, page: _page);
      if (requestId != _requestId) return;
      _searchResults = results;
      _hasMore = results.isNotEmpty;
    } catch (e) {
      debugPrint('Genre filter error: $e');
      if (requestId != _requestId) return;
      _searchResults = [];
      _hasMore = false;
    } finally {
      if (requestId == _requestId) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  /// Pulls the next page of whichever view is active. A no-op while a page is
  /// already in flight, so scroll events cannot stack requests.
  Future<void> loadMore() async {
    if (_isLoadingMore || _isSearching || !_hasMore) return;

    final requestId = _requestId;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _page + 1;
      final results = _selectedGenreId != null
          ? await _tmdbService.fetchByGenre(_selectedGenreId!, page: nextPage)
          : await _tmdbService.searchMedia(_query, page: nextPage);

      if (requestId != _requestId) return;

      if (results.isEmpty) {
        _hasMore = false;
      } else {
        _page = nextPage;
        // TMDB pages overlap occasionally; a duplicate id breaks nothing but
        // shows the same poster twice.
        final seen = _searchResults.map((item) => item.id).toSet();
        _searchResults = [..._searchResults, ...results.where((item) => seen.add(item.id))];
      }
    } catch (e) {
      debugPrint('Pagination error: $e');
    } finally {
      if (requestId == _requestId) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  void clearSearch() {
    _debounce?.cancel();
    _requestId++;
    _query = '';
    _selectedGenreId = null;
    _searchResults = [];
    _isSearching = false;
    _isLoadingMore = false;
    _hasMore = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
