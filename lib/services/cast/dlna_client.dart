import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/cast_device.dart';

/// UPnP/DLNA discovery (SSDP) and control (SOAP AVTransport).
///
/// This is what talks to Samsung, LG, Sony and Philips TVs, plus anything
/// else that advertises itself as a `MediaRenderer` — no vendor SDK needed.
class DlnaClient {
  DlnaClient._();

  static const String _ssdpAddress = '239.255.255.250';
  static const int _ssdpPort = 1900;
  static const String _avTransport = 'urn:schemas-upnp-org:service:AVTransport:1';

  /// Broadcasts an SSDP `M-SEARCH` and resolves every renderer that answers.
  ///
  /// [onDevice] is called as devices come in so the picker can populate
  /// progressively instead of waiting for the whole [timeout].
  static Future<void> discover({
    required Duration timeout,
    required void Function(CastDevice device) onDevice,
  }) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0, reuseAddress: true);
    } catch (e) {
      debugPrint('DLNA: could not bind SSDP socket — $e');
      return;
    }

    socket.broadcastEnabled = true;
    try {
      socket.multicastHops = 4;
    } catch (_) {
      // Not settable on every platform; the default hop count still reaches
      // devices on the same subnet.
    }

    final seenLocations = <String>{};
    final pending = <Future<void>>[];

    final subscription = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket?.receive();
      if (datagram == null) return;

      final response = utf8.decode(datagram.data, allowMalformed: true);
      final location = _header(response, 'location');
      final searchTarget = _header(response, 'st') ?? '';

      if (searchTarget.contains('roku:ecp')) {
        final device = _rokuFromSsdp(response, datagram.address.address);
        if (device != null && seenLocations.add(device.id)) onDevice(device);
        return;
      }

      if (location == null || !seenLocations.add(location)) return;
      pending.add(_describe(location, datagram.address.address).then((device) {
        if (device != null) onDevice(device);
      }));
    });

    for (final target in [
      'urn:schemas-upnp-org:device:MediaRenderer:1',
      'roku:ecp',
    ]) {
      final message = 'M-SEARCH * HTTP/1.1\r\n'
          'HOST: $_ssdpAddress:$_ssdpPort\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 3\r\n'
          'ST: $target\r\n'
          '\r\n';
      // Sent three times: SSDP runs over UDP and a single datagram is
      // routinely dropped on busy Wi-Fi.
      for (var i = 0; i < 3; i++) {
        try {
          socket.send(utf8.encode(message), InternetAddress(_ssdpAddress), _ssdpPort);
        } catch (e) {
          debugPrint('DLNA: M-SEARCH send failed — $e');
        }
      }
    }

    await Future.delayed(timeout);
    await subscription.cancel();
    socket.close();
    await Future.wait(pending);
  }

  /// Fetches a device description document and turns it into a [CastDevice].
  static Future<CastDevice?> _describe(String location, String host) async {
    try {
      final response = await http
          .get(Uri.parse(location))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return null;

      final xml = utf8.decode(response.bodyBytes, allowMalformed: true);
      final controlUrl = _avTransportControlUrl(xml, location);
      if (controlUrl == null) return null;

      final name = _tag(xml, 'friendlyName') ?? 'TV ($host)';
      final model = _tag(xml, 'modelName');
      final udn = _tag(xml, 'UDN') ?? location;

      return CastDevice(
        id: udn,
        name: name,
        host: Uri.parse(location).host,
        port: Uri.parse(location).port,
        protocol: CastProtocol.dlna,
        controlUrl: controlUrl,
        model: model,
      );
    } catch (e) {
      debugPrint('DLNA: description fetch failed for $location — $e');
      return null;
    }
  }

  static CastDevice? _rokuFromSsdp(String response, String host) {
    final location = _header(response, 'location');
    final usn = _header(response, 'usn') ?? 'roku:$host';
    final uri = location != null ? Uri.tryParse(location) : null;
    return CastDevice(
      id: usn,
      name: 'Roku ($host)',
      host: uri?.host ?? host,
      port: uri?.port ?? 8060,
      protocol: CastProtocol.roku,
    );
  }

  /// Locates the AVTransport service block and resolves its `controlURL`
  /// against the description document's base URL.
  static String? _avTransportControlUrl(String xml, String location) {
    final services = RegExp(r'<service>(.*?)</service>', dotAll: true)
        .allMatches(xml)
        .map((m) => m.group(1)!);

    for (final service in services) {
      final type = _tag(service, 'serviceType') ?? '';
      if (!type.contains('AVTransport')) continue;
      final control = _tag(service, 'controlURL');
      if (control == null || control.isEmpty) continue;

      final base = _tag(xml, 'URLBase');
      final baseUri = Uri.parse(
        base != null && base.isNotEmpty ? base : location,
      );
      return baseUri.resolve(control).toString();
    }
    return null;
  }

  static String? _tag(String xml, String name) {
    final match = RegExp('<$name[^>]*>(.*?)</$name>', dotAll: true).firstMatch(xml);
    return match?.group(1)?.trim();
  }

  static String? _header(String response, String name) {
    for (final line in const LineSplitter().convert(response)) {
      final index = line.indexOf(':');
      if (index <= 0) continue;
      if (line.substring(0, index).trim().toLowerCase() == name) {
        return line.substring(index + 1).trim();
      }
    }
    return null;
  }

  // --- Control ----------------------------------------------------------

  static Future<bool> setUriAndPlay(
    CastDevice device, {
    required String url,
    required String title,
    String? imageUrl,
  }) async {
    final metadata = _didlLite(url: url, title: title, imageUrl: imageUrl);
    final ok = await _soap(device, 'SetAVTransportURI', {
      'InstanceID': '0',
      'CurrentURI': _escape(url),
      'CurrentURIMetaData': _escape(metadata),
    });
    if (!ok) return false;
    return play(device);
  }

  static Future<bool> play(CastDevice device) =>
      _soap(device, 'Play', {'InstanceID': '0', 'Speed': '1'});

  static Future<bool> pause(CastDevice device) =>
      _soap(device, 'Pause', {'InstanceID': '0'});

  static Future<bool> stop(CastDevice device) =>
      _soap(device, 'Stop', {'InstanceID': '0'});

  static Future<bool> seek(CastDevice device, Duration position) => _soap(
        device,
        'Seek',
        {
          'InstanceID': '0',
          'Unit': 'REL_TIME',
          'Target': _formatTime(position),
        },
      );

  /// Reads the renderer's current position, so the app can mirror the TV's
  /// progress on the phone.
  static Future<Duration?> position(CastDevice device) async {
    final body = await _soapRaw(device, 'GetPositionInfo', {'InstanceID': '0'});
    if (body == null) return null;
    final relTime = _tag(body, 'RelTime');
    return relTime == null ? null : _parseTime(relTime);
  }

  static Future<bool> _soap(
    CastDevice device,
    String action,
    Map<String, String> arguments,
  ) async {
    return await _soapRaw(device, action, arguments) != null;
  }

  static Future<String?> _soapRaw(
    CastDevice device,
    String action,
    Map<String, String> arguments,
  ) async {
    final controlUrl = device.controlUrl;
    if (controlUrl == null) return null;

    final args = arguments.entries
        .map((e) => '<${e.key}>${e.value}</${e.key}>')
        .join();
    final envelope = '<?xml version="1.0" encoding="utf-8"?>'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
        's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
        '<s:Body><u:$action xmlns:u="$_avTransport">$args</u:$action></s:Body>'
        '</s:Envelope>';

    try {
      final response = await http
          .post(
            Uri.parse(controlUrl),
            headers: {
              'Content-Type': 'text/xml; charset="utf-8"',
              'SOAPAction': '"$_avTransport#$action"',
              'Connection': 'close',
            },
            body: utf8.encode(envelope),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return utf8.decode(response.bodyBytes, allowMalformed: true);
      }
      debugPrint('DLNA: $action failed (${response.statusCode})');
    } catch (e) {
      debugPrint('DLNA: $action failed — $e');
    }
    return null;
  }

  /// Minimal DIDL-Lite item so the TV shows a title instead of the raw URL.
  static String _didlLite({
    required String url,
    required String title,
    String? imageUrl,
  }) {
    final art = imageUrl == null || imageUrl.isEmpty
        ? ''
        : '<upnp:albumArtURI>${_escape(imageUrl)}</upnp:albumArtURI>';
    return '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
        '<item id="0" parentID="-1" restricted="1">'
        '<dc:title>${_escape(title)}</dc:title>'
        '<upnp:class>object.item.videoItem</upnp:class>'
        '$art'
        '<res protocolInfo="http-get:*:video/mp4:*">${_escape(url)}</res>'
        '</item></DIDL-Lite>';
  }

  static String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static String _formatTime(Duration duration) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(duration.inHours)}:${two(duration.inMinutes.remainder(60))}'
        ':${two(duration.inSeconds.remainder(60))}';
  }

  static Duration? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 3) return null;
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    final seconds = double.tryParse(parts[2]);
    if (hours == null || minutes == null || seconds == null) return null;
    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds.round(),
    );
  }
}
