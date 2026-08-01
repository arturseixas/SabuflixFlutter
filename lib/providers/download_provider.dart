import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/download_item.dart';
import '../models/media_item.dart';
import '../services/download_service.dart';
import '../services/download_store.dart';

/// Owns the download library and its queue.
///
/// The list is persisted (via [DownloadStore], a plain JSON file — not
/// SharedPreferences, see its doc comment for why) on every state change,
/// and the `.part` file on disk is the source of truth for how many bytes
/// we already have — so closing the app mid-download loses nothing: on
/// the next launch the unfinished items are re-queued and resume where
/// they stopped.
class DownloadProvider extends ChangeNotifier {
  /// One transfer at a time: sequential downloads finish sooner and make
  /// resume behaviour predictable.
  static const int maxConcurrent = 1;

  final List<DownloadItem> _items = [];
  final Map<String, DownloadHandle> _handles = {};
  final Map<String, int> _lastNotifyMs = {};

  bool _isLoading = true;
  bool _disposed = false;

  DownloadProvider() {
    load();
  }

  List<DownloadItem> get items => List.unmodifiable(_items);

  List<DownloadItem> get completed =>
      _items.where((item) => item.status == DownloadStatus.completed).toList();

  List<DownloadItem> get pending =>
      _items.where((item) => item.status != DownloadStatus.completed).toList();

  bool get isLoading => _isLoading;

  bool get hasActiveDownloads => _items.any((item) => item.isActive);

  /// Queued + running transfers, i.e. what the Downloads badge shows.
  int get activeCount => _items.where((item) => item.isActive).length;

  int get usedBytes => _items.fold<int>(
        0,
        (sum, item) => sum + (item.isCompleted ? item.totalBytes : item.receivedBytes),
      );

