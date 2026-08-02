import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/cast_device.dart';

/// Roku External Control Protocol (ECP).
///
/// Roku boxes and Roku TVs answer SSDP with `roku:ecp` (handled by
/// [DlnaClient.discover]) and expose a plain HTTP API on port 8060. Video is
/// pushed by launching the built-in Roku Media Player channel with the URL.
class RokuClient {
  RokuClient._();

  /// Channel id of the pre-installed "Roku Media Player".
  static const String _mediaPlayerChannel = '15985';

  /// Replaces the generic `Roku (ip)` name with what the user called the
  /// device, and records its model.
  static Future<CastDevice> enrich(CastDevice device) async {
    try {
      final response = await http
          .get(Uri.parse('http://${device.host}:${device.port}/query/device-info'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return device;

      final xml = utf8.decode(response.bodyBytes, allowMalformed: true);
      final name = _tag(xml, 'user-device-name') ??
          _tag(xml, 'friendly-device-name') ??
          _tag(xml, 'default-device-name');
      final model = _tag(xml, 'model-name');
      final serial = _tag(xml, 'serial-number');

      return CastDevice(
        id: serial ?? device.id,
        name: name != null && name.isNotEmpty ? name : device.name,
        host: device.host,
        port: device.port,
        protocol: CastProtocol.roku,
        model: model,
      );
    } catch (e) {
      debugPrint('Roku: device-info failed for ${device.host} — $e');
      return device;
    }
  }

  static Future<bool> launchVideo(
    CastDevice device, {
    required String url,
    required String title,
  }) async {
    final format = _formatFor(url);
    final uri = Uri.parse(
      'http://${device.host}:${device.port}/launch/$_mediaPlayerChannel'
      '?t=v'
      '&u=${Uri.encodeQueryComponent(url)}'
      '&videoName=${Uri.encodeQueryComponent(title)}'
      '&videoFormat=$format',
    );
    return _post(uri);
  }

  /// ECP has no explicit pause — `Play` is a toggle on the remote.
  static Future<bool> togglePlayPause(CastDevice device) =>
      _keypress(device, 'Play');

  static Future<bool> stop(CastDevice device) => _keypress(device, 'Back');

  static Future<bool> _keypress(CastDevice device, String key) =>
      _post(Uri.parse('http://${device.host}:${device.port}/keypress/$key'));

  static Future<bool> _post(Uri uri) async {
    try {
      final response = await http.post(uri).timeout(const Duration(seconds: 8));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('Roku: request failed ($uri) — $e');
      return false;
    }
  }

  /// The Roku Media Player needs to be told the container up front.
  static String _formatFor(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    if (path.endsWith('.mkv')) return 'mkv';
    if (path.endsWith('.m3u8')) return 'hls';
    if (path.endsWith('.mov')) return 'mp4';
    if (path.endsWith('.webm')) return 'mkv';
    return 'mp4';
  }

  static String? _tag(String xml, String name) {
    final match = RegExp('<$name>(.*?)</$name>', dotAll: true).firstMatch(xml);
    return match?.group(1)?.trim();
  }
}
