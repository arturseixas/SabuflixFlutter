import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tv_detect_stub.dart' if (dart.library.js_interop) 'tv_detect_web.dart' as detect;

/// Which living-room platform we are running on.
enum TvSystem {
  /// Phone, tablet, desktop or a plain browser window.
  none,

  /// Android TV / Google TV (also covers Fire TV and the Chromecast with
  /// Google TV, which report the same leanback feature).
  androidTv,

  /// Samsung Tizen, running the packaged web app.
  tizen,

  /// LG webOS, running the packaged web app.
  webOs,

  /// Any other TV browser: Vidaa/Hisense, Foxxum, Zeasn, Philips/NetCast,
  /// HbbTV sets, Chromecast, and the generic "SmartTV" user agents.
  otherTv,
}

/// How the app decides whether to show the TV interface.
enum TvModeSetting { auto, on, off }

/// Runtime answer to "are we on a television?", plus the manual override.
///
/// Detection has to work across three very different worlds, so it uses the
/// signal each one actually offers:
///
/// * **Android TV / Google TV** — asks the platform through a method channel
///   (`UiModeManager` + the leanback system feature). This is the same check
///   Google's own leanback libraries make.
/// * **Tizen / webOS / other TV browsers** — looks for the JS runtime object
///   the TV injects into the page, falling back to the user agent.
/// * **Anything else** — stays off, unless the build was compiled with
///   `--dart-define=SABUFLIX_TV=on` or the user turned TV mode on by hand.
///
/// The manual override matters more than it looks: it is what lets the app be
/// usable on the TVs nobody can test against — a set-top box, a projector
/// stick, a TV browser with an unknown user agent — without shipping a new
/// build.
class TvPlatform {
  TvPlatform._();

  static const MethodChannel _channel = MethodChannel('sabuflix/tv');

  /// Compile-time switch: `flutter build ... --dart-define=SABUFLIX_TV=on`.
  /// Accepts `on`, `off` and `auto` (the default).
  static const String _compileTimeMode = String.fromEnvironment('SABUFLIX_TV', defaultValue: 'auto');

  static const String _prefsKey = 'sabuflix_tv_mode';

  static TvSystem _system = TvSystem.none;
  static bool _detected = false;
  static TvModeSetting _setting = TvModeSetting.auto;
  static bool _initialized = false;

  /// Bumped whenever the effective mode changes, so the widget tree can
  /// rebuild into (or out of) the TV interface without a restart.
  static final ValueNotifier<bool> modeChanged = ValueNotifier<bool>(false);

  /// The detected platform, regardless of the user's override.
  static TvSystem get system => _system;

  static TvModeSetting get setting => _setting;

  /// True when the TV detection fired on its own, before any override.
  static bool get detectedTv => _detected;

  /// The answer the whole UI keys off.
  static bool get isTv {
    switch (_setting) {
      case TvModeSetting.on:
        return true;
      case TvModeSetting.off:
        return false;
      case TvModeSetting.auto:
        return _detected;
    }
  }

  /// Offline downloads need a real filesystem, which the browser-based TVs
  /// (Tizen, webOS) do not give us.
  static bool get supportsDownloads => !kIsWeb;

  /// Human-readable platform name, shown in the TV settings panel.
  static String get systemLabel {
    switch (_system) {
      case TvSystem.androidTv:
        return 'Android TV / Google TV';
      case TvSystem.tizen:
        return 'Samsung Tizen';
      case TvSystem.webOs:
        return 'LG webOS';
      case TvSystem.otherTv:
        return 'Smart TV';
      case TvSystem.none:
        return kIsWeb ? 'Navegador' : defaultTargetPlatform.name;
    }
  }

  /// Runs the detection once, at startup, before the first frame.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _system = await _detectSystem();
    _detected = _system != TvSystem.none;

    switch (_compileTimeMode.toLowerCase()) {
      case 'on':
      case 'true':
      case '1':
        _setting = TvModeSetting.on;
        break;
      case 'off':
      case 'false':
      case '0':
        _setting = TvModeSetting.off;
        break;
      default:
        _setting = await _readStoredSetting();
    }
  }

  /// Switches the interface by hand, and remembers the choice.
  static Future<void> setMode(TvModeSetting mode) async {
    if (_setting == mode) return;
    _setting = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (e) {
      debugPrint('Could not persist TV mode: $e');
    }
    modeChanged.value = !modeChanged.value;
  }

  static Future<TvModeSetting> _readStoredSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      for (final mode in TvModeSetting.values) {
        if (mode.name == stored) return mode;
      }
    } catch (e) {
      debugPrint('Could not read TV mode: $e');
    }
    return TvModeSetting.auto;
  }

  static Future<TvSystem> _detectSystem() async {
    if (kIsWeb) return _detectWebSystem();

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final isTelevision = await _channel.invokeMethod<bool>('isTelevision');
        if (isTelevision == true) return TvSystem.androidTv;
      } on MissingPluginException {
        // Older build of the host app: fall through to "not a TV".
      } catch (e) {
        debugPrint('Could not query Android TV mode: $e');
      }
    }

    return TvSystem.none;
  }

  static TvSystem _detectWebSystem() {
    if (detect.hasTizenRuntime()) return TvSystem.tizen;
    if (detect.hasWebOsRuntime()) return TvSystem.webOs;

    final agent = detect.webUserAgent().toLowerCase();
    if (agent.isEmpty) return TvSystem.none;

    if (agent.contains('tizen')) return TvSystem.tizen;
    if (agent.contains('web0s') || agent.contains('webos') || agent.contains('netcast')) {
      return TvSystem.webOs;
    }

    const tvMarkers = [
      'smart-tv',
      'smarttv',
      'smart tv',
      'googletv',
      'android tv',
      'androidtv',
      'crkey', // Chromecast
      'hbbtv',
      'vidaa',
      'hisense',
      'philipstv',
      'nettv',
      'bravia',
      'viera',
      'aquos',
      'roku',
      'appletv',
      'aftb', // Fire TV
      'dtv',
      'largescreen',
    ];
    for (final marker in tvMarkers) {
      if (agent.contains(marker)) return TvSystem.otherTv;
    }

    return TvSystem.none;
  }

  /// Keeps the panel awake while a video plays (Android only — the TV browsers
  /// handle this themselves for a playing `<video>`).
  static Future<void> setKeepScreenOn(bool enabled) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setKeepScreenOn', {'enabled': enabled});
    } on MissingPluginException {
      // Nothing to do — the screen will follow the system timeout.
    } catch (e) {
      debugPrint('Could not toggle keep-screen-on: $e');
    }
  }
}
