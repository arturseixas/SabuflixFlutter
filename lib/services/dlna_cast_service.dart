import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/cast_device.dart';

/// Discovers and controls DLNA/UPnP "MediaRenderer" devices — the standard
/// most Smart TVs (Samsung, LG, Sony, Android TV...) speak natively, with no
/// Chromecast hardware or companion app required.
class DlnaCastService {
  static const String _multicastAddress = '239.255.255.250';
  static const int _multicastPort = 1900;

  /// Broadcasts an SSDP M-SEARCH and collects MediaRenderer responses for
  /// [timeout], resolving each device's description XML for its friendly
  /// name and AVTransport control URL.
  Future<List<CastDevice>> discover({Duration timeout = const Duration(seconds: 4)}) async {
    final Map<String, CastDevice> found = {};
    RawDatagramSocket? socket;

    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final searchMessage = utf8.encode(
        'M-SEARCH * HTTP/1.1\r\n'
        'HOST: $_multicastAddress:$_multicastPort\r\n'
        'MAN: "ssdp:discover"\r\n'
        'MX: 3\r\n'
        'ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n'
        '\r\n',
      );
      final target = InternetAddress(_multicastAddress);

      final pendingLookups = <Future<void>>[];
      final sub = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket!.receive();
        if (datagram == null) return;

        final response = utf8.decode(datagram.data, allowMalformed: true);
        pendingLookups.add(_resolveDevice(response).then((device) {
          if (device != null) found[device.id] = device;
        }));
      });

      // Re-send a few times since UDP is unreliable and TVs answer at random delays.
      for (int i = 0; i < 3; i++) {
        socket.send(searchMessage, target, _multicastPort);
        await Future.delayed(const Duration(milliseconds: 400));
      }

      await Future.delayed(timeout);
      await Future.wait(pendingLookups);
      await sub.cancel();
    } catch (e) {
      print('DLNA discovery error: $e');
    } finally {
      socket?.close();
    }

    return found.values.toList();
  }

  Future<CastDevice?> _resolveDevice(String ssdpResponse) async {
    final location = _extractHeader(ssdpResponse, 'LOCATION');
    if (location == null || location.isEmpty) return null;

    try {
      final uri = Uri.parse(location);
      final response = await http.get(uri).timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) return null;

      final document = XmlDocument.parse(response.body);
      final friendlyName = _first(document.findAllElements('friendlyName'))?.innerText.trim();
      if (friendlyName == null || friendlyName.isEmpty) return null;

      String? controlPath;
      for (final service in document.findAllElements('service')) {
        final serviceType = _first(service.findElements('serviceType'))?.innerText ?? '';
        if (serviceType.contains('AVTransport')) {
          controlPath = _first(service.findElements('controlURL'))?.innerText.trim();
          break;
        }
      }
      if (controlPath == null || controlPath.isEmpty) return null;

      final controlUrl = uri.resolve(controlPath).toString();
      final udn = _first(document.findAllElements('UDN'))?.innerText.trim() ?? location;

      return CastDevice(
        id: 'dlna:$udn',
        name: friendlyName,
        protocol: CastProtocol.dlna,
        host: uri.host,
        port: uri.hasPort ? uri.port : 80,
        controlUrl: controlUrl,
      );
    } catch (e) {
      print('Error resolving DLNA device description at $location: $e');
      return null;
    }
  }

  String? _extractHeader(String rawResponse, String header) {
    final pattern = RegExp('^$header:(.*)\$', caseSensitive: false, multiLine: true);
    final match = pattern.firstMatch(rawResponse);
    return match?.group(1)?.trim();
  }

  Future<void> setAndPlay(CastDevice device, {required String mediaUrl, required String title}) async {
    await _setAVTransportURI(device, mediaUrl: mediaUrl, title: title);
    await play(device);
  }

  Future<void> _setAVTransportURI(CastDevice device, {required String mediaUrl, required String title}) async {
    final metadata = _escapeXml(
      '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" '
      'xmlns:dc="http://purl.org/dc/elements/1.1/" '
      'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
      '<item id="0" parentID="-1" restricted="0">'
      '<dc:title>${_escapeXml(title)}</dc:title>'
      '<upnp:class>object.item.videoItem</upnp:class>'
      '<res protocolInfo="http-get:*:video/mp4:*">${_escapeXml(mediaUrl)}</res>'
      '</item>'
      '</DIDL-Lite>',
    );

    await _sendAction(device, 'SetAVTransportURI', '''
<InstanceID>0</InstanceID>
<CurrentURI>${_escapeXml(mediaUrl)}</CurrentURI>
<CurrentURIMetaData>$metadata</CurrentURIMetaData>
''');
  }

  Future<void> play(CastDevice device) => _sendAction(device, 'Play', '<InstanceID>0</InstanceID><Speed>1</Speed>');

  Future<void> pause(CastDevice device) => _sendAction(device, 'Pause', '<InstanceID>0</InstanceID>');

  Future<void> stop(CastDevice device) => _sendAction(device, 'Stop', '<InstanceID>0</InstanceID>');

  Future<void> seek(CastDevice device, Duration position) => _sendAction(device, 'Seek', '''
<InstanceID>0</InstanceID>
<Unit>REL_TIME</Unit>
<Target>${_formatDuration(position)}</Target>
''');

  Future<void> _sendAction(CastDevice device, String action, String argumentsXml) async {
    final controlUrl = device.controlUrl;
    if (controlUrl == null) throw StateError('Dispositivo DLNA sem URL de controle.');

    final body = '''<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
<s:Body>
<u:$action xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
$argumentsXml
</u:$action>
</s:Body>
</s:Envelope>''';

    final response = await http.post(
      Uri.parse(controlUrl),
      headers: {
        'Content-Type': 'text/xml; charset="utf-8"',
        'SOAPACTION': '"urn:schemas-upnp-org:service:AVTransport:1#$action"',
      },
      body: body,
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode >= 300) {
      throw HttpException('Ação $action falhou (${response.statusCode})');
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

T? _first<T>(Iterable<T> iterable) => iterable.isEmpty ? null : iterable.first;
