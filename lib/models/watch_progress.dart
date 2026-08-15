import '../utils/formatters.dart';
import 'media_item.dart';

/// Where the viewer stopped on a given title.
///
/// Series keep a single entry per show — the last episode watched — the same
/// way Apple TV's "Continue Watching" shelf behaves.
class WatchProgress {
  final MediaItem media;
  final int? season;
  final int? episode;
  final String? episodeTitle;
  final int positionSeconds;
  final int durationSeconds;

  /// Source the title was playing from. A local file path for a download, or
  /// the remote stream URL, so playback can resume without re-picking a source.
  final String? sourceUrl;

  /// Epoch milliseconds of the last update, used to sort the shelf.
  final int updatedAt;

  const WatchProgress({
    required this.media,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.updatedAt,
    this.season,
    this.episode,
    this.episodeTitle,
    this.sourceUrl,
  });

  /// One entry per series, one per movie.
  static String buildId(int mediaId) => 'w_$mediaId';

  String get id => buildId(media.id);

  bool get isEpisode => season != null && episode != null;

  double get progress {
    if (durationSeconds <= 0) return 0;
    return (positionSeconds / durationSeconds).clamp(0.0, 1.0);
  }

  /// Treated as watched once the credits are effectively rolling.
  bool get isFinished => durationSeconds > 0 && progress >= 0.95;

  int get remainingSeconds =>
      (durationSeconds - positionSeconds).clamp(0, durationSeconds);

  String get remainingLabel => formatRemaining(remainingSeconds);

  /// `T2 E5 · Nome do episódio`, or the release year for a movie.
  String get subtitleLabel {
    if (!isEpisode) return media.formattedYear;
    final tag = formatEpisodeTag(season, episode);
    final name = episodeTitle;
    if (name == null || name.trim().isEmpty) return tag;
    return '$tag · ${name.trim()}';
  }

  String get resumeLabel =>
      isEpisode ? 'Retomar ${formatEpisodeTag(season, episode)}' : 'Retomar';

  Duration get position => Duration(seconds: positionSeconds);

  WatchProgress copyWith({
    MediaItem? media,
    int? season,
    int? episode,
    String? episodeTitle,
    int? positionSeconds,
    int? durationSeconds,
    String? sourceUrl,
    int? updatedAt,
  }) {
    return WatchProgress(
      media: media ?? this.media,
      season: season ?? this.season,
      episode: episode ?? this.episode,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'media': media.forStorage.toJson(),
      'season': season,
      'episode': episode,
      'episodeTitle': episodeTitle,
      'positionSeconds': positionSeconds,
      'durationSeconds': durationSeconds,
      'sourceUrl': sourceUrl,
      'updatedAt': updatedAt,
    };
  }

  factory WatchProgress.fromJson(Map<String, dynamic> json) {
    return WatchProgress(
      media:
          MediaItem.fromJson(Map<String, dynamic>.from(json['media'] as Map)),
      season: (json['season'] as num?)?.toInt(),
      episode: (json['episode'] as num?)?.toInt(),
      episodeTitle: json['episodeTitle'] as String?,
      positionSeconds: (json['positionSeconds'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      sourceUrl: json['sourceUrl'] as String?,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}
