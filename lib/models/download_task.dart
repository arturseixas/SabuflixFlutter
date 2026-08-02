import '../models/media_item.dart';

enum DownloadStatus { queued, resolving, downloading, paused, completed, failed }

extension DownloadStatusLabel on DownloadStatus {
  String get label {
    switch (this) {
      case DownloadStatus.queued:
        return 'Na fila';
      case DownloadStatus.resolving:
        return 'Buscando fonte…';
      case DownloadStatus.downloading:
        return 'Baixando';
      case DownloadStatus.paused:
        return 'Pausado';
      case DownloadStatus.completed:
        return 'Baixado';
      case DownloadStatus.failed:
        return 'Falhou';
    }
  }

  bool get isActive =>
      this == DownloadStatus.queued ||
      this == DownloadStatus.resolving ||
      this == DownloadStatus.downloading;
}

/// One downloadable item: a film, or a single episode of a series.
///
/// The source URL is deliberately optional. Queueing a whole series would
/// otherwise mean resolving a stream for every episode up front — dozens of
/// requests, most of them stale by the time the download starts. Instead the
/// task carries the IMDB id plus season/episode and resolves its own URL when
/// it reaches the front of the queue.
class DownloadTask {
  final String id;
  final MediaItem media;
  final int? season;
  final int? episode;
  final String? episodeTitle;
  final String? stillPath;
  final String? imdbId;

  String? url;
  String? qualityLabel;
  String? filePath;
  int receivedBytes;
  int totalBytes;
  DownloadStatus status;
  String? error;

  DownloadTask({
    required this.id,
    required this.media,
    this.season,
    this.episode,
    this.episodeTitle,
    this.stillPath,
    this.imdbId,
    this.url,
    this.qualityLabel,
    this.filePath,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.status = DownloadStatus.queued,
    this.error,
  });

  static String buildId(int mediaId, {int? season, int? episode}) {
    if (season != null && episode != null) return '$mediaId-s$season-e$episode';
    return '$mediaId';
  }

  bool get isEpisode => season != null && episode != null;

  /// `Severance · T1:E4 — Woe's Hollow` style label used in lists.
  String get title {
    if (!isEpisode) return media.title;
    final name = episodeTitle;
    final prefix = 'T$season:E$episode';
    return name == null || name.isEmpty ? prefix : '$prefix — $name';
  }

  double get progress {
    if (status == DownloadStatus.completed) return 1;
    if (totalBytes <= 0) return 0;
    return (receivedBytes / totalBytes).clamp(0.0, 1.0);
  }

  String get formattedSize {
    if (totalBytes <= 0) {
      return receivedBytes <= 0 ? '' : _formatBytes(receivedBytes);
    }
    return '${_formatBytes(receivedBytes)} / ${_formatBytes(totalBytes)}';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'media': media.toJson(),
        'season': season,
        'episode': episode,
        'episodeTitle': episodeTitle,
        'stillPath': stillPath,
        'imdbId': imdbId,
        'url': url,
        'qualityLabel': qualityLabel,
        'filePath': filePath,
        'receivedBytes': receivedBytes,
        'totalBytes': totalBytes,
        // Anything mid-flight when the app closed comes back as paused, so a
        // restart never silently resumes a dozen downloads over mobile data.
        'status': (status == DownloadStatus.completed
                ? DownloadStatus.completed
                : status == DownloadStatus.failed
                    ? DownloadStatus.failed
                    : DownloadStatus.paused)
            .name,
        'error': error,
      };

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'] as String,
      media: MediaItem.fromJson(Map<String, dynamic>.from(json['media'] as Map)),
      season: json['season'] as int?,
      episode: json['episode'] as int?,
      episodeTitle: json['episodeTitle'] as String?,
      stillPath: json['stillPath'] as String?,
      imdbId: json['imdbId'] as String?,
      url: json['url'] as String?,
      qualityLabel: json['qualityLabel'] as String?,
      filePath: json['filePath'] as String?,
      receivedBytes: json['receivedBytes'] as int? ?? 0,
      totalBytes: json['totalBytes'] as int? ?? 0,
      status: DownloadStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => DownloadStatus.paused,
      ),
      error: json['error'] as String?,
    );
  }

  String get fullStillPath {
    if (stillPath != null && stillPath!.isNotEmpty) {
      return 'https://image.tmdb.org/t/p/w300$stillPath';
    }
    return media.fullBackdropPath;
  }
}

/// A series (or a film) with everything downloaded for it, ready to render as
/// one collapsible card.
class DownloadGroup {
  final MediaItem media;
  final List<DownloadTask> tasks;

  DownloadGroup({required this.media, required this.tasks});

  bool get isSeries => media.mediaType == 'tv';

  /// Episodes bucketed by season number, seasons and episodes in order.
  Map<int, List<DownloadTask>> get seasons {
    final result = <int, List<DownloadTask>>{};
    for (final task in tasks) {
      result.putIfAbsent(task.season ?? 0, () => []).add(task);
    }
    for (final entry in result.entries) {
      entry.value.sort((a, b) => (a.episode ?? 0).compareTo(b.episode ?? 0));
    }
    return Map.fromEntries(
      result.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  int get completedCount =>
      tasks.where((t) => t.status == DownloadStatus.completed).length;

  int get activeCount => tasks.where((t) => t.status.isActive).length;

  int get totalBytes => tasks.fold(0, (sum, t) => sum + t.totalBytes);

  int get receivedBytes => tasks.fold(0, (sum, t) => sum + t.receivedBytes);

  double get progress {
    if (tasks.isEmpty) return 0;
    final total = tasks.fold<double>(0, (sum, t) => sum + t.progress);
    return total / tasks.length;
  }
}
