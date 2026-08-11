import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../../models/cast_device.dart';

/// DLNA / UPnP sender.
///
/// This is the protocol with the widest reach on televisions: Samsung, LG,
/// Sony, Philips, Panasonic and practically every set sold in the last decade
/// ships a UPnP "MediaRenderer", and it needs nothing installed on the TV. The
/// phone finds the renderer over SSDP, hands it a URL, and the television
/// fetches and plays the video itself — so the quality is whatever the TV can
/// pull, not whatever the phone can re-encode.
class DlnaClient {
  DlnaClient._();

  static const String _ssdpAddress = '239.255.255.250';
  static const int _ssdpPort = 1900;

  static const String avTransport = 'urn:schemas-upnp-org:service:AVTransport:1';
  static const String renderingControl = 'urn:schemas-upnp-org:service:RenderingControl:1';

  /// Searches the local network for renderers.
  ///
  /// SSDP is fire-and-forget over UDP multicast: the search is sent several
  /// times because a single datagram is routinely dropped by home Wi-Fi, and
  /// answers trickle in for as long as [timeout].
  static Stream<CastDevice> discover({
    Duration timeout = const Duration(seconds: 5),
  }) {
    final controller = StreamController<CastDevice>();
    final seenLocations = <String>{};

    Future<void> run() async {
      RawDatagramSocket? socket;
      try {
        socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        socket.broadcastEnabled = true;
        socket.multicastHops = 4;
      } catch (e) {
        debugPrint('SSDP: could not open the socket: $e');
        await controller.close();
        return;
      }

      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket!.receive();
        if (datagram == null) return;

        final response = utf8.decode(datagram.data, allowMalformed: true);
        final location = headerValue(response, 'location');
        if (location == null || !seenLocations.add(location)) return;

        // The response only carries a URL; the friendly name and the control
        // endpoint live in the description document it points at.
        _describe(location).then((device) {
          if (device != null && !controller.isClosed) controller.add(device);
        });
      });

      final searches = [
        'urn:schemas-upnp-org:device:MediaRenderer:1',
        avTransport,
      ];
      final target = InternetAddress(_ssdpAddress);
      for (var attempt = 0; attempt < 3; attempt++) {
        for (final st in searches) {
          try {
            socket.send(utf8.encode(buildSearchRequest(st)), target, _ssdpPort);
          } catch (e) {
            debugPrint('SSDP: search failed: $e');
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }

      await Future<void>.delayed(timeout);
      socket.close();
      await controller.close();
    }

    controller.onListen = run;
    return controller.stream;
  }

  /// The M-SEARCH datagram. `MX` is the number of seconds a renderer may wait
  /// before answering, which keeps a busy network from answering all at once.
  static String buildSearchRequest(String searchTarget) {
    return 'M-SEARCH * HTTP/1.1\r\n'
        'HOST: $_ssdpAddress:$_ssdpPort\r\n'
        'MAN: "ssdp:discover"\r\n'
        'MX: 2\r\n'
        'ST: $searchTarget\r\n'
        'USER-AGENT: Sabuflix/1.0 UPnP/1.0\r\n'
        '\r\n';
  }

  /// Reads a header out of an SSDP response, which is HTTP-shaped but not HTTP.
  static String? headerValue(String response, String name) {
    final lowerName = name.toLowerCase();
    for (final line in const LineSplitter().convert(response)) {
      final separator = line.indexOf(':');
      if (separator == -1) continue;
      if (line.substring(0, separator).trim().toLowerCase() != lowerName) continue;
      return line.substring(separator + 1).trim();
    }
    return null;
  }

  static Future<CastDevice?> _describe(String location) async {
    try {
      final response = await http
          .get(Uri.parse(location))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return null;
      return parseDeviceDescription(utf8.decode(response.bodyBytes), Uri.parse(location));
    } catch (e) {
      debugPrint('SSDP: could not describe $location: $e');
      return null;
    }
  }

  /// Turns a UPnP device description into a [CastDevice].
  ///
  /// Returns null for anything that cannot play a video — the same SSDP search
  /// also turns up routers, printers and NAS boxes.
  static CastDevice? parseDeviceDescription(String xmlBody, Uri baseUrl) {
    late final XmlDocument document;
    try {
      document = XmlDocument.parse(xmlBody);
    } catch (e) {
      debugPrint('SSDP: malformed description at $baseUrl: $e');
      return null;
    }

    String? textOf(XmlElement parent, String tag) {
      final elements = parent.findAllElements(tag);
      return elements.isEmpty ? null : elements.first.innerText.trim();
    }

    final deviceElements = document.findAllElements('device');
    if (deviceElements.isEmpty) return null;
    final device = deviceElements.first;

    String? controlPath;
    for (final service in document.findAllElements('service')) {
      final type = textOf(service, 'serviceType');
      if (type == null || !type.startsWith('urn:schemas-upnp-org:service:AVTransport:')) {
        continue;
      }
      controlPath = textOf(service, 'controlURL');
      break;
    }
    if (controlPath == null || controlPath.isEmpty) return null;

    // The description may give the control URL as absolute, root-relative or
    // relative to a URLBase the device declares.
    final baseHref = textOf(document.rootElement, 'URLBase');
    final base = (baseHref != null && baseHref.isNotEmpty) ? Uri.parse(baseHref) : baseUrl;
    final controlUrl = base.resolve(controlPath).toString();

    final name = textOf(device, 'friendlyName') ?? baseUrl.host;
    final udn = textOf(device, 'UDN') ?? controlUrl;

    return CastDevice(
      id: 'dlna:$udn',
      name: name,
      host: baseUrl.host,
      port: baseUrl.port,
      protocol: CastProtocol.dlna,
      controlUrl: controlUrl,
      model: textOf(device, 'modelName'),
    );
  }

