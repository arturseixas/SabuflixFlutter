import 'package:flutter/material.dart';
import '../theme/sabuflix_theme.dart';

/// Where the bytes being played are coming from.
///
/// Used to tag the player (and any surface that offers playback) so the
/// user always knows whether a title is streaming over the network or
/// running from a file already on the device.
enum PlaybackSource { stream, download }

extension PlaybackSourceInfo on PlaybackSource {
  String get label => this == PlaybackSource.download ? 'Download' : 'Streaming';

  String get description => this == PlaybackSource.download
      ? 'Reproduzindo do arquivo baixado neste dispositivo'
      : 'Reproduzindo direto da fonte online';

  IconData get icon => this == PlaybackSource.download
      ? Icons.download_done_rounded
      : Icons.cloud_outlined;

  Color get color =>
      this == PlaybackSource.download ? SabuflixTheme.success : SabuflixTheme.accent;

  /// Infers the source from a media URL: anything that is not an http(s)
  /// address is treated as a local file.
  static PlaybackSource fromUrl(String? url) {
    if (url == null || url.isEmpty) return PlaybackSource.stream;
    final lower = url.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return PlaybackSource.stream;
    }
    return PlaybackSource.download;
  }
}