  DownloadItem? byId(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  DownloadItem? findFor(int mediaId, {int? season, int? episode}) =>
      byId(DownloadItem.buildId(mediaId, season: season, episode: episode));

  bool isDownloaded(int mediaId, {int? season, int? episode}) =>
      findFor(mediaId, season: season, episode: episode)?.isCompleted ?? false;

  /// Absolute path of a finished download, or `null` when it is not
  /// available offline yet.
  Future<String?> localPathFor(int mediaId, {int? season, int? episode}) async {
    final item = findFor(mediaId, season: season, episode: episode);
    if (item == null || !item.isCompleted) return null;
    if (!await DownloadService.fileExists(item.fileName)) return null;
    return DownloadService.filePath(item.fileName);
  }

  // --- Persistence -------------------------------------------------------

  Future<void> load() async {
    _isLoading = true;
    _safeNotify();

    try {
      final dir = await DownloadService.directory();
      DownloadService.log(
        'load() iniciado [${DownloadService.buildTag}], pasta=${dir.path}',
      );

      final entries = await DownloadStore.read();
      DownloadService.log('load() leu ${entries.length} entrada(s) do disco');
      _items.clear();
      bool hadParseErrors = false;

      for (final entry in entries) {
        try {
          _items.add(DownloadItem.fromJson(entry));
        } catch (e) {
          // A parsing bug must never look like the entry itself was ever
          // gone — surviving on disk is the whole point of this store, so
          // an item we failed to read this session must not get silently
          // overwritten with nothing by the auto-save below. It stays
          // out of the in-memory list for now (so a broken entry can't
          // crash the UI) but the file it came from is left untouched.
          hadParseErrors = true;
          DownloadService.log('load() descartou uma entrada corrompida: $e');
        }
      }

      // Reconcile the saved state with what is actually on disk.
      for (int i = 0; i < _items.length; i++) {
        final item = _items[i];
        if (item.status == DownloadStatus.completed) {
          final exists = await DownloadService.fileExists(item.fileName);
          if (!exists) {
            _items[i] = item.copyWith(
              status: DownloadStatus.failed,
              receivedBytes: 0,
              errorMessage: 'Arquivo não encontrado no dispositivo',
            );
          }
          continue;
        }

        final onDisk = await DownloadService.partialSize(item.fileName);
        // Anything left mid-flight by a previous session goes back to the
        // queue so it picks up automatically.
        final status = item.status == DownloadStatus.downloading || item.status == DownloadStatus.queued
            ? DownloadStatus.queued
            : item.status;
        _items[i] = item.copyWith(status: status, receivedBytes: onDisk);
      }

      _sort();
      DownloadService.log(
        'load() finalizado com ${_items.length} item(ns) '
        '(erros de parse: $hadParseErrors): '
        '${_items.map((i) => '${i.id}:${i.status.name}').join(', ')}',
      );
      if (hadParseErrors) {
        DownloadService.log('load() NÃO salvou de volta — havia entrada(s) que falharam ao ler');
      } else {
        await _save();
      }
    } catch (e) {
      debugPrint('Erro ao carregar downloads: $e');
      DownloadService.log('load() falhou: $e');
    }

    _isLoading = false;
    _safeNotify();
    _pump();
  }

  Future<void> _save() async {
    try {
      DownloadService.log(
        'salvando ${_items.length} item(ns): '
        '${_items.map((i) => '${i.id}:${i.status.name}:${i.receivedBytes}b').join(', ')}',
      );
      await DownloadStore.write(_items.map((i) => i.toJson()).toList());
    } catch (e) {
      debugPrint('Erro ao salvar downloads: $e');
      DownloadService.log('_save() falhou: $e');
    }
  }

  void _sort() {
    _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  int _indexOf(String id) => _items.indexWhere((item) => item.id == id);

  void _replace(String id, DownloadItem Function(DownloadItem) update) {
    final index = _indexOf(id);
    if (index == -1) return;
    _items[index] = update(_items[index]);
  }

  // --- Queue -------------------------------------------------------------

  /// Adds a title (or episode) to the download queue.
  ///
  /// Returns `false` when the same entry is already downloaded or queued.
  Future<bool> addDownload({
    required MediaItem media,
    required String url,
    String sourceName = '',
    String quality = '',
    int? season,
    int? episode,
  }) async {
    if (url.isEmpty) return false;

    final id = DownloadItem.buildId(media.id, season: season, episode: episode);
    final existing = byId(id);
    if (existing != null) {
      if (existing.status == DownloadStatus.failed) {
        await retry(id);
        return true;
      }
      return false;
    }

    final item = DownloadItem(
      id: id,
      media: media,
      url: url,
      fileName: DownloadService.buildFileName(downloadId: id, url: url),
      sourceName: sourceName,
      quality: quality,
      season: season,
      episode: episode,
      status: DownloadStatus.queued,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    _items.insert(0, item);
    _sort();
    await _save();
    _safeNotify();
    _pump();
    return true;
  }

  Future<void> pause(String id) async {
    final handle = _handles.remove(id);
    await handle?.cancel();

    final item = byId(id);
    if (item == null || item.isCompleted) return;

    final onDisk = await DownloadService.partialSize(item.fileName);
    _replace(id, (i) => i.copyWith(status: DownloadStatus.paused, receivedBytes: onDisk));
    await _save();
    _safeNotify();
    _pump();
  }

  Future<void> resume(String id) async {
    final item = byId(id);
    if (item == null || item.isCompleted || _handles.containsKey(id)) return;

    _replace(id, (i) => i.copyWith(status: DownloadStatus.queued, clearError: true));
    await _save();
    _safeNotify();
    _pump();
  }

  Future<void> retry(String id) async {
    final item = byId(id);
    if (item == null) return;

    final handle = _handles.remove(id);
    await handle?.cancel();

    // A failed transfer may have left a truncated tail behind; start clean.
    await DownloadService.deleteFiles(item.fileName);
    _replace(
      id,
      (i) => i.copyWith(
        status: DownloadStatus.queued,
        receivedBytes: 0,
        totalBytes: 0,
        clearError: true,
      ),
    );
    await _save();
    _safeNotify();
    _pump();
  }

  /// Cancels the transfer (when running), erases the files and drops the
  /// entry from the library.
  Future<void> remove(String id) async {
    final handle = _handles.remove(id);
    await handle?.cancel();

    final item = byId(id);
    if (item != null) await DownloadService.deleteFiles(item.fileName);

    _items.removeWhere((i) => i.id == id);
    _lastNotifyMs.remove(id);
    await _save();
    _safeNotify();
    _pump();
  }

  Future<void> removeAllCompleted() async {
    final ids = completed.map((item) => item.id).toList();
    for (final id in ids) {
      final item = byId(id);
      if (item != null) await DownloadService.deleteFiles(item.fileName);
      _items.removeWhere((i) => i.id == id);
      _lastNotifyMs.remove(id);
    }
    await _save();
    _safeNotify();
  }

  Future<void> pauseAll() async {
    for (final item in _items.where((i) => i.isActive).toList()) {
      await pause(item.id);
    }
  }

  /// Starts queued items until [maxConcurrent] transfers are running.
  void _pump() {
    if (_disposed) return;
    while (_handles.length < maxConcurrent) {
      DownloadItem? next;
      for (final item in _items.reversed) {
        if (item.status == DownloadStatus.queued && !_handles.containsKey(item.id)) {
          next = item;
          break;
        }
      }
      if (next == null) return;
      _start(next);
    }
  }

  void _start(DownloadItem item) {
    _replace(item.id, (i) => i.copyWith(status: DownloadStatus.downloading, clearError: true));
    _safeNotify();
    unawaited(_save());

    final handle = DownloadService.start(
      url: item.url,
      fileName: item.fileName,
      onProgress: (received, total) => _onProgress(item.id, received, total),
      onComplete: (path) => _onComplete(item.id, path),
      onError: (error) => _onError(item.id, error),
    );
    _handles[item.id] = handle;
  }

  void _onProgress(String id, int received, int total) {
    final index = _indexOf(id);
    if (index == -1) return;

    final current = _items[index];
    _items[index] = current.copyWith(
      receivedBytes: received,
      totalBytes: total > 0 ? total : current.totalBytes,
    );

    // Repainting on every chunk would burn frames for nothing; ~400ms is
    // still a smooth-looking progress bar.
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastNotifyMs[id] ?? 0;
    if (now - last < 400) return;
    _lastNotifyMs[id] = now;
    _safeNotify();
  }

  Future<void> _onComplete(String id, String path) async {
    _handles.remove(id);
    final size = await DownloadService.fileSize(byId(id)?.fileName ?? '');
    _replace(
      id,
      (i) => i.copyWith(
        status: DownloadStatus.completed,
        receivedBytes: size > 0 ? size : i.receivedBytes,
        totalBytes: size > 0 ? size : i.totalBytes,
        clearError: true,
      ),
    );
    await _save();
    _safeNotify();
    _pump();
  }

  Future<void> _onError(String id, Object error) async {
    _handles.remove(id);
    final item = byId(id);
    if (item != null) {
      final onDisk = await DownloadService.partialSize(item.fileName);
      _replace(
        id,
        (i) => i.copyWith(
          status: DownloadStatus.failed,
          receivedBytes: onDisk,
          errorMessage: _friendlyError(error),
        ),
      );
      await _save();
    }
    _safeNotify();
    _pump();
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('SocketException') || text.contains('Failed host lookup')) {
      return 'Sem conexão com a fonte';
    }
    if (text.contains('espaço') || text.contains('No space left')) {
      return 'Sem espaço no dispositivo';
    }
    return text.replaceFirst('Exception: ', '');
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final handle in _handles.values) {
      handle.cancel();
    }
    _handles.clear();
    super.dispose();
  }
}
