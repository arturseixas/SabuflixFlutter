import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'cast_device.dart';
import 'mdns_discovery.dart';
import 'ssdp_discovery.dart';

/// Runs every discovery protocol at once and merges the results.
class CastDiscovery {
  CastDiscovery({SsdpDiscovery? ssdp, MdnsDiscovery? mdns})
      : _ssdp = ssdp ?? SsdpDiscovery(),
        _mdns = mdns ?? MdnsDiscovery();

  final SsdpDiscovery _ssdp;
  final MdnsDiscovery _mdns;

  /// Casting needs raw sockets, which browsers do not expose to Dart.
  static bool get isSupported => !kIsWeb;

  Stream<CastDevice> discover({Duration timeout = const Duration(seconds: 4)}) {
    if (!isSupported) return const Stream.empty();
    final controller = StreamController<CastDevice>();
    final seen = <String>{};
    var open = 2;
    void done() {
      open--;
      if (open == 0 && !controller.isClosed) controller.close();
    }

    for (final source in [
      _ssdp.discover(timeout: timeout),
      _mdns.discover(timeout: timeout),
    ]) {
      source.listen(
        (device) {
          if (!controller.isClosed && seen.add(device.id)) {
            controller.add(device);
          }
        },
        onError: (Object error) => debugPrint('Discovery error: $error'),
        onDone: done,
      );
    }
    return controller.stream;
  }

  /// Resolves a TV the viewer typed in by IP. Tries Google Cast (port 8009)
  /// and the description URLs the common TV brands publish, in parallel.
  static Future<CastDevice?> probe(String host, {http.Client? client}) async {
    if (!isSupported) return null;
    final trimmed = host.trim();
    if (trimmed.isEmpty) return null;
    final results = await Future.wait([
      _probeChromecast(trimmed),
      _probeDlna(trimmed, client: client),
    ]);
    for (final device in results) {
      if (device != null) return device;
    }
    return null;
  }

  static Future<CastDevice?> _probeChromecast(String host) async {
    try {
      // Only a TLS handshake: enough to know a Cast receiver is listening.
      final socket = await SecureSocket.connect(host, 8009,
          onBadCertificate: (_) => true, timeout: const Duration(seconds: 3));
      socket.destroy();
      return CastDevice(
        id: 'cast:manual:$host',
        name: 'Google Cast ($host)',
        host: host,
        port: 8009,
        protocol: CastProtocol.chromecast,
        manufacturer: 'Google Cast',
        manual: true,
      );
    } catch (_) {
      return null;
    }
  }

  /// Description document URLs published by the popular brands.
  static const List<String> dlnaDescriptionPaths = [
    'http://{host}:9197/dmr', // Samsung
    'http://{host}:52235/dmr/SamsungMRDesc.xml', // Samsung (older)
    'http://{host}:1925/DeviceDescription.xml', // Philips
    'http://{host}:1400/xml/device_description.xml', // Sonos
    'http://{host}:49152/description.xml', // LG, Sony, TCL, Hisense
    'http://{host}:49153/description.xml',
    'http://{host}:2870/dmr.xml', // Panasonic
    'http://{host}:8080/description.xml',
    'http://{host}:1900/description.xml',
    'http://{host}:49494/description.xml',
  ];

  static Future<CastDevice?> _probeDlna(String host,
      {http.Client? client}) async {
    final attempts = dlnaDescriptionPaths.map((template) async {
      final uri = Uri.parse(template.replaceAll('{host}', host));
      try {
        final response = await (client?.get(uri) ?? http.get(uri))
            .timeout(const Duration(seconds: 3));
        if (response.statusCode != 200) return null;
        final device = SsdpDiscovery.parseDescription(
            utf8.decode(response.bodyBytes, allowMalformed: true), uri,
            fallbackHost: host);
        return device?.copyWith(manual: true);
      } catch (_) {
        return null;
      }
    });
    for (final device in await Future.wait(attempts)) {
      if (device != null) return device;
    }
    return null;
  }
}
