import 'dart:async';

import 'fenixflix_service.dart';
import 'froststream_service.dart';

/// One step of a source search: everything found so far, plus whether any
/// source is still being waited on.
class StreamDiscoveryUpdate {
  final List<Map<String, dynamic>> streams;
  final bool done;

  const StreamDiscoveryUpdate(this.streams, this.done);
}

/// Queries every configured stream source at once and reports results as
/// each one lands, instead of making the picker wait for the slowest.
///
/// Waiting for all of them is what made the picker feel frozen: a source
/// that is merely slow (or hanging) held back results that had already
/// arrived from a source that answered in milliseconds. Each source also
/// caps its own request (see the services), so one dead host can no longer
/// stall the search for minutes.
class StreamSourceAggregator {
  static Stream<StreamDiscoveryUpdate> discover({
    required String imdbId,
    required String type, // 'movie' or 'tv'
    int? season,
    int? episode,
  }) {
    final controller = StreamController<StreamDiscoveryUpdate>();
    final found = <Map<String, dynamic>>[];

    final sources = <Future<List<Map<String, dynamic>>>>[
      FrostStreamService.fetchStreams(imdbId: imdbId, type: type, season: season, episode: episode),
      FenixflixService.fetchStreams(imdbId: imdbId, type: type, season: season, episode: episode),
    ];

    var pending = sources.length;
    for (final source in sources) {
      unawaited(() async {
        try {
          found.addAll(await source);
        } catch (_) {
          // A failing source is simply one that contributes nothing; the
          // others still populate the list.
        }
        pending--;
        if (controller.isClosed) return;
        controller.add(StreamDiscoveryUpdate(List.of(found), pending == 0));
        if (pending == 0) await controller.close();
      }());
    }

    return controller.stream;
  }
}
