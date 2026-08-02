import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'playback_service.dart';

/// Bridge to the platform's native Picture-in-Picture window.
///
/// Only Android exposes a real system PiP window to a Flutter app (the
/// activity is re-rendered into a floating window by the OS). Everywhere else
/// [PlaybackService.enterPip] falls back to the in-app mini player, which is
/// driven entirely from Dart.
class PipService {
  PipService._();

  static final PipService instance = PipService._();

  static const MethodChannel _channel = MethodChannel('com.sabuflix.app/pip');

  static bool get supportsSystemPip =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool _initialised = false;

  /// Wires the native → Dart callbacks. Call once at start-up.
  void init() {
    if (_initialised || !supportsSystemPip) return;
    _initialised = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipModeChanged') {
        PlaybackService.instance.setSystemPipMode(call.arguments == true);
      }
      return null;
    });
  }

  /// Lets Android float the video automatically when the user presses Home
  /// mid-playback, instead of hiding it.
  Future<void> setAutoPipEnabled(bool enabled) async {
    if (!supportsSystemPip) return;
    try {
      await _channel.invokeMethod<void>('setAutoPipEnabled', enabled);
    } on PlatformException catch (e) {
      debugPrint('PipService: could not toggle auto-PiP — ${e.message}');
    } on MissingPluginException {
      // Older build without the native side; nothing to toggle.
    }
  }

  /// Asks Android to move the activity into its PiP window.
  ///
  /// Returns false when the device or OS version refuses (pre-Oreo, PiP
  /// disabled for the app, or the activity is not in a valid state).
  Future<bool> enterSystemPip({double aspectRatio = 16 / 9}) async {
    if (!supportsSystemPip) return false;
    try {
      final result = await _channel.invokeMethod<bool>(
        'enterPip',
        {'aspectRatio': aspectRatio},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('PipService: system PiP unavailable — ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
