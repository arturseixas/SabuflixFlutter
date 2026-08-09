import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/download_task.dart';
import '../models/media_item.dart';
import '../services/download_service.dart';

/// Why a download could not be started, so the UI can explain itself instead
/// of failing silently.
enum EnqueueResult {
  started,
  alreadyExists,
  waitingForWifi,
}

/// Owns the download queue: what is downloading, what is waiting, and what is
/// already on disk.
///
/// Only one transfer runs at a time. Several parallel downloads would split
/// the same bandwidth, finish later on average, and make progress bars jump
/// around — a queue is both simpler and faster in practice.
class DownloadProvider extends ChangeNotifier {
  static const String _wifiOnlyKey = 'sabuflix_downloads_wifi_only';

  final DownloadService _service = DownloadService();
  final Connectivity _connectivity = Connectivity();

  List<DownloadTask> _tasks = [];
  List<DownloadTask> get tasks => List.unmodifiable(_tasks);

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  /// False until the stored index has been read. Guards every write, so a
  /// save triggered during startup cannot clobber the saved library.
  bool _indexLoaded = false;

  /// Set when the stored library could not be read at all. The list is empty
  /// in that case, but for a different reason than "nothing was downloaded".
  String? _loadError;
  String? get loadError => _loadError;

  String? _activeId;
  String? get activeId => _activeId;

  bool _wifiOnly = false;
  bool get wifiOnly => _wifiOnly;

  int _usedBytes = 0;
  int get usedBytes => _usedBytes;

  /// Transfer rate of the active download, in bytes per second.
  int _bytesPerSecond = 0;
  int get bytesPerSecond => _bytesPerSecond;

  bool _onAllowedNetwork = true;

  /// True when downloads are held back because the device left Wi-Fi.
  bool get isBlockedByNetwork => _wifiOnly && !_onAllowedNetwork;

  DateTime? _rateSampleTime;
  int _rateSampleBytes = 0;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  DownloadProvider() {
    _init();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _wifiOnly = prefs.getBool(_wifiOnlyKey) ?? false;
    } catch (_) {
      _wifiOnly = false;
    }

    try {
      final stored = await _service.loadIndex();
      _tasks = await _service.reconcileWithDisk(stored);
    } catch (e) {
      // Never leave the library looking empty because of a read error — say
      // so instead, so a real failure is not mistaken for "no downloads".
      _tasks = [];
      _loadError = e.toString();
      debugPrint('Sabuflix: falha ao ler o índice de downloads: $e');
    }

    // Only from here on may anything write the index. Before this point
    // _tasks is still the empty starting list, and persisting it would
    // overwrite a perfectly good library on disk. A failed read also stays
    // unwritten, so the file on disk survives for the next attempt.
    _indexLoaded = _loadError == null;

    if (_indexLoaded) {
      await _persist();
    }
    _usedBytes = await _service.usedBytes();

