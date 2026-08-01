import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';

class SearchProvider extends ChangeNotifier {
  final TMDBService _tmdbService = TMDBService();

  String _query = '';
  String get query => _query;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  List<MediaItem> _searchResults = [];
  List<MediaItem> get searchResults => _searchResults;

  int? _selectedGenreId;
  int? get selectedGenreId => _selectedGenreId;

  Future<void> search(String text) async {
    _query = text;
    _selectedGenreId = null;

    if (text.trim().isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      _searchResults = await _tmdbService.searchMedia(text);
    } catch (e) {
      print('Search error: $e');
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<void> filterByGenre(int genreId) async {
    _selectedGenreId = genreId;
    _query = '';
    _isSearching = true;
    notifyListeners();

    try {
      _searchResults = await _tmdbService.fetchByGenre(genreId);
    } catch (e) {
      print('Genre filter error: $e');
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _query = '';
    _selectedGenreId = null;
    _searchResults = [];
    _isSearching = false;
    notifyListeners();
  }
}
