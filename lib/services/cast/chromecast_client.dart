import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';

import '../../models/cast_device.dart';
import 'cast_channel.dart';

/// Google Cast sender: Chromecast, Google TV, and every television with
/// Chromecast built in.
///
/// Cast is a private protocol, but a well-understood one: discovery is mDNS
/// (`_googlecast._tcp`), the transport is protobuf frames over TLS on port
/// 8009, and the payloads are JSON. Only the media receiver is used here — the
/// app hands the television a URL and it streams the video itself.
class ChromecastClient {
  ChromecastClient._();

  static const String serviceName = '_googlecast._tcp';
  static const int port = 8009;

  /// The stock receiver, which plays a plain media URL. Anything richer would
  /// need a receiver app registered with Google.
  static const String defaultMediaReceiver = 'CC1AD845';

  static const String namespaceConnection = 'urn:x-cast:com.google.cast.tp.connection';
  static const String namespaceHeartbeat = 'urn:x-cast:com.google.cast.tp.heartbeat';
  static const String namespaceReceiver = 'urn:x-cast:com.google.cast.receiver';
  static const String namespaceMedia = 'urn:x-cast:com.google.cast.media';

  /// Finds Cast devices by their mDNS advertisement.
  static Stream<CastDevice> discover({
    Duration timeout = const Duration(seconds: 5),
  }) {
    final controller = StreamController<CastDevice>();

    Future<void> run() async {
      final client = MDnsClient();
      try {
        await client.start();
      } catch (e) {
        // Happens when the platform refuses the multicast socket (a phone on a
        // network that blocks it, a desktop firewall). DLNA discovery is
        // unaffected, so this is not fatal to casting as a whole.
        debugPrint('mDNS: could not start: $e');
        await controller.close();
        return;
      }

      try {
        await for (final ptr in client
            .lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer('$serviceName.local'))
            .timeout(timeout, onTimeout: (sink) => sink.close())) {
          final device = await _resolve(client, ptr.domainName);
          if (device != null && !controller.isClosed) controller.add(device);
        }
      } catch (e) {
        debugPrint('mDNS: lookup failed: $e');
      } finally {
        client.stop();
        await controller.close();
      }
    }

    controller.onListen = run;
    return controller.stream;
  }

  static Future<CastDevice?> _resolve(MDnsClient client, String domainName) async {
    try {
      final srv = await client
          .lookup<SrvResourceRecord>(ResourceRecordQuery.service(domainName))
          .first
          .timeout(const Duration(seconds: 3));

      final ip = await client
          .lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4(srv.target))
          .first
          .timeout(const Duration(seconds: 3));

      String? friendlyName;
      String? model;
      try {
        final txt = await client
            .lookup<TxtResourceRecord>(ResourceRecordQuery.text(domainName))
            .first
            .timeout(const Duration(seconds: 2));
        final parsed = parseTxtRecord(txt.text);
        friendlyName = parsed['fn'];
        model = parsed['md'];
      } catch (_) {
        // The TXT record is a nicety; the address is what matters.
      }

      return CastDevice(
        id: 'cast:$domainName',
        name: friendlyName ?? domainName.split('.').first,
        host: ip.address.address,
        port: srv.port,
        protocol: CastProtocol.googleCast,
        model: model,
      );
    } catch (e) {
      debugPrint('mDNS: could not resolve $domainName: $e');
      return null;
    }
  }

  /// The TXT record is `key=value` pairs, one per line. `fn` carries the name
  /// the user gave the device ("Sala"), `md` the model ("Chromecast Ultra").
  static Map<String, String> parseTxtRecord(String text) {
    final values = <String, String>{};
    for (final line in const LineSplitter().convert(text)) {
      final separator = line.indexOf('=');
      if (separator <= 0) continue;
      values[line.substring(0, separator).trim()] = line.substring(separator + 1).trim();
    }
    return values;
  }
}

/// A live connection to a Cast device.
class ChromecastSession implements CastSession {
  @override
  final CastDevice device;

