import 'media_item.dart';

enum DownloadStatus { queued, downloading, paused, completed, failed }

/// A single downloadable entry — a movie, or one episode of a series.
///
/// Everything here is serialisable: the list is written to
/// SharedPreferences on every state change so the queue (and its
/// progress) survives an app restart.
class DownloadItem {
  /// Stable key, also used as the on-disk file name: `1234` for a movie,
  /// `1234_s1e4` for an episode.
  final String id;
  final MediaItem media;
  final String url;
  final String fileName;
  final String sourceName;
  final String quality;
  final int? season;
  final int? episode;
  final DownloadStatus status;
  final int receivedBytes;
  final int totalBytes;
  final int createdAt;
  final String? errorMessage;

  const DownloadItem({
    required this.id,
    required this.media,
    required this.url,
    required this.fileName,
    this.sourceName = '',
    this.quality = '',
    this.season,
    this.episode,
    this.status = DownloadStatus.queued,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    required this.createdAt,
    this.errorMessage,
  });

  static String buildId(int mediaId, {int? season, int? episode}) {
    if (season != null && episode != null) return '${mediaId}_s${season}e$episode';
    return '$mediaId';
  }

  bool get isEpisode => season != null && episode != null;
  bool get isCompleted => status == DownloadStatus.completed;
  bool get isActive => status == DownloadStatus.downloading || status == DownloadStatus.queued;

  /// 0.0 – 1.0, or `null` when the total size is still unknown.
  double? get progress {
    if (isCompleted) return 1.0;
    if (totalBytes <= 0) return null;
    return (receivedBytes / totalBytes).clamp(0.0, 1.0);
  }

  String get episodeLabel => isEpisode ? 'T$season:E$episode' : '';

  String get displayTitle => isEpisode ? '${media.title} · $episodeLabel' : media.title;

  String get statusLabel {
    switch (status) {
      case DownloadStatus.queued:
        return 'Na fila';
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

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double value = bytes.toDouble();
    int unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final decimals = value >= 100 || unit <= 1 ? 0 : 1;
    return '${value.toStringAsFixed(decimals)} ${units[unit]}';
  }

  String get sizeLabel {
    if (totalBytes <= 0) return DownloadItem.formatBytes(receivedBytes);
    if (isCompleted) return DownloadItem.formatBytes(totalBytes);
    return '${DownloadItem.formatBytes(receivedBytes)} / ${DownloadItem.formatBytes(totalBytes)}';
  }

  DownloadItem copyWith({
    String? url,
    DownloadStatus? status,
    int? receivedBytes,
    int? totalBytes,
    String? sourceName,
    String? quality,
    bool clearError = false,
    String? errorMessage,
  }) {
    return DownloadItem(
      id: id,
      media: media,
      url: url ?? this.url,
      fileName: fileName,
      sourceName: sourceName ?? this.sourceName,
      quality: quality ?? this.quality,
      season: season,
      episode: episode,
      status: status ?? this.status,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      createdAt: createdAt,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  /// Swaps in richer metadata for the same download — used when a
  /// recovered entry gets identified and its real title/artwork arrive.
  DownloadItem copyWithMedia(MediaItem newMedia) {
    return DownloadItem(
      id: id,
      media: newMedia,
      url: url,
      fileName: fileName,
      sourceName: sourceName,
      quality: quality,
      season: season,
      episode: episode,
      status: status,
      receivedBytes: receivedBytes,
      totalBytes: totalBytes,
      createdAt: createdAt,
      errorMessage: errorMessage,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'media': media.toJson(),
        'url': url,
        'fileName': fileName,
        'sourceName': sourceName,
        'quality': quality,
        'season': season,
        'episode': episode,
        'status': status.name,
        'receivedBytes': receivedBytes,
        'totalBytes': totalBytes,
        'createdAt': createdAt,
        'errorMessage': errorMessage,
      };

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'] as String,
      media: MediaItem.fromJson(Map<String, dynamic>.from(json['media'] as Map)),
      url: json['url'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '${json['id']}.mp4',
      sourceName: json['sourceName'] as String? ?? '',
      quality: json['quality'] as String? ?? '',
      season: json['season'] as int?,
      episode: json['episode'] as int?,
      status: DownloadStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => DownloadStatus.paused,
      ),
      receivedBytes: json['receivedBytes'] as int? ?? 0,
      totalBytes: json['totalBytes'] as int? ?? 0,
      createdAt: json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}
