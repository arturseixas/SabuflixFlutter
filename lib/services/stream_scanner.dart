import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'froststream_service.dart';

/// What a quick probe learned about a link.
enum StreamHealth {
  /// Not probed yet.
  pending,

  /// The server answered with media (2xx).
  ok,

  /// No verdict: timeout, network error or a browser CORS refusal. Players
  /// can still manage these, so they stay in the list.
  unknown,

  /// The server refused the link (4xx/5xx) or the player failed on it.
  dead,
}

/// One playable link, normalised from a Stremio stream.
class StreamCandidate {
  final String url;
  final String provider;
  final String quality;
  final String? audio;
  final Map<String, String> headers;

  /// Position within its provider's answer (providers list best first).
  final int order;

  /// The original stream map, for the download flow.
  final Map<String, dynamic> raw;

  StreamHealth health;
  Duration? latency;

  StreamCandidate({
    required this.url,
    required this.provider,
    required this.quality,
    this.audio,
    this.headers = const {},
    this.order = 0,
    Map<String, dynamic>? raw,
    this.health = StreamHealth.pending,
    this.latency,
  }) : raw = raw ?? const {};

  factory StreamCandidate.fromStream(Map<String, dynamic> stream) {
    final headers = stream['headers'];
    return StreamCandidate(
      url: stream['url'].toString(),
      provider:
          (stream['displayName'] ?? stream['sourceName'] ?? 'Fonte').toString(),
      quality: (stream['displayQuality'] ?? 'Qualidade automática').toString(),
      audio: stream['displayAudio']?.toString(),
      headers: headers is Map<String, String>
          ? headers
          : FrostStreamService.requestHeadersOf(stream),
      order: (stream['sourceOrder'] as num?)?.toInt() ?? 0,
      raw: stream,
    );
  }

  /// "Nebula · 1080p · Dublado" — what the player shows.
  String get label => [
        provider,
        if (quality != 'Qualidade automática') quality,
        if (audio != null) audio!,
      ].join(' · ');

  /// Higher is better; health dominates, then picture quality, then speed.
  double get score {
    final healthScore = switch (health) {
      StreamHealth.ok => 3000.0,
      StreamHealth.pending => 1500.0,
      StreamHealth.unknown => 1000.0,
      StreamHealth.dead => 0.0,
    };
    final qualityScore = switch (quality.toUpperCase()) {
      '4K' => 500.0,
      '1440P' => 450.0,
      '1080P' => 400.0,
      '720P' => 300.0,
      '480P' => 150.0,
      'CAM' => -500.0,
      _ => 200.0,
    };
    // Up to ~300 points for a fast first byte; slow hosts stutter.
    final speedScore = latency == null
        ? 0.0
        : (300 - latency!.inMilliseconds / 10).clamp(0, 300).toDouble();
    return healthScore + qualityScore + speedScore - order * 2;
  }
}

/// Which title and episode to look up.
typedef StreamQuery = ({String imdbId, String type, int? season, int? episode});

typedef ProviderFetcher = Future<List<Map<String, dynamic>>> Function(
    StreamProvider provider, StreamQuery query);
typedef StreamProbe = Future<(StreamHealth, Duration?)> Function(
    StreamCandidate candidate);

/// Fast, progressive stream discovery.
///
/// Every add-on is queried at once with a short timeout, and each answer is
/// published the moment it lands instead of waiting for the slowest one. Each
/// link is then probed with a one-byte range request, in parallel, so the
/// player can start on a link that is known to answer — usually within a
/// second or two. Results are cached briefly so reopening a title, or
/// failing over inside the player, costs nothing.
class StreamScanner {
  StreamScanner({
    List<StreamProvider>? providers,
    ProviderFetcher? fetcher,
    StreamProbe? probe,
    http.Client Function()? clientFactory,
    this.providerTimeout = const Duration(seconds: 6),
    this.probeTimeout = const Duration(milliseconds: 3500),
    this.maxProbes = 16,
    bool? isWeb,
    bool? pageIsHttps,
  })  : _providers = providers ?? FrostStreamService.providers,
        _fetcher = fetcher,
        _probe = probe,
        _clientFactory = clientFactory ?? http.Client.new,
        _isWeb = isWeb ?? kIsWeb,
        _pageIsHttps = pageIsHttps ?? (kIsWeb && Uri.base.scheme == 'https');

  final List<StreamProvider> _providers;
  final ProviderFetcher? _fetcher;
  final StreamProbe? _probe;
  final http.Client Function() _clientFactory;
  final Duration providerTimeout;
  final Duration probeTimeout;
  final int maxProbes;
  final bool _isWeb;
  final bool _pageIsHttps;

  static const cacheLifetime = Duration(minutes: 10);
  static final _cache = <String, ({DateTime at, List<StreamCandidate> list})>{};

  @visibleForTesting
  static void clearCache() => _cache.clear();

  static String _key(StreamQuery q) =>
      '${q.type}:${q.imdbId}:${q.season ?? ''}:${q.episode ?? ''}';

