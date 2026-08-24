import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/download_item.dart';
import '../models/media_item.dart';
import '../services/download_service.dart';

/// Owns the offline library: what has been downloaded, what is still coming
/// down, and where each file lives on disk.
///
/// The library is rehydrated from shared preferences on launch, on every
/// profile switch and whenever the app returns to the foreground, and the
/// stored records are reconciled against the real files before anything is
/// shown. An entry is never silently dropped — a finished download whose file
/// went missing is surfaced as failed so it can be fetched again, and a
/// transfer that was cut short by the app being killed goes back into the
/// queue instead of disappearing.
class DownloadsProvider extends ChangeNotifier {
  static const String _keyPrefix = 'sabuflix_downloads_';
  static const int _maxParallel = 2;

  /// Progress arrives far faster than the screen can usefully repaint.
  static const int _notifyIntervalMs = 350;

  final DownloadService _service = DownloadService();

  List<DownloadItem> _items = [];
  String _profileKey = 'default';
  bool _isLoading = true;
  bool _hydrated = false;
  int _lastNotifyMs = 0;

  DownloadsProvider() {
    loadForProfile(null);
  }

  bool get isLoading => _isLoading;
  String get profileKey => _profileKey;

  List<DownloadItem> get items => List.unmodifiable(_items);

  /// Downloaded movies, newest first.
  List<DownloadItem> get movies {
    final list = _items.where((item) => !item.isEpisode).toList();
    list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return list;
  }

  /// Downloaded episodes grouped by series, newest series first.
  List<SeriesDownloadGroup> get series {
    final grouped = <int, List<DownloadItem>>{};
    for (final item in _items) {
      if (!item.isEpisode) continue;
      grouped.putIfAbsent(item.media.id, () => []).add(item);
    }
    final groups = grouped.values
        .map((episodes) => SeriesDownloadGroup(
            series: episodes.first.media, episodes: episodes))
        .toList();
    groups.sort((a, b) => b.newestAt.compareTo(a.newestAt));
    return groups;
  }

  SeriesDownloadGroup? seriesById(int mediaId) {
    for (final group in series) {
      if (group.series.id == mediaId) return group;
    }
    return null;
  }

  List<DownloadItem> get inProgress =>
      _items.where((item) => !item.isCompleted).toList();

  int get activeCount => _items.where((item) => item.isPending).length;

  bool get hasAnything => _items.isNotEmpty;

  /// Bytes actually occupied on the device, partial transfers included.
  int get bytesUsed => _items.fold(0, (sum, item) => sum + item.receivedBytes);

  int get completedCount => _items.where((item) => item.isCompleted).length;

