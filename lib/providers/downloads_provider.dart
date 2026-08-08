import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/download_item.dart';
import '../models/media_item.dart';
import '../services/download_service.dart';

/// Owns the offline download library for the active profile.
///
/// One transfer runs at a time; everything else waits in the queue. Transfers
/// are streamed straight to disk and resumed with a HTTP `Range` request when
/// the user pauses or the app is closed mid-download.
class DownloadsProvider extends ChangeNotifier {
  final DownloadService _service = DownloadService();

  List<DownloadItem> _downloads = [];
  bool _isLoading = true;
  String? _profileId;
  String? _directoryPath;

  // --- Active transfer bookkeeping -------------------------------------
  String? _activeId;
  Future<void>? _activeRun;
  StreamSubscription<List<int>>? _activeSub;
  Completer<void>? _activeCompleter;
  http.Client? _activeClient;
  bool _cancelRequested = false;
  DateTime _lastProgressNotify = DateTime.fromMillisecondsSinceEpoch(0);

  /// Guards against a slow load landing after a newer one and clobbering it
  /// (the initial default-profile load racing the profile the user picked).
  int _loadToken = 0;

  DownloadsProvider() {
    loadForProfile(null);
  }

  /// Newest first — the order the library reads in.
  List<DownloadItem> get downloads => List.unmodifiable(_downloads);
  bool get isLoading => _isLoading;
  String? get activeId => _activeId;

  List<DownloadItem> get completed =>
      _downloads.where((d) => d.status == DownloadStatus.completed).toList();

  int get totalBytesOnDisk =>
      _downloads.fold(0, (sum, d) => sum + d.bytesReceived);

  /// Loads the library of a profile, flipping any transfer that was cut short
  /// by an app close back to `paused` so the user can resume it.
  Future<void> loadForProfile(String? profileId) async {
    final token = ++_loadToken;
    await _stopActive();
    if (token != _loadToken) return;

    _profileId = profileId;
    _isLoading = true;
    notifyListeners();

    String? directory;
    try {
      directory = (await _service.ensureDirectory(profileId)).path;
    } catch (e) {
      directory = null;
    }

    final loaded = await _service.load(profileId);
    if (token != _loadToken) return;

    _directoryPath = directory;
    _downloads = loaded
        .map((d) => d.status == DownloadStatus.downloading
            ? d.copyWith(status: DownloadStatus.paused)
            : d)
        .toList();
    _sort();

    _isLoading = false;
    notifyListeners();

    await _save();
    _maybeStartNext();
  }

  // --- Queries ---------------------------------------------------------

  DownloadItem? itemById(String id) {
    final index = _indexOf(id);
    return index < 0 ? null : _downloads[index];
  }

  DownloadItem? itemFor(MediaItem media, {int? season, int? episode}) {
    return itemById(DownloadItem.buildId(media.id, media.mediaType,
        season: season, episode: episode));
  }

  bool isDownloaded(MediaItem media, {int? season, int? episode}) {
    return itemFor(media, season: season, episode: episode)?.status ==
        DownloadStatus.completed;
  }

  /// Absolute path of a finished download, for offline playback.
  String? filePathFor(DownloadItem item) {
    if (_directoryPath == null) return null;
    return _service.fileFor(_directoryPath!, item).path;
  }

  // --- Mutations -------------------------------------------------------

  /// Adds a stream to the download queue. Returns false when that exact title
  /// (or episode) is already downloaded or queued.
  Future<bool> enqueue({
    required MediaItem media,
    required String url,
    required String sourceName,
    required String quality,
    int? season,
    int? episode,
  }) async {
    if (url.isEmpty) return false;

    final id = DownloadItem.buildId(media.id, media.mediaType,
        season: season, episode: episode);
    final existing = itemById(id);
    if (existing != null && existing.status != DownloadStatus.failed) {
      return false;
    }
    if (existing != null) {
      // Retry a previously failed item with the newly picked source.
      await remove(id);
    }

    _downloads.add(DownloadItem(
      id: id,
      media: media,
      season: season,
      episode: episode,
      sourceName: sourceName,
      quality: quality,
      url: url,
      fileName: _service.buildFileName(id, url),
      createdAt: DateTime.now(),
    ));
    _sort();
    notifyListeners();

    await _save();
    _maybeStartNext();
    return true;
  }

  Future<void> pause(String id) async {
    final item = itemById(id);
    if (item == null || !item.isActive) return;

    if (_activeId == id) await _stopActive();
    _patch(id, (d) => d.copyWith(status: DownloadStatus.paused));
    await _save();
  }

  Future<void> resume(String id) async {
    final item = itemById(id);
    if (item == null) return;
    if (item.status == DownloadStatus.completed || item.status == DownloadStatus.downloading) {
      return;
    }

    _patch(id, (d) => d.copyWith(status: DownloadStatus.queued, clearError: true));
    await _save();
    _maybeStartNext();
  }

  /// Cancels the transfer if running, deletes the media file and drops the
  /// entry from the library.
  Future<void> remove(String id) async {
    final item = itemById(id);
    if (item == null) return;

    if (_activeId == id) await _stopActive();
    if (_directoryPath != null) {
      await _service.deleteFile(_directoryPath!, item);
    }
    _downloads.removeWhere((d) => d.id == id);
    notifyListeners();

    await _save();
    _maybeStartNext();
  }

