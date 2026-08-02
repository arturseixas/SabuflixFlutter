import 'dart:io';

import 'package:flutter/foundation.dart';

/// Serves a downloaded file over the LAN so a TV can pull it.
///
/// Casting hands the TV a URL, not bytes — which works for streams, but a
/// downloaded episode only exists inside the app sandbox. This exposes those
/// files on an ephemeral port for as long as the cast session lasts.
class LocalMediaServer {
  LocalMediaServer._();

  static final LocalMediaServer instance = LocalMediaServer._();

  HttpServer? _server;
  final Map<String, String> _routes = {};
  int _nextId = 1;

  /// Publishes [filePath] and returns the URL a device on the same network
  /// can fetch it from, or null when the LAN address can't be determined.
  Future<String?> publish(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    await _ensureStarted();
    final server = _server;
    if (server == null) return null;

    final address = await _lanAddress();
    if (address == null) return null;

    final existing = _routes.entries
        .where((entry) => entry.value == filePath)
        .map((entry) => entry.key);
    final id = existing.isNotEmpty ? existing.first : '${_nextId++}';
    _routes[id] = filePath;

    final name = Uri.encodeComponent(filePath.split(Platform.pathSeparator).last);
    return 'http://$address:${server.port}/media/$id/$name';
  }

  Future<void> _ensureStarted() async {
    if (_server != null) return;
    try {
      final server = await HttpServer.bind(InternetAddress.anyIPv4, 0, shared: true);
      _server = server;
      server.listen(_handle, onError: (Object e) {
        debugPrint('LocalMediaServer: $e');
      });
    } catch (e) {
      debugPrint('LocalMediaServer: could not bind — $e');
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final segments = request.uri.pathSegments;
    final id = segments.length >= 2 && segments.first == 'media' ? segments[1] : null;
    final path = id == null ? null : _routes[id];

    if (path == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final file = File(path);
    final length = await file.length();
    final range = parseRange(request.headers.value(HttpHeaders.rangeHeader), length);

    request.response.headers
      ..set(HttpHeaders.acceptRangesHeader, 'bytes')
      ..set(HttpHeaders.contentTypeHeader, _contentTypeFor(path));

    try {
      if (range == null) {
        request.response.headers.set(HttpHeaders.contentLengthHeader, length);
        await request.response.addStream(file.openRead());
      } else {
        final (start, end) = range;
        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers
          ..set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$length')
          ..set(HttpHeaders.contentLengthHeader, end - start + 1);
        await request.response.addStream(file.openRead(start, end + 1));
      }
      await request.response.close();
    } catch (e) {
      // The TV closing the socket mid-seek is normal; nothing to recover.
      debugPrint('LocalMediaServer: stream aborted — $e');
    }
  }

  /// Parses `bytes=start-end`, tolerating open-ended forms.
  @visibleForTesting
  static (int, int)? parseRange(String? header, int length) {
    if (header == null || !header.startsWith('bytes=')) return null;
    final spec = header.substring(6).split('-');
    if (spec.length != 2) return null;

    final startText = spec[0].trim();
    final endText = spec[1].trim();

    if (startText.isEmpty) {
      final suffix = int.tryParse(endText);
      if (suffix == null || suffix <= 0) return null;
      final start = (length - suffix).clamp(0, length - 1);
      return (start, length - 1);
    }

    final start = int.tryParse(startText);
    if (start == null || start >= length) return null;
    final end = endText.isEmpty
        ? length - 1
        : (int.tryParse(endText) ?? length - 1).clamp(start, length - 1);
    return (start, end);
  }

  static Future<String?> _lanAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback) return address.address;
        }
      }
    } catch (e) {
      debugPrint('LocalMediaServer: interface lookup failed — $e');
    }
    return null;
  }

  static String _contentTypeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.avi')) return 'video/x-msvideo';
    return 'video/mp4';
  }

  Future<void> stop() async {
    _routes.clear();
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }
}
