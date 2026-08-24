import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';

class SearchProvider extends ChangeNotifier {
  static const _recentSearchesKey = 'sabuflix_recent_searches';
  final TMDBService _tmdbService = TMDBService();
  Timer? _debounce;
  int _requestGeneration = 0;

  String _query = '';
  String get query => _query;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  List<MediaItem> _searchResults = [];
  List<MediaItem> get searchResults => _searchResults;

  int? _selectedGenreId;
  int? get selectedGenreId => _selectedGenreId;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<String> _recentSearches = [];
  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  SearchProvider() {
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    _recentSearches = prefs.getStringList(_recentSearchesKey) ?? [];
    notifyListeners();
  }

  void scheduleSearch(String text) {
    _debounce?.cancel();
    _query = text;
    _selectedGenreId = null;
    _errorMessage = null;
    if (text.trim().isEmpty) {
      _requestGeneration++;
      _searchResults = [];
      _isSearching = false;
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
    _errorMessage = null;

    if (text.trim().isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      final results = await _tmdbService.searchMedia(text);
      if (generation != _requestGeneration) return;
      _searchResults = results;
      if (results.isNotEmpty) await _remember(text.trim());
    } catch (e) {
      debugPrint('Search error: $e');
      if (generation != _requestGeneration) return;
      _errorMessage = 'Não foi possível concluir a busca.';
      _searchResults = [];
    } finally {
      if (generation == _requestGeneration) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  Future<void> filterByGenre(int genreId) async {
    _debounce?.cancel();
    final generation = ++_requestGeneration;
    _selectedGenreId = genreId;
    _query = '';
    _errorMessage = null;
    _isSearching = true;
    notifyListeners();

    try {
      final results = await _tmdbService.fetchByGenre(genreId);
      if (generation != _requestGeneration) return;
      _searchResults = results;
    } catch (e) {
      debugPrint('Genre filter error: $e');
      if (generation != _requestGeneration) return;
      _errorMessage = 'Não foi possível carregar este gênero.';
      _searchResults = [];
    } finally {
      if (generation == _requestGeneration) {
        _isSearching = false;
        notifyListeners();
      }
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
    _searchResults = [];
    _isSearching = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
