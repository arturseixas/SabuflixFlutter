import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sabuflix/services/addon_service.dart';
import 'package:sabuflix/services/tmdb_service.dart';

void main() {
  test('SRT subtitles are converted to WebVTT for browser playback', () async {
    final service = AddonService(
        client: MockClient((_) async => http.Response(
            '1\n00:00:01,000 --> 00:00:02,500\nOlá\n', 200,
            headers: {'content-type': 'text/plain; charset=utf-8'})));
    final text = await service.webSubtitle('https://example.com/subtitle.srt');
    expect(text, startsWith('WEBVTT\n\n'));
    expect(text, contains('00:00:01.000 --> 00:00:02.500'));
    expect(text, contains('Olá'));
  });

  test(
      'episode subtitles preserve identity, reject invalid URLs and prioritize Portuguese',
      () async {
    final service = AddonService(client: MockClient((request) async {
      expect(request.url.path, '/subtitles/series/tt123:2:4.json');
      return http.Response(
          jsonEncode({
            'subtitles': [
              {'lang': 'eng', 'url': 'https://example.com/en.vtt'},
              {'lang': 'pob', 'url': 'https://example.com/pt.vtt'},
              {'lang': 'pob', 'url': 'https://example.com/pt.vtt'},
              {'lang': 'por', 'url': 'file:///private.srt'},
            ]
          }),
          200);
    }));
    final result = await service.subtitles(
        imdbId: 'tt123', type: 'tv', season: 2, episode: 4);
    expect(result.length, 2);
    expect(result.first['lang'], 'pob');
    expect(await service.subtitles(imdbId: 'tt123', type: 'tv'), isEmpty);
  });

  test('subtitle failures do not prevent playback', () async {
    for (final response in [
      http.Response('unavailable', 503),
      http.Response('{bad json', 200)
    ]) {
      final service = AddonService(client: MockClient((_) async => response));
      expect(await service.subtitles(imdbId: 'tt123', type: 'movie'), isEmpty);
    }
  });

  test('Fenix catalogs resolve IMDb to real TMDB identity', () async {
    final service = TMDBService(client: MockClient((request) async {
      if (request.url.host == 'fenixflix.fenixhub.online') {
        expect(request.url.toString(), contains('%7C'));
        expect(request.url.toString(), isNot(contains('%257C')));
        expect(
            request.url.path, endsWith('/catalog/series/populares_fenix.json'));
        return http.Response('{"metas":[{"id":"tt123"}]}', 200);
      }
      expect(request.url.path, '/3/find/tt123');
      return http.Response(
          '{"tv_results":[{"id":42,"name":"Cinema","first_air_date":"2025-01-01"}]}',
          200);
    }));
    final items = await service.fetchFenixCatalog('series', 'populares_fenix');
    expect(items.single.storageKey, 'tv_42');
    expect(items.single.imdbId, 'tt123');
  });
}
