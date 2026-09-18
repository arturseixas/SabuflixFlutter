import 'package:flutter_test/flutter_test.dart';
import 'package:sabuflix/services/playback_resolver.dart';

Map<String, dynamic> stream(String quality, {String audio = ''}) => {
      'url': 'https://cdn/$quality-$audio.mp4',
      'displayQuality': quality,
      'displayDescription': '$quality  •  $audio  •  Opção 01',
    };

void main() {
  test('quality labels rank from 4K down to SD', () {
    expect(PlaybackResolver.qualityRank('4K'), 4);
    expect(PlaybackResolver.qualityRank('2160p'), 4);
    expect(PlaybackResolver.qualityRank('1080P'), 3);
    expect(PlaybackResolver.qualityRank('720p'), 2);
    expect(PlaybackResolver.qualityRank('SD'), 1);
    expect(PlaybackResolver.qualityRank('Qualidade automática'), 0);
  });

  test('automatic quality prefers the sharpest source', () {
    final best = PlaybackResolver.pickBest(
      [stream('720p'), stream('4K'), stream('1080p')],
      quality: PreferredQuality.auto,
      audio: PreferredAudio.any,
    );
    expect(best!['displayQuality'], '4K');
  });

  test('an exact quality match beats higher and lower options', () {
    final sorted = PlaybackResolver.sort(
      [stream('4K'), stream('720p'), stream('1080p'), stream('SD')],
      quality: PreferredQuality.hd,
      audio: PreferredAudio.any,
    );
    expect(
        sorted.map((s) => s['displayQuality']), ['720p', 'SD', '1080p', '4K']);
  });

  test('dubbed preference wins over a sharper subtitled source', () {
    final best = PlaybackResolver.pickBest(
      [stream('1080p', audio: 'Legendado'), stream('720p', audio: 'Dublado')],
      quality: PreferredQuality.auto,
      audio: PreferredAudio.dubbed,
    );
    expect(best!['displayDescription'], contains('Dublado'));
  });

  test('ties keep the original source order', () {
    final a = stream('1080p')..['url'] = 'a';
    final b = stream('1080p')..['url'] = 'b';
    final sorted = PlaybackResolver.sort([a, b],
        quality: PreferredQuality.fhd, audio: PreferredAudio.any);
    expect(sorted.map((s) => s['url']), ['a', 'b']);
  });

  group('next episode', () {
    final seasons = [
      {'season_number': 0, 'episode_count': 3}, // specials are ignored
      {'season_number': 1, 'episode_count': 8},
      {'season_number': 2, 'episode_count': 10},
    ];

    test('advances within the season', () {
      final next = PlaybackResolver.nextEpisodeFromSeasons(seasons, 1, 3)!;
      expect((next.season, next.episode), (1, 4));
    });

    test('crosses into the next season after the finale', () {
      final next = PlaybackResolver.nextEpisodeFromSeasons(seasons, 1, 8)!;
      expect((next.season, next.episode), (2, 1));
    });

    test('is null after the last episode of the last season', () {
      expect(PlaybackResolver.nextEpisodeFromSeasons(seasons, 2, 10), isNull);
    });

    test('assumes the season continues when metadata is missing', () {
      final next = PlaybackResolver.nextEpisodeFromSeasons(const [], 3, 5)!;
      expect((next.season, next.episode), (3, 6));
    });
  });
}
