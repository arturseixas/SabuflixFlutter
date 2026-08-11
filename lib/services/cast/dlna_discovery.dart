import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../../models/cast_device.dart';

const _ssdpAddress = '239.255.255.250';
const _ssdpPort = 1900;
const _avTransportPrefix = 'urn:schemas-upnp-org:service:AVTransport:';

/// Finds DLNA/UPnP media renderers — the built-in "cast"/"Smart View" every
/// major smart TV brand (LG, Samsung, Sony, Panasonic, Philips…) ships,
/// regardless of whether it also speaks Chromecast.
///
/// SSDP replies to a discovery search arrive as unicast UDP back to the
/// socket that sent it, so this needs no multicast group membership to
/// *receive* — only to send the initial M-SEARCH — which keeps it reliable
/// on platforms (notably Android) that throttle multicast reception.
Stream<CastDevice> discoverDlnaDevices({
  Duration timeout = const Duration(seconds: 5),
}) {
  final controller = StreamController<CastDevice>();
  final seenLocations = <String>{};
  RawDatagramSocket? socket;
  Timer? closeTimer;

  Future<void> run() async {
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    } catch (_) {
      await controller.close();
      return;
    }

    final search = utf8.encode(
      'M-SEARCH * HTTP/1.1\r\n'
      'HOST: $_ssdpAddress:$_ssdpPort\r\n'
      'MAN: "ssdp:discover"\r\n'
      'MX: 2\r\n'
      'ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n'
      '\r\n',
    );

    socket!.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket!.receive();
      if (datagram == null) return;
      final response = utf8.decode(datagram.data, allowMalformed: true);
      final location = _extractHeader(response, 'LOCATION');
      if (location == null || !seenLocations.add(location)) return;

      _describeDlnaDevice(location).then((device) {
        if (device != null && !controller.isClosed) controller.add(device);
      }).catchError((_) {});
    });

    final target = InternetAddress(_ssdpAddress);
    // A couple of bursts, since SSDP is UDP and routers occasionally drop
    // the first packet of a multicast burst.
    socket!.send(search, target, _ssdpPort);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!controller.isClosed) socket!.send(search, target, _ssdpPort);
  }

  run();
  closeTimer = Timer(timeout, () {
    socket?.close();
    if (!controller.isClosed) controller.close();
  });
  controller.onCancel = () {
    closeTimer?.cancel();
    socket?.close();
  };

  return controller.stream;
}

String? _extractHeader(String rawResponse, String header) {
  final lines = rawResponse.split('\r\n');
  final needle = '${header.toLowerCase()}:';
  for (final line in lines) {
    if (line.toLowerCase().startsWith(needle)) {
      return line.substring(line.indexOf(':') + 1).trim();
    }
  }
  return null;
}

Future<CastDevice?> _describeDlnaDevice(String location) async {
  final response = await http.get(Uri.parse(location)).timeout(const Duration(seconds: 4));
  if (response.statusCode != 200) return null;

  final doc = XmlDocument.parse(response.body);
  final device = _firstOrNull(doc.findAllElements('device'));
  if (device == null) return null;

  final friendlyName = _firstOrNull(device.findElements('friendlyName'))?.innerText.trim();
  final udn = _firstOrNull(device.findElements('UDN'))?.innerText.trim();

  String? controlUrl;
  String? serviceType;
  for (final service in device.findAllElements('service')) {
    final type = _firstOrNull(service.findElements('serviceType'))?.innerText.trim() ?? '';
    if (type.startsWith(_avTransportPrefix)) {
      controlUrl = _firstOrNull(service.findElements('controlURL'))?.innerText.trim();
      serviceType = type;
      break;
    }
  }
  if (controlUrl == null || controlUrl.isEmpty) return null;

  final locationUri = Uri.parse(location);
  final urlBaseText = _firstOrNull(doc.rootElement.findElements('URLBase'))?.innerText.trim();
  final baseUri = (urlBaseText != null && urlBaseText.isNotEmpty) ? Uri.parse(urlBaseText) : locationUri;
  final resolvedControlUrl = baseUri.resolveUri(Uri.parse(controlUrl)).toString();

  return CastDevice(
    id: 'dlna-${udn ?? location}',
    name: (friendlyName == null || friendlyName.isEmpty) ? locationUri.host : friendlyName,
    protocol: CastProtocol.dlna,
    host: locationUri.host,
    port: locationUri.hasPort ? locationUri.port : 80,
    dlnaControlUrl: resolvedControlUrl,
    dlnaServiceType: serviceType,
  );
}

XmlElement? _firstOrNull(Iterable<XmlElement> elements) => elements.isEmpty ? null : elements.first;
