import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Bridges to Android's real system Picture-in-Picture — the same
/// `Activity.enterPictureInPictureMode()` API Netflix/YouTube use, so the
/// video keeps floating over the home screen and every other app, not just
/// within Sabuflix.
///
/// Native side lives in `MainActivity.kt`. `setEligible(true)` arms
/// auto-PiP-on-home-press (via `onUserLeaveHint`), matching how those apps
/// behave; `enter()` triggers it immediately for an explicit PiP button.
class AndroidPipController {
  static const _channel = MethodChannel('sabuflix/pip');

  static final _modeChangedController = StreamController<bool>.broadcast();

  /// Emits the new PiP state whenever Android enters or exits it — driven
  /// by `Activity.onPictureInPictureModeChanged`, not by our own button
  /// taps, since the system can also exit PiP on its own (user drags it
  /// closed, taps "expand", etc.).
  static Stream<bool> get onModeChanged => _modeChangedController.stream;

  static bool _handlerInstalled = false;

  static void _ensureHandler() {
    if (_handlerInstalled || !Platform.isAndroid) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'modeChanged':
          _modeChangedController.add(call.arguments as bool? ?? false);
          break;
        case 'togglePlayPause':
          _playPauseController.add(null);
          break;
      }
      return null;
    });
  }

  static final _playPauseController = StreamController<void>.broadcast();

  /// Fires when the user taps the play/pause action Android draws on the
  /// PiP window's own system chrome.
  static Stream<void> get onTogglePlayPauseRequested => _playPauseController.stream;

  static Future<bool> isSupported() async {
    if (!Platform.isAndroid) return false;
    _ensureHandler();
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Arms (or disarms) auto-PiP: while eligible, pressing Home/switching
  /// apps enters PiP automatically instead of just pausing in the
  /// background.
  static Future<void> setEligible(bool eligible) async {
    if (!Platform.isAndroid) return;
    _ensureHandler();
    try {
      await _channel.invokeMethod('setEligible', {'eligible': eligible});
    } catch (_) {}
  }

  /// Keeps the native side's play/pause PiP action icon in sync with actual
  /// playback state.
  static Future<void> setPlaying(bool playing) async {
    if (!Platform.isAndroid) return;
    _ensureHandler();
    try {
      await _channel.invokeMethod('setPlaying', {'playing': playing});
    } catch (_) {}
  }

  static Future<void> enter() async {
    if (!Platform.isAndroid) return;
    _ensureHandler();
    try {
      await _channel.invokeMethod('enter');
    } catch (_) {}
  }
}