  /// Emits the ranked list every time it improves, best link first, and
  /// closes once every add-on has answered and every probe has finished.
  Stream<List<StreamCandidate>> scan(StreamQuery query, {bool fresh = false}) {
    final controller = StreamController<List<StreamCandidate>>();
    final key = _key(query);
    final cached = _cache[key];
    if (!fresh &&
        cached != null &&
        DateTime.now().difference(cached.at) < cacheLifetime) {
      controller.add(rank(cached.list));
      controller.close();
      return controller.stream;
    }
    if (query.imdbId.isEmpty ||
        (query.type != 'movie' &&
            (query.season == null || query.episode == null))) {
      controller.add(const []);
      controller.close();
      return controller.stream;
    }

    final client = _clientFactory();
    final found = <StreamCandidate>[];
    final seen = <String>{};
    final probes = <Future<void>>[];
    var probed = 0;

    void publish() {
      if (!controller.isClosed) controller.add(rank(found));
    }

    Future<void> probeOne(StreamCandidate candidate) async {
      final (health, latency) =
          await (_probe?.call(candidate) ?? _rangeProbe(client, candidate));
      candidate
        ..health = health
        ..latency = latency;
      publish();
    }

    Future<void> fetchOne(StreamProvider provider) async {
      List<Map<String, dynamic>> streams;
      try {
        streams = await (_fetcher?.call(provider, query) ??
                FrostStreamService.fetchProvider(
                  source: provider,
                  imdbId: query.imdbId,
                  type: query.type,
                  season: query.season,
                  episode: query.episode,
                  client: client,
                  timeout: providerTimeout,
                ))
            .timeout(providerTimeout + const Duration(seconds: 1));
      } catch (_) {
        return;
      }
      final fresh = <StreamCandidate>[];
      for (final stream in streams) {
        final url = stream['url']?.toString() ?? '';
        if (!playable(url) || !seen.add(url)) continue;
        final candidate = StreamCandidate.fromStream(stream);
        found.add(candidate);
        fresh.add(candidate);
      }
      if (fresh.isEmpty) return;
      publish();
      // Probe the most promising links first; the rest keep their
      // provider's own ordering.
      fresh.sort((a, b) => b.score.compareTo(a.score));
      for (final candidate in fresh) {
        if (probed >= maxProbes) {
          candidate.health = StreamHealth.unknown;
          continue;
        }
        probed++;
        probes.add(probeOne(candidate));
      }
    }

    () async {
      try {
        await Future.wait(_providers.map(fetchOne));
        await Future.wait(probes);
        if (found.isNotEmpty) {
          _cache[key] = (at: DateTime.now(), list: List.of(found));
        }
        publish();
      } finally {
        client.close();
        await controller.close();
      }
    }();

    return controller.stream;
  }

  /// Best-first ordering; ties keep the order they were found in.
  static List<StreamCandidate> rank(Iterable<StreamCandidate> candidates) {
    final indexed = candidates.toList().asMap().entries.toList()
      ..sort((a, b) {
        final byScore = b.value.score.compareTo(a.value.score);
        return byScore != 0 ? byScore : a.key.compareTo(b.key);
      });
    return [for (final e in indexed) e.value];
  }

  /// Whether this client can play the URL at all. An HTTPS page (GitHub
  /// Pages) is never allowed to load plain-HTTP media, and browsers can't play
  /// Matroska/AVI containers.
  bool playable(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return false;
    if (!const ['http', 'https'].contains(uri.scheme)) return false;
    if (_isWeb) {
      if (_pageIsHttps && uri.scheme == 'http') return false;
      final path = uri.path.toLowerCase();
      if (path.endsWith('.mkv') || path.endsWith('.avi')) return false;
    }
    return true;
  }

  /// Asks for a single byte and drops the connection as soon as the status
  /// line arrives, so a probe costs one round trip, not a download.
  Future<(StreamHealth, Duration?)> _rangeProbe(
      http.Client client, StreamCandidate candidate) async {
    final watch = Stopwatch()..start();
    StreamSubscription<List<int>>? body;
    try {
      final request = http.Request('GET', Uri.parse(candidate.url))
        ..followRedirects = true
        ..headers.addAll({
          // Browsers refuse to send forbidden headers (Referer, User-Agent);
          // native platforms send what the add-on asked for.
          if (!_isWeb) ...candidate.headers,
          'Range': 'bytes=0-0',
        });
      final response = await client.send(request).timeout(probeTimeout);
      final latency = watch.elapsed;
      body = response.stream.listen(null, cancelOnError: true);
      final status = response.statusCode;
      if (status >= 200 && status < 300) return (StreamHealth.ok, latency);
      // 416: the server understood the range but the file is shorter (live
      // HLS playlists) — the link itself is alive.
      if (status == 416) return (StreamHealth.ok, latency);
      return (StreamHealth.dead, latency);
    } catch (_) {
      return (StreamHealth.unknown, null);
    } finally {
      unawaited(body?.cancel());
    }
  }
}
