import 'package:flutter_test/flutter_test.dart';
import 'package:sabuflix/models/media_item.dart';
import 'package:sabuflix/providers/watched_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('histórico assistido é isolado por perfil', () async {
    final media = MediaItem(
      id: 42,
      title: 'Filme',
      voteAverage: 7,
      voteCount: 5,
      mediaType: 'movie',
      genreIds: const [],
    );
    final provider = WatchedProvider();
    await provider.loadForProfile('adulto');
    await provider.markWatched(media);
    expect(provider.isWatched(42), isTrue);

    await provider.loadForProfile('infantil');
    expect(provider.isWatched(42), isFalse);

    await provider.loadForProfile('adulto');
    expect(provider.isWatched(42), isTrue);
  });
}
