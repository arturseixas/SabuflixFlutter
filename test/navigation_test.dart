import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sabuflix/models/media_item.dart';
import 'package:sabuflix/providers/catalog_provider.dart';
import 'package:sabuflix/providers/continue_watching_provider.dart';
import 'package:sabuflix/providers/downloads_provider.dart';
import 'package:sabuflix/providers/favorites_provider.dart';
import 'package:sabuflix/providers/playlist_provider.dart';
import 'package:sabuflix/providers/profile_provider.dart';
import 'package:sabuflix/providers/search_provider.dart';
import 'package:sabuflix/providers/settings_provider.dart';
import 'package:sabuflix/providers/watched_provider.dart';
import 'package:sabuflix/screens/main_navigation_screen.dart';
import 'package:sabuflix/services/tmdb_service.dart';
import 'package:sabuflix/theme/sabuflix_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCatalog extends TMDBService {
  final items = [
    MediaItem.fromJson({'id': 1, 'title': 'Filme', 'overview': 'Uma história.'})
  ];
  @override
  Future<List<MediaItem>> fetchTrending(
          {String mediaType = 'all', String timeWindow = 'week'}) async =>
      items;
  @override
  Future<List<MediaItem>> fetchPopularMovies() async => items;
  @override
  Future<List<MediaItem>> fetchPopularTV() async => [];
  @override
  Future<List<MediaItem>> fetchTopRatedMovies() async => [];
  @override
  Future<List<MediaItem>> fetchByGenre(int id,
          {String mediaType = 'movie'}) async =>
      [];
  @override
  Future<String?> fetchLogoPath(int id, String type) async => null;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [320.0, 800.0, 1440.0]) {
    testWidgets('navigation remains usable at $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider(
                create: (_) => CatalogProvider(service: LocalCatalog())),
            ChangeNotifierProvider(create: (_) => ProfileProvider()),
            ChangeNotifierProvider(create: (_) => DownloadsProvider()),
            ChangeNotifierProvider(create: (_) => ContinueWatchingProvider()),
            ChangeNotifierProvider(create: (_) => FavoritesProvider()),
            ChangeNotifierProvider(create: (_) => WatchedProvider()),
            ChangeNotifierProvider(create: (_) => PlaylistProvider()),
            ChangeNotifierProvider(create: (_) => SearchProvider()),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ],
          child: MaterialApp(
              theme: SabuflixTheme.themeData,
              home: const MainNavigationScreen())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Pesquisar').first);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Ajustes').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
