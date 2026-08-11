import 'dart:js_interop';

/// Browser probes used by [TvPlatform] on the web target.
///
/// Smart TVs are identified the same way every TV web app does it: the user
/// agent string, plus the JS runtime object the platform injects into the page
/// (`window.tizen` on Samsung, `window.webOS` on LG). The runtime object is the
/// stronger signal — it only exists inside a packaged TV app — so the detector
/// checks it first and falls back to the user agent for the long tail of
/// browser-based TVs (Vidaa, Foxxum, Zeasn, HbbTV sets and so on).
@JS('navigator.userAgent')
external String? get _navigatorUserAgent;

@JS('window.tizen')
external JSAny? get _tizenRuntime;

@JS('window.webOS')
external JSAny? get _webOsRuntime;

@JS('window.webOSSystem')
external JSAny? get _webOsSystem;

@JS('window.screen.width')
external num? get _screenWidth;

String webUserAgent() => _navigatorUserAgent ?? '';

bool hasTizenRuntime() => _tizenRuntime != null;

bool hasWebOsRuntime() => _webOsRuntime != null || _webOsSystem != null;

double webScreenWidth() => _screenWidth?.toDouble() ?? 0;
