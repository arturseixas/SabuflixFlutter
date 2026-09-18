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

  test('episódios assistidos são rastreados por série e temporada', () async {
    final provider = WatchedProvider();
    await provider.loadForProfile('a');
    await provider.markEpisodeWatched(7, 1, 1);
    await provider.markEpisodeWatched(7, 1, 2);
    await provider.markEpisodeWatched(7, 2, 1);
    expect(provider.isEpisodeWatched(7, 1, 2), isTrue);
    expect(provider.isEpisodeWatched(7, 1, 3), isFalse);
    expect(provider.watchedCountInSeason(7, 1), 2);
    expect(provider.watchedEpisodeCount(7), 3);
    expect(provider.lastWatchedEpisode(7), (season: 2, episode: 1));

    await provider.toggleEpisode(7, 2, 1);
    expect(provider.lastWatchedEpisode(7), (season: 1, episode: 2));

    final restored = WatchedProvider();
    await restored.loadForProfile('a');
    expect(restored.isEpisodeWatched(7, 1, 1), isTrue);
    expect(restored.isEpisodeWatched(7, 2, 1), isFalse);

    await restored.loadForProfile('b');
    expect(restored.watchedEpisodeCount(7), 0);
  });
}
