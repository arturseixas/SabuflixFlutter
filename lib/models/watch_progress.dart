import 'media_item.dart';

/// A title the user started and has not finished — one entry per title, so a
/// series moves through its episodes in place instead of piling up.
class WatchProgress {
  final MediaItem media;
  final Duration position;
  final Duration duration;

  /// Set for series only, so the row can label and resume the right episode.
  final int? season;
  final int? episode;

  /// The stream that was playing. Source URLs are not guaranteed to stay
  /// valid, so this is a best-effort shortcut — the details screen is always
  /// the fallback for picking a fresh source.
  final String? videoUrl;

  final DateTime updatedAt;

  const WatchProgress({
    required this.media,
    required this.position,
    required this.duration,
    required this.updatedAt,
    this.season,
    this.episode,
    this.videoUrl,
  });

  /// Below this, the title barely got started; above [_completedFraction] it
  /// counts as watched. Neither belongs in "Continuar assistindo".
  static const Duration _minimumPosition = Duration(seconds: 30);
  static const double completedFraction = 0.95;

  double get fraction {
    if (duration.inSeconds <= 0) return 0;
    return (position.inSeconds / duration.inSeconds).clamp(0.0, 1.0);
  }

  bool get isWorthResuming =>
      duration > Duration.zero &&
      position >= _minimumPosition &&
      fraction < completedFraction;

  bool get isFinished => duration > Duration.zero && fraction >= completedFraction;

  Duration get remaining {
    final left = duration - position;
    return left.isNegative ? Duration.zero : left;
  }

  String get remainingLabel {
    final minutes = remaining.inMinutes;
    if (minutes < 1) return 'Quase no fim';
    if (minutes < 60) return 'Faltam $minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? 'Faltam ${hours}h' : 'Faltam ${hours}h${rest}min';
  }

  /// 'T1:E3' for series, null for films.
  String? get episodeLabel {
    if (season == null || episode == null) return null;
    return 'T$season:E$episode';
  }

  factory WatchProgress.fromJson(Map<String, dynamic> json) {
    return WatchProgress(
      media: MediaItem.fromJson(Map<String, dynamic>.from(json['media'])),
      position: Duration(seconds: json['position_seconds'] ?? 0),
      duration: Duration(seconds: json['duration_seconds'] ?? 0),
      season: json['season'],
      episode: json['episode'],
      videoUrl: json['video_url'],
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'media': media.toJson(),
      'position_seconds': position.inSeconds,
      'duration_seconds': duration.inSeconds,
      'season': season,
      'episode': episode,
      'video_url': videoUrl,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }
}
