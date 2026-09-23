import 'package:flutter_test/flutter_test.dart';
import 'package:sabuflix/models/media_item.dart';
import 'package:sabuflix/utils/formatters.dart';

void main() {
  test('film credits come from TMDB details and survive local storage', () {
    final film = MediaItem.fromJson({
      'id': 1,
      'title': 'Retrato de uma Jovem em Chamas',
      'original_title': 'Portrait de la jeune fille en feu',
      'release_date': '2019-09-18',
      'vote_average': 8.1,
      'tagline': ' ',
      'production_countries': [
        {'iso_3166_1': 'FR', 'name': 'France'},
        {'iso_3166_1': 'XX', 'name': 'Elsewhere'},
      ],
      'credits': {
        'crew': [
          {'job': 'Director', 'name': 'Céline Sciamma'},
          {'job': 'Editor', 'name': 'Julien Lacheray'},
        ],
      },
    });
    expect(film.directorLine, 'Dirigido por Céline Sciamma');
    expect(film.originLine, 'França, Elsewhere, 2019');
    expect(film.distinctOriginalTitle, 'Portrait de la jeune fille en feu');
    expect(film.starRating, '4,0');
    expect(film.tagline, isNull);

    final restored = MediaItem.fromJson(film.forStorage.toJson());
    expect(restored.directorLine, film.directorLine);
    expect(restored.originLine, film.originLine);
    expect(restored.distinctOriginalTitle, film.distinctOriginalTitle);
  });

  test('series credit their creators and list items stay minimal', () {
    final series = MediaItem.fromJson({
      'id': 2,
      'name': 'Dark',
      'original_name': 'Dark',
      'first_air_date': '2017-12-01',
      'origin_country': ['DE'],
      'created_by': [
        {'name': 'Baran bo Odar'},
        {'name': 'Jantje Friese'},
      ],
    });
    expect(series.directorLine, 'Criado por Baran bo Odar e Jantje Friese');
    expect(series.originLine, 'Alemanha, 2017');
    expect(series.distinctOriginalTitle, isNull);

    final bare = MediaItem.fromJson({'id': 3, 'title': 'Sem dados'});
    expect(bare.directorLine, isNull);
    expect(bare.originLine, isEmpty);
  });

  test('counts use the pt-BR thousands separator', () {
    expect(formatCount(7), '7');
    expect(formatCount(2493), '2.493');
    expect(formatCount(1234567), '1.234.567');
  });
}