    try {
      await _refreshConnectivity();
      _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
        _applyConnectivity(results);
      });
    } catch (_) {
      // Without connectivity events the Wi-Fi-only rule cannot react to
      // network changes, but downloads must still work.
      _onAllowedNetwork = true;
    }

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------- queries

  List<DownloadTask> get completed =>
      _tasks.where((t) => t.status == DownloadStatus.completed).toList();

  List<DownloadTask> get inProgress =>
      _tasks.where((t) => t.status != DownloadStatus.completed).toList();

  bool get hasActiveWork => _tasks.any((t) => t.isActive);

  DownloadTask? taskFor(MediaItem media, {int? season, int? episode}) {
    final id = DownloadTask.buildId(media.id, media.mediaType, season, episode);
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  /// True when this exact item is already fully downloaded.
  bool isDownloaded(MediaItem media, {int? season, int? episode}) =>
      taskFor(media, season: season, episode: episode)?.status ==
      DownloadStatus.completed;

  /// Absolute path to play an item offline, or null if it is not ready.
  Future<String?> localPathFor(DownloadTask task) async {
    if (task.status != DownloadStatus.completed) return null;
    return _service.filePathFor(task);
  }

  /// Seconds left on the active transfer, or null when it cannot be estimated.
  int? get secondsRemaining {
    final task = _activeTask;
    if (task == null || _bytesPerSecond <= 0 || task.totalBytes <= 0) return null;
    final remaining = task.totalBytes - task.bytesReceived;
    if (remaining <= 0) return 0;
    return (remaining / _bytesPerSecond).round();
  }

  DownloadTask? get _activeTask {
    final id = _activeId;
    if (id == null) return null;
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  // ----------------------------------------------------------------- queue

  /// Adds an item to the queue. Returns why nothing happened when it did not
  /// start, so the caller can show a meaningful message.
  Future<EnqueueResult> enqueue({
    required MediaItem media,
    required String url,
    required String sourceName,
    required String quality,
    int? season,
    int? episode,
  }) async {
    final id = DownloadTask.buildId(media.id, media.mediaType, season, episode);

    final existing = taskFor(media, season: season, episode: episode);
    if (existing != null) {
      if (existing.status == DownloadStatus.completed) {
        return EnqueueResult.alreadyExists;
      }
      // Same item queued again: retry it rather than creating a duplicate.
      existing.status = DownloadStatus.queued;
      existing.error = null;
      await _persist();
      unawaited(_pump());
      return EnqueueResult.started;
    }

    final task = DownloadTask(
      mediaId: media.id,
      media: media,
      sourceName: sourceName,
      quality: quality,
      url: url,
      fileName: DownloadService.buildFileName(id, url),
      season: season,
      episode: episode,
    );

    _tasks.add(task);
    await _persist();

    if (isBlockedByNetwork) {
      return EnqueueResult.waitingForWifi;
    }

    unawaited(_pump());
    return EnqueueResult.started;
  }

  /// Starts the next queued task if nothing is running.
  Future<void> _pump() async {
    if (_activeId != null) return;
    if (isBlockedByNetwork) return;

    DownloadTask? next;
    for (final task in _tasks) {
      if (task.status == DownloadStatus.queued) {
        next = task;
        break;
      }
    }
    if (next == null) return;

    await _run(next);
  }

  Future<void> _run(DownloadTask task) async {
    _activeId = task.id;
    task.status = DownloadStatus.downloading;
    task.error = null;
    _resetRate();
    notifyListeners();

    try {
      await _service.start(
        task,
        onProgress: (received, total) {
          task.bytesReceived = received;
          if (total > 0) task.totalBytes = total;
          _updateRate(received);
          _notifyThrottled();
        },
      );

      task.status = DownloadStatus.completed;
      task.completedAt = DateTime.now();
      if (task.totalBytes <= 0) task.totalBytes = task.bytesReceived;
    } on DownloadPausedException {
      // Deliberate stop: leave it paused and keep the partial file.
      task.status = DownloadStatus.paused;
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.error = _readableError(e);
    } finally {
      _activeId = null;
      _bytesPerSecond = 0;
      _usedBytes = await _service.usedBytes();
      await _persist();
    }

    // Move on to whatever is next in line.
    unawaited(_pump());
  }

  String _readableError(Object error) {
    final text = error.toString();
    if (text.contains('SocketException') || text.contains('Failed host lookup')) {
      return 'Sem conexão com o servidor';
    }
    if (text.contains('No space left')) {
      return 'Espaço insuficiente no dispositivo';
    }
    return text.replaceFirst('Exception: ', '');
  }

  // --------------------------------------------------------------- actions

  Future<void> pause(DownloadTask task) async {
    if (task.status == DownloadStatus.downloading) {
      await _service.pause(task.id);
      // _run settles the status when the transfer unwinds.
      return;
    }
    if (task.status == DownloadStatus.queued) {
      task.status = DownloadStatus.paused;
      await _persist();
    }
  }

  Future<void> resume(DownloadTask task) async {
    if (task.status == DownloadStatus.completed) return;
    task.status = DownloadStatus.queued;
    task.error = null;
    await _persist();
    unawaited(_pump());
  }

  Future<void> pauseAll() async {
    for (final task in _tasks) {
      if (task.status == DownloadStatus.queued) {
        task.status = DownloadStatus.paused;
      }
    }
    final active = _activeTask;
    if (active != null) {
      await _service.pause(active.id);
    }
    await _persist();
  }

  Future<void> resumeAll() async {
    for (final task in _tasks) {
      if (task.isResumable) {
        task.status = DownloadStatus.queued;
        task.error = null;
      }
    }
    await _persist();
    unawaited(_pump());
  }

  /// Removes the entry and its file from disk.
  Future<void> remove(DownloadTask task) async {
    await _service.deleteFile(task);
    _tasks.removeWhere((t) => t.id == task.id);
    if (_activeId == task.id) _activeId = null;
    _usedBytes = await _service.usedBytes();
    await _persist();
    unawaited(_pump());
  }

  Future<void> removeCompleted() async {
    final done = completed;
    for (final task in done) {
      await _service.deleteFile(task);
      _tasks.removeWhere((t) => t.id == task.id);
    }
    _usedBytes = await _service.usedBytes();
    await _persist();
  }

  // -------------------------------------------------------------- settings

  Future<void> setWifiOnly(bool value) async {
    _wifiOnly = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wifiOnlyKey, value);

    if (isBlockedByNetwork) {
      await _holdForNetwork();
    } else {
      unawaited(_pump());
    }
    notifyListeners();
  }

  // ---------------------------------------------------------- connectivity

  Future<void> _refreshConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _onAllowedNetwork = _isAllowed(results);
    } catch (_) {
      // If connectivity cannot be read, assume the network is usable rather
      // than blocking downloads outright.
      _onAllowedNetwork = true;
    }
  }

  void _applyConnectivity(List<ConnectivityResult> results) {
    final wasAllowed = _onAllowedNetwork;
    _onAllowedNetwork = _isAllowed(results);
    if (wasAllowed == _onAllowedNetwork) return;

    if (isBlockedByNetwork) {
      unawaited(_holdForNetwork());
    } else {
      unawaited(_pump());
    }
    notifyListeners();
  }

  /// Ethernet counts as an unmetered connection alongside Wi-Fi — on desktop
  /// that is the normal way to be online.
  bool _isAllowed(List<ConnectivityResult> results) {
    if (!_wifiOnly) return true;
    return results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn);
  }

  /// Parks everything that is running or waiting until Wi-Fi is back.
  Future<void> _holdForNetwork() async {
    final active = _activeTask;
    if (active != null) {
      await _service.pause(active.id);
    }
    for (final task in _tasks) {
      if (task.status == DownloadStatus.queued) {
        task.status = DownloadStatus.paused;
      }
    }
    await _persist();
  }

  // ----------------------------------------------------------------- rates

  /// Chunks land far faster than a screen can usefully repaint, so progress
  /// notifications are capped at a few per second. Without this the whole
  /// downloads list rebuilds on every packet and the UI stutters.
  static const Duration _notifyInterval = Duration(milliseconds: 250);
  DateTime? _lastNotify;

  void _notifyThrottled() {
    final now = DateTime.now();
    final last = _lastNotify;
    if (last != null && now.difference(last) < _notifyInterval) return;
    _lastNotify = now;
    notifyListeners();
  }

  void _resetRate() {
    _rateSampleTime = null;
    _rateSampleBytes = 0;
    _bytesPerSecond = 0;
    _lastNotify = null;
  }

  /// Samples the rate about once a second so the number is readable instead of
  /// flickering with every chunk.
  void _updateRate(int received) {
    final now = DateTime.now();
    final lastTime = _rateSampleTime;
    if (lastTime == null) {
      _rateSampleTime = now;
      _rateSampleBytes = received;
      return;
    }
    final elapsed = now.difference(lastTime).inMilliseconds;
    if (elapsed < 1000) return;

    final delta = received - _rateSampleBytes;
    _bytesPerSecond = (delta * 1000 / elapsed).round();
    _rateSampleTime = now;
    _rateSampleBytes = received;
  }

  /// Last error hit while writing the index, so a library that is silently
  /// failing to save can be reported instead of appearing to work until the
  /// next launch.
  String? _persistError;
  String? get persistError => _persistError;

  Future<void> _persist() async {
    if (!_indexLoaded) return;
    try {
      await _service.saveIndex(_tasks);
      _persistError = null;
    } catch (e) {
      _persistError = e.toString();
      debugPrint('Sabuflix: falha ao salvar o índice de downloads: $e');
    }
    notifyListeners();
  }
}
