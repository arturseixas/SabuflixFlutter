import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../../models/cast_device.dart';
import 'cast_playback_status.dart';

/// Controls a DLNA/UPnP `AVTransport` renderer over HTTP+SOAP.
///
/// Unlike Chromecast's push-based MEDIA_STATUS, UPnP has no cheap way to
/// subscribe to playback changes without a standing HTTP eventing
/// subscription (GENA), so position/state are recovered by polling
/// `GetPositionInfo`/`GetTransportInfo` once a second — plenty smooth for a
/// progress bar, and simple enough not to need its own event server.
class DlnaClient {
  final CastDevice device;
  Timer? _pollTimer;
  bool _disposed = false;

  final _statusController = StreamController<CastPlaybackStatus>.broadcast();
  Stream<CastPlaybackStatus> get status => _statusController.stream;

  DlnaClient(this.device) : assert(device.dlnaControlUrl != null);

  String get _serviceType => device.dlnaServiceType ?? 'urn:schemas-upnp-org:service:AVTransport:1';

  Future<void> loadMedia({
    required String contentUrl,
    required String title,
    String? imageUrl,
    Duration startAt = Duration.zero,
  }) async {
    await _soapCall('SetAVTransportURI', {
      'InstanceID': '0',
      'CurrentURI': contentUrl,
      'CurrentURIMetaData': _didlLiteMetadata(contentUrl, title, imageUrl),
    });
    await _soapCall('Play', {'InstanceID': '0', 'Speed': '1'});
    if (startAt > Duration.zero) {
      // Best-effort: not every renderer accepts a seek before it has
      // buffered enough of the stream to know its own duration.
      try {
        await seek(startAt);
      } catch (_) {}
    }
    _startPolling();
  }

  Future<void> play() async {
    await _soapCall('Play', {'InstanceID': '0', 'Speed': '1'});
  }

  Future<void> pause() async {
    await _soapCall('Pause', {'InstanceID': '0'});
  }

  Future<void> stop() async {
    await _soapCall('Stop', {'InstanceID': '0'});
  }

  Future<void> seek(Duration position) async {
    await _soapCall('Seek', {
      'InstanceID': '0',
      'Unit': 'REL_TIME',
      'Target': _formatTime(position),
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollOnce();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _pollOnce());
  }

  Future<void> _pollOnce() async {
    try {
      final transportDoc = await _soapCall('GetTransportInfo', {'InstanceID': '0'});
      final state = _firstOrNull(transportDoc.findAllElements('CurrentTransportState'))?.innerText.trim();

      final positionDoc = await _soapCall('GetPositionInfo', {'InstanceID': '0'});
      final relTime = _firstOrNull(positionDoc.findAllElements('RelTime'))?.innerText.trim();
      final trackDuration = _firstOrNull(positionDoc.findAllElements('TrackDuration'))?.innerText.trim();

      if (_disposed) return;
      _statusController.add(CastPlaybackStatus(
        connected: true,
        playing: state == 'PLAYING',
        buffering: state == 'TRANSITIONING',
        position: _parseTime(relTime),
        duration: _parseTime(trackDuration),
      ));
    } catch (_) {
      // A single missed poll (TV briefly busy, Wi-Fi hiccup) shouldn't tear
      // the session down — the next tick just tries again.
    }
  }

  Future<XmlDocument> _soapCall(String action, Map<String, String> args) async {
    final controlUrl = device.dlnaControlUrl!;
    final argsXml = args.entries.map((e) => '<${e.key}>${_escapeXml(e.value)}</${e.key}>').join();
    final body = '<?xml version="1.0" encoding="utf-8"?>'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
        's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
        '<s:Body>'
        '<u:$action xmlns:u="$_serviceType">$argsXml</u:$action>'
        '</s:Body>'
        '</s:Envelope>';

    final response = await http
        .post(
          Uri.parse(controlUrl),
          headers: {
            'Content-Type': 'text/xml; charset="utf-8"',
            'SOAPACTION': '"$_serviceType#$action"',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode >= 300) {
      throw StateError('Ação DLNA "$action" falhou (HTTP ${response.statusCode})');
    }
    return XmlDocument.parse(response.body);
  }

  String _didlLiteMetadata(String contentUrl, String title, String? imageUrl) {
    final contentType = guessMediaContentType(contentUrl);
    final safeTitle = _escapeXml(title.isEmpty ? 'Sabuflix' : title);
    final art =
        (imageUrl != null && imageUrl.isNotEmpty) ? '<upnp:albumArtURI>${_escapeXml(imageUrl)}</upnp:albumArtURI>' : '';
    return '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
        '<item id="0" parentID="-1" restricted="1">'
        '<dc:title>$safeTitle</dc:title>'
        '<upnp:class>object.item.videoItem</upnp:class>'
        '$art'
        '<res protocolInfo="http-get:*:$contentType:*">${_escapeXml(contentUrl)}</res>'
        '</item>'
        '</DIDL-Lite>';
  }

  Future<void> disconnect() async {
    _pollTimer?.cancel();
    try {
      await _soapCall('Stop', {'InstanceID': '0'});
    } catch (_) {}
  }

  Future<void> dispose() async {
    _disposed = true;
    _pollTimer?.cancel();
    await _statusController.close();
  }
}

String _escapeXml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String _formatTime(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

Duration _parseTime(String? value) {
  if (value == null) return Duration.zero;
  final parts = value.split(':');
  if (parts.length != 3) return Duration.zero;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  final s = int.tryParse(parts[2].split('.').first) ?? 0;
  return Duration(hours: h, minutes: m, seconds: s);
}

XmlElement? _firstOrNull(Iterable<XmlElement> elements) => elements.isEmpty ? null : elements.first;
