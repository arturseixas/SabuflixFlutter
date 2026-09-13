import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sabuflix/models/media_item.dart';
import 'package:sabuflix/providers/continue_watching_provider.dart';
import 'package:sabuflix/providers/watched_provider.dart';
import 'package:sabuflix/screens/video_player_screen.dart';
import 'package:sabuflix/theme/sabuflix_theme.dart';

void main() {
  testWidgets('browser waits for Play and then advances actual video',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    MediaKit.ensureInitialized();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ContinueWatchingProvider()),
          ChangeNotifierProvider(create: (_) => WatchedProvider()),
        ],
        child: MaterialApp(
            theme: SabuflixTheme.themeData,
            home: VideoPlayerScreen(
              media: MediaItem.fromJson(
                  {'id': 1, 'title': 'Browser playback test'}),
              videoUrl:
                  'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
            ))));
    await tester.pump(const Duration(seconds: 35));
    expect(find.byTooltip('Reproduzir'), findsOneWidget);
    expect(find.textContaining('não conseguiu reproduzir'), findsNothing);
    final player = tester.widget<Video>(find.byType(Video)).controller.player;
    // Automated widget taps are not trusted DOM gestures; mute only in this test.
    await tester.runAsync(
        () => player.setVolume(0).timeout(const Duration(seconds: 20)));
    await tester.tap(find.byTooltip('Reproduzir'));
    await tester.runAsync(() async {
      await player.stream.position
          .firstWhere((p) => p > Duration.zero)
          .timeout(const Duration(seconds: 20));
    });
    await tester.pump();
    expect(player.state.position, greaterThan(Duration.zero));
    expect(find.byTooltip('Pausar'), findsOneWidget);
    await tester.tap(find.byTooltip('Pausar'));
    await tester.runAsync(() async {
      if (player.state.playing) {
        await player.stream.playing
            .firstWhere((playing) => !playing)
            .timeout(const Duration(seconds: 5));
      }
    });
    expect(player.state.playing, isFalse);
    await tester.pumpWidget(const SizedBox());
  }, skip: !kIsWeb);
}
