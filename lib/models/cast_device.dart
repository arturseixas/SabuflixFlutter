enum CastProtocol { dlna, chromecast }

/// A TV (or other renderer) discovered on the local network, reachable via
/// either DLNA/UPnP or Google Cast.
class CastDevice {
  final String id;
  final String name;
  final CastProtocol protocol;
  final String host;
  final int port;

  /// DLNA only: absolute URL of the AVTransport SOAP control endpoint.
  final String? controlUrl;

  CastDevice({
    required this.id,
    required this.name,
    required this.protocol,
    required this.host,
    required this.port,
    this.controlUrl,
  });

  String get subtitle => protocol == CastProtocol.chromecast ? 'Chromecast' : 'DLNA / UPnP';
}
