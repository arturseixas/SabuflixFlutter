/// The wire protocol used to talk to a TV.
enum CastProtocol {
  /// UPnP/DLNA AVTransport — Samsung, LG, Sony, Philips, Xbox, most
  /// "smart TV" boxes and AV receivers.
  dlna,

  /// Roku External Control Protocol.
  roku,

  /// Google Cast v2 — Chromecast, Google TV, Nest Hub, Android TV with
  /// built-in Cast.
  googleCast,
}

extension CastProtocolLabel on CastProtocol {
  String get label {
    switch (this) {
      case CastProtocol.dlna:
        return 'DLNA';
      case CastProtocol.roku:
        return 'Roku';
      case CastProtocol.googleCast:
        return 'Google Cast';
    }
  }
}

/// A playback target found on the local network.
class CastDevice {
  /// Stable identity for the device (UUID/USN, serial number or mDNS name),
  /// used to de-duplicate answers arriving from several discovery passes.
  final String id;
  final String name;
  final String host;
  final int port;
  final CastProtocol protocol;

  /// DLNA only: absolute URL of the AVTransport control endpoint.
  final String? controlUrl;

  /// Manufacturer/model string when the device advertises one.
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

  String get subtitle {
    final parts = <String>[protocol.label];
    if (model != null && model!.isNotEmpty) parts.add(model!);
    parts.add(host);
    return parts.join(' · ');
  }

  @override
  bool operator ==(Object other) => other is CastDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
