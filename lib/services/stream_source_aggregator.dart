import 'fenixflix_service.dart';
import 'froststream_service.dart';

/// Fetches from every configured stream source in parallel and merges the
/// results into one list — the picker never shows "which addon" answered,
/// only "here are the sources Sabuflix found".
///
/// Each source's own `fetchStreams` already swallows its errors and
/// returns `[]` on failure, so one source being down never blocks the
/// other from showing.
class StreamSourceAggregator {
  static Future<List<Map<String, dynamic>>> fetchStreams({
    required String imdbId,
    required String type, // 'movie' or 'tv'
    int? season,
    int? episode,
  }) async {
    final results = await Future.wait([
      FrostStreamService.fetchStreams(imdbId: imdbId, type: type, season: season, episode: episode),
      FenixflixService.fetchStreams(imdbId: imdbId, type: type, season: season, episode: episode),
    ]);
    return results.expand((streams) => streams).toList();
  }
}
