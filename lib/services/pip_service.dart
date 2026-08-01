import 'package:flutter/services.dart';

/// Bridges to the native Android Picture-in-Picture APIs.
/// On platforms without a matching native implementation, calls fail
/// safely and the app falls back to the in-app floating mini-player.
class PipService {
  static const MethodChannel _methodChannel = MethodChannel('sabuflix/pip');
  static const EventChannel _eventChannel = EventChannel('sabuflix/pip_events');

  static Stream<bool>? _pipModeStream;

  /// Requests the OS to enter Picture-in-Picture mode.
  /// Returns true if the request was accepted by the platform.
  static Future<bool> enterPip() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('enterPip');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Tells the native side whether playback is currently active, so it can
  /// decide to auto-enter PiP when the user leaves the app (e.g. home button).
  static Future<void> setPlaybackActive(bool active) async {
    try {
      await _methodChannel.invokeMethod('setPlaybackActive', {'active': active});
    } on PlatformException {
      // ignore
    } on MissingPluginException {
      // ignore
    }
  }

  /// Emits true/false whenever the native PiP mode changes.
  static Stream<bool> get pipModeChanges {
    _pipModeStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => event == true)
        .handleError((_) {});
    return _pipModeStream!;
  }
}
