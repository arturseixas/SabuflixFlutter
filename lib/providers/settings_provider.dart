import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_item.dart';
import '../models/watch_progress.dart';
import '../services/playback_resolver.dart';

enum ContinueWatchingSort { recent, progress, remaining }

/// Which subtitle track to turn on automatically when playback starts.
enum SubtitlePreference { portuguese, english, off }

extension SubtitlePreferenceLabel on SubtitlePreference {
  String get label => switch (this) {
        SubtitlePreference.portuguese => 'Português',
        SubtitlePreference.english => 'Inglês',
        SubtitlePreference.off => 'Desligadas',
      };

  List<String> get languageCodes => switch (this) {
        SubtitlePreference.portuguese => const [
            'por',
            'pob',
            'pt',
            'pt-br',
            'pb',
            'bra'
          ],
        SubtitlePreference.english => const ['eng', 'en', 'en-us'],
        SubtitlePreference.off => const [],
      };
}

/// User-facing playback and catalogue preferences.
///
/// Everything is stored locally. This keeps the web build useful without an
/// account and makes the same preferences portable to the desktop and Android
/// builds through Flutter's platform storage implementation.
class SettingsProvider extends ChangeNotifier {
  static const _compactPostersKey = 'sabuflix_setting_compact_posters';
  static const _hideUnreleasedKey = 'sabuflix_setting_hide_unreleased';
  static const _continueSortKey = 'sabuflix_setting_continue_sort';
  static const _themeModeKey = 'sabuflix_setting_theme_mode';
  static const _autoplayNextKey = 'sabuflix_setting_autoplay_next';
  static const _quickPlayKey = 'sabuflix_setting_quick_play';
  static const _preferredQualityKey = 'sabuflix_setting_preferred_quality';
  static const _preferredAudioKey = 'sabuflix_setting_preferred_audio';
  static const _subtitlePreferenceKey = 'sabuflix_setting_subtitle_language';
  static const _subtitleScaleKey = 'sabuflix_setting_subtitle_scale';
  static const _playbackSpeedKey = 'sabuflix_setting_playback_speed';
  static const _volumeKey = 'sabuflix_setting_volume';
  static const _seekStepKey = 'sabuflix_setting_seek_step';
  static const _autoplayCountdownKey = 'sabuflix_setting_autoplay_countdown';

  static const List<double> speedOptions = [
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0
  ];
  static const List<int> seekStepOptions = [5, 10, 15, 30];

  ThemeMode _themeMode = ThemeMode.dark;
  bool _compactPosters = false;
  bool _hideUnreleased = true;
  ContinueWatchingSort _continueWatchingSort = ContinueWatchingSort.recent;
  bool _autoplayNext = true;
  bool _quickPlay = false;
  PreferredQuality _preferredQuality = PreferredQuality.auto;
  PreferredAudio _preferredAudio = PreferredAudio.any;
  SubtitlePreference _subtitlePreference = SubtitlePreference.portuguese;
  double _subtitleScale = 1.0;
  double _playbackSpeed = 1.0;
  double _volume = 100;
  int _seekStepSeconds = 10;
  int _autoplayCountdownSeconds = 10;
  bool _isLoading = true;

  SettingsProvider() {
    _load();
  }

  ThemeMode get themeMode => _themeMode;
  bool get compactPosters => _compactPosters;
  bool get hideUnreleased => _hideUnreleased;
  ContinueWatchingSort get continueWatchingSort => _continueWatchingSort;
  bool get autoplayNext => _autoplayNext;
  bool get quickPlay => _quickPlay;
  PreferredQuality get preferredQuality => _preferredQuality;
  PreferredAudio get preferredAudio => _preferredAudio;
  SubtitlePreference get subtitlePreference => _subtitlePreference;
  double get subtitleScale => _subtitleScale;
  double get playbackSpeed => _playbackSpeed;

