import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/download_item.dart';
import '../models/media_item.dart';
import '../services/download_service.dart';
import '../services/download_store.dart';
import '../services/tmdb_service.dart';

/// Owns the download library and its queue.
///
/// The list is persisted (via [DownloadStore], a plain JSON file — not
/// SharedPreferences, see its doc comment for why) on every state change,
/// and the `.part` file on disk is the source of truth for how many bytes
/// we already have — so closing the app mid-download loses nothing: on
/// the next launch the unfinished items are re-queued and resume where
/// they stopped.
///
/// The library is also self-healing: the downloaded video files are
/// treated as the ultimate authority on what exists. If the index is
/// lost, emptied or unreadable for any reason, [load] rebuilds the
/// missing entries from the files still on disk (via their sidecars, or
/// from the file name plus a TMDB lookup as a last resort). A bug in the
/// bookkeeping can therefore cost a title's metadata, but never the
/// download itself.
class DownloadProvider extends ChangeNotifier {
  /// One transfer at a time: sequential downloads finish sooner and make
  /// resume behaviour predictable.
  static const int maxConcurrent = 1;

  final List<DownloadItem> _items = [];
  final Map<String, DownloadHandle> _handles = {};
  final Map<String, int> _lastNotifyMs = {};

  /// Entries we failed to decode this session, kept exactly as they were
  /// read. They are written back verbatim on every save, so a decoding
  /// bug can never turn into permanent data loss: a future build that
  /// understands them again will pick them right back up.
  final List<Map<String, dynamic>> _unreadableEntries = [];

  final TMDBService _tmdb = TMDBService();

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
      _unreadableEntries.clear();

      for (final entry in entries) {
        try {
          _items.add(DownloadItem.fromJson(entry));
        } catch (e) {
          // Keep the raw entry so the next save writes it back untouched
          // instead of dropping it — a decoding bug costs us this
          // session's view of the item, never the item itself.
          _unreadableEntries.add(entry);
          DownloadService.log('load() não conseguiu ler uma entrada (preservada intacta): $e');
        }
      }

      // Whatever the index says, the videos on disk are the truth.
      final recovered = await _recoverOrphanedFiles();
      if (recovered > 0) {
        DownloadService.log('load() recuperou $recovered download(s) a partir dos arquivos em disco');
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
        '(${_unreadableEntries.length} ilegível(is) preservada(s)): '
        '${_items.map((i) => '${i.id}:${i.status.name}').join(', ')}',
      );
      await _save();
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
      final payload = _items.map((i) => i.toJson()).toList();

      // Carry forward anything we couldn't decode, unless a healthy item
      // with the same id has since taken its place.
      final knownIds = _items.map((i) => i.id).toSet();
      final preserved = _unreadableEntries.where((e) => !knownIds.contains(e['id'])).toList();
      payload.addAll(preserved);

      DownloadService.log(
        'salvando ${_items.length} item(ns)'
        '${preserved.isEmpty ? '' : ' + ${preserved.length} preservada(s)'}: '
        '${_items.map((i) => '${i.id}:${i.status.name}:${i.receivedBytes}b').join(', ')}',
      );
      await DownloadStore.write(payload);

