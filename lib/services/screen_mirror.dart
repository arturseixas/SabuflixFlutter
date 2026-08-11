import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The system's own screen-mirroring panel, and the multicast lock that makes
/// device discovery work on Android.
///
/// Mirroring the whole screen is not something an app can do to itself: on
/// Android it is a system service (Cast / Smart View / Screen Share), reached
/// through a settings panel the user confirms. So the app opens that panel
/// rather than pretending to own the feature.
///
/// For playing a video, [CastProvider] is the better path anyway — the TV pulls
/// the stream at full quality, the phone can be locked, and nothing is
/// re-encoded. Mirroring is the fallback for the odd television that answers
/// neither Cast nor DLNA.
class ScreenMirror {
  ScreenMirror._();

  static const MethodChannel _channel = MethodChannel('sabuflix/cast');

  /// Whether a system mirroring panel exists to open.
  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Opens the system's cast / screen-mirroring picker.
  ///
  /// Returns false when no panel could be opened, so the caller can explain
  /// instead of leaving the user staring at a button that did nothing.
  static Future<bool> openSystemMirroring() async {
    if (!isSupported) return false;
    try {
      final opened = await _channel.invokeMethod<bool>('openMirrorSettings');
      return opened ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('Mirror: could not open the system panel: $e');
      return false;
    }
  }

  /// Android filters multicast traffic away from apps by default; without this
  /// lock the SSDP and mDNS answers from televisions never arrive.
  static Future<void> acquireMulticastLock() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('acquireMulticastLock');
    } on MissingPluginException {
      // Older host build; discovery still works on most networks.
    } catch (e) {
      debugPrint('Mirror: could not acquire the multicast lock: $e');
    }
  }

  static Future<void> releaseMulticastLock() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('releaseMulticastLock');
    } on MissingPluginException {
      // Nothing was acquired.
    } catch (e) {
      debugPrint('Mirror: could not release the multicast lock: $e');
    }
  }
}