  /// Wraps an action in the SOAP envelope UPnP expects.
  static String soapEnvelope(String service, String action, String body) {
    return '<?xml version="1.0" encoding="utf-8"?>'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
        's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
        '<s:Body>'
        '<u:$action xmlns:u="$service">'
        '<InstanceID>0</InstanceID>'
        '$body'
        '</u:$action>'
        '</s:Body>'
        '</s:Envelope>';
  }

  /// The item description a renderer wants alongside the URL.
  ///
  /// Without it many televisions play the video but show the file name (or
  /// nothing at all) on screen, and some refuse the stream outright because
  /// they cannot tell what kind of media it is.
  static String buildDidl({
    required String url,
    required String title,
    String? imageUrl,
  }) {
    final didl = StringBuffer()
      ..write('<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" ')
      ..write('xmlns:dc="http://purl.org/dc/elements/1.1/" ')
      ..write('xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" ')
      ..write('xmlns:dlna="urn:schemas-dlna-org:metadata-1-0/">')
      ..write('<item id="sabuflix" parentID="0" restricted="1">')
      ..write('<dc:title>${escapeXml(title)}</dc:title>')
      ..write('<upnp:class>object.item.videoItem</upnp:class>');
    if (imageUrl != null && imageUrl.isNotEmpty) {
      didl.write('<upnp:albumArtURI>${escapeXml(imageUrl)}</upnp:albumArtURI>');
    }
    didl
      ..write('<res protocolInfo="http-get:*:video/mp4:'
          'DLNA.ORG_OP=01;DLNA.ORG_CI=0;DLNA.ORG_FLAGS=01700000000000000000000000000000">')
      ..write(escapeXml(url))
      ..write('</res>')
      ..write('</item></DIDL-Lite>');
    return didl.toString();
  }

  static String escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// UPnP speaks `H:MM:SS`, not seconds.
  static String formatUpnpTime(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  static Duration parseUpnpTime(String? value) {
    if (value == null) return Duration.zero;
    final parts = value.trim().split(':');
    if (parts.length != 3) return Duration.zero;
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    // Some renderers append fractions of a second ("00:12:31.000").
    final seconds = double.tryParse(parts[2])?.floor() ?? 0;
    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }
}

/// A live connection to a DLNA renderer.
class DlnaSession implements CastSession {
  @override
  final CastDevice device;

  final http.Client _client;

  DlnaSession(this.device, {http.Client? client}) : _client = client ?? http.Client();

  String get _controlUrl => device.controlUrl!;

  @override
  Future<void> load({
    required String url,
    required String title,
    String? subtitle,
    String? imageUrl,
    Duration startAt = Duration.zero,
  }) async {
    final didl = DlnaClient.buildDidl(
      url: url,
      title: subtitle == null || subtitle.isEmpty ? title : '$title — $subtitle',
      imageUrl: imageUrl,
    );

    await _invoke(
      DlnaClient.avTransport,
      'SetAVTransportURI',
      '<CurrentURI>${DlnaClient.escapeXml(url)}</CurrentURI>'
      '<CurrentURIMetaData>${DlnaClient.escapeXml(didl)}</CurrentURIMetaData>',
    );
    await play();

    // Renderers reject a seek until the stream is actually open, so the resume
    // point is applied once playback has started rather than with the URL.
    if (startAt > Duration.zero) {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await seek(startAt);
    }
  }

  @override
  Future<void> play() => _invoke(DlnaClient.avTransport, 'Play', '<Speed>1</Speed>');

  @override
  Future<void> pause() => _invoke(DlnaClient.avTransport, 'Pause', '');

  @override
  Future<void> stop() => _invoke(DlnaClient.avTransport, 'Stop', '');

  @override
  Future<void> seek(Duration position) {
    return _invoke(
      DlnaClient.avTransport,
      'Seek',
      '<Unit>REL_TIME</Unit><Target>${DlnaClient.formatUpnpTime(position)}</Target>',
    );
  }

  @override
  Future<CastStatus> status() async {
    final positionInfo = await _invoke(DlnaClient.avTransport, 'GetPositionInfo', '');
    final transportInfo = await _invoke(DlnaClient.avTransport, 'GetTransportInfo', '');
    return parseStatus(positionInfo, transportInfo);
  }

  /// Reads the two status responses a renderer answers with.
  @visibleForTesting
  static CastStatus parseStatus(String? positionInfo, String? transportInfo) {
    String? tagValue(String? body, String tag) {
      if (body == null) return null;
      final match = RegExp('<$tag[^>]*>(.*?)</$tag>', dotAll: true).firstMatch(body);
      return match?.group(1)?.trim();
    }

    final state = tagValue(transportInfo, 'CurrentTransportState') ?? '';
    return CastStatus(
      isPlaying: state.toUpperCase() == 'PLAYING',
      position: DlnaClient.parseUpnpTime(tagValue(positionInfo, 'RelTime')),
      duration: DlnaClient.parseUpnpTime(tagValue(positionInfo, 'TrackDuration')),
    );
  }

  Future<String?> _invoke(String service, String action, String body) async {
    try {
      final response = await _client
          .post(
            Uri.parse(_controlUrl),
            headers: {
              'Content-Type': 'text/xml; charset="utf-8"',
              'SOAPAction': '"$service#$action"',
              'Connection': 'close',
            },
            body: utf8.encode(DlnaClient.soapEnvelope(service, action, body)),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint('DLNA: $action answered ${response.statusCode}');
        return null;
      }
      return utf8.decode(response.bodyBytes);
    } catch (e) {
      debugPrint('DLNA: $action failed: $e');
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    _client.close();
  }
}
