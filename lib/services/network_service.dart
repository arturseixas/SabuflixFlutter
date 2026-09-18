import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android needs a Wi-Fi multicast lock before SSDP/mDNS replies reach us.
/// Every other platform delivers them without ceremony, so this is a no-op
/// there.
class NetworkService {
  NetworkService._();

  static final NetworkService instance = NetworkService._();
  static const _channel = MethodChannel('com.sabuflix.app/network');

  Future<void> acquireMulticastLock() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<bool>('acquireMulticastLock');
    } catch (error) {
      debugPrint('Multicast lock unavailable: $error');
    }
  }

  Future<void> releaseMulticastLock() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('releaseMulticastLock');
    } catch (_) {
      // Nothing to release.
    }
  }
}
