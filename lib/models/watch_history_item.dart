import 'media_item.dart';

/// A single "continue watching" entry: how far the user got into [media]
/// (and which season/episode, for TV shows) and when they last watched it.
class WatchHistoryItem {
  final MediaItem media;
  final int? season;
  final int? episode;
  final double positionSeconds;
  final double durationSeconds;
  final DateTime watchedAt;

  WatchHistoryItem({
    required this.media,
    this.season,
    this.episode,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.watchedAt,
  });

  double get progress =>
      durationSeconds > 0 ? (positionSeconds / durationSeconds).clamp(0.0, 1.0) : 0.0;

  /// Treated as fully watched once past 92% — resuming from there would be pointless.
  bool get isFinished => progress >= 0.92;

  factory WatchHistoryItem.fromJson(Map<String, dynamic> json) {
    return WatchHistoryItem(
      media: MediaItem.fromJson(json['media']),
      season: json['season'],
      episode: json['episode'],
      positionSeconds: (json['positionSeconds'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 0.0,
      watchedAt: DateTime.tryParse(json['watchedAt'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'media': media.toJson(),
      'season': season,
      'episode': episode,
      'positionSeconds': positionSeconds,
      'durationSeconds': durationSeconds,
      'watchedAt': watchedAt.toIso8601String(),
    };
  }
}