  Future<void> clearCompleted() async {
    final finished = _downloads.where((d) => d.status == DownloadStatus.completed).toList();
    for (final item in finished) {
      if (_directoryPath != null) {
        await _service.deleteFile(_directoryPath!, item);
      }
    }
    _downloads.removeWhere((d) => d.status == DownloadStatus.completed);
    notifyListeners();
    await _save();
  }

  // --- Transfer engine -------------------------------------------------

  void _maybeStartNext() {
    if (_activeId != null || _directoryPath == null) return;
    final next = _downloads.where((d) => d.status == DownloadStatus.queued).toList();
    if (next.isEmpty) return;
    _activeRun = _run(next.first.id);
  }

  Future<void> _run(String id) async {
    final item = itemById(id);
    if (item == null) return;

    _activeId = id;
    _cancelRequested = false;
    _patch(id, (d) => d.copyWith(status: DownloadStatus.downloading, clearError: true));

    final file = _service.fileFor(_directoryPath!, item);
    final client = http.Client();
    _activeClient = client;
    // Held only so the `finally` can close a sink an error left open.
    IOSink? pendingSink;

    try {
      var existingBytes = 0;
      if (await file.exists()) existingBytes = await file.length();

      final request = http.Request('GET', Uri.parse(item.url));
      if (existingBytes > 0) {
        request.headers['range'] = 'bytes=$existingBytes-';
      }
      final response = await client.send(request);

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException('Servidor respondeu ${response.statusCode}');
      }

      // A 200 to a ranged request means the server ignored it: start over.
      final appending = response.statusCode == 206 && existingBytes > 0;
      if (!appending) existingBytes = 0;

      final total = (response.contentLength ?? 0) + existingBytes;
      var received = existingBytes;

      final sink = file.openWrite(mode: appending ? FileMode.append : FileMode.write);
      pendingSink = sink;
      _patch(id, (d) => d.copyWith(bytesReceived: received, totalBytes: total));

      final completer = Completer<void>();
      _activeCompleter = completer;
      var sinceFlush = 0;

      final sub = response.stream.listen(
        (chunk) {
          sink.add(chunk);
          received += chunk.length;
          sinceFlush += chunk.length;

          // Backpressure: hold the socket until the disk catches up, so a
          // fast connection can't buffer a whole movie in memory.
          if (sinceFlush >= 2 * 1024 * 1024) {
            sinceFlush = 0;
            _activeSub?.pause(sink.flush());
          }
          _reportProgress(id, received, total);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (Object e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
        cancelOnError: true,
      );
      _activeSub = sub;

      await completer.future;

      await sink.flush();
      await sink.close();
      pendingSink = null;

      if (_cancelRequested) return; // pause()/remove() owns the state now.

      final onDisk = await file.length();
      if (total > 0 && onDisk < total) {
        throw const HttpException('Transferência incompleta');
      }
      _patch(
        id,
        (d) => d.copyWith(
          status: DownloadStatus.completed,
          bytesReceived: onDisk,
          totalBytes: total > 0 ? total : onDisk,
          clearError: true,
        ),
      );
    } catch (e) {
      if (!_cancelRequested) {
        _patch(id, (d) => d.copyWith(status: DownloadStatus.failed, error: _readableError(e)));
      }
    } finally {
      try {
        await pendingSink?.flush();
        await pendingSink?.close();
      } catch (_) {
        // Nothing else to do — the partial file stays for a later resume.
      }
      client.close();
      _activeSub = null;
      _activeCompleter = null;
      _activeClient = null;
      _activeId = null;
      _activeRun = null;
      await _save();
      _maybeStartNext();
    }
  }

  /// Stops the running transfer and waits until its file handle is closed.
  Future<void> _stopActive() async {
    if (_activeId == null) return;
    _cancelRequested = true;

    await _activeSub?.cancel();
    if (!(_activeCompleter?.isCompleted ?? true)) {
      _activeCompleter!.complete();
    }
    try {
      await _activeRun;
    } catch (_) {
      // _run reports its own failures.
    }
    _cancelRequested = false;
  }

  void _reportProgress(String id, int received, int total) {
    final index = _indexOf(id);
    if (index < 0) return;
    _downloads[index] = _downloads[index].copyWith(bytesReceived: received, totalBytes: total);

    // Repainting on every chunk would peg the UI thread.
    final now = DateTime.now();
    if (now.difference(_lastProgressNotify).inMilliseconds < 350) return;
    _lastProgressNotify = now;
    notifyListeners();
  }

  String _readableError(Object e) {
    if (e is SocketException) return 'Sem conexão com a fonte';
    if (e is HttpException) return e.message;
    return e.toString();
  }

  int _indexOf(String id) => _downloads.indexWhere((d) => d.id == id);

  void _patch(String id, DownloadItem Function(DownloadItem) update) {
    final index = _indexOf(id);
    if (index < 0) return;
    _downloads[index] = update(_downloads[index]);
    notifyListeners();
  }

  void _sort() {
    _downloads.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _save() => _service.save(_downloads, _profileId);

  @override
  void dispose() {
    _activeSub?.cancel();
    _activeClient?.close();
    super.dispose();
  }
}
