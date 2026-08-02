import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';

import '../../models/cast_device.dart';

/// Google Cast (CASTv2) client.
///
/// Chromecast, Google TV and Nest displays do not speak DLNA, so this
/// implements the protocol directly: a TLS socket on port 8009 carrying
/// length-prefixed protobuf frames whose payload is JSON. The protobuf
/// message has seven scalar fields, so it is encoded and decoded by hand
/// rather than pulling in a code generator.
class ChromecastClient {
  ChromecastClient(this.device);

  final CastDevice device;

  static const String _defaultMediaReceiver = 'CC1AD845';
  static const String _nsConnection = 'urn:x-cast:com.google.cast.tp.connection';
  static const String _nsHeartbeat = 'urn:x-cast:com.google.cast.tp.heartbeat';
  static const String _nsReceiver = 'urn:x-cast:com.google.cast.receiver';
  static const String _nsMedia = 'urn:x-cast:com.google.cast.media';
  static const String _sourceId = 'sender-sabuflix';

  SecureSocket? _socket;
  StreamSubscription<Uint8List>? _subscription;
  Timer? _heartbeatTimer;
  final BytesBuilder _inbox = BytesBuilder();

  int _requestId = 1;
  String? _transportId;
  String? _sessionId;
  int? _mediaSessionId;

  final Map<int, Completer<Map<String, dynamic>>> _pending = {};

  bool get isConnected => _socket != null;

  // --- Discovery --------------------------------------------------------

