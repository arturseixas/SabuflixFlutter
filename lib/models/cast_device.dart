/// The two ways a television can be told to play something over the network.
enum CastProtocol {
  /// Google Cast — Chromecast, Google TV, and the TVs with Chromecast built in
  /// (most Sony, Philips and TCL sets).
  googleCast,

  /// DLNA / UPnP AVTransport — what Samsung, LG, Sony, Philips, Panasonic and
  /// nearly every other smart TV of the last decade speaks natively.
  dlna,
}

/// A television (or dongle) found on the local network.
class CastDevice {
  /// Stable identity, used to keep the list from showing duplicates as the
  /// discovery sockets answer more than once.
  final String id;

  final String name;
  final String host;
  final int port;
  final CastProtocol protocol;

  /// DLNA only: absolute URL of the AVTransport control endpoint.
  final String? controlUrl;

  /// Model line reported by the device, shown under the name to tell two
  /// televisions in the same house apart.
  final String? model;

  const CastDevice({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.protocol,
    this.controlUrl,
    this.model,
  });

  String get protocolLabel => protocol == CastProtocol.googleCast ? 'Google Cast' : 'DLNA';

  @override
  bool operator ==(Object other) => other is CastDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CastDevice($name, $host:$port, ${protocol.name})';
}

/// What the television reports back while it is playing.
class CastStatus {
  final bool isPlaying;
  final Duration position;
  final Duration duration;

  const CastStatus({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  CastStatus copyWith({bool? isPlaying, Duration? position, Duration? duration}) {
    return CastStatus(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }

  double get progress {
    if (duration.inSeconds <= 0) return 0;
    return (position.inSeconds / duration.inSeconds).clamp(0.0, 1.0);
  }
}

/// What a sender has to be able to do, whichever protocol it speaks.
abstract class CastSession {
  CastDevice get device;

  /// Starts playback of [url] on the device.
  Future<void> load({
    required String url,
    required String title,
    String? subtitle,
    String? imageUrl,
    Duration startAt = Duration.zero,
  });

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> stop();

  /// Reads the current transport state from the device.
  Future<CastStatus> status();

  /// Closes the connection, leaving whatever is on screen playing.
  Future<void> dispose();
}
