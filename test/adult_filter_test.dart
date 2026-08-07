import 'package:flutter_test/flutter_test.dart';
import 'package:sabuflix/models/media_item.dart';
import 'package:sabuflix/services/tmdb_service.dart';

Map<String, dynamic> _tmdbResult({required int id, required bool adult}) {
  return {
    'id': id,
    'title': 'Título $id',
    'adult': adult,
    'vote_average': 5.0,
    'vote_count': 10,
    'media_type': 'movie',
    'genre_ids': <int>[],
  };
}

void main() {
  group('adult content filtering', () {
    test('reads TMDB\'s adult flag', () {
      expect(MediaItem.fromJson(_tmdbResult(id: 1, adult: true)).isAdult, isTrue);
      expect(MediaItem.fromJson(_tmdbResult(id: 2, adult: false)).isAdult, isFalse);
    });

    test('treats a missing flag as not adult', () {
      final json = _tmdbResult(id: 3, adult: false)..remove('adult');
      expect(MediaItem.fromJson(json).isAdult, isFalse);
    });

    test('withoutAdult drops flagged titles and keeps the rest', () {
      final items = [
        MediaItem.fromJson(_tmdbResult(id: 1, adult: false)),
        MediaItem.fromJson(_tmdbResult(id: 2, adult: true)),
        MediaItem.fromJson(_tmdbResult(id: 3, adult: false)),
      ];

      final filtered = TMDBService.withoutAdult(items);

      expect(filtered.map((item) => item.id), [1, 3]);
    });

    test('the flag survives a storage round trip', () {
      final original = MediaItem.fromJson(_tmdbResult(id: 4, adult: true));
      expect(MediaItem.fromJson(original.toJson()).isAdult, isTrue);
    });
  });
}
