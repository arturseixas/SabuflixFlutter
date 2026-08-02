import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/download_task.dart';
import '../models/media_item.dart';
import 'froststream_service.dart';

/// Queue, worker and bookkeeping for offline downloads.
///
/// Two downloads run at a time; everything else waits in the queue, which is
/// what makes "download the whole series" reasonable — 60 episodes can be
/// queued in one tap without opening 60 sockets.
class DownloadService extends ChangeNotifier {
  DownloadService._();

  static final DownloadService instance = DownloadService._();

  static const String _prefsKey = 'sabuflix_downloads_v1';
  static const int _maxConcurrent = 2;

  final List<DownloadTask> _tasks = [];
  final Set<String> _running = {};

  /// Ids whose worker should stop at the next chunk boundary.
  final Set<String> _stopRequests = {};

  /// Ids to delete once their worker has actually stopped.
  final Set<String> _cancelRequests = {};

  bool _loaded = false;
  Timer? _saveDebounce;

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  bool get isLoaded => _loaded;

  List<DownloadTask> get activeTasks =>
      _tasks.where((t) => t.status.isActive).toList();

  /// Downloads grouped by title — the shape the downloads screen renders.
  /// Series come first, then films, each newest-first.
  List<DownloadGroup> get groups {
    final byMedia = <int, List<DownloadTask>>{};
    for (final task in _tasks) {
      byMedia.putIfAbsent(task.media.id, () => []).add(task);
    }

    final groups = byMedia.values
        .map((tasks) => DownloadGroup(media: tasks.first.media, tasks: tasks))
        .toList();

    groups.sort((a, b) {
      if (a.isSeries != b.isSeries) return a.isSeries ? -1 : 1;
      return a.media.title.toLowerCase().compareTo(b.media.title.toLowerCase());
    });
    return groups;
  }

  DownloadTask? taskFor(int mediaId, {int? season, int? episode}) {
    final id = DownloadTask.buildId(mediaId, season: season, episode: episode);
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  /// Local path of a finished download, if the file is still on disk.
  Future<String?> completedFilePath(
    int mediaId, {
    int? season,
    int? episode,
  }) async {
    final task = taskFor(mediaId, season: season, episode: episode);
    if (task == null || task.status != DownloadStatus.completed) return null;
    final path = task.filePath;
    if (path == null) return null;
    return await File(path).exists() ? path : null;
  }

  // --- Persistence ------------------------------------------------------

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = json.decode(raw) as List<dynamic>;
        _tasks
          ..clear()
          ..addAll(decoded.map(
            (item) => DownloadTask.fromJson(Map<String, dynamic>.from(item as Map)),
          ));
      }

