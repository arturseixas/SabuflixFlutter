import '../models/media_item.dart';
import 'froststream_service.dart';
import 'tmdb_service.dart';

/// Video quality the viewer prefers when more than one source is offered.
enum PreferredQuality { auto, uhd, fhd, hd, sd }

/// Audio the viewer prefers: dubbed in Portuguese, original with subtitles,
/// or whatever comes first.
enum PreferredAudio { any, dubbed, subtitled }

extension PreferredQualityLabel on PreferredQuality {
  String get label => switch (this) {
        PreferredQuality.auto => 'Automática',
        PreferredQuality.uhd => '4K',
        PreferredQuality.fhd => 'Full HD (1080p)',
        PreferredQuality.hd => 'HD (720p)',
        PreferredQuality.sd => 'SD',
      };

  int get rank => switch (this) {
        PreferredQuality.uhd => 4,
        PreferredQuality.fhd => 3,
        PreferredQuality.hd => 2,
        PreferredQuality.sd => 1,
        PreferredQuality.auto => 0,
      };
}

extension PreferredAudioLabel on PreferredAudio {
  String get label => switch (this) {
        PreferredAudio.any => 'Tanto faz',
        PreferredAudio.dubbed => 'Dublado',
        PreferredAudio.subtitled => 'Legendado',
      };
}

/// The next episode after a given one, resolved against TMDB's season list.
class EpisodePointer {
  final int season;
  final int episode;
  final String? title;
  const EpisodePointer(this.season, this.episode, {this.title});
}

/// Ranks and picks stream sources, and figures out what plays next.
///
/// Everything here is deterministic and unit-testable; network access goes
/// through the injected services.
class PlaybackResolver {
  PlaybackResolver({TMDBService? tmdb}) : _tmdb = tmdb ?? TMDBService();

  final TMDBService _tmdb;

  /// `4K` -> 4, `1080p` -> 3, `720p` -> 2, `480p`/`SD` -> 1, unknown -> 0.
  static int qualityRank(String? label) {
    final text = (label ?? '').toUpperCase();
    if (text.contains('4K') || text.contains('2160')) return 4;
    if (text.contains('1440') || text.contains('1080')) return 3;
    if (text.contains('720')) return 2;
    if (text.contains('480') || text.contains('SD') || text.contains('CAM')) {
      return 1;
    }
    return 0;
  }

  static bool isDubbed(Map<String, dynamic> stream) =>
      _describe(stream).contains('dublado');

  static bool isSubtitled(Map<String, dynamic> stream) =>
      _describe(stream).contains('legendado');

  static String _describe(Map<String, dynamic> stream) =>
      '${stream['displayDescription'] ?? ''} ${stream['title'] ?? ''} ${stream['name'] ?? ''}'
          .toLowerCase();

  /// Scores a source against the viewer's preferences: higher is better.
  static int score(
    Map<String, dynamic> stream, {
    required PreferredQuality quality,
    required PreferredAudio audio,
  }) {
    final rank = qualityRank(stream['displayQuality']?.toString() ??
        '${stream['title'] ?? ''} ${stream['name'] ?? ''}');
    var points = 0;
    if (quality == PreferredQuality.auto) {
      points += rank * 10;
    } else {
      // Exact match first, then the closest below, then anything above.
      final wanted = quality.rank;
      if (rank == wanted) {
        points += 100;
      } else if (rank != 0 && rank < wanted) {
        points += 60 + rank * 5;
      } else if (rank > wanted) {
        points += 40 - (rank - wanted) * 5;
      }
    }
    switch (audio) {
      case PreferredAudio.dubbed:
        if (isDubbed(stream)) points += 30;
        if (isSubtitled(stream) && !isDubbed(stream)) points -= 10;
        break;
      case PreferredAudio.subtitled:
        if (isSubtitled(stream)) points += 30;
        if (isDubbed(stream) && !isSubtitled(stream)) points -= 10;
        break;
      case PreferredAudio.any:
        break;
    }
    return points;
  }

