/// Browser probes used by [TvPlatform], for every target that is *not* the web.
///
/// The real implementation lives in `tv_detect_web.dart` and is swapped in by
/// the conditional import in `tv_platform.dart`.
String webUserAgent() => '';

bool hasTizenRuntime() => false;

bool hasWebOsRuntime() => false;

/// Screen width in CSS pixels. Zero means "unknown", which the detector reads
/// as "no opinion" instead of "small screen".
double webScreenWidth() => 0;
