import 'dart:async';
import 'package:flutter/services.dart';

/// Bridges to native Android code (MainActivity.kt) that drives the system's
/// real Picture-in-Picture mode (PictureInPictureParams). No-ops safely on
/// platforms/OS versions where it isn't wired up or supported.
class AndroidPipService {
  static const MethodChannel _channel = MethodChannel('com.sabuflix.app/pip');

  static final StreamController<bool> _modeController = StreamController<bool>.broadcast();
  static bool _initialized = false;

  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipModeChanged') {
        _modeController.add(call.arguments as bool);
      }
    });
  }

  /// Emits the current `isInPictureInPictureMode` state whenever it changes.
  static Stream<bool> get onModeChanged {
    _ensureInitialized();
    return _modeController.stream;
  }

  /// Tells the native side whether a video is currently playing, so it knows
  /// whether to automatically enter PiP when the user leaves the app.
  static Future<void> setAutoEnter(bool enabled) async {
    _ensureInitialized();
    try {
      await _channel.invokeMethod('setAutoEnter', {'enabled': enabled});
    } on MissingPluginException {
      // Not wired up on this platform; ignore.
    } on PlatformException {
      // PiP unsupported (e.g. old Android version); ignore.
    }
  }

  /// Manually enters system PiP mode right now (e.g. from a button tap).
  static Future<void> enterPipMode() async {
    _ensureInitialized();
    try {
      await _channel.invokeMethod('enterPipMode');
    } on MissingPluginException {
      // Not wired up on this platform; ignore.
    } on PlatformException {
      // PiP unsupported; ignore.
    }
  }
}
