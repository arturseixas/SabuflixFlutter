/// Snapshot of what a connected receiver (Chromecast or DLNA renderer) is
/// currently doing, normalized to a single shape both backends emit.
class CastPlaybackStatus {
  final bool connected;
  final bool playing;
  final bool buffering;
  final Duration position;
  final Duration duration;

  const CastPlaybackStatus({
    required this.connected,
    required this.playing,
    required this.buffering,
    required this.position,
    required this.duration,
  });

  const CastPlaybackStatus.disconnected()
      : connected = false,
        playing = false,
        buffering = false,
        position = Duration.zero,
        duration = Duration.zero;
}

/// Best-effort content type from the file extension — both Chromecast and
/// DLNA renderers use this to pick a decoder/pipeline before they've
/// downloaded a single byte of the stream.
String guessMediaContentType(String url) {
  final path = (Uri.tryParse(url)?.path ?? url).toLowerCase();
  if (path.endsWith('.m3u8')) return 'application/x-mpegURL';
  if (path.endsWith('.mpd')) return 'application/dash+xml';
  if (path.endsWith('.webm')) return 'video/webm';
  if (path.endsWith('.mkv')) return 'video/x-matroska';
  if (path.endsWith('.mov')) return 'video/quicktime';
  if (path.endsWith('.avi')) return 'video/x-msvideo';
  return 'video/mp4';
}
