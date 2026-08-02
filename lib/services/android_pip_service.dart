import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Wraps the native Android Picture-in-Picture MethodChannel so the app can
/// enter true system-level PiP (floating over other apps), the same way
/// Firefox does on Android, instead of an in-app-only mini player.
class AndroidPipService {
  AndroidPipService._();
  static final AndroidPipService instance = AndroidPipService._();

  static bool get isPlatformAndroid => !kIsWeb && Platform.isAndroid;

  static const MethodChannel _channel = MethodChannel('sabuflix/pip');

  final StreamController<bool> _modeController = StreamController<bool>.broadcast();

  /// Emits true when the activity enters system PiP mode, false when it leaves.
  Stream<bool> get onModeChanged => _modeController.stream;

  bool _handlerAttached = false;

  void _ensureHandler() {
    if (_handlerAttached || !isPlatformAndroid) return;
    _handlerAttached = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipModeChanged') {
        _modeController.add(call.arguments as bool? ?? false);
      }
    });
  }

  Future<bool> isSupported() async {
    if (!isPlatformAndroid) return false;
    _ensureHandler();
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> enter({double aspectRatio = 16 / 9}) async {
    if (!isPlatformAndroid) return;
    _ensureHandler();
    final ratio = aspectRatio > 0 ? aspectRatio : 16 / 9;
    try {
      await _channel.invokeMethod('enterPip', {
        'aspectRatioX': (ratio * 100).round(),
        'aspectRatioY': 100,
      });
    } catch (_) {}
  }

  /// Tells the native side whether it should auto-enter PiP when the user
  /// leaves the app (presses Home / switches apps) while a video is playing.
  Future<void> setAutoEnterEnabled(bool enabled) async {
    if (!isPlatformAndroid) return;
    _ensureHandler();
    try {
      await _channel.invokeMethod('setAutoEnter', {'enabled': enabled});
    } catch (_) {}
  }
}
