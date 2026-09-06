import 'package:flutter_test/flutter_test.dart';
import 'package:sabuflix/models/media_item.dart';
import 'package:sabuflix/providers/favorites_provider.dart';
import 'package:sabuflix/providers/continue_watching_provider.dart';
import 'package:sabuflix/providers/watched_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('movie and series with the same TMDB id keep independent state',
      () async {
    SharedPreferences.setMockInitialValues({});
    final movie =
        MediaItem.fromJson({'id': 42, 'title': 'Movie', 'media_type': 'movie'});
    final series =
        MediaItem.fromJson({'id': 42, 'name': 'Series', 'media_type': 'tv'});
    final favorites = FavoritesProvider();
    final watched = WatchedProvider();
    final progress = ContinueWatchingProvider();
    await Future.wait([
      favorites.loadFavorites('a'),
      watched.loadForProfile('a'),
      progress.loadForProfile('a')
    ]);
    await favorites.toggleFavorite(movie);
    await favorites.toggleFavorite(series);
    await watched.markWatched(movie);
    await watched.markWatched(series);
    for (final media in [movie, series]) {
      await progress.record(
          media: media, positionSeconds: 120, durationSeconds: 3600);
    }
    expect(favorites.favorites, hasLength(2));
    expect(watched.items, hasLength(2));
    expect(progress.entries, hasLength(2));
    await favorites.toggleFavorite(movie);
    await watched.toggle(movie);
    await progress.remove(movie.id, mediaType: movie.mediaType);
    expect(favorites.isFavorite(42, mediaType: 'movie'), isFalse);
    expect(favorites.isFavorite(42, mediaType: 'tv'), isTrue);
    expect(watched.isWatched(42, mediaType: 'movie'), isFalse);
    expect(watched.isWatched(42, mediaType: 'tv'), isTrue);
    expect(progress.forMedia(42, mediaType: 'movie'), isNull);
    expect(progress.forMedia(42, mediaType: 'tv'), isNotNull);
    favorites.dispose();
    watched.dispose();
    progress.dispose();
  });
}