      // A file removed behind the app's back (OS cleanup, manual delete)
      // should not keep claiming to be downloaded.
      for (final task in _tasks) {
        if (task.status == DownloadStatus.completed &&
            (task.filePath == null || !await File(task.filePath!).exists())) {
          task.status = DownloadStatus.failed;
          task.error = 'Arquivo removido do dispositivo';
        }
      }
    } catch (e) {
      debugPrint('Downloads: could not restore queue — $e');
    }
    notifyListeners();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 700), _save);
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        json.encode(_tasks.map((task) => task.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('Downloads: could not persist queue — $e');
    }
  }

  // --- Queueing ---------------------------------------------------------

  /// Queues a film.
  DownloadTask enqueueMovie(MediaItem media, {String? url, String? quality}) {
    return _enqueue(DownloadTask(
      id: DownloadTask.buildId(media.id),
      media: media,
      imdbId: media.imdbId,
      url: url,
      qualityLabel: quality,
    ));
  }

  /// Queues one episode.
  DownloadTask enqueueEpisode({
    required MediaItem media,
    required int season,
    required int episode,
    String? episodeTitle,
    String? stillPath,
    String? url,
    String? quality,
  }) {
    return _enqueue(DownloadTask(
      id: DownloadTask.buildId(media.id, season: season, episode: episode),
      media: media,
      season: season,
      episode: episode,
      episodeTitle: episodeTitle,
      stillPath: stillPath,
      imdbId: media.imdbId,
      url: url,
      qualityLabel: quality,
    ));
  }

  /// Queues many episodes at once — a season, or an entire series.
  ///
  /// Episodes already downloaded (or already in the queue) are skipped, so
  /// tapping "baixar série inteira" twice does not duplicate work. Returns
  /// how many new downloads were added.
  int enqueueEpisodes({
    required MediaItem media,
    required List<({int season, int episode, String? title, String? stillPath})> episodes,
  }) {
    var added = 0;
    for (final entry in episodes) {
      final existing = taskFor(media.id, season: entry.season, episode: entry.episode);
      if (existing != null && existing.status != DownloadStatus.failed) continue;
      if (existing != null) remove(existing.id);

      enqueueEpisode(
        media: media,
        season: entry.season,
        episode: entry.episode,
        episodeTitle: entry.title,
        stillPath: entry.stillPath,
      );
      added++;
    }
    return added;
  }

  DownloadTask _enqueue(DownloadTask task) {
    final existingIndex = _tasks.indexWhere((t) => t.id == task.id);
    if (existingIndex >= 0) {
      final existing = _tasks[existingIndex];
      if (existing.status == DownloadStatus.completed) return existing;
      existing.status = DownloadStatus.queued;
      existing.error = null;
      if (task.url != null) existing.url = task.url;
      notifyListeners();
      _scheduleSave();
      _pump();
      return existing;
    }

    _tasks.add(task);
    notifyListeners();
    _scheduleSave();
    _pump();
    return task;
  }

  // --- Control ----------------------------------------------------------

  void pause(String id) {
    final task = _byId(id);
    if (task == null || !task.status.isActive) return;
    _stopRequests.add(id);
    task.status = DownloadStatus.paused;
    notifyListeners();
    _scheduleSave();
    // A queued task has no worker to interrupt; free the slot immediately.
    if (!_running.contains(id)) _stopRequests.remove(id);
  }

  void resume(String id) {
    final task = _byId(id);
    if (task == null) return;
    if (task.status == DownloadStatus.completed) return;
    _stopRequests.remove(id);
    task.status = DownloadStatus.queued;
    task.error = null;
    notifyListeners();
    _scheduleSave();
    _pump();
  }

  void pauseAll() {
    for (final task in _tasks.where((t) => t.status.isActive).toList()) {
      pause(task.id);
    }
  }

  void resumeAll() {
    for (final task in _tasks.where((t) => t.status == DownloadStatus.paused).toList()) {
      resume(task.id);
    }
  }

  /// Cancels (if running) and deletes the download plus its partial file.
  void remove(String id) {
    final task = _byId(id);
    if (task == null) return;

    if (_running.contains(id)) {
      // The worker owns the file handle; let it finish the current chunk and
      // clean up in _finishRemoval.
      _cancelRequests.add(id);
      _stopRequests.add(id);
      task.status = DownloadStatus.paused;
      notifyListeners();
      return;
    }

    _tasks.removeWhere((t) => t.id == id);
    _deleteFile(task.filePath);
    notifyListeners();
    _scheduleSave();
  }

  /// Removes every download of a series/film in one go.
  void removeGroup(int mediaId) {
    for (final task in _tasks.where((t) => t.media.id == mediaId).toList()) {
      remove(task.id);
    }
  }

  void retry(String id) => resume(id);

  DownloadTask? _byId(String id) {
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  Future<void> _deleteFile(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('Downloads: could not delete $path — $e');
    }
  }

  // --- Worker -----------------------------------------------------------

  void _pump() {
    while (_running.length < _maxConcurrent) {
      DownloadTask? next;
      for (final task in _tasks) {
        if (task.status == DownloadStatus.queued && !_running.contains(task.id)) {
          next = task;
          break;
        }
      }
      if (next == null) return;
      _running.add(next.id);
      unawaited(_run(next));
    }
  }

  Future<void> _run(DownloadTask task) async {
    try {
      if (_stopRequests.contains(task.id)) return;

      if (task.url == null || task.url!.isEmpty) {
        task.status = DownloadStatus.resolving;
        notifyListeners();
        final resolved = await _resolveSource(task);
        if (resolved == null) {
          task.status = DownloadStatus.failed;
          task.error = 'Nenhuma fonte encontrada para baixar';
          notifyListeners();
          _scheduleSave();
          return;
        }
        task.url = resolved.$1;
        task.qualityLabel = resolved.$2;
      }

      if (_stopRequests.contains(task.id)) {
        task.status = DownloadStatus.paused;
        notifyListeners();
        return;
      }

      await _download(task);
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.error = '$e';
      notifyListeners();
      _scheduleSave();
    } finally {
      _running.remove(task.id);
      _stopRequests.remove(task.id);
      if (_cancelRequests.remove(task.id)) {
        _tasks.removeWhere((t) => t.id == task.id);
        await _deleteFile(task.filePath);
        notifyListeners();
      }
      _scheduleSave();
      _pump();
    }
  }

  /// Asks FrostStream for a source and picks the best quality on offer.
  Future<(String, String?)?> _resolveSource(DownloadTask task) async {
    final imdbId = task.imdbId ?? task.media.imdbId;
    if (imdbId == null || imdbId.isEmpty) return null;

    final streams = await FrostStreamService.fetchStreams(
      imdbId: imdbId,
      type: task.media.mediaType,
      season: task.season,
      episode: task.episode,
    );

    final candidates = streams
        .where((s) => (s['url'] as String?)?.isNotEmpty ?? false)
        .toList();
    if (candidates.isEmpty) return null;

    candidates.sort((a, b) => _qualityScore(b).compareTo(_qualityScore(a)));
    final best = candidates.first;
    return (best['url'] as String, best['name'] as String?);
  }

  /// Prefers 1080p: high enough to be worth the disk, small enough to finish.
  static int _qualityScore(Map<String, dynamic> stream) {
    final text = '${stream['name'] ?? ''} ${stream['title'] ?? ''}'.toLowerCase();
    if (text.contains('2160') || text.contains('4k')) return 3;
    if (text.contains('1080')) return 5;
    if (text.contains('720')) return 4;
    if (text.contains('480')) return 2;
    return 1;
  }

  Future<void> _download(DownloadTask task) async {
    final file = File(task.filePath ?? await _targetPath(task));
    task.filePath = file.path;
    await file.parent.create(recursive: true);

    var offset = 0;
    if (await file.exists()) {
      offset = await file.length();
      // A partial file bigger than the recorded total means the previous
      // attempt wrote something else entirely — start over.
      if (task.totalBytes > 0 && offset >= task.totalBytes) offset = 0;
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    IOSink? sink;
    try {
      final request = await client.getUrl(Uri.parse(task.url!));
      request.headers.set(HttpHeaders.userAgentHeader, 'Sabuflix/1.0');
      if (offset > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
      }

      final response = await request.close();
      final resumed = response.statusCode == HttpStatus.partialContent;

      if (response.statusCode != HttpStatus.ok && !resumed) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      if (offset > 0 && !resumed) {
        // Server ignored the Range header — restart from scratch.
        offset = 0;
      }

      task.receivedBytes = offset;
      task.totalBytes = response.contentLength > 0
          ? response.contentLength + offset
          : task.totalBytes;
      task.status = DownloadStatus.downloading;
      notifyListeners();

      sink = file.openWrite(mode: offset > 0 ? FileMode.append : FileMode.write);

      var lastNotify = DateTime.now();
      var stopped = false;

      await for (final chunk in response) {
        if (_stopRequests.contains(task.id)) {
          stopped = true;
          break;
        }
        sink.add(chunk);
        task.receivedBytes += chunk.length;

        // Repainting on every chunk would rebuild the list hundreds of times
        // a second for no visible gain.
        final now = DateTime.now();
        if (now.difference(lastNotify) > const Duration(milliseconds: 400)) {
          lastNotify = now;
          notifyListeners();
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (stopped) {
        task.status = DownloadStatus.paused;
      } else {
        task.status = DownloadStatus.completed;
        task.totalBytes = task.receivedBytes;
        task.error = null;
      }
      notifyListeners();
      _scheduleSave();
    } finally {
      try {
        await sink?.close();
      } catch (_) {
        // Sink already closed after a successful run.
      }
      client.close(force: true);
    }
  }

  Future<String> _targetPath(DownloadTask task) async {
    final base = await getApplicationSupportDirectory();
    final folder = Directory('${base.path}/downloads/${task.media.id}');
    final extension = _extensionFor(task.url);
    final name = task.isEpisode
        ? 's${task.season}e${task.episode}$extension'
        : 'movie$extension';
    return '${folder.path}/$name';
  }

  static String _extensionFor(String? url) {
    final path = url == null ? '' : (Uri.tryParse(url)?.path.toLowerCase() ?? '');
    for (final extension in ['.mkv', '.mp4', '.avi', '.webm', '.mov']) {
      if (path.endsWith(extension)) return extension;
    }
    return '.mp4';
  }
}
