import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabuflix/tv/tv_focus.dart';
import 'package:sabuflix/tv/tv_metrics.dart';
import 'package:sabuflix/tv/tv_platform.dart';
import 'package:sabuflix/tv/tv_remote.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await TvPlatform.setMode(TvModeSetting.auto);
  });

  group('TvPlatform', () {
    test('stays off on a device that is not a television', () async {
      await TvPlatform.setMode(TvModeSetting.auto);
      expect(TvPlatform.isTv, isFalse);
    });

    test('the manual override wins over detection, both ways', () async {
      await TvPlatform.setMode(TvModeSetting.on);
      expect(TvPlatform.isTv, isTrue, reason: 'forcing TV mode must work on an undetected device');

      await TvPlatform.setMode(TvModeSetting.off);
      expect(TvPlatform.isTv, isFalse, reason: 'forcing touch mode must work on a detected TV');
    });

    test('remembers the choice', () async {
      await TvPlatform.setMode(TvModeSetting.on);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sabuflix_tv_mode'), 'on');
    });
  });

  group('TvMetrics', () {
    const screen = Size(1920, 1080);

    test('a phone gets no overscan margin and the phone poster size', () {
      final metrics = TvMetrics.forSize(const Size(390, 844), isTv: false);
      expect(metrics.overscan, EdgeInsets.zero);
      expect(metrics.posterWidth, 148);
    });

    test('a television insets the title-safe area and scales up', () {
      final metrics = TvMetrics.forSize(screen, isTv: true);

      // 4% horizontal / 4.5% vertical is the standard title-safe margin.
      expect(metrics.overscan.left, closeTo(76.8, 0.01));
      expect(metrics.overscan.top, closeTo(48.6, 0.01));

      expect(metrics.posterWidth, greaterThan(200));
      expect(metrics.sectionTitleSize, greaterThan(20));
      expect(metrics.posterRowHeight, greaterThan(metrics.posterWidth));
    });

    test('poster width stays inside its clamps on very small and very large panels', () {
      expect(TvMetrics.forSize(const Size(1280, 720), isTv: true).posterWidth, greaterThanOrEqualTo(150));
      expect(TvMetrics.forSize(const Size(3840, 2160), isTv: true).posterWidth, lessThanOrEqualTo(260));
    });
  });

  group('RemoteKey', () {
    KeyEvent down(LogicalKeyboardKey key) => KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.escape,
          logicalKey: key,
          timeStamp: Duration.zero,
        );

    test('recognises the back button of each ecosystem', () {
      // Android sends goBack; the TV browsers are normalised to Escape by the
      // shim in web/index.html.
      expect(RemoteKey.isBack(down(LogicalKeyboardKey.escape)), isTrue);
      expect(RemoteKey.isBack(down(LogicalKeyboardKey.goBack)), isTrue);
      expect(RemoteKey.isBack(down(LogicalKeyboardKey.browserBack)), isTrue);
      expect(RemoteKey.isBack(down(LogicalKeyboardKey.arrowLeft)), isFalse);
    });

    // SingleActivator has no value equality, so the map cannot be probed with a
    // freshly built key — the entries are scanned instead.
    Intent? unmodifiedBinding(LogicalKeyboardKey key) {
      for (final entry in tvShortcuts.entries) {
        final activator = entry.key;
        if (activator is SingleActivator &&
            activator.trigger == key &&
            !activator.control &&
            !activator.shift &&
            !activator.alt &&
            !activator.meta) {
          return entry.value;
        }
      }
      return null;
    }

    test('the TV shortcuts steer the focus with the arrows, never the scroll offset', () {
      // The regression this guards: on the web — which is what Tizen and webOS
      // run — Flutter's default map binds the arrows to ScrollIntent, so a
      // D-pad would move the scroll offset and never the highlight. If these
      // ever go back to ScrollIntent, the Samsung and LG builds stop being
      // navigable at all.
      for (final key in [
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
      ]) {
        expect(
          unmodifiedBinding(key),
          isA<DirectionalFocusIntent>(),
          reason: '$key must traverse the focus on a TV',
        );
      }
    });

    test('OK is bound for a D-pad, a keyboard and a gamepad alike', () {
      for (final key in [
        LogicalKeyboardKey.select,
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.numpadEnter,
        LogicalKeyboardKey.gameButtonA,
      ]) {
        expect(unmodifiedBinding(key), isA<ActivateIntent>(), reason: '$key must activate');
      }
    });

    test('recognises the transport keys', () {
      expect(RemoteKey.isPlayPause(down(LogicalKeyboardKey.mediaPlayPause)), isTrue);
      expect(RemoteKey.isFastForward(down(LogicalKeyboardKey.mediaFastForward)), isTrue);
      expect(RemoteKey.isRewind(down(LogicalKeyboardKey.mediaRewind)), isTrue);
      expect(RemoteKey.isStop(down(LogicalKeyboardKey.mediaStop)), isTrue);
    });
  });

  group('TvFocusable', () {
    Future<void> pumpButton(WidgetTester tester, VoidCallback onPressed) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvFocusable(
              autofocus: true,
              onPressed: onPressed,
              semanticLabel: 'Assistir',
              child: const SizedBox(width: 120, height: 60),
            ),
          ),
        ),
      );
    }

    testWidgets('answers the D-pad centre key', (tester) async {
      var presses = 0;
      await pumpButton(tester, () => presses++);
      await tester.pump();

      // What an Android TV remote sends for OK.
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(presses, 1);

      // What a TV browser and a keyboard send.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(presses, 2);
    });

    testWidgets('still works as a tap target', (tester) async {
      var presses = 0;
      await pumpButton(tester, () => presses++);
      await tester.pump();

      await tester.tap(find.byType(TvFocusable));
      await tester.pump();
      expect(presses, 1);
    });

    testWidgets('takes the focus on its own so the first key press has a target', (tester) async {
      await pumpButton(tester, () {});
      await tester.pump();

      final node = Focus.of(tester.element(find.byType(SizedBox).first), scopeOk: true);
      expect(node.hasFocus, isTrue);
    });
  });
}