  /// Sources ordered best-first for these preferences. Stable for ties.
  static List<Map<String, dynamic>> sort(
    List<Map<String, dynamic>> streams, {
    required PreferredQuality quality,
    required PreferredAudio audio,
  }) {
    final indexed = streams.asMap().entries.toList();
    indexed.sort((a, b) {
      final diff = score(b.value, quality: quality, audio: audio) -
          score(a.value, quality: quality, audio: audio);
      return diff != 0 ? diff : a.key.compareTo(b.key);
    });
    return indexed.map((e) => e.value).toList();
  }

  static Map<String, dynamic>? pickBest(
    List<Map<String, dynamic>> streams, {
    required PreferredQuality quality,
    required PreferredAudio audio,
  }) {
    if (streams.isEmpty) return null;
    return sort(streams, quality: quality, audio: audio).first;
  }

  /// Fetches every source for a title and returns the best one, or `null`.
  Future<Map<String, dynamic>?> resolveBest({
    required MediaItem media,
    required PreferredQuality quality,
    required PreferredAudio audio,
    int? season,
    int? episode,
  }) async {
    final imdbId = await _imdbIdFor(media);
    if (imdbId == null) return null;
    final streams = await FrostStreamService.fetchStreams(
      imdbId: imdbId,
      type: media.mediaType,
      season: season,
      episode: episode,
    );
    return pickBest(streams, quality: quality, audio: audio);
  }

  Future<String?> _imdbIdFor(MediaItem media) async {
    if (media.imdbId != null && media.imdbId!.isNotEmpty) return media.imdbId;
    final details = await _tmdb.fetchMediaDetails(media.id, media.mediaType);
    return details?.imdbId;
  }

  /// The episode after `season`/`episode`, crossing into the next season when
  /// the current one ends. `null` on the series finale.
  ///
  /// [seasons] is TMDB's `seasons` array; when missing it is fetched.
  Future<EpisodePointer?> nextEpisode({
    required MediaItem media,
    required int season,
    required int episode,
    List<dynamic>? seasons,
  }) async {
    var list = seasons ?? media.seasons;
    if (list == null || list.isEmpty) {
      final details = await _tmdb.fetchMediaDetails(media.id, 'tv');
      list = details?.seasons;
    }
    final pointer = nextEpisodeFromSeasons(list ?? const [], season, episode);
    if (pointer == null) return null;
    // Resolve the episode name for the "Next episode" card.
    try {
      final episodes =
          await _tmdb.fetchSeasonEpisodes(media.id, pointer.season);
      for (final entry in episodes) {
        if (entry is Map &&
            (entry['episode_number'] as num?)?.toInt() == pointer.episode) {
          return EpisodePointer(pointer.season, pointer.episode,
              title: entry['name']?.toString());
        }
      }
    } catch (_) {
      // The name is decoration; the pointer is what matters.
    }
    return pointer;
  }

  /// Pure helper behind [nextEpisode].
  static EpisodePointer? nextEpisodeFromSeasons(
      List<dynamic> seasons, int season, int episode) {
    final counts = <int, int>{};
    for (final entry in seasons) {
      if (entry is! Map) continue;
      final number = (entry['season_number'] as num?)?.toInt();
      final count = (entry['episode_count'] as num?)?.toInt();
      if (number == null || number <= 0 || count == null) continue;
      counts[number] = count;
    }
    if (counts.isEmpty) {
      // Without metadata, assume the season continues.
      return EpisodePointer(season, episode + 1);
    }
    final current = counts[season];
    if (current != null && episode < current) {
      return EpisodePointer(season, episode + 1);
    }
    final later = counts.keys.where((s) => s > season).toList()..sort();
    for (final candidate in later) {
      if ((counts[candidate] ?? 0) > 0) return EpisodePointer(candidate, 1);
    }
    return null;
  }
}
