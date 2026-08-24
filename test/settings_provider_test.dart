import 'package:flutter_test/flutter_test.dart';
import 'package:sabuflix/models/media_item.dart';
import 'package:sabuflix/models/watch_progress.dart';
import 'package:sabuflix/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

MediaItem _media(int id, {String? releaseDate}) => MediaItem(
      id: id,
      title: 'Título $id',
      voteAverage: 8,
      voteCount: 10,
      releaseDate: releaseDate,
      mediaType: 'movie',
      genreIds: const [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('oculta lançamentos futuros sem descartar datas desconhecidas',
      () async {
    final settings = SettingsProvider();
    await Future<void>.delayed(Duration.zero);
    final visible = settings.visibleItems([
      _media(1, releaseDate: '2020-01-01'),
      _media(2, releaseDate: '2999-01-01'),
      _media(3),
    ]);

    expect(visible.map((item) => item.id), [1, 3]);
  });

  test('ordena continuar assistindo por tempo restante', () async {
    final settings = SettingsProvider();
    await Future<void>.delayed(Duration.zero);
    await settings.setContinueWatchingSort(ContinueWatchingSort.remaining);
    final entries = [
      WatchProgress(
          media: _media(1),
          positionSeconds: 10,
          durationSeconds: 100,
          updatedAt: 1),
      WatchProgress(
          media: _media(2),
          positionSeconds: 80,
          durationSeconds: 100,
          updatedAt: 2),
    ];

    expect(settings.sortedProgress(entries).map((entry) => entry.media.id),
        [2, 1]);
  });
}
