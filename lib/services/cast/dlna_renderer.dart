import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cast_device.dart';

/// Drives a DLNA / UPnP `MediaRenderer` through its AVTransport and
/// RenderingControl SOAP services. Every command is a plain HTTP POST, so the
/// same code runs on Android, Windows, macOS, Linux and iOS.
class DlnaRenderer {
  DlnaRenderer(this.device, {http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final CastDevice device;
  final http.Client _client;
  final bool _ownsClient;

  static const String avTransport =
      'urn:schemas-upnp-org:service:AVTransport:1';
  static const String renderingControl =
      'urn:schemas-upnp-org:service:RenderingControl:1';

  Future<void> load(CastMediaRequest request) async {
    await _avTransport('SetAVTransportURI', {
      'CurrentURI': request.url,
      'CurrentURIMetaData': buildMetadata(request),
    });
    await play();
    if (request.startAt > const Duration(seconds: 5)) {
      // Most renderers ignore a seek issued before the transport is PLAYING,
      // so give the pipeline a moment to spin up first.
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      try {
        await seek(request.startAt);
      } on CastException {
        // Live/HLS sources are not seekable; playback already started.
      }
    }
  }

  Future<void> play() => _avTransport('Play', {'Speed': '1'});
  Future<void> pause() => _avTransport('Pause', {});
  Future<void> stop() => _avTransport('Stop', {});

  Future<void> seek(Duration position) => _avTransport('Seek', {
        'Unit': 'REL_TIME',
        'Target': formatTime(position),
      });

  Future<CastPlaybackStatus> status(CastPlaybackStatus previous) async {
    final transport = await _avTransport('GetTransportInfo', {});
    final info = await _avTransport('GetPositionInfo', {});
    final rawState = _tag(transport, 'CurrentTransportState') ?? '';
    final state = switch (rawState.toUpperCase()) {
      'PLAYING' => CastPlayerState.playing,
      'PAUSED_PLAYBACK' || 'PAUSED_RECORDING' => CastPlayerState.paused,
      'TRANSITIONING' => CastPlayerState.buffering,
      'STOPPED' => CastPlayerState.stopped,
      _ => CastPlayerState.idle,
    };
    var volume = previous.volume;
    var muted = previous.muted;
    if (device.renderingControlUrl != null) {
      try {
        final response =
            await _renderingControl('GetVolume', {'Channel': 'Master'});
        final level = int.tryParse(_tag(response, 'CurrentVolume') ?? '');
        if (level != null) volume = (level / 100).clamp(0.0, 1.0);
      } on CastException {
        // Optional service; keep the last known level.
      }
    }
    return CastPlaybackStatus(
      state: state,
      position: parseTime(_tag(info, 'RelTime')) ?? previous.position,
      duration: parseTime(_tag(info, 'TrackDuration')) ?? previous.duration,
      volume: volume,
      muted: muted,
    );
  }

  Future<void> setVolume(double level) async {
    final url = device.renderingControlUrl;
    if (url == null) {
      throw const CastException('Esta TV não expõe controle de volume.');
    }
    await _renderingControl('SetVolume', {
      'Channel': 'Master',
      'DesiredVolume': (level.clamp(0.0, 1.0) * 100).round().toString(),
    });
  }

  Future<void> setMuted(bool muted) async {
    final url = device.renderingControlUrl;
    if (url == null) return;
    await _renderingControl('SetMute', {
      'Channel': 'Master',
      'DesiredMute': muted ? '1' : '0',
    });
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }

  Future<String> _avTransport(String action, Map<String, String> args) {
    final url = device.avTransportUrl;
    if (url == null) throw const CastException('TV sem serviço de reprodução.');
    return _soap(url, avTransport, action, args);
  }

  Future<String> _renderingControl(String action, Map<String, String> args) {
    final url = device.renderingControlUrl;
    if (url == null) throw const CastException('TV sem controle de volume.');
    return _soap(url, renderingControl, action, args);
  }

  Future<String> _soap(Uri url, String serviceType, String action,
      Map<String, String> args) async {
    final body = buildEnvelope(serviceType, action, args);
    http.Response response;
    try {
      response = await _client
          .post(url,
              headers: {
                'Content-Type': 'text/xml; charset="utf-8"',
                'SOAPACTION': '"$serviceType#$action"',
                'User-Agent': 'Sabuflix/1.0 UPnP/1.1 DLNADOC/1.50',
                'Connection': 'close',
              },
              body: utf8.encode(body))
          .timeout(const Duration(seconds: 8));
    } catch (error) {
      throw CastException('A TV não respondeu ($action).');
    }
    if (response.statusCode != 200) {
      final text = utf8.decode(response.bodyBytes, allowMalformed: true);
      final code = _tag(text, 'errorCode');
      final description = _tag(text, 'errorDescription');
      throw CastException(
          'A TV recusou $action${code != null ? ' ($code${description != null ? ' $description' : ''})' : ''}.');
    }
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  /// SOAP request body for one UPnP action on `InstanceID` 0.
  static String buildEnvelope(
      String serviceType, String action, Map<String, String> args) {
    final buffer = StringBuffer()
      ..write('<?xml version="1.0" encoding="utf-8"?>')
      ..write(
          '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" ')
      ..write('s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">')
      ..write(
          '<s:Body><u:$action xmlns:u="$serviceType"><InstanceID>0</InstanceID>');
    for (final entry in args.entries) {
      buffer.write('<${entry.key}>${escapeXml(entry.value)}</${entry.key}>');
    }
    buffer.write('</u:$action></s:Body></s:Envelope>');
    return buffer.toString();
  }

  /// DIDL-Lite item describing the title, so the TV shows a name and poster
  /// instead of a bare URL. Returned already escaped for embedding in SOAP.
  static String buildMetadata(CastMediaRequest request) {
    final title = escapeXml(request.title +
        (request.subtitle != null && request.subtitle!.isNotEmpty
            ? ' · ${request.subtitle}'
            : ''));
    final didl = StringBuffer()
      ..write(
          '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" ')
      ..write('xmlns:dc="http://purl.org/dc/elements/1.1/" ')
      ..write('xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" ')
      ..write('xmlns:sec="http://www.sec.co.kr/">')
      ..write('<item id="sabuflix-0" parentID="-1" restricted="1">')
      ..write('<dc:title>$title</dc:title>')
      ..write('<upnp:class>object.item.videoItem.movie</upnp:class>');
    if (request.imageUrl != null && request.imageUrl!.isNotEmpty) {
      didl.write(
          '<upnp:albumArtURI>${escapeXml(request.imageUrl!)}</upnp:albumArtURI>');
    }
    didl
      ..write(
          '<res protocolInfo="http-get:*:${request.contentType}:DLNA.ORG_OP=01;DLNA.ORG_FLAGS=01700000000000000000000000000000">')
      ..write(escapeXml(request.url))
      ..write('</res></item></DIDL-Lite>');
    return didl.toString();
  }

  static String escapeXml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  /// `H:MM:SS` as the UPnP AVTransport spec wants it.
  static String formatTime(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  /// Parses `H:MM:SS`, `HH:MM:SS.mmm` and `NOT_IMPLEMENTED`.
  static Duration? parseTime(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'^(\d+):(\d{1,2}):(\d{1,2})(?:[.,](\d+))?')
        .firstMatch(raw.trim());
    if (match == null) return null;
    final fraction = match.group(4);
    return Duration(
      hours: int.parse(match.group(1)!),
      minutes: int.parse(match.group(2)!),
      seconds: int.parse(match.group(3)!),
      milliseconds: fraction == null
          ? 0
          : int.parse(fraction.padRight(3, '0').substring(0, 3)),
    );
  }

  static String? _tag(String xml, String name) {
    final match = RegExp(
            '<(?:[a-zA-Z0-9]+:)?$name(?:\\s[^>]*)?>(.*?)</(?:[a-zA-Z0-9]+:)?$name>',
            dotAll: true)
        .firstMatch(xml);
    return match?.group(1)?.trim();
  }
}
