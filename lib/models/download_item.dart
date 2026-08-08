import 'media_item.dart';

/// Lifecycle of a single offline download.
enum DownloadStatus { queued, downloading, paused, completed, failed }

/// One downloaded (or downloading) title — a movie, or a single episode of a
/// series. Persisted per profile alongside the media it belongs to so the
/// downloads library keeps working with no network at all.
class DownloadItem {
  /// Stable key: `movie_<tmdbId>` or `tv_<tmdbId>_s<season>e<episode>`.
  final String id;
  final MediaItem media;
  final int? season;
  final int? episode;

  /// Name of the source add-on the stream came from.
  final String sourceName;

  /// Human readable quality/description line of the chosen stream.
  final String quality;
  final String url;

  /// File name relative to the profile's downloads directory. Stored relative
  /// because the sandbox path changes between installs on iOS/macOS.
  final String fileName;

  final DownloadStatus status;
  final int bytesReceived;
  final int totalBytes;
  final String? error;
  final DateTime createdAt;

  const DownloadItem({
    required this.id,
    required this.media,
    this.season,
    this.episode,
    required this.sourceName,
    required this.quality,
    required this.url,
    required this.fileName,
    this.status = DownloadStatus.queued,
    this.bytesReceived = 0,
    this.totalBytes = 0,
    this.error,
    required this.createdAt,
  });

  static String buildId(int mediaId, String mediaType, {int? season, int? episode}) {
    if (mediaType == 'tv' && season != null && episode != null) {
      return 'tv_${mediaId}_s${season}e$episode';
    }
    return '${mediaType}_$mediaId';
  }

  bool get isEpisode => season != null && episode != null;

  bool get isActive => status == DownloadStatus.downloading || status == DownloadStatus.queued;

  /// 0.0–1.0, or null when the server never reported a content length.
  double? get progress {
    if (totalBytes <= 0) return null;
    return (bytesReceived / totalBytes).clamp(0.0, 1.0);
  }

  /// Title shown in the downloads library — includes the episode marker.
  String get displayTitle {
    if (isEpisode) return '${media.title} · T$season:E$episode';
    return media.title;
  }

  DownloadItem copyWith({
    DownloadStatus? status,
    int? bytesReceived,
    int? totalBytes,
    String? url,
    String? error,
    bool clearError = false,
  }) {
    return DownloadItem(
      id: id,
      media: media,
      season: season,
      episode: episode,
      sourceName: sourceName,
      quality: quality,
      url: url ?? this.url,
      fileName: fileName,
      status: status ?? this.status,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      totalBytes: totalBytes ?? this.totalBytes,
      error: clearError ? null : (error ?? this.error),
      createdAt: createdAt,
    );
  }

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'],
      media: MediaItem.fromJson(Map<String, dynamic>.from(json['media'])),
      season: json['season'],
      episode: json['episode'],
      sourceName: json['sourceName'] ?? 'Sabuflix',
      quality: json['quality'] ?? '',
      url: json['url'] ?? '',
      fileName: json['fileName'],
      status: DownloadStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => DownloadStatus.queued,
      ),
      bytesReceived: json['bytesReceived'] ?? 0,
      totalBytes: json['totalBytes'] ?? 0,
      error: json['error'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'media': media.toJson(),
      'season': season,
      'episode': episode,
      'sourceName': sourceName,
      'quality': quality,
      'url': url,
      'fileName': fileName,
      'status': status.name,
      'bytesReceived': bytesReceived,
      'totalBytes': totalBytes,
      'error': error,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
