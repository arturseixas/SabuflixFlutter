import 'package:flutter/material.dart';
import '../models/download_item.dart';
import '../models/media_item.dart';
import '../services/download_service.dart';

/// Manages the offline library: an ordered list of downloads that are worked
/// through one at a time, with pause/resume/remove and progress reporting.
class DownloadsProvider extends ChangeNotifier {
  final DownloadService _downloadService = DownloadService();

  List<DownloadItem> _downloads = [];
  List<DownloadItem> get downloads => _downloads;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _currentProfileId;

  /// Id of the download currently transferring bytes, if any.
  String? _activeId;
  String? get activeId => _activeId;

  /// Ids whose in-flight transfer should stop at the next chunk boundary
  /// (because the user paused or removed them).
  final Set<String> _cancelRequests = {};

  DateTime _lastProgressNotify = DateTime.fromMillisecondsSinceEpoch(0);

  // Bumped on every loadDownloads() call so a slower, stale call can detect
  // it's been superseded and avoid clobbering a newer load's result.
  int _loadRequestId = 0;

  DownloadsProvider() {
    loadDownloads(null);
  }

  Future<void> loadDownloads(String? profileId) async {
    final requestId = ++_loadRequestId;

    _currentProfileId = profileId;
    _isLoading = true;
    notifyListeners();

    final loaded = await _downloadService.getDownloads(_currentProfileId);
    if (requestId != _loadRequestId) return; // superseded by a newer load

    _downloads = loaded;

    // Nothing is transferring right after a load, so anything the app died
    // mid-download on comes back as paused and resumable.
    for (final item in _downloads) {
      if (item.status == DownloadStatus.downloading) {
        item.status = DownloadStatus.paused;
      }
    }

    _activeId = null;
    _cancelRequests.clear();
    _isLoading = false;
    notifyListeners();
    _processQueue();
  }

  Future<void> _save() => _downloadService.saveDownloads(_downloads, _currentProfileId);

  DownloadItem? itemFor(int mediaId, {int? season, int? episode}) {
    final id = DownloadItem.buildId(mediaId, season: season, episode: episode);
    try {
      return _downloads.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Local file path to play offline, or null when not fully downloaded yet.
  String? localPathFor(int mediaId, {int? season, int? episode}) {
    final item = itemFor(mediaId, season: season, episode: episode);
    return item != null && item.isComplete ? item.filePath : null;
  }

  /// Adds a title to the download queue. Returns false when it is already
  /// downloaded or queued, so the caller can tell the user.
  Future<bool> enqueue({
    required MediaItem media,
    required String sourceUrl,
    required String qualityLabel,
    int? season,
    int? episode,
  }) async {
    final id = DownloadItem.buildId(media.id, season: season, episode: episode);
    if (_downloads.any((item) => item.id == id)) return false;

    final filePath = await _downloadService.buildFilePath(id: id, sourceUrl: sourceUrl);
    _downloads.add(DownloadItem(
      id: id,
      media: media,
      season: season,
      episode: episode,
      sourceUrl: sourceUrl,
      qualityLabel: qualityLabel,
      filePath: filePath,
    ));

    await _save();
    notifyListeners();
    _processQueue();
    return true;
  }

  Future<void> pause(String id) async {
    final item = itemById(id);
    if (item == null || !item.isActive) return;

    if (_activeId == id) _cancelRequests.add(id);
    item.status = DownloadStatus.paused;
    await _save();
    notifyListeners();
  }

  Future<void> resume(String id) async {
    final item = itemById(id);
    if (item == null) return;
    if (item.status != DownloadStatus.paused && item.status != DownloadStatus.failed) return;

    item.status = DownloadStatus.queued;
    item.errorMessage = null;
    await _save();
    notifyListeners();
    _processQueue();
  }

  /// Removes a download and deletes its files from disk.
  Future<void> remove(String id) async {
    final item = itemById(id);
    if (item == null) return;

    _downloads.removeWhere((d) => d.id == id);
    await _save();
    notifyListeners();

    if (_activeId == id) {
      // The transfer loop deletes the files once it unwinds.
      _cancelRequests.add(id);
    } else {
      await _downloadService.deleteFiles(item);
    }
  }

  /// Apaga todos os downloads do perfil atual, inclusive os arquivos em disco.
  Future<void> clearAll() async {
    final toDelete = List<DownloadItem>.from(_downloads);
    final activeItem = _activeId != null ? itemById(_activeId!) : null;
    if (activeItem != null) _cancelRequests.add(activeItem.id);

    _downloads = [];
    await _save();
    notifyListeners();

    for (final item in toDelete) {
      if (item.id == activeItem?.id) continue; // handled by the transfer loop
      await _downloadService.deleteFiles(item);
    }
  }

  DownloadItem? itemById(String id) {
    try {
      return _downloads.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Picks up the next queued download; re-enters itself until the queue is dry.
  Future<void> _processQueue() async {
    if (_activeId != null) return;

    final index = _downloads.indexWhere((item) => item.status == DownloadStatus.queued);
    if (index == -1) return;

    final item = _downloads[index];
    _activeId = item.id;
    item.status = DownloadStatus.downloading;
    notifyListeners();

    try {
      final finished = await _downloadService.download(
        item: item,
        onProgress: (received, total) => _onProgress(item, received, total),
        isCancelled: () => _cancelRequests.contains(item.id),
      );
      if (finished) {
        item.status = DownloadStatus.completed;
        item.receivedBytes = item.totalBytes;
      }
    } catch (e) {
      item.status = DownloadStatus.failed;
      item.errorMessage = e.toString();
    } finally {
      _cancelRequests.remove(item.id);
      _activeId = null;
    }

    // Removed (or cleared) while it was transferring — clean the disk now.
    if (!_downloads.any((d) => d.id == item.id)) {
      await _downloadService.deleteFiles(item);
    }

    await _save();
    notifyListeners();
    _processQueue();
  }

  /// Throttled so a fast connection does not rebuild the UI on every chunk.
  void _onProgress(DownloadItem item, int received, int total) {
    item.receivedBytes = received;
    item.totalBytes = total;

    final now = DateTime.now();
    if (now.difference(_lastProgressNotify).inMilliseconds >= 400) {
      _lastProgressNotify = now;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _downloadService.dispose();
    super.dispose();
  }
}
