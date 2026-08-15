/// Small pt-BR formatting helpers shared by the downloads and
/// continue-watching surfaces.

/// `1536000` -> `1,5 MB`. Uses a comma as the decimal separator.
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 MB';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var unit = 0;
  var value = bytes.toDouble();
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = (unit <= 1 || value >= 100)
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '${text.replaceAll('.', ',')} ${units[unit]}';
}

/// `5400` -> `1h 30min`.
String formatMinutes(int seconds) {
  if (seconds <= 0) return '0 min';
  final totalMinutes = (seconds / 60).round();
  if (totalMinutes < 60) return '$totalMinutes min';
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}min';
}

/// Label for the time left on a partially watched title.
String formatRemaining(int remainingSeconds) {
  if (remainingSeconds <= 60) return 'Quase no fim';
  return '${formatMinutes(remainingSeconds)} restantes';
}

/// `T2 E5` — the compact season/episode tag used across the app.
String formatEpisodeTag(int? season, int? episode) {
  if (season == null || episode == null) return '';
  return 'T$season E$episode';
}
