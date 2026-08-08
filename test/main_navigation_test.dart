import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sabuflix/providers/catalog_provider.dart';
import 'package:sabuflix/providers/downloads_provider.dart';
import 'package:sabuflix/providers/favorites_provider.dart';
import 'package:sabuflix/providers/playlist_provider.dart';
import 'package:sabuflix/providers/profile_provider.dart';
import 'package:sabuflix/providers/search_provider.dart';
import 'package:sabuflix/screens/main_navigation_screen.dart';
import 'package:sabuflix/theme/sabuflix_theme.dart';

void main() {
  testWidgets('mobile dock fits 6 destinations on a narrow phone', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ProfileProvider()),
          ChangeNotifierProvider(create: (_) => PlaylistProvider()),
          ChangeNotifierProvider(create: (_) => CatalogProvider()),
          ChangeNotifierProvider(create: (_) => FavoritesProvider()),
          ChangeNotifierProvider(create: (_) => SearchProvider()),
          ChangeNotifierProvider(create: (_) => DownloadsProvider()),
        ],
        child: MaterialApp(theme: SabuflixTheme.themeData, home: const MainNavigationScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Início'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
