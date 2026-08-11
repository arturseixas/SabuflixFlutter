import 'dart:io';

import 'package:flutter/services.dart';

/// Thin wrapper around Android's `WifiManager.MulticastLock`.
///
/// Android throttles multicast packet reception by default to save power,
/// which makes mDNS-based Chromecast discovery unreliable unless the app
/// explicitly asks to receive them. This is a no-op on every other
/// platform, where multicast reception isn't gated behind a lock.
class AndroidMulticastLock {
  static const _channel = MethodChannel('sabuflix/multicast_lock');

  static Future<void> acquire() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('acquire');
    } catch (_) {
      // Best-effort — discovery still works without it on most devices,
      // just less reliably in the background or with the screen off.
    }
  }

  static Future<void> release() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('release');
    } catch (_) {}
  }
}
