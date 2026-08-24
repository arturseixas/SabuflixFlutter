import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_item.dart';
import '../models/watch_progress.dart';

enum ContinueWatchingSort { recent, progress, remaining }

/// User-facing playback and catalogue preferences.
///
/// Everything is stored locally. This keeps the web build useful without an
/// account and makes the same preferences portable to the future desktop and
/// Android builds through Flutter's platform storage implementation.
class SettingsProvider extends ChangeNotifier {
  static const _compactPostersKey = 'sabuflix_setting_compact_posters';
  static const _hideUnreleasedKey = 'sabuflix_setting_hide_unreleased';
  static const _continueSortKey = 'sabuflix_setting_continue_sort';

  bool _compactPosters = false;
  bool _hideUnreleased = true;
  ContinueWatchingSort _continueWatchingSort = ContinueWatchingSort.recent;
  bool _isLoading = true;

  SettingsProvider() {
    _load();
  }

  bool get compactPosters => _compactPosters;
  bool get hideUnreleased => _hideUnreleased;
  ContinueWatchingSort get continueWatchingSort => _continueWatchingSort;
  bool get isLoading => _isLoading;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _compactPosters = prefs.getBool(_compactPostersKey) ?? false;
    _hideUnreleased = prefs.getBool(_hideUnreleasedKey) ?? true;
    final rawSort = prefs.getString(_continueSortKey);
    _continueWatchingSort = ContinueWatchingSort.values.firstWhere(
      (value) => value.name == rawSort,
      orElse: () => ContinueWatchingSort.recent,
    );
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setCompactPosters(bool value) async {
    if (_compactPosters == value) return;
    _compactPosters = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_compactPostersKey, value);
  }

  Future<void> setHideUnreleased(bool value) async {
    if (_hideUnreleased == value) return;
    _hideUnreleased = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hideUnreleasedKey, value);
  }

  Future<void> setContinueWatchingSort(ContinueWatchingSort value) async {
    if (_continueWatchingSort == value) return;
    _continueWatchingSort = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_continueSortKey, value.name);
  }

  List<MediaItem> visibleItems(Iterable<MediaItem> items) {
    if (!_hideUnreleased) return List<MediaItem>.unmodifiable(items);
    final today = DateTime.now();
    return List<MediaItem>.unmodifiable(items.where((item) {
      final date = DateTime.tryParse(item.releaseDate ?? '');
      return date == null || !date.isAfter(today);
    }));
  }

  List<WatchProgress> sortedProgress(Iterable<WatchProgress> entries) {
    final result = entries.toList();
    switch (_continueWatchingSort) {
      case ContinueWatchingSort.recent:
        result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case ContinueWatchingSort.progress:
        result.sort((a, b) => b.progress.compareTo(a.progress));
        break;
      case ContinueWatchingSort.remaining:
        result.sort((a, b) => a.remainingSeconds.compareTo(b.remainingSeconds));
        break;
    }
    return List.unmodifiable(result);
  }
}
