/// Transport used to reach a discovered TV/receiver.
enum CastProtocol {
  /// Google Cast (CASTV2 over TLS) — Chromecast, Android TV, Google TV, and
  /// any "Chromecast built-in" smart TV (many Sony, TCL, Hisense models).
  chromecast,

  /// DLNA/UPnP AVTransport over HTTP+SOAP — the built-in screen/media
  /// casting most smart TVs ship regardless of brand (LG "Cast", Samsung
  /// "Smart View", Sony, Panasonic, Philips…).
  dlna,
}

/// A single receiver found on the local network, ready to be cast to.
class CastDevice {
  final String id;
  final String name;
  final CastProtocol protocol;
  final String host;
  final int port;

  /// DLNA only: absolute control URL for the AVTransport service, resolved
  /// from the device description XML at discovery time.
  final String? dlnaControlUrl;

  /// DLNA only: the eventing service namespace URN advertised by the
  /// device, kept because a few renderers use a vendor-specific version.
  final String? dlnaServiceType;

  const CastDevice({
    required this.id,
    required this.name,
    required this.protocol,
    required this.host,
    required this.port,
    this.dlnaControlUrl,
    this.dlnaServiceType,
  });

  @override
  bool operator ==(Object other) => other is CastDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
