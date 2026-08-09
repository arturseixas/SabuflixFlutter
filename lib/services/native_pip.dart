import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// System-level picture-in-picture, where the platform offers it.
///
/// Android can float the video over other apps entirely, which is what
/// picture-in-picture means outside this app. Everywhere else the in-app
/// floating window is the best available, so every call here reports failure
/// rather than throwing and the caller falls back to it.
class NativePip {
  static const MethodChannel _channel = MethodChannel('sabuflix/pip');

  static bool get _isCandidatePlatform {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isSupported() async {
    if (!_isCandidatePlatform) return false;
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Returns true when the system took the video into its own window.
  static Future<bool> enter() async {
    if (!_isCandidatePlatform) return false;
    try {
      return await _channel.invokeMethod<bool>('enter') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Reports entering and leaving system picture-in-picture, so the app can
  /// strip its controls while the window is thumbnail sized.
  static void listenModeChanges(ValueChanged<bool> onChanged) {
    if (!_isCandidatePlatform) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'modeChanged') {
        onChanged(call.arguments == true);
      }
      return null;
    });
  }

  static void stopListening() {
    if (!_isCandidatePlatform) return;
    _channel.setMethodCallHandler(null);
  }
}
