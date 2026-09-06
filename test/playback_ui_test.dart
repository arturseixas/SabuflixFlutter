import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sabuflix/models/media_item.dart';
import 'package:sabuflix/providers/favorites_provider.dart';
import 'package:sabuflix/providers/settings_provider.dart';
import 'package:sabuflix/providers/watched_provider.dart';
import 'package:sabuflix/providers/continue_watching_provider.dart';
import 'package:sabuflix/widgets/hero_banner.dart';
import 'package:sabuflix/widgets/media_row.dart';
import 'package:sabuflix/screens/video_player_screen.dart';
import 'package:sabuflix/theme/sabuflix_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

final media = MediaItem.fromJson({
  'id': 7,
  'title': 'Uma história para lembrar',
  'overview': 'Uma jornada inesperada aproxima pessoas de mundos diferentes.',
  'release_date': '2024-01-01',
  'vote_count': 10,
  'vote_average': 8.2
});
Widget host(Widget child, {double scale = 1}) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => FavoritesProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => WatchedProvider()),
          ChangeNotifierProvider(create: (_) => ContinueWatchingProvider()),
        ],
        child: MaterialApp(
            theme: SabuflixTheme.themeData,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Scaffold(body: child)));
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [320.0, 390.0, 800.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('catalog layout at $width and text scale $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(host(
            SingleChildScrollView(
                child: Column(children: [
              HeroBanner(media: media),
              MediaRow(title: 'Em alta', mediaItems: [media]),
            ])),
            scale: scale));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        expect(find.text('Ver detalhes'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets('catalog card accepts keyboard focus', (tester) async {
    await tester
        .pumpWidget(host(MediaRow(title: 'Em alta', mediaItems: [media])));
    await tester.pump(const Duration(seconds: 1));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('missing video shows recovery instead of simulated playback',
      (tester) async {
    await tester.pumpWidget(host(VideoPlayerScreen(media: media)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Nenhuma fonte de vídeo disponível.'), findsOneWidget);
    expect(find.text('Voltar aos detalhes'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
