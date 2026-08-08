import 'media_item.dart';

/// Lifecycle of a single offline download.
enum DownloadStatus {
  /// Waiting in line for a slot.
  queued,

  /// Bytes are actively coming in.
  downloading,

  /// Stopped by the user, partial file kept on disk for resuming.
  paused,

  /// Fully written to disk and playable offline.
  completed,

  /// Stopped by an error, partial file kept so a retry can resume.
  failed,
}

/// One downloadable item: a movie, or a single episode of a series.
///
/// The identity of a task is the media it points at, not the source or the
/// quality — downloading a second quality of the same episode replaces the
/// first rather than piling up duplicates on disk.
class DownloadTask {
  final int mediaId;
  final MediaItem media;

  /// Provider that served the stream, shown as the download's origin.
  final String sourceName;

  /// Human-readable quality description coming from the source.
  final String quality;

  /// Remote URL the bytes are pulled from. Kept so a failed or paused
  /// download can be resumed later without re-opening the source picker.
  final String url;

  /// File name inside the downloads directory. Never an absolute path, so the
  /// index stays valid when the OS moves the app's container between launches
  /// (which happens routinely on iOS upgrades).
  final String fileName;

  final int? season;
  final int? episode;

  DownloadStatus status;
  int bytesReceived;
  int totalBytes;
  String? error;

  final DateTime createdAt;
  DateTime? completedAt;

  DownloadTask({
    required this.mediaId,
    required this.media,
    required this.sourceName,
    required this.quality,
    required this.url,
    required this.fileName,
    this.season,
    this.episode,
    this.status = DownloadStatus.queued,
    this.bytesReceived = 0,
    this.totalBytes = 0,
    this.error,
    DateTime? createdAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Stable identity used for de-duplication, file naming and lookups.
  static String buildId(int mediaId, String mediaType, int? season, int? episode) {
    if (mediaType == 'tv' && season != null && episode != null) {
      return '${mediaType}_${mediaId}_s${season}e$episode';
    }
    return '${mediaType}_$mediaId';
  }

  String get id => buildId(mediaId, media.mediaType, season, episode);

  bool get isEpisode => season != null && episode != null;

  /// Title as shown in the downloads list, including the episode marker.
  String get displayTitle {
    if (isEpisode) {
      final s = season.toString().padLeft(2, '0');
      final e = episode.toString().padLeft(2, '0');
      return '${media.title} · S${s}E$e';
    }
    return media.title;
  }

  /// 0.0 to 1.0, or null when the server never told us the total size.
  double? get progress {
    if (status == DownloadStatus.completed) return 1.0;
    if (totalBytes <= 0) return null;
    return (bytesReceived / totalBytes).clamp(0.0, 1.0);
  }

  bool get isActive =>
      status == DownloadStatus.queued || status == DownloadStatus.downloading;

  /// True when the download can be resumed instead of restarted.
  bool get isResumable =>
      status == DownloadStatus.paused || status == DownloadStatus.failed;

  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'media': media.toJson(),
        'sourceName': sourceName,
        'quality': quality,
        'url': url,
        'fileName': fileName,
        'season': season,
        'episode': episode,
        'status': status.name,
        'bytesReceived': bytesReceived,
        'totalBytes': totalBytes,
        'error': error,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    // A download that was mid-flight when the app was killed is restored as
    // paused: the bytes on disk are still good, but nothing is transferring.
    DownloadStatus status = DownloadStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => DownloadStatus.paused,
    );
    if (status == DownloadStatus.downloading || status == DownloadStatus.queued) {
      status = DownloadStatus.paused;
    }

    return DownloadTask(
      mediaId: json['mediaId'] ?? 0,
      media: MediaItem.fromJson(Map<String, dynamic>.from(json['media'] ?? {})),
      sourceName: json['sourceName'] ?? 'Desconhecida',
      quality: json['quality'] ?? '',
      url: json['url'] ?? '',
      fileName: json['fileName'] ?? '',
      season: json['season'],
      episode: json['episode'],
      status: status,
      bytesReceived: json['bytesReceived'] ?? 0,
      totalBytes: json['totalBytes'] ?? 0,
      error: json['error'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'])
          : null,
    );
  }
}

/// Formats a byte count the way a download manager should: no decimals for
/// bytes and KB, one for the larger units.
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit <= 1 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}