      // Each finished download also keeps its own copy, so the library
      // can be rebuilt even if this index is lost entirely.
      for (final item in _items) {
        if (item.isCompleted) {
          await DownloadStore.writeSidecar(item.id, item.toJson());
        }
      }
    } catch (e) {
      debugPrint('Erro ao salvar downloads: $e');
      DownloadService.log('_save() falhou: $e');
    }
  }

  static final RegExp _episodeIdPattern = RegExp(r'^(\d+)_s(\d+)e(\d+)$');
  static final RegExp _movieIdPattern = RegExp(r'^(\d+)$');

  /// Rebuilds entries for finished videos sitting in the downloads folder
  /// that the index doesn't know about.
  ///
  /// This is what makes a lost or unreadable index a cosmetic problem
  /// rather than a data-loss one: the file is what the user actually
  /// cares about, and it is still right there. Metadata comes from the
  /// download's own sidecar when present; otherwise the file name alone
  /// identifies the title well enough to rebuild a playable entry, and
  /// the real details are filled in from TMDB in the background.
  Future<int> _recoverOrphanedFiles() async {
    final videoFiles = await DownloadService.videoFileNames();
    if (videoFiles.isEmpty) return 0;

    final knownFiles = _items.map((i) => i.fileName).toSet();
    final toEnrich = <DownloadItem>[];
    int recovered = 0;

    for (final fileName in videoFiles) {
      if (knownFiles.contains(fileName)) continue;

      final dot = fileName.lastIndexOf('.');
      final id = dot > 0 ? fileName.substring(0, dot) : fileName;
      final size = await DownloadService.fileSize(fileName);

      final sidecar = await DownloadStore.readSidecar(id);
      if (sidecar != null) {
        try {
          final item = DownloadItem.fromJson(sidecar);
          _items.add(item.copyWith(
            status: DownloadStatus.completed,
            receivedBytes: size,
            totalBytes: size,
            clearError: true,
          ));
          recovered++;
          continue;
        } catch (e) {
          DownloadService.log('sidecar de $id ilegível, caindo para o nome do arquivo: $e');
        }
      }

      final placeholder = _placeholderFor(id: id, fileName: fileName, size: size);
      if (placeholder == null) continue;
      _items.add(placeholder);
      toEnrich.add(placeholder);
      recovered++;
    }

    if (toEnrich.isNotEmpty) {
      // Deliberately not awaited: a recovered download must show up (and
      // be playable) immediately, with or without a working connection.
      unawaited(_enrichRecovered(toEnrich));
    }

    return recovered;
  }

  /// Builds a minimal, playable entry from a download's file name.
  DownloadItem? _placeholderFor({
    required String id,
    required String fileName,
    required int size,
  }) {
    int mediaId;
    int? season;
    int? episode;

    final episodeMatch = _episodeIdPattern.firstMatch(id);
    final movieMatch = _movieIdPattern.firstMatch(id);
    if (episodeMatch != null) {
      mediaId = int.parse(episodeMatch.group(1)!);
      season = int.parse(episodeMatch.group(2)!);
      episode = int.parse(episodeMatch.group(3)!);
    } else if (movieMatch != null) {
      mediaId = int.parse(movieMatch.group(1)!);
    } else {
      // Not a file this app produced — leave it alone.
      return null;
    }

    return DownloadItem(
      id: id,
      media: MediaItem(
        id: mediaId,
        title: 'Download recuperado',
        voteAverage: 0,
        voteCount: 0,
        mediaType: season != null ? 'tv' : 'movie',
        genreIds: const [],
      ),
      url: '',
      fileName: fileName,
      season: season,
      episode: episode,
      status: DownloadStatus.completed,
      receivedBytes: size,
      totalBytes: size,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Restores real titles and artwork for recovered placeholders.
  Future<void> _enrichRecovered(List<DownloadItem> placeholders) async {
    for (final placeholder in placeholders) {
      if (_disposed) return;
      try {
        final details = await _tmdb
            .fetchMediaDetails(placeholder.media.id, placeholder.media.mediaType)
            .timeout(const Duration(seconds: 15));
        if (details == null || _disposed) continue;

        final index = _indexOf(placeholder.id);
        if (index == -1) continue;
        _items[index] = _items[index].copyWithMedia(details);
        DownloadService.log('recuperado ${placeholder.id} identificado como "${details.title}"');
        await _save();
        _safeNotify();
      } catch (e) {
        DownloadService.log('não foi possível identificar ${placeholder.id}: $e');
      }
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
    // Also drop the sidecar, otherwise recovery would resurrect the entry
    // on the next launch.
    await DownloadStore.deleteSidecar(id);
    _unreadableEntries.removeWhere((e) => e['id'] == id);

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
      await DownloadStore.deleteSidecar(id);
      _unreadableEntries.removeWhere((e) => e['id'] == id);
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