  DownloadItem? find(int mediaId, {int? season, int? episode}) {
    final id = DownloadItem.buildId(mediaId, season: season, episode: episode);
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  bool isDownloaded(int mediaId, {int? season, int? episode}) =>
      find(mediaId, season: season, episode: episode)?.isCompleted ?? false;

  /// Absolute path of a finished download, or `null` when it is not playable.
  ///
  /// Resolved on demand instead of being stored, because the app container
  /// path can change between launches.
  Future<String?> localPathOf(DownloadItem item) =>
      _service.existingPath(_profileKey, item.fileName);

  // --- Loading & reconciliation ----------------------------------------

  Future<void> loadForProfile(String? profileId) async {
    final key = profileId ?? 'default';
    if (_hydrated && key == _profileKey) {
      // Same profile (the selection screen re-confirms it on every launch):
      // just re-check the files instead of tearing running transfers down.
      await refreshFromDisk();
      return;
    }

    await _service.stopAll();
    _profileKey = key;
    _hydrated = false;
    _isLoading = true;
    notifyListeners();

    _items = await _readStored(key);
    await _reconcileWithDisk();

    _isLoading = false;
    _hydrated = true;
    notifyListeners();
    _pumpQueue();
  }

  /// Re-checks the stored library against the filesystem. Called when the app
  /// comes back to the foreground so files removed by the system (or by the
  /// user through Settings) are reflected instead of failing at playback.
  Future<void> refreshFromDisk() async {
    if (!_hydrated) return;
    await _reconcileWithDisk();
    notifyListeners();
    _pumpQueue();
  }

  Future<List<DownloadItem>> _readStored(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$key');
    final restored = <DownloadItem>[];
    if (raw == null || raw.isEmpty) return restored;
    try {
      final decoded = json.decode(raw);
      if (decoded is List) {
        for (final entry in decoded) {
          // One unreadable record must not cost the user their whole library.
          try {
            restored.add(
                DownloadItem.fromJson(Map<String, dynamic>.from(entry as Map)));
          } catch (e) {
            debugPrint('Skipping unreadable download: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error decoding downloads: $e');
    }
    return restored;
  }

  Future<void> _reconcileWithDisk() async {
    final reconciled = <DownloadItem>[];
    for (final item in _items) {
      if (_service.isRunning(item.id)) {
        reconciled.add(item);
        continue;
      }

      final onDisk = await _service.bytesOnDisk(_profileKey, item.fileName);

      if (item.isCompleted) {
        if (onDisk <= 0) {
          reconciled.add(item.copyWith(
            status: DownloadStatus.failed,
            receivedBytes: 0,
            error: 'Arquivo não encontrado no aparelho',
          ));
        } else {
          reconciled.add(item.copyWith(
            receivedBytes: onDisk,
            totalBytes: onDisk > item.totalBytes ? onDisk : item.totalBytes,
            clearError: true,
          ));
        }
        continue;
      }

      // Anything that was mid-flight when the process died is put back in the
      // queue with its partial bytes intact, so it resumes on its own.
      final canResume = item.url.isNotEmpty;
      reconciled.add(item.copyWith(
        receivedBytes: onDisk,
        status: canResume && item.status != DownloadStatus.paused
            ? DownloadStatus.queued
            : (canResume ? item.status : DownloadStatus.failed),
        error: canResume ? null : 'Fonte indisponível',
        clearError: canResume,
      ));
    }
    _items = reconciled;
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(_items.map((item) => item.toJson()).toList());
      await prefs.setString('$_keyPrefix$_profileKey', encoded);
    } catch (e) {
      debugPrint('Error saving downloads: $e');
    }
  }

  // --- Mutations --------------------------------------------------------

  /// Adds a title (or a single episode) to the download queue.
  /// Returns `false` when it is already in the library.
  Future<bool> enqueue({
    required MediaItem media,
    required String url,
    required String quality,
    int? season,
    int? episode,
    String? episodeTitle,
  }) async {
    final id = DownloadItem.buildId(media.id, season: season, episode: episode);
    if (_items.any((item) => item.id == id)) return false;

    final item = DownloadItem(
      id: id,
      media: media.forStorage,
      season: season,
      episode: episode,
      episodeTitle: episodeTitle,
      url: url,
      quality: quality,
      fileName: DownloadItem.fileNameFor(id, url),
      addedAt: DateTime.now().millisecondsSinceEpoch,
      status: DownloadStatus.queued,
    );

    _items.insert(0, item);
    await _persist();
    notifyListeners();
    _pumpQueue();
    return true;
  }

  Future<void> pause(String id) async {
    final item = _byId(id);
    if (item == null || item.isCompleted) return;
    await _service.stop(id);
    _replace(id, (current) => current.copyWith(status: DownloadStatus.paused));
    await _persist();
    notifyListeners();
    _pumpQueue();
  }

  Future<void> resume(String id) async {
    final item = _byId(id);
    if (item == null || item.isCompleted) return;
    if (item.url.isEmpty) return;
    _replace(
        id,
        (current) =>
            current.copyWith(status: DownloadStatus.queued, clearError: true));
    await _persist();
    notifyListeners();
    _pumpQueue();
  }

  Future<void> resumeAll() async {
    var changed = false;
    for (final item in _items) {
      if (item.isCompleted || item.url.isEmpty) continue;
      if (item.status == DownloadStatus.paused ||
          item.status == DownloadStatus.failed) {
        _replace(
            item.id,
            (current) => current.copyWith(
                status: DownloadStatus.queued, clearError: true));
        changed = true;
      }
    }
    if (!changed) return;
    await _persist();
    notifyListeners();
    _pumpQueue();
  }

  /// Removes an item from the library and deletes its file.
  Future<void> remove(String id) async {
    final item = _byId(id);
    if (item == null) return;
    await _service.stop(id);
    await _service.deleteFile(_profileKey, item.fileName);
    _items.removeWhere((current) => current.id == id);
    await _persist();
    notifyListeners();
    _pumpQueue();
  }

  /// Removes every downloaded episode of a series in one go.
  Future<void> removeSeries(int mediaId) async {
    final targets = _items
        .where((item) => item.isEpisode && item.media.id == mediaId)
        .toList();
    for (final item in targets) {
      await _service.stop(item.id);
      await _service.deleteFile(_profileKey, item.fileName);
    }
    _items.removeWhere((item) => item.isEpisode && item.media.id == mediaId);
    await _persist();
    notifyListeners();
    _pumpQueue();
  }

  Future<void> removeAll() async {
    for (final item in _items) {
      await _service.stop(item.id);
      await _service.deleteFile(_profileKey, item.fileName);
    }
    _items = [];
    await _persist();
    notifyListeners();
  }

  // --- Queue ------------------------------------------------------------

  void _pumpQueue() {
    if (!_hydrated) return;
    var slots = _maxParallel -
        _items
            .where((item) => item.status == DownloadStatus.downloading)
            .length;
    if (slots <= 0) return;
    for (final item in _items) {
      if (slots <= 0) break;
      if (item.status != DownloadStatus.queued) continue;
      if (_service.isRunning(item.id)) continue;
      slots--;
      unawaited(_run(item.id));
    }
  }

  Future<void> _run(String id) async {
    final item = _byId(id);
    if (item == null) return;

    _replace(
        id,
        (current) => current.copyWith(
            status: DownloadStatus.downloading, clearError: true));
    notifyListeners();

    try {
      await _service.download(
        profileKey: _profileKey,
        item: item,
        onProgress: (received, total) => _onProgress(id, received, total),
      );
      _replace(
          id,
          (current) => current.copyWith(
                status: DownloadStatus.completed,
                totalBytes: current.totalBytes > 0
                    ? current.totalBytes
                    : current.receivedBytes,
                clearError: true,
              ));
    } on DownloadCancelled {
      // Paused or removed on purpose — `pause`/`remove` already set the state.
      if (_byId(id)?.status == DownloadStatus.downloading) {
        _replace(
            id, (current) => current.copyWith(status: DownloadStatus.paused));
      }
    } catch (e) {
      _replace(
          id,
          (current) => current.copyWith(
                status: DownloadStatus.failed,
                error: _friendlyError(e),
              ));
    }

    await _persist();
    notifyListeners();
    _pumpQueue();
  }

  void _onProgress(String id, int received, int total) {
    _replace(
        id,
        (current) => current.copyWith(
              receivedBytes: received,
              totalBytes: total > 0 ? total : current.totalBytes,
            ));
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastNotifyMs < _notifyIntervalMs) return;
    _lastNotifyMs = now;
    notifyListeners();
  }

  DownloadItem? _byId(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _replace(String id, DownloadItem Function(DownloadItem current) update) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) return;
    _items[index] = update(_items[index]);
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup')) {
      return 'Sem conexão com a fonte';
    }
    if (text.contains('No space left')) {
      return 'Espaço insuficiente no aparelho';
    }
    if (text.contains('respondeu')) {
      return text.replaceAll('HttpException: ', '');
    }
    return 'Falha no download';
  }

  @override
  void dispose() {
    _service.stopAll();
    super.dispose();
  }
}
