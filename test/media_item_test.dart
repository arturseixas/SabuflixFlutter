import 'package:flutter_test/flutter_test.dart';
import 'package:sabuflix/models/media_item.dart';

void main() {
  group('MediaItem.fromJson — formato de "genres"', () {
    test('aceita o formato bruto da TMDB: lista de {id, name}', () {
      final item = MediaItem.fromJson({
        'id': 40075,
        'title': 'Gravity Falls',
        'vote_average': 8.6,
        'vote_count': 100,
        'media_type': 'tv',
        'genres': [
          {'id': 16, 'name': 'Animação'},
          {'id': 35, 'name': 'Comédia'},
        ],
      });

      expect(item.genres, ['Animação', 'Comédia']);
      expect(item.genreIds, [16, 35]);
    });

    test('aceita o formato gravado pelo próprio toJson(): lista de nomes', () {
      // Isto é exatamente o que MediaItem.toJson() escreve — e exatamente
      // o que travava ao reabrir o app: um MediaItem com detalhes
      // completos (buscados na tela de detalhes) é salvo num download,
      // favorito ou playlist, e ao recarregar, fromJson() tentava tratar
      // cada nome de gênero (uma String) como se fosse um Map.
      final item = MediaItem.fromJson({
        'id': 40075,
        'title': 'Gravity Falls',
        'vote_average': 8.6,
        'vote_count': 100,
        'media_type': 'tv',
        'genre_ids': [16, 35],
        'genres': ['Animação', 'Comédia'],
      });

      expect(item.genres, ['Animação', 'Comédia']);
      expect(item.genreIds, [16, 35]);
    });

    test('sobrevive a um ciclo completo de toJson() -> fromJson() com genres preenchido', () {
      final original = MediaItem(
        id: 40075,
        title: 'Gravity Falls',
        voteAverage: 8.6,
        voteCount: 100,
        mediaType: 'tv',
        genreIds: const [16, 35],
        genres: const ['Animação', 'Comédia'],
      );

      final roundTripped = MediaItem.fromJson(original.toJson());

      expect(roundTripped.genres, original.genres);
      expect(roundTripped.genreIds, original.genreIds);
    });

    test('não quebra quando genres vem vazio ou ausente', () {
      final withEmpty = MediaItem.fromJson({
        'id': 1,
        'title': 'X',
        'vote_average': 5.0,
        'vote_count': 1,
        'media_type': 'movie',
        'genres': [],
      });
      expect(withEmpty.genres, isEmpty);

      final withoutField = MediaItem.fromJson({
        'id': 1,
        'title': 'X',
        'vote_average': 5.0,
        'vote_count': 1,
        'media_type': 'movie',
      });
      expect(withoutField.genres, isNull);
    });
  });
}
