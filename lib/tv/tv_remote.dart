import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// What each button on a TV remote arrives as, once the three ecosystems are
/// reconciled.
///
/// * Android TV / Google TV sends real Android key codes, which Flutter maps
///   to `select`, `mediaPlayPause`, `mediaFastForward` and friends.
/// * Samsung Tizen and LG webOS are browsers: their remote sends vendor key
///   codes (Tizen `10009` = Return, webOS `461` = Back, plus the numeric media
///   codes) which `web/index.html` normalises into standard `KeyboardEvent`s
///   before Flutter ever sees them.
/// * A keyboard, a gamepad or a mouse-driven browser window keeps working,
///   because the standard keys are listed alongside the TV ones.
class RemoteKey {
  RemoteKey._();

  static final Set<LogicalKeyboardKey> back = {
    LogicalKeyboardKey.escape,
    LogicalKeyboardKey.goBack,
    LogicalKeyboardKey.browserBack,
    LogicalKeyboardKey.gameButtonB,
  };

  static final Set<LogicalKeyboardKey> select = {
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.gameButtonA,
  };

  static final Set<LogicalKeyboardKey> playPause = {
    LogicalKeyboardKey.mediaPlayPause,
    LogicalKeyboardKey.mediaPlay,
    LogicalKeyboardKey.mediaPause,
    LogicalKeyboardKey.pause,
  };

  static final Set<LogicalKeyboardKey> fastForward = {
    LogicalKeyboardKey.mediaFastForward,
    LogicalKeyboardKey.mediaTrackNext,
    LogicalKeyboardKey.mediaSkipForward,
  };

  static final Set<LogicalKeyboardKey> rewind = {
    LogicalKeyboardKey.mediaRewind,
    LogicalKeyboardKey.mediaTrackPrevious,
    LogicalKeyboardKey.mediaSkipBackward,
  };

  static final Set<LogicalKeyboardKey> stop = {
    LogicalKeyboardKey.mediaStop,
  };

  static final Set<LogicalKeyboardKey> left = {LogicalKeyboardKey.arrowLeft};
  static final Set<LogicalKeyboardKey> right = {LogicalKeyboardKey.arrowRight};
  static final Set<LogicalKeyboardKey> up = {LogicalKeyboardKey.arrowUp};
  static final Set<LogicalKeyboardKey> down = {LogicalKeyboardKey.arrowDown};

  static bool isBack(KeyEvent event) => back.contains(event.logicalKey);
  static bool isSelect(KeyEvent event) => select.contains(event.logicalKey);
  static bool isPlayPause(KeyEvent event) => playPause.contains(event.logicalKey);
  static bool isFastForward(KeyEvent event) => fastForward.contains(event.logicalKey);
  static bool isRewind(KeyEvent event) => rewind.contains(event.logicalKey);
  static bool isStop(KeyEvent event) => stop.contains(event.logicalKey);
  static bool isLeft(KeyEvent event) => left.contains(event.logicalKey);
  static bool isRight(KeyEvent event) => right.contains(event.logicalKey);
  static bool isUp(KeyEvent event) => up.contains(event.logicalKey);
  static bool isDown(KeyEvent event) => down.contains(event.logicalKey);
}

/// What the remote's D-pad and OK button mean, app-wide, in TV mode.
///
/// This map exists because of one platform difference that would otherwise
/// make the Samsung and LG builds unusable: **on the web, Flutter binds the
/// arrow keys to scrolling rather than to focus traversal** — a sensible
/// default for a page in a browser tab, fatal for a D-pad. Tizen and webOS are
/// web platforms, so without this override pressing left or right on the
/// remote would nudge a scroll offset and never move the highlight.
///
/// `select` — what an Android TV D-pad centre button reports — is bound here
/// too, alongside the gamepad button and Enter, so OK behaves identically on
/// all three ecosystems.
final Map<ShortcutActivator, Intent> tvShortcuts = <ShortcutActivator, Intent>{
  ...WidgetsApp.defaultShortcuts,
  const SingleActivator(LogicalKeyboardKey.arrowLeft): const DirectionalFocusIntent(TraversalDirection.left),
  const SingleActivator(LogicalKeyboardKey.arrowRight): const DirectionalFocusIntent(TraversalDirection.right),
  const SingleActivator(LogicalKeyboardKey.arrowUp): const DirectionalFocusIntent(TraversalDirection.up),
  const SingleActivator(LogicalKeyboardKey.arrowDown): const DirectionalFocusIntent(TraversalDirection.down),
  const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
  const SingleActivator(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
  const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
  const SingleActivator(LogicalKeyboardKey.gameButtonA): const ActivateIntent(),
};

/// Turns the remote's Back button into a route pop on the TV browsers.
///
/// Android delivers Back as a system navigation event, which `PopScope` and
/// the Navigator already handle. Tizen and webOS deliver it as a key, so
/// somebody has to translate it — this widget sits above the navigator and
/// does exactly that, and nothing else, so it never interferes with the
/// arrow-key traversal underneath it.
class TvBackKeyHandler extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  const TvBackKeyHandler({
    Key? key,
    required this.navigatorKey,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent || !RemoteKey.isBack(event)) {
          return KeyEventResult.ignored;
        }
        final navigator = navigatorKey.currentState;
        if (navigator == null) return KeyEventResult.ignored;
        // maybePop honours the PopScope guards the screens install, so the
        // "press back again to leave" prompt still gets its say.
        navigator.maybePop();
        return KeyEventResult.handled;
      },
      child: child,
    );
  }
}
