import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thin wrapper over [HapticFeedback] with a single place to tune intensity.
///
/// Desktop and web have no vibrator; the platform calls are silently ignored
/// there, but skipping them avoids a pointless channel round-trip on every
/// tap.
class Haptics {
  Haptics._();

  static bool get _enabled {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Navigation, list taps, opening a sheet — the everyday tap.
  static void selection() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
  }

  /// A light bump for toggles and scrubbing past a tick.
  static void light() {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
  }

  /// Primary actions: play, start a download, confirm a choice.
  static void medium() {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
  }

  /// Destructive or committing actions: delete, cast, download a whole series.
  static void heavy() {
    if (!_enabled) return;
    HapticFeedback.heavyImpact();
  }

  /// Something failed or is blocked (age rating, no sources found).
  static void error() {
    if (!_enabled) return;
    HapticFeedback.vibrate();
  }
}
