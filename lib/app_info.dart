/// Single source of truth for the version shown in the UI. Keep in sync with
/// `pubspec.yaml` and `windows/installer.iss`.
class AppInfo {
  AppInfo._();

  static const String name = 'Sabuflix';
  static const String version = '1.5.0';
  static const String copyright = '© 2026 Sabuflix';
}
