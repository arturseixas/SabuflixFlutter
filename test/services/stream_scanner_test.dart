import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sabuflix/services/froststream_service.dart';
import 'package:sabuflix/services/stream_scanner.dart';

const StreamProvider fast = (name: 'Fast', brand: 'Fast', baseUrl: 'https://a');
const StreamProvider slow = (name: 'Slow', brand: 'Slow', baseUrl: 'https://b');
const StreamProvider stuck =
    (name: 'Stuck', brand: 'Stuck', baseUrl: 'https://c');
const StreamQuery film =
    (imdbId: 'tt1', type: 'movie', season: null, episode: null);

Map<String, dynamic> stream(String url,
        {String provider = 'Fast', String quality = '1080p', int order = 0}) =>
    {
      'url': url,
      'displayName': provider,
      'displayQuality': quality,
      'sourceOrder': order,
    };

StreamCandidate candidate(String quality, StreamHealth health,
        {Duration? latency}) =>
    StreamCandidate(
        url: 'https://x/$quality/${health.name}',
        provider: 'P',
        quality: quality,
        health: health,
        latency: latency);

void main() {
  setUp(StreamScanner.clearCache);

  test('ranking prefers links known to answer, then quality, then speed', () {
    final ranked = StreamScanner.rank([
      candidate('4K', StreamHealth.dead),
      candidate('4K', StreamHealth.unknown),
      candidate('CAM', StreamHealth.ok,
          latency: const Duration(milliseconds: 50)),
      candidate('720p', StreamHealth.ok,
          latency: const Duration(milliseconds: 90)),
      candidate('1080p', StreamHealth.ok, latency: const Duration(seconds: 2)),
      candidate('1080p', StreamHealth.ok,
          latency: const Duration(milliseconds: 100)),
    ]);
    expect(
        ranked.map((c) =>
            '${c.quality} ${c.health.name} ${c.latency?.inMilliseconds}'),
        [
          '1080p ok 100',
          // A host that takes 2 s for the first byte loses to a fast 720p.
          '720p ok 90',
          '1080p ok 2000',
          'CAM ok 50',
          '4K unknown null',
          '4K dead null',
        ]);
  });

  test('publishes the fast add-on without waiting for slow or stuck ones',
      () async {
    final slowAnswer = Completer<List<Map<String, dynamic>>>();
    final scanner = StreamScanner(
      providers: [fast, slow, stuck],
      providerTimeout: const Duration(milliseconds: 200),
      fetcher: (provider, query) => switch (provider.name) {
        'Fast' => Future.value([stream('https://a/1')]),
        'Slow' => slowAnswer.future,
        _ => Completer<List<Map<String, dynamic>>>().future,
      },
      probe: (c) async => (StreamHealth.ok, const Duration(milliseconds: 10)),
    );
    final updates = <List<String>>[];
    final done = scanner
        .scan(film)
        .listen((list) => updates.add([for (final c in list) c.url]))
        .asFuture<void>();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(updates, isNotEmpty);
    expect(updates.last, ['https://a/1']);

    slowAnswer.complete([
      stream('https://b/1', provider: 'Slow'),
      stream('https://a/1', provider: 'Slow'), // duplicate link
    ]);
    await done.timeout(const Duration(seconds: 2));
    expect(updates.last, unorderedEquals(['https://a/1', 'https://b/1']));
  });

  test('a finished scan is cached and dead links stay demoted', () async {
    var calls = 0;
    final scanner = StreamScanner(
      providers: [fast],
      fetcher: (provider, query) async {
        calls++;
        return [stream('https://a/good'), stream('https://a/bad', order: 1)];
      },
      probe: (c) async => c.url.endsWith('bad')
          ? (StreamHealth.dead, null)
          : (StreamHealth.ok, const Duration(milliseconds: 5)),
    );
    final first = await scanner.scan(film).last;
    expect(first.map((c) => c.url), ['https://a/good', 'https://a/bad']);
    final second = await scanner.scan(film).last;
    expect(calls, 1);
    expect(second.last.health, StreamHealth.dead);
    await scanner.scan(film, fresh: true).last;
    expect(calls, 2);
  });

  test('series without an episode and titles without IMDb id find nothing',
      () async {
    final scanner = StreamScanner(
        providers: [fast], fetcher: (_, __) async => [stream('https://a/1')]);
    expect(
        await scanner.scan(
            (imdbId: 'tt1', type: 'series', season: 1, episode: null)).last,
        isEmpty);
    expect(
        await scanner.scan(
            (imdbId: '', type: 'movie', season: null, episode: null)).last,
        isEmpty);
  });

  test('browsers on HTTPS skip links they can never play', () {
    final web = StreamScanner(isWeb: true, pageIsHttps: true);
    expect(web.playable('http://cdn/movie.mp4'), isFalse);
    expect(web.playable('https://cdn/movie.mkv'), isFalse);
    expect(web.playable('https://cdn/master.m3u8'), isTrue);
    final native = StreamScanner(isWeb: false);
    expect(native.playable('http://cdn/movie.mkv'), isTrue);
    expect(native.playable('magnet:?xt=urn:btih:abc'), isFalse);
  });

  test('range probe sends the add-on headers and reads the status only',
      () async {
    final seen = <String, Map<String, String>>{};
    final client = MockClient((request) async {
      seen[request.url.path] = request.headers;
      return switch (request.url.path) {
        '/ok' => http.Response('x', 206),
        '/gone' => http.Response('', 404),
        _ => throw http.ClientException('reset'),
      };
    });
    final scanner = StreamScanner(
      providers: [fast],
      clientFactory: () => client,
      fetcher: (_, __) async => [
        {
          ...stream('https://h/ok'),
          'headers': {'Referer': 'https://site'},
        },
        stream('https://h/gone', order: 1),
        stream('https://h/reset', order: 2),
      ],
    );
    final result = {
      for (final c in await scanner.scan(film).last) c.url: c.health
    };
    expect(result, {
      'https://h/ok': StreamHealth.ok,
      'https://h/reset': StreamHealth.unknown,
      'https://h/gone': StreamHealth.dead,
    });
    expect(seen['/ok']!['Range'], 'bytes=0-0');
    expect(seen['/ok']!['Referer'], 'https://site');
  });

  test('Stremio proxy headers are read from behaviorHints', () {
    expect(
      FrostStreamService.requestHeadersOf({
        'behaviorHints': {
          'proxyHeaders': {
            'request': {'Referer': 'https://site/', 'User-Agent': 'UA'}
          }
        }
      }),
      {'Referer': 'https://site/', 'User-Agent': 'UA'},
    );
    expect(FrostStreamService.requestHeadersOf({'behaviorHints': {}}), isEmpty);
    final candidate = StreamCandidate.fromStream({
      'url': 'https://h/1',
      'displayName': 'Nebula',
      'displayQuality': '720p',
      'displayAudio': 'Dublado',
    });
    expect(candidate.label, 'Nebula · 720p · Dublado');
  });

  test('the Global add-on is queried at its base URL', () {
    final global = FrostStreamService.providers
        .firstWhere((provider) => provider.name == 'Global');
    expect(global.brand, 'Global');
    expect(
      global.baseUrl,
      'https://hdhub.thevolecitor.qzz.io/'
      'eyJ0b3Jib3giOiJ1bnNldCIsInF1YWxpdGllcyI6IjIxNjBwLDEwODBwLDcyMHAiLCJzb3J0IjoiZGVzYyJ9',
    );
  });
}
