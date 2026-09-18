import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'cast_device.dart';

/// Finds DLNA / UPnP media renderers with SSDP (Simple Service Discovery
/// Protocol): an `M-SEARCH` is multicast to the network, every renderer
/// answers with the URL of its description document, and that document tells
/// us where to send playback commands.
///
/// Replies come back unicast to the port we sent from, so no multicast lock
/// is needed on Android.
class SsdpDiscovery {
  SsdpDiscovery({http.Client? client}) : _client = client;

  final http.Client? _client;

  static final InternetAddress multicastAddress =
      InternetAddress('239.255.255.250');
  static const int multicastPort = 1900;

  static const List<String> searchTargets = [
    'urn:schemas-upnp-org:device:MediaRenderer:1',
    'urn:schemas-upnp-org:service:AVTransport:1',
    'ssdp:all',
  ];

  static const String avTransportType =
      'urn:schemas-upnp-org:service:AVTransport';
  static const String renderingControlType =
      'urn:schemas-upnp-org:service:RenderingControl';

  /// Streams renderers as they answer, for [timeout], deduplicated by UDN.
  Stream<CastDevice> discover({Duration timeout = const Duration(seconds: 4)}) {
    final controller = StreamController<CastDevice>();
    unawaited(_run(controller, timeout));
    return controller.stream;
  }

  Future<void> _run(
      StreamController<CastDevice> controller, Duration timeout) async {
    RawDatagramSocket? socket;
    final seenLocations = <String>{};
    final seenIds = <String>{};
    final pending = <Future<void>>[];
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0,
          reuseAddress: true);
      socket.broadcastEnabled = true;
      try {
        socket.multicastHops = 4;
      } catch (_) {
        // Not every platform lets us tune the TTL; the default reaches the LAN.
      }

      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket?.receive();
        if (datagram == null) return;
        final location =
            parseLocation(utf8.decode(datagram.data, allowMalformed: true));
        if (location == null || !seenLocations.add(location)) return;
        pending.add(_describe(location, datagram.address).then((device) {
          if (device == null || controller.isClosed) return;
          if (seenIds.add(device.id)) controller.add(device);
        }));
      });

      // Send each search target a couple of times: UDP on Wi-Fi drops packets
      // and some TVs only answer the second request.
      for (var round = 0; round < 2; round++) {
        for (final target in searchTargets) {
          final message = buildSearchMessage(target);
          socket.send(utf8.encode(message), multicastAddress, multicastPort);
        }
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
      await Future<void>.delayed(timeout);
      await Future.wait(pending);
    } catch (error) {
      debugPrint('SSDP discovery unavailable: $error');
    } finally {
      socket?.close();
      await controller.close();
    }
  }

  static String buildSearchMessage(String searchTarget, {int mx = 2}) {
    return 'M-SEARCH * HTTP/1.1\r\n'
        'HOST: 239.255.255.250:1900\r\n'
        'MAN: "ssdp:discover"\r\n'
        'MX: $mx\r\n'
        'ST: $searchTarget\r\n'
        'USER-AGENT: Sabuflix/1.0 UPnP/1.1\r\n'
        '\r\n';
  }

  /// `LOCATION` header of an SSDP reply, or `null` for anything else (NOTIFY
  /// chatter, malformed packets, replies without a description URL).
  static String? parseLocation(String response) {
    final lines = response.split(RegExp(r'\r?\n'));
    if (lines.isEmpty ||
        !lines.first.toUpperCase().startsWith('HTTP/1.1 200')) {
      return null;
    }
    for (final line in lines.skip(1)) {
      final colon = line.indexOf(':');
      if (colon <= 0) continue;
      final name = line.substring(0, colon).trim().toLowerCase();
      if (name != 'location') continue;
      final value = line.substring(colon + 1).trim();
      final uri = Uri.tryParse(value);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        return value;
      }
    }
    return null;
  }

  Future<CastDevice?> _describe(String location, InternetAddress from) async {
    try {
      final uri = Uri.parse(location);
      final response = await (_client?.get(uri) ?? http.get(uri))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      return parseDescription(body, uri, fallbackHost: from.address);
    } catch (error) {
      debugPrint('Ignoring unreadable UPnP description at $location: $error');
      return null;
    }
  }

  /// Turns a UPnP device description document into a [CastDevice], or `null`
  /// when the device cannot play video (no AVTransport service).
  static CastDevice? parseDescription(String xml, Uri location,
      {String? fallbackHost}) {
    final base = _tag(xml, 'URLBase');
    final baseUri = (base != null && base.isNotEmpty)
        ? (Uri.tryParse(base) ?? location)
        : location;

    Uri? avTransport;
    Uri? renderingControl;
    for (final match
        in RegExp(r'<service>(.*?)</service>', dotAll: true).allMatches(xml)) {
      final block = match.group(1)!;
      final type = _tag(block, 'serviceType') ?? '';
      final control = _tag(block, 'controlURL');
      if (control == null || control.isEmpty) continue;
      final resolved = baseUri.resolve(control.trim());
      if (type.startsWith(avTransportType)) {
        avTransport ??= resolved;
      } else if (type.startsWith(renderingControlType)) {
        renderingControl ??= resolved;
      }
    }
    if (avTransport == null) return null;

    final udn = _tag(xml, 'UDN') ?? 'uuid:${location.host}:${location.port}';
    final name = _unescape(_tag(xml, 'friendlyName') ?? '').trim();
    final manufacturer = _unescape(_tag(xml, 'manufacturer') ?? '').trim();
    final model = _unescape(_tag(xml, 'modelName') ?? '').trim();
    final host =
        location.host.isNotEmpty ? location.host : (fallbackHost ?? '');

    return CastDevice(
      id: 'dlna:${udn.trim()}',
      name: name.isNotEmpty ? name : (model.isNotEmpty ? model : 'Smart TV'),
      host: host,
      port: location.hasPort ? location.port : 80,
      protocol: CastProtocol.dlna,
      manufacturer: manufacturer.isEmpty ? null : manufacturer,
      model: model.isEmpty ? null : model,
      avTransportUrl: avTransport,
      renderingControlUrl: renderingControl,
    );
  }

  static String? _tag(String xml, String name) {
    final match = RegExp(
            '<(?:[a-zA-Z0-9]+:)?$name(?:\\s[^>]*)?>(.*?)</(?:[a-zA-Z0-9]+:)?$name>',
            dotAll: true)
        .firstMatch(xml);
    return match?.group(1);
  }

  static String _unescape(String value) => value
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#39;', "'");
}
