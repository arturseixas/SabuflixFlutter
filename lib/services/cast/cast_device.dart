/// Which protocol a discovered TV or dongle speaks.
enum CastProtocol {
  /// DLNA / UPnP AVTransport renderer: Samsung, LG, Sony, Philips, TCL,
  /// Hisense, Roku (some models), Xbox, Kodi, VLC and most smart TVs.
  dlna,

  /// Google Cast v2: Chromecast, Google TV, Android TV with built-in Cast,
  /// Nest Hub and TVs from Sony, Philips, TCL, Vizio and others.
  chromecast,
}

/// A device on the local network that can play a video URL on our behalf.
class CastDevice {
  /// Stable identity used to de-duplicate discovery rounds: the UPnP UDN for
  /// DLNA renderers and the mDNS `id` TXT record for Cast devices.
  final String id;
  final String name;
  final String host;
  final int port;
  final CastProtocol protocol;
  final String? manufacturer;
  final String? model;

  /// DLNA only: absolute control endpoints resolved from the device
  /// description document.
  final Uri? avTransportUrl;
  final Uri? renderingControlUrl;

  /// True when typed in by the viewer instead of discovered, so the picker
  /// can offer to forget it.
  final bool manual;

  const CastDevice({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.protocol,
    this.manufacturer,
    this.model,
    this.avTransportUrl,
    this.renderingControlUrl,
    this.manual = false,
  });

  bool get isDlna => protocol == CastProtocol.dlna;
  bool get isChromecast => protocol == CastProtocol.chromecast;

  String get protocolLabel => isChromecast ? 'Google Cast' : 'DLNA / Smart TV';

  /// `Samsung · UE55` style detail line, falling back to the protocol.
  String get detailLabel {
    final parts = <String>[
      if (manufacturer != null && manufacturer!.trim().isNotEmpty)
        manufacturer!.trim(),
      if (model != null &&
          model!.trim().isNotEmpty &&
          !(manufacturer ?? '').toLowerCase().contains(model!.toLowerCase()))
        model!.trim(),
    ];
    if (parts.isEmpty) return protocolLabel;
    return '${parts.join(' ')} · $protocolLabel';
  }

  CastDevice copyWith({
    String? name,
    String? host,
    int? port,
    String? manufacturer,
    String? model,
    Uri? avTransportUrl,
    Uri? renderingControlUrl,
    bool? manual,
  }) {
    return CastDevice(
      id: id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      protocol: protocol,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      avTransportUrl: avTransportUrl ?? this.avTransportUrl,
      renderingControlUrl: renderingControlUrl ?? this.renderingControlUrl,
      manual: manual ?? this.manual,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'protocol': protocol.name,
        'manufacturer': manufacturer,
        'model': model,
        'avTransportUrl': avTransportUrl?.toString(),
        'renderingControlUrl': renderingControlUrl?.toString(),
        'manual': manual,
      };

  factory CastDevice.fromJson(Map<String, dynamic> json) {
    final protocol = CastProtocol.values.firstWhere(
      (value) => value.name == json['protocol'],
      orElse: () => CastProtocol.dlna,
    );
    Uri? uri(Object? raw) => raw == null ? null : Uri.tryParse(raw.toString());
    return CastDevice(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'TV',
      host: json['host']?.toString() ?? '',
      port: (json['port'] as num?)?.toInt() ??
          (protocol == CastProtocol.chromecast ? 8009 : 80),
      protocol: protocol,
      manufacturer: json['manufacturer']?.toString(),
      model: json['model']?.toString(),
      avTransportUrl: uri(json['avTransportUrl']),
      renderingControlUrl: uri(json['renderingControlUrl']),
      manual: json['manual'] == true,
    );
  }

  @override
  bool operator ==(Object other) => other is CastDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CastDevice($name, $protocol, $host:$port)';
}

/// What the remote player is doing right now.
enum CastPlayerState { idle, buffering, playing, paused, stopped }

/// Snapshot of the remote playback, refreshed by polling or by push events.
class CastPlaybackStatus {
  final CastPlayerState state;
  final Duration position;
  final Duration duration;

  /// 0.0 – 1.0
  final double volume;
  final bool muted;

  const CastPlaybackStatus({
    this.state = CastPlayerState.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.muted = false,
  });

  bool get isPlaying => state == CastPlayerState.playing;
  bool get isActive =>
      state == CastPlayerState.playing ||
      state == CastPlayerState.paused ||
      state == CastPlayerState.buffering;

  double get progress {
    if (duration.inMilliseconds <= 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  CastPlaybackStatus copyWith({
    CastPlayerState? state,
    Duration? position,
    Duration? duration,
    double? volume,
    bool? muted,
  }) {
    return CastPlaybackStatus(
      state: state ?? this.state,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      muted: muted ?? this.muted,
    );
  }
}

/// Everything the receiver needs to show and play one title.
class CastMediaRequest {
  final String url;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final Duration startAt;

  /// Optional external subtitle in WebVTT, only honoured by Google Cast.
  final String? subtitleUrl;
  final String? subtitleLanguage;

  const CastMediaRequest({
    required this.url,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.startAt = Duration.zero,
    this.subtitleUrl,
    this.subtitleLanguage,
  });

  /// Best-effort MIME type from the URL, which both protocols use to pick a
  /// decoder before the first byte arrives.
  String get contentType => contentTypeFor(url);

  static String contentTypeFor(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    if (path.endsWith('.m3u8')) return 'application/x-mpegURL';
    if (path.endsWith('.mpd')) return 'application/dash+xml';
    if (path.endsWith('.mkv')) return 'video/x-matroska';
    if (path.endsWith('.webm')) return 'video/webm';
    if (path.endsWith('.avi')) return 'video/x-msvideo';
    if (path.endsWith('.mov')) return 'video/quicktime';
    if (path.endsWith('.ts')) return 'video/mp2t';
    if (path.endsWith('.mp3')) return 'audio/mpeg';
    return 'video/mp4';
  }
}

/// Raised when a device rejects a command or the connection breaks.
class CastException implements Exception {
  final String message;
  const CastException(this.message);
  @override
  String toString() => message;
}