  ChromecastSession(this.device);

  static const String _senderId = 'sender-0';
  static const String _receiverId = 'receiver-0';

  SecureSocket? _socket;
  final CastFrameReader _reader = CastFrameReader();
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};

  Timer? _heartbeat;
  int _requestId = 1;

  /// The receiver session the media commands are addressed to, once the media
  /// app has been launched.
  String? _transportId;
  int? _mediaSessionId;

  CastStatus _status = const CastStatus();

  Future<void> connect() async {
    if (_socket != null) return;

    // Cast devices present a self-signed certificate; the connection is
    // point-to-point on the local network, and every Cast sender accepts it.
    final socket = await SecureSocket.connect(
      device.host,
      device.port,
      onBadCertificate: (_) => true,
      timeout: const Duration(seconds: 8),
    );
    _socket = socket;

    socket.listen(
      (chunk) {
        for (final message in _reader.add(chunk)) {
          _handle(message);
        }
      },
      onError: (Object error) => debugPrint('Cast: socket error: $error'),
      onDone: _teardown,
      cancelOnError: false,
    );

    _send(ChromecastClient.namespaceConnection, _receiverId, {'type': 'CONNECT'});

    // The receiver drops a sender that goes quiet for ten seconds.
    _heartbeat = Timer.periodic(const Duration(seconds: 5), (_) {
      _send(ChromecastClient.namespaceHeartbeat, _receiverId, {'type': 'PING'});
    });
  }

  @override
  Future<void> load({
    required String url,
    required String title,
    String? subtitle,
    String? imageUrl,
    Duration startAt = Duration.zero,
  }) async {
    await connect();

    final launch = await _request(ChromecastClient.namespaceReceiver, _receiverId, {
      'type': 'LAUNCH',
      'appId': ChromecastClient.defaultMediaReceiver,
    });
    _transportId = _transportIdFrom(launch) ?? _transportId;
    if (_transportId == null) {
      throw const CastException('A TV não abriu o aplicativo de reprodução.');
    }

    // Every destination needs its own virtual connection before it will accept
    // messages — including the media session that was just launched.
    _send(ChromecastClient.namespaceConnection, _transportId!, {'type': 'CONNECT'});

    final response = await _request(ChromecastClient.namespaceMedia, _transportId!, {
      'type': 'LOAD',
      'autoplay': true,
      'currentTime': startAt.inSeconds,
      'media': {
        'contentId': url,
        'contentType': contentTypeFor(url),
        'streamType': 'BUFFERED',
        'metadata': {
          'metadataType': 0,
          'title': title,
          if (subtitle != null && subtitle.isNotEmpty) 'subtitle': subtitle,
          if (imageUrl != null && imageUrl.isNotEmpty)
            'images': [
              {'url': imageUrl},
            ],
        },
      },
    });

    _applyMediaStatus(response);
    if (_mediaSessionId == null) {
      throw const CastException('A TV recusou este vídeo.');
    }
  }

  /// Cast needs a MIME type up front and will not sniff the stream, so a HLS
  /// playlist announced as `video/mp4` simply fails to open.
  @visibleForTesting
  static String contentTypeFor(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    if (path.endsWith('.m3u8')) return 'application/x-mpegurl';
    if (path.endsWith('.mpd')) return 'application/dash+xml';
    if (path.endsWith('.mkv')) return 'video/x-matroska';
    if (path.endsWith('.webm')) return 'video/webm';
    return 'video/mp4';
  }

  @override
  Future<void> play() => _mediaCommand('PLAY');

  @override
  Future<void> pause() => _mediaCommand('PAUSE');

  @override
  Future<void> stop() => _mediaCommand('STOP');

  @override
  Future<void> seek(Duration position) => _mediaCommand('SEEK', {'currentTime': position.inSeconds});

  @override
  Future<CastStatus> status() async {
    if (_transportId == null) return _status;
    try {
      final response = await _request(ChromecastClient.namespaceMedia, _transportId!, {
        'type': 'GET_STATUS',
      });
      _applyMediaStatus(response);
    } catch (e) {
      debugPrint('Cast: status failed: $e');
    }
    return _status;
  }

  Future<void> _mediaCommand(String type, [Map<String, dynamic> extra = const {}]) async {
    final transportId = _transportId;
    final sessionId = _mediaSessionId;
    if (transportId == null || sessionId == null) return;

    final response = await _request(ChromecastClient.namespaceMedia, transportId, {
      'type': type,
      'mediaSessionId': sessionId,
      ...extra,
    });
    _applyMediaStatus(response);
  }

  void _handle(CastMessage message) {
    final payload = message.json;

    if (message.namespace == ChromecastClient.namespaceHeartbeat) {
      if (payload['type'] == 'PING') {
        _send(ChromecastClient.namespaceHeartbeat, message.sourceId, {'type': 'PONG'});
      }
      return;
    }

    if (message.namespace == ChromecastClient.namespaceMedia) {
      _applyMediaStatus(payload);
    }
    if (message.namespace == ChromecastClient.namespaceReceiver) {
      _transportId = _transportIdFrom(payload) ?? _transportId;
    }

    final requestId = payload['requestId'];
    if (requestId is int) {
      final completer = _pending.remove(requestId);
      if (completer != null && !completer.isCompleted) completer.complete(payload);
    }
  }

  /// Pulls the media session out of a RECEIVER_STATUS.
  static String? _transportIdFrom(Map<String, dynamic> payload) {
    final status = payload['status'];
    if (status is! Map) return null;
    final applications = status['applications'];
    if (applications is! List || applications.isEmpty) return null;
    final application = applications.first;
    if (application is! Map) return null;
    return application['transportId'] as String?;
  }

  void _applyMediaStatus(Map<String, dynamic> payload) {
    final statuses = payload['status'];
    if (statuses is! List || statuses.isEmpty) return;
    final status = statuses.first;
    if (status is! Map) return;

    final sessionId = status['mediaSessionId'];
    if (sessionId is int) _mediaSessionId = sessionId;

    final position = (status['currentTime'] as num?)?.toDouble() ?? _status.position.inSeconds.toDouble();
    final media = status['media'];
    final duration = media is Map ? (media['duration'] as num?)?.toDouble() : null;

    _status = CastStatus(
      isPlaying: status['playerState'] == 'PLAYING',
      position: Duration(seconds: position.round()),
      duration: duration != null ? Duration(seconds: duration.round()) : _status.duration,
    );
  }

  void _send(String namespace, String destinationId, Map<String, dynamic> payload) {
    final socket = _socket;
    if (socket == null) return;
    final message = CastMessage(
      sourceId: _senderId,
      destinationId: destinationId,
      namespace: namespace,
      payload: jsonEncode(payload),
    );
    try {
      socket.add(message.encodeFramed());
    } catch (e) {
      debugPrint('Cast: send failed: $e');
    }
  }

  Future<Map<String, dynamic>> _request(
    String namespace,
    String destinationId,
    Map<String, dynamic> payload,
  ) {
    final requestId = _requestId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[requestId] = completer;

    _send(namespace, destinationId, {...payload, 'requestId': requestId});

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _pending.remove(requestId);
        throw const CastException('A TV não respondeu.');
      },
    );
  }

  void _teardown() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _socket = null;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(const CastException('Conexão encerrada.'));
    }
    _pending.clear();
  }

  @override
  Future<void> dispose() async {
    final socket = _socket;
    if (socket != null) {
      _send(ChromecastClient.namespaceConnection, _transportId ?? _receiverId, {'type': 'CLOSE'});
      await socket.flush().catchError((_) {});
      await socket.close().catchError((_) => <int>[]);
    }
    _teardown();
  }
}

class CastException implements Exception {
  final String message;
  const CastException(this.message);

  @override
  String toString() => message;
}