  /// Finds Cast receivers over mDNS (`_googlecast._tcp`).
  static Future<void> discover({
    required Duration timeout,
    required void Function(CastDevice device) onDevice,
  }) async {
    final client = MDnsClient();
    final seen = <String>{};
    try {
      await client.start();

      final deadline = DateTime.now().add(timeout);
      await for (final ptr in client
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer('_googlecast._tcp.local'),
          )
          .timeout(timeout, onTimeout: (sink) => sink.close())) {
        if (DateTime.now().isAfter(deadline)) break;

        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) break;

        String? friendlyName;
        String? model;
        await for (final txt in client
            .lookup<TxtResourceRecord>(ResourceRecordQuery.text(ptr.domainName))
            .timeout(remaining, onTimeout: (sink) => sink.close())) {
          for (final line in const LineSplitter().convert(txt.text)) {
            if (line.startsWith('fn=')) friendlyName = line.substring(3);
            if (line.startsWith('md=')) model = line.substring(3);
          }
          break;
        }

        await for (final srv in client
            .lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName))
            .timeout(remaining, onTimeout: (sink) => sink.close())) {
          await for (final address in client
              .lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(srv.target),
              )
              .timeout(remaining, onTimeout: (sink) => sink.close())) {
            if (!seen.add(ptr.domainName)) break;
            onDevice(CastDevice(
              id: ptr.domainName,
              name: friendlyName ?? srv.target,
              host: address.address.address,
              port: srv.port,
              protocol: CastProtocol.googleCast,
              model: model,
            ));
            break;
          }
          break;
        }
      }
    } catch (e) {
      debugPrint('Cast: mDNS discovery failed — $e');
    } finally {
      client.stop();
    }
  }

  // --- Session ----------------------------------------------------------

  /// Opens the TLS session and launches the Default Media Receiver.
  Future<bool> connect() async {
    try {
      // Receivers present a self-signed certificate chained to Google's
      // device CA, which is not in the system trust store — the transport is
      // still encrypted, and the device is one the user picked off their own
      // network.
      _socket = await SecureSocket.connect(
        device.host,
        device.port == 0 ? 8009 : device.port,
        onBadCertificate: (_) => true,
        timeout: const Duration(seconds: 8),
      );
    } catch (e) {
      debugPrint('Cast: TLS connect to ${device.host} failed — $e');
      return false;
    }

    _subscription = _socket!.listen(
      _onData,
      onError: (Object e) => debugPrint('Cast: socket error — $e'),
      onDone: _cleanUp,
      cancelOnError: true,
    );

    _send(_nsConnection, 'receiver-0', {'type': 'CONNECT'});
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _send(_nsHeartbeat, _transportId ?? 'receiver-0', {'type': 'PING'}),
    );

    try {
      final status = await _request(
        _nsReceiver,
        'receiver-0',
        (id) => {
          'type': 'LAUNCH',
          'requestId': id,
          'appId': _defaultMediaReceiver,
        },
      ).timeout(const Duration(seconds: 15));
      _readReceiverStatus(status);
    } catch (e) {
      debugPrint('Cast: LAUNCH failed — $e');
      await disconnect();
      return false;
    }

    if (_transportId == null) {
      await disconnect();
      return false;
    }

    // A second virtual connection, this one to the media receiver app.
    _send(_nsConnection, _transportId!, {'type': 'CONNECT'});
    return true;
  }

  Future<bool> loadMedia({
    required String url,
    required String title,
    String? subtitle,
    String? imageUrl,
    Duration startFrom = Duration.zero,
  }) async {
    final transportId = _transportId;
    if (transportId == null) return false;

    try {
      final status = await _request(
        _nsMedia,
        transportId,
        (id) => {
          'type': 'LOAD',
          'requestId': id,
          if (_sessionId != null) 'sessionId': _sessionId,
          'autoplay': true,
          'currentTime': startFrom.inSeconds,
          'media': {
            'contentId': url,
            'streamType': 'BUFFERED',
            'contentType': _contentTypeFor(url),
            'metadata': {
              'metadataType': 0,
              'title': title,
              if (subtitle != null) 'subtitle': subtitle,
              if (imageUrl != null) 'images': [
                {'url': imageUrl}
              ],
            },
          },
        },
      ).timeout(const Duration(seconds: 20));

      _readMediaStatus(status);
      return status['type'] != 'LOAD_FAILED' && status['type'] != 'LOAD_CANCELLED';
    } catch (e) {
      debugPrint('Cast: LOAD failed — $e');
      return false;
    }
  }

  Future<void> play() async => _mediaCommand('PLAY');

  Future<void> pause() async => _mediaCommand('PAUSE');

  Future<void> seek(Duration position) async =>
      _mediaCommand('SEEK', {'currentTime': position.inSeconds});

  Future<void> stopCasting() async {
    await _mediaCommand('STOP');
    final sessionId = _sessionId;
    if (sessionId != null) {
      _send(_nsReceiver, 'receiver-0', {
        'type': 'STOP',
        'requestId': _requestId++,
        'sessionId': sessionId,
      });
    }
    await disconnect();
  }

  Future<void> disconnect() async {
    final transportId = _transportId;
    if (transportId != null && _socket != null) {
      _send(_nsConnection, transportId, {'type': 'CLOSE'});
    }
    _cleanUp();
    try {
      await _socket?.close();
    } catch (_) {
      // Already closed by the receiver.
    }
    _socket = null;
  }

  void _cleanUp() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _subscription?.cancel();
    _subscription = null;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Cast connection closed'));
      }
    }
    _pending.clear();
  }

  Future<void> _mediaCommand(String type, [Map<String, dynamic>? extra]) async {
    final transportId = _transportId;
    final mediaSessionId = _mediaSessionId;
    if (transportId == null || mediaSessionId == null) return;
    _send(_nsMedia, transportId, {
      'type': type,
      'requestId': _requestId++,
      'mediaSessionId': mediaSessionId,
      ...?extra,
    });
  }

  // --- Framing ----------------------------------------------------------

  Future<Map<String, dynamic>> _request(
    String namespace,
    String destination,
    Map<String, dynamic> Function(int requestId) build,
  ) {
    final id = _requestId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _send(namespace, destination, build(id));
    return completer.future;
  }

  void _send(String namespace, String destination, Map<String, dynamic> payload) {
    final socket = _socket;
    if (socket == null) return;
    try {
      socket.add(encodeFrame(
        namespace: namespace,
        destination: destination,
        payload: json.encode(payload),
      ));
    } catch (e) {
      debugPrint('Cast: send failed — $e');
    }
  }

  void _onData(Uint8List data) {
    _inbox.add(data);
    var buffer = _inbox.toBytes();

    while (buffer.length >= 4) {
      final length = ByteData.sublistView(buffer, 0, 4).getUint32(0);
      if (buffer.length < 4 + length) break;

      final frame = buffer.sublist(4, 4 + length);
      buffer = Uint8List.fromList(buffer.sublist(4 + length));
      _handleFrame(frame);
    }

    _inbox.clear();
    _inbox.add(buffer);
  }

  void _handleFrame(Uint8List frame) {
    final decoded = decodeFrame(frame);
    final namespace = decoded.namespace;
    final payload = decoded.payload;
    if (payload == null) return;

    Map<String, dynamic> message;
    try {
      message = json.decode(payload) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    if (namespace == _nsHeartbeat && message['type'] == 'PING') {
      _send(_nsHeartbeat, decoded.sourceId ?? 'receiver-0', {'type': 'PONG'});
      return;
    }

    if (message['type'] == 'RECEIVER_STATUS') _readReceiverStatus(message);
    if (message['type'] == 'MEDIA_STATUS') _readMediaStatus(message);

    final requestId = message['requestId'];
    if (requestId is int) {
      final completer = _pending.remove(requestId);
      if (completer != null && !completer.isCompleted) completer.complete(message);
    }
  }

  void _readReceiverStatus(Map<String, dynamic> message) {
    final applications = message['status']?['applications'];
    if (applications is! List || applications.isEmpty) return;
    final app = applications.first as Map<String, dynamic>;
    _transportId = app['transportId'] as String? ?? _transportId;
    _sessionId = app['sessionId'] as String? ?? _sessionId;
  }

  void _readMediaStatus(Map<String, dynamic> message) {
    final statuses = message['status'];
    if (statuses is! List || statuses.isEmpty) return;
    final status = statuses.first as Map<String, dynamic>;
    final id = status['mediaSessionId'];
    if (id is int) _mediaSessionId = id;
  }

  /// `CastMessage` — protocol_version(1), source_id(2), destination_id(3),
  /// namespace(4), payload_type(5), payload_utf8(6) — prefixed with its
  /// big-endian length.
  @visibleForTesting
  static Uint8List encodeFrame({
    required String namespace,
    required String destination,
    required String payload,
  }) {
    final body = BytesBuilder();
    body.add([0x08, 0x00]); // protocol_version = CASTV2_1_0
    _writeString(body, 2, _sourceId);
    _writeString(body, 3, destination);
    _writeString(body, 4, namespace);
    body.add([0x28, 0x00]); // payload_type = STRING
    _writeString(body, 6, payload);

    final message = body.toBytes();
    final frame = BytesBuilder();
    final header = ByteData(4)..setUint32(0, message.length);
    frame.add(header.buffer.asUint8List());
    frame.add(message);
    return frame.toBytes();
  }

  @visibleForTesting
  static DecodedFrame decodeFrame(Uint8List bytes) {
    String? sourceId;
    String? namespace;
    String? payload;

    var offset = 0;
    while (offset < bytes.length) {
      final key = _readVarint(bytes, offset);
      offset = key.offset;
      final field = key.value >> 3;
      final wireType = key.value & 0x07;

      if (wireType == 2) {
        final length = _readVarint(bytes, offset);
        offset = length.offset;
        final end = offset + length.value;
        if (end > bytes.length) break;
        final value = utf8.decode(bytes.sublist(offset, end), allowMalformed: true);
        offset = end;
        if (field == 2) sourceId = value;
        if (field == 4) namespace = value;
        if (field == 6) payload = value;
      } else if (wireType == 0) {
        offset = _readVarint(bytes, offset).offset;
      } else if (wireType == 5) {
        offset += 4;
      } else if (wireType == 1) {
        offset += 8;
      } else {
        break; // Unknown wire type — the rest of the frame is unreadable.
      }
    }

    return DecodedFrame(sourceId: sourceId, namespace: namespace, payload: payload);
  }

  static void _writeString(BytesBuilder builder, int field, String value) {
    final bytes = utf8.encode(value);
    builder.addByte((field << 3) | 2);
    _writeVarint(builder, bytes.length);
    builder.add(bytes);
  }

  static void _writeVarint(BytesBuilder builder, int value) {
    var remaining = value;
    while (remaining >= 0x80) {
      builder.addByte((remaining & 0x7F) | 0x80);
      remaining >>= 7;
    }
    builder.addByte(remaining);
  }

  static _Varint _readVarint(Uint8List bytes, int offset) {
    var result = 0;
    var shift = 0;
    var index = offset;
    while (index < bytes.length) {
      final byte = bytes[index++];
      result |= (byte & 0x7F) << shift;
      if (byte & 0x80 == 0) break;
      shift += 7;
    }
    return _Varint(result, index);
  }

  static String _contentTypeFor(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    if (path.endsWith('.mkv')) return 'video/x-matroska';
    if (path.endsWith('.webm')) return 'video/webm';
    if (path.endsWith('.m3u8')) return 'application/x-mpegurl';
    if (path.endsWith('.mpd')) return 'application/dash+xml';
    return 'video/mp4';
  }
}

/// One decoded `CastMessage`.
class DecodedFrame {
  final String? sourceId;
  final String? namespace;
  final String? payload;

  const DecodedFrame({this.sourceId, this.namespace, this.payload});
}

class _Varint {
  final int value;
  final int offset;

  const _Varint(this.value, this.offset);
}
