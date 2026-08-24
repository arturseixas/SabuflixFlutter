import '../utils/formatters.dart';
import 'media_item.dart';

/// Lifecycle of a single offline title or episode.
enum DownloadStatus {
  /// Waiting for a free slot in the download queue.
  queued,

  /// Bytes are actively coming in.
  downloading,

  /// Stopped by the user, or interrupted when the app was killed.
  paused,

  /// Fully on disk and playable offline.
  completed,

  /// The transfer failed, or the file went missing after completing.
  failed,
}

DownloadStatus _statusFromName(Object? raw) {
  final name = raw?.toString();
  for (final status in DownloadStatus.values) {
    if (status.name == name) return status;
  }
  return DownloadStatus.paused;
}

/// One row in the Downloads library.
///
/// A movie is stored on its own; an episode carries its season/episode numbers
/// so the Downloads screen can group it under its series.
class DownloadItem {
  final String id;
  final MediaItem media;
  final int? season;
  final int? episode;
  final String? episodeTitle;

  /// Remote source the file came from. Kept so a paused or failed transfer can
  /// be resumed without going back through the stream picker.
  final String url;

  /// Human label of the chosen source, e.g. `1080p · Dublado`.
  final String quality;

  /// File name *relative* to the profile's download folder.
  ///
  /// The absolute path is deliberately never persisted: iOS hands the app a new
  /// container UUID after an update or a restore, and Android can relocate app
  /// storage too, so an absolute path saved yesterday points nowhere today —
  /// which is exactly how a finished download appears to "vanish" once the app
  /// is closed and reopened.
  final String fileName;

  final int receivedBytes;
  final int totalBytes;
  final DownloadStatus status;
  final String? error;

  /// Epoch milliseconds, used to sort the library newest-first.
  final int addedAt;

  const DownloadItem({
    required this.id,
    required this.media,
    required this.url,
    required this.quality,
    required this.fileName,
    required this.addedAt,
    this.season,
    this.episode,
    this.episodeTitle,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.status = DownloadStatus.queued,
    this.error,
  });

  /// Stable identity for a title or a single episode of a series.
  static String buildId(int mediaId, {int? season, int? episode}) {
    if (season != null && episode != null) {
      return 'tv_${mediaId}_s${season}e$episode';
    }
    return 'movie_$mediaId';
  }

  /// Picks a sane on-disk extension from the source URL.
  static String fileNameFor(String id, String url) {
    var extension = 'mp4';
    try {
      final path = Uri.parse(url).path;
      final dot = path.lastIndexOf('.');
      if (dot != -1 && dot < path.length - 1) {
        final candidate = path.substring(dot + 1).toLowerCase();
        if (RegExp(r'^[a-z0-9]{2,4}$').hasMatch(candidate)) {
          extension = candidate;
        }
      }
    } catch (_) {
      // Keep the default extension for URLs we cannot parse.
    }
    return '$id.$extension';
  }

  bool get isEpisode => season != null && episode != null;
  bool get isCompleted => status == DownloadStatus.completed;
  bool get isRunning => status == DownloadStatus.downloading;
  bool get isPending =>
      status == DownloadStatus.queued || status == DownloadStatus.downloading;

  double get progress {
    if (totalBytes <= 0) return 0;
    return (receivedBytes / totalBytes).clamp(0.0, 1.0);
  }

  /// Title shown on the row: the episode name for series, the movie name otherwise.
  String get displayTitle {
    if (!isEpisode) return media.title;
    final name = episodeTitle;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    return 'Episódio $episode';
  }

  String get episodeTag => formatEpisodeTag(season, episode);

  String get sizeLabel =>
      formatBytes(totalBytes > 0 ? totalBytes : receivedBytes);

  String get statusLabel {
    switch (status) {
      case DownloadStatus.queued:
        return 'Na fila';
      case DownloadStatus.downloading:
        return totalBytes > 0
            ? '${(progress * 100).round()}% · ${formatBytes(receivedBytes)} de ${formatBytes(totalBytes)}'
            : 'Baixando · ${formatBytes(receivedBytes)}';
      case DownloadStatus.paused:
        return totalBytes > 0
            ? 'Pausado · ${(progress * 100).round()}%'
            : 'Pausado';
      case DownloadStatus.completed:
        return sizeLabel;
      case DownloadStatus.failed:
        return error ?? 'Falha no download';
    }
  }

  DownloadItem copyWith({
    MediaItem? media,
    String? url,
    String? quality,
    String? fileName,
    String? episodeTitle,
    int? receivedBytes,
    int? totalBytes,
    DownloadStatus? status,
    String? error,
    bool clearError = false,
  }) {
    return DownloadItem(
      id: id,
      media: media ?? this.media,
      season: season,
      episode: episode,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      url: url ?? this.url,
      quality: quality ?? this.quality,
      fileName: fileName ?? this.fileName,
      addedAt: addedAt,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'media': media.forStorage.toJson(),
      'season': season,
      'episode': episode,
      'episodeTitle': episodeTitle,
      'url': url,
      'quality': quality,
      'fileName': fileName,
      'receivedBytes': receivedBytes,
      'totalBytes': totalBytes,
      'status': status.name,
      'error': error,
      'addedAt': addedAt,
    };
  }

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    final media =
        MediaItem.fromJson(Map<String, dynamic>.from(json['media'] as Map));
    final season = (json['season'] as num?)?.toInt();
    final episode = (json['episode'] as num?)?.toInt();
    final id = (json['id'] as String?) ??
        DownloadItem.buildId(media.id, season: season, episode: episode);
    final url = (json['url'] as String?) ?? '';
    return DownloadItem(
      id: id,
      media: media,
      season: season,
      episode: episode,
      episodeTitle: json['episodeTitle'] as String?,
      url: url,
      quality: (json['quality'] as String?) ?? '',
      fileName:
          (json['fileName'] as String?) ?? DownloadItem.fileNameFor(id, url),
      receivedBytes: (json['receivedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      status: _statusFromName(json['status']),
      error: json['error'] as String?,
      addedAt: (json['addedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// All downloaded episodes of one series, so the library can show a single
/// row per show instead of a flat wall of episodes.
class SeriesDownloadGroup {
  final MediaItem series;
  final List<DownloadItem> episodes;

  const SeriesDownloadGroup({required this.series, required this.episodes});

  int get completedCount => episodes.where((e) => e.isCompleted).length;
  int get pendingCount => episodes.where((e) => !e.isCompleted).length;
  int get totalBytes => episodes.fold(
      0, (sum, e) => sum + (e.isCompleted ? e.totalBytes : e.receivedBytes));
  int get newestAt =>
      episodes.fold(0, (newest, e) => e.addedAt > newest ? e.addedAt : newest);

  /// Seasons present in this group, ascending.
  List<int> get seasons {
    final seen = <int>{};
    for (final episode in episodes) {
      final season = episode.season;
      if (season != null) seen.add(season);
    }
    final list = seen.toList()..sort();
    return list;
  }

  List<DownloadItem> episodesOfSeason(int season) {
    final list = episodes.where((e) => e.season == season).toList();
    list.sort((a, b) => (a.episode ?? 0).compareTo(b.episode ?? 0));
    return list;
  }

  String get subtitle {
    final count = episodes.length;
    final plural = count == 1 ? 'episódio' : 'episódios';
    final size = formatBytes(totalBytes);
    if (pendingCount > 0) return '$count $plural · $pendingCount na fila';
    return '$count $plural · $size';
  }
}
