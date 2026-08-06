import 'media_item.dart';

class WatchHistoryEntry {
  final MediaItem media;
  final int? season;
  final int? episode;
  final double positionSeconds;
  final double durationSeconds;
  final DateTime updatedAt;

  WatchHistoryEntry({
    required this.media,
    this.season,
    this.episode,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.updatedAt,
  });

  double get progress {
    if (durationSeconds <= 0) return 0.0;
    return (positionSeconds / durationSeconds).clamp(0.0, 1.0);
  }

  bool get isFinished {
    if (durationSeconds <= 0) return false;
    return positionSeconds >= durationSeconds - 30;
  }

  String? get episodeLabel {
    if (season == null || episode == null) return null;
    return 'S$season:E$episode';
  }

  factory WatchHistoryEntry.fromJson(Map<String, dynamic> json) {
    return WatchHistoryEntry(
      media: MediaItem.fromJson(json['media']),
      season: json['season'],
      episode: json['episode'],
      positionSeconds: (json['positionSeconds'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 0.0,
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'media': media.toJson(),
      'season': season,
      'episode': episode,
      'positionSeconds': positionSeconds,
      'durationSeconds': durationSeconds,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
