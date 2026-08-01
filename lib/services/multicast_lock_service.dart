import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android silently drops incoming multicast packets to save battery unless
/// a WifiManager.MulticastLock is held — without it, SSDP (DLNA) and mDNS
/// (Chromecast) discovery see nothing on many devices. No-ops elsewhere.
class MulticastLockService {
  static const MethodChannel _channel = MethodChannel('sabuflix/multicast');

  static Future<void> acquire() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod('acquire');
    } on PlatformException {
      // ignore
    } on MissingPluginException {
      // ignore
    }
  }

  static Future<void> release() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod('release');
    } on PlatformException {
      // ignore
    } on MissingPluginException {
      // ignore
    }
  }
}
