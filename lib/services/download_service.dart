/// Offline downloads, picked per platform at compile time.
///
/// Android, Windows, macOS, Linux and iOS get the real transfer service, which
/// streams a file into the app's private storage with byte-range resume.
///
/// The Samsung Tizen and LG webOS builds run as web apps, where there is no
/// filesystem to stream into and no `dart:io` to do it with — importing the
/// real one there would not even compile. They get the stub instead, which
/// keeps the same API and reports that the feature is unavailable; the UI
/// hides the Downloads section on those platforms anyway (see
/// `TvPlatform.supportsDownloads`).
export 'download_service_io.dart' if (dart.library.js_interop) 'download_service_web.dart';
