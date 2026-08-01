import 'media_item.dart';

enum DownloadStatus { queued, downloading, paused, completed, failed }

/// One downloaded (or downloading) title kept for offline playback.
/// For TV shows each episode is its own entry.
class DownloadItem {
  final String id;
  final MediaItem media;
  final int? season;
  final int? episode;
  final String sourceUrl;
  final String qualityLabel;

  /// Absolute path of the finished file. While downloading, bytes go to
  /// "<filePath>.part" and are only renamed once the transfer completes.
  final String filePath;

  DownloadStatus status;
  int receivedBytes;
  int totalBytes;
  String? errorMessage;

  DownloadItem({
    required this.id,
    required this.media,
    this.season,
    this.episode,
    required this.sourceUrl,
    required this.qualityLabel,
    required this.filePath,
    this.status = DownloadStatus.queued,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.errorMessage,
  });

  /// Stable key for a title (or a single episode of a series).
  static String buildId(int mediaId, {int? season, int? episode}) {
    if (season != null && episode != null) return '$mediaId:s$season:e$episode';
    return '$mediaId';
  }

  bool get isComplete => status == DownloadStatus.completed;

  bool get isActive => status == DownloadStatus.queued || status == DownloadStatus.downloading;

  double get progress => totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  String get subtitle {
    if (season != null && episode != null) return 'T$season : E$episode · $qualityLabel';
    return qualityLabel;
  }

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'],
      media: MediaItem.fromJson(json['media']),
      season: json['season'],
      episode: json['episode'],
      sourceUrl: json['sourceUrl'] ?? '',
      qualityLabel: json['qualityLabel'] ?? '',
      filePath: json['filePath'] ?? '',
      status: DownloadStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => DownloadStatus.queued,
      ),
      receivedBytes: json['receivedBytes'] ?? 0,
      totalBytes: json['totalBytes'] ?? 0,
      errorMessage: json['errorMessage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'media': media.toJson(),
      'season': season,
      'episode': episode,
      'sourceUrl': sourceUrl,
      'qualityLabel': qualityLabel,
      'filePath': filePath,
      'status': status.name,
      'receivedBytes': receivedBytes,
      'totalBytes': totalBytes,
      'errorMessage': errorMessage,
    };
  }
}