  /// 0 – 100, the way media_kit expects it.
  double get volume => _volume;
  int get seekStepSeconds => _seekStepSeconds;
  int get autoplayCountdownSeconds => _autoplayCountdownSeconds;
  bool get isLoading => _isLoading;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = _enumFrom(
        ThemeMode.values, prefs.getString(_themeModeKey), ThemeMode.dark);
    _compactPosters = prefs.getBool(_compactPostersKey) ?? false;
    _hideUnreleased = prefs.getBool(_hideUnreleasedKey) ?? true;
    _continueWatchingSort = _enumFrom(ContinueWatchingSort.values,
        prefs.getString(_continueSortKey), ContinueWatchingSort.recent);
    _autoplayNext = prefs.getBool(_autoplayNextKey) ?? true;
    _quickPlay = prefs.getBool(_quickPlayKey) ?? false;
    _preferredQuality = _enumFrom(PreferredQuality.values,
        prefs.getString(_preferredQualityKey), PreferredQuality.auto);
    _preferredAudio = _enumFrom(PreferredAudio.values,
        prefs.getString(_preferredAudioKey), PreferredAudio.any);
    _subtitlePreference = _enumFrom(SubtitlePreference.values,
        prefs.getString(_subtitlePreferenceKey), SubtitlePreference.portuguese);
    _subtitleScale =
        (prefs.getDouble(_subtitleScaleKey) ?? 1.0).clamp(0.7, 1.8);
    _playbackSpeed =
        (prefs.getDouble(_playbackSpeedKey) ?? 1.0).clamp(0.25, 3.0);
    _volume = (prefs.getDouble(_volumeKey) ?? 100).clamp(0.0, 100.0);
    _seekStepSeconds = prefs.getInt(_seekStepKey) ?? 10;
    if (!seekStepOptions.contains(_seekStepSeconds)) _seekStepSeconds = 10;
    _autoplayCountdownSeconds =
        (prefs.getInt(_autoplayCountdownKey) ?? 10).clamp(3, 30);
    _isLoading = false;
    notifyListeners();
  }

  static T _enumFrom<T extends Enum>(List<T> values, String? raw, T fallback) =>
      values.firstWhere((value) => value.name == raw, orElse: () => fallback);

  Future<void> setThemeMode(ThemeMode value) async {
    if (_themeMode == value) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, value.name);
    _themeMode = value;
    notifyListeners();
  }

  Future<void> setCompactPosters(bool value) => _setBool(
      _compactPostersKey, value, _compactPosters, (v) => _compactPosters = v);

  Future<void> setHideUnreleased(bool value) => _setBool(
      _hideUnreleasedKey, value, _hideUnreleased, (v) => _hideUnreleased = v);

  Future<void> setAutoplayNext(bool value) => _setBool(
      _autoplayNextKey, value, _autoplayNext, (v) => _autoplayNext = v);

  Future<void> setQuickPlay(bool value) =>
      _setBool(_quickPlayKey, value, _quickPlay, (v) => _quickPlay = v);

  Future<void> setContinueWatchingSort(ContinueWatchingSort value) async {
    if (_continueWatchingSort == value) return;
    _continueWatchingSort = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_continueSortKey, value.name);
  }

  Future<void> setPreferredQuality(PreferredQuality value) async {
    if (_preferredQuality == value) return;
    _preferredQuality = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferredQualityKey, value.name);
  }

  Future<void> setPreferredAudio(PreferredAudio value) async {
    if (_preferredAudio == value) return;
    _preferredAudio = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferredAudioKey, value.name);
  }

  Future<void> setSubtitlePreference(SubtitlePreference value) async {
    if (_subtitlePreference == value) return;
    _subtitlePreference = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_subtitlePreferenceKey, value.name);
  }

  Future<void> setSubtitleScale(double value) async {
    final clamped = value.clamp(0.7, 1.8);
    if (_subtitleScale == clamped) return;
    _subtitleScale = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_subtitleScaleKey, clamped);
  }

  Future<void> setPlaybackSpeed(double value) async {
    final clamped = value.clamp(0.25, 3.0);
    if (_playbackSpeed == clamped) return;
    _playbackSpeed = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_playbackSpeedKey, clamped);
  }

  Future<void> setVolume(double value) async {
    final clamped = value.clamp(0.0, 100.0);
    if (_volume == clamped) return;
    _volume = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, clamped);
  }

  Future<void> setSeekStepSeconds(int value) async {
    if (_seekStepSeconds == value || !seekStepOptions.contains(value)) return;
    _seekStepSeconds = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seekStepKey, value);
  }

  Future<void> setAutoplayCountdownSeconds(int value) async {
    final clamped = value.clamp(3, 30);
    if (_autoplayCountdownSeconds == clamped) return;
    _autoplayCountdownSeconds = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoplayCountdownKey, clamped);
  }

  Future<void> _setBool(
      String key, bool value, bool current, void Function(bool) assign) async {
    if (current == value) return;
    assign(value);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
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

  /// Every preference as JSON, for the backup feature.
  Map<String, dynamic> toJson() => {
        'themeMode': _themeMode.name,
        'compactPosters': _compactPosters,
        'hideUnreleased': _hideUnreleased,
        'continueWatchingSort': _continueWatchingSort.name,
        'autoplayNext': _autoplayNext,
        'quickPlay': _quickPlay,
        'preferredQuality': _preferredQuality.name,
        'preferredAudio': _preferredAudio.name,
        'subtitlePreference': _subtitlePreference.name,
        'subtitleScale': _subtitleScale,
        'playbackSpeed': _playbackSpeed,
        'volume': _volume,
        'seekStepSeconds': _seekStepSeconds,
        'autoplayCountdownSeconds': _autoplayCountdownSeconds,
      };

  Future<void> applyJson(Map<String, dynamic> json) async {
    await setThemeMode(
        _enumFrom(ThemeMode.values, json['themeMode']?.toString(), _themeMode));
    if (json['compactPosters'] is bool) {
      await setCompactPosters(json['compactPosters']);
    }
    if (json['hideUnreleased'] is bool) {
      await setHideUnreleased(json['hideUnreleased']);
    }
    await setContinueWatchingSort(_enumFrom(ContinueWatchingSort.values,
        json['continueWatchingSort']?.toString(), _continueWatchingSort));
    if (json['autoplayNext'] is bool) {
      await setAutoplayNext(json['autoplayNext']);
    }
    if (json['quickPlay'] is bool) await setQuickPlay(json['quickPlay']);
    await setPreferredQuality(_enumFrom(PreferredQuality.values,
        json['preferredQuality']?.toString(), _preferredQuality));
    await setPreferredAudio(_enumFrom(PreferredAudio.values,
        json['preferredAudio']?.toString(), _preferredAudio));
    await setSubtitlePreference(_enumFrom(SubtitlePreference.values,
        json['subtitlePreference']?.toString(), _subtitlePreference));
    if (json['subtitleScale'] is num) {
      await setSubtitleScale((json['subtitleScale'] as num).toDouble());
    }
    if (json['playbackSpeed'] is num) {
      await setPlaybackSpeed((json['playbackSpeed'] as num).toDouble());
    }
    if (json['volume'] is num) {
      await setVolume((json['volume'] as num).toDouble());
    }
    if (json['seekStepSeconds'] is num) {
      await setSeekStepSeconds((json['seekStepSeconds'] as num).toInt());
    }
    if (json['autoplayCountdownSeconds'] is num) {
      await setAutoplayCountdownSeconds(
          (json['autoplayCountdownSeconds'] as num).toInt());
    }
  }
}
