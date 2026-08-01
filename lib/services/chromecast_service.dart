import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:multicast_dns/multicast_dns.dart';
import '../models/cast_device.dart';

const String _namespaceConnection = 'urn:x-cast:com.google.cast.tp.connection';
const String _namespaceHeartbeat = 'urn:x-cast:com.google.cast.tp.heartbeat';
const String _namespaceReceiver = 'urn:x-cast:com.google.cast.receiver';
const String _namespaceMedia = 'urn:x-cast:com.google.cast.media';

/// Google's stock "Default Media Receiver" app — plays a plain media URL
/// without us needing to register/publish a custom Cast receiver app.
const String _defaultMediaReceiverAppId = 'CC1AD845';

const String _senderId = 'sender-sabuflix';
const String _platformReceiverId = 'receiver-0';

/// Discovers Chromecast (and Chromecast built-in) devices via mDNS and
/// controls playback through the Cast V2 binary protocol — implemented by
/// hand here (no native Google Cast SDK) so it works the same on every
/// platform Flutter runs on.
class ChromecastService {
  Future<List<CastDevice>> discover({Duration timeout = const Duration(seconds: 4)}) async {
    final client = MDnsClient();
    final List<CastDevice> devices = [];

    try {
      await client.start();

      await for (final ptr in client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer('_googlecast._tcp.local'),
      ).timeout(timeout, onTimeout: (sink) => sink.close())) {
        String? host;
        int port = 8009;
        String name = ptr.domainName.split('.').first;

        await for (final srv in client
            .lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName))
            .timeout(const Duration(seconds: 2), onTimeout: (sink) => sink.close())) {
          host = srv.target;
          port = srv.port;
          break;
        }

        await for (final txt in client
            .lookup<TxtResourceRecord>(ResourceRecordQuery.text(ptr.domainName))
            .timeout(const Duration(seconds: 2), onTimeout: (sink) => sink.close())) {
          final friendly = _extractTxtValue(txt.text, 'fn');
          if (friendly != null && friendly.isNotEmpty) name = friendly;
          break;
        }

        if (host == null) continue;

        String ip = host;
        await for (final ip4 in client
            .lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4(host))
            .timeout(const Duration(seconds: 2), onTimeout: (sink) => sink.close())) {
          ip = ip4.address.address;
          break;
        }

        devices.add(CastDevice(
          id: 'cast:${ptr.domainName}',
          name: name,
          protocol: CastProtocol.chromecast,
          host: ip,
          port: port,
        ));
      }
    } catch (e) {
      print('Chromecast discovery error: $e');
    } finally {
      client.stop();
    }

    return devices;
  }

  String? _extractTxtValue(String txt, String key) {
    for (final entry in txt.split('\n')) {
      final parts = entry.split('=');
      if (parts.length == 2 && parts[0] == key) return parts[1];
    }
    return null;
  }
}

/// One active connection + casting session to a single Chromecast device.
class ChromecastSession {
  final CastDevice device;

  SecureSocket? _socket;
  final BytesBuilder _recvBuffer = BytesBuilder(copy: false);
  Timer? _heartbeatTimer;
  int _requestId = 0;

  String? _transportId;
  String? _sessionId;
  int? _mediaSessionId;

  final _mediaStatusController = StreamController<Map<String, dynamic>>.broadcast();

  /// Emits the raw `media.MEDIA_STATUS` payload (`playerState`, `currentTime`, ...).
  Stream<Map<String, dynamic>> get mediaStatusStream => _mediaStatusController.stream;

  final Map<int, Completer<Map<String, dynamic>>> _pendingRequests = {};

  ChromecastSession(this.device);

  Future<void> connect() async {
    _socket = await SecureSocket.connect(
      device.host,
      device.port,
      onBadCertificate: (cert) => true, // Chromecast uses a self-signed cert.
      timeout: const Duration(seconds: 6),
    );

    _socket!.listen(_onData, onError: (_) {}, onDone: () {});

    _send(namespace: _namespaceConnection, destinationId: _platformReceiverId, payload: {'type': 'CONNECT'});

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _send(namespace: _namespaceHeartbeat, destinationId: _platformReceiverId, payload: {'type': 'PING'});
    });
  }

  /// Launches the default media receiver (if needed) and loads [mediaUrl].
  Future<void> loadMedia({
    required String mediaUrl,
    required String title,
    String? posterUrl,
    Duration startAt = Duration.zero,
  }) async {
    if (_transportId == null) {
      await _launchReceiverApp();
    }

    final requestId = ++_requestId;
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[requestId] = completer;

    _send(namespace: _namespaceMedia, destinationId: _transportId!, payload: {
      'type': 'LOAD',
      'requestId': requestId,
      'sessionId': _sessionId,
      'autoplay': true,
      'currentTime': startAt.inSeconds,
      'media': {
        'contentId': mediaUrl,
        'streamType': 'BUFFERED',
        'contentType': 'video/mp4',
        'metadata': {
          'metadataType': 0,
          'title': title,
          if (posterUrl != null) 'images': [
            {'url': posterUrl}
          ],
        },
      },
    });

    final response = await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => throw TimeoutException('A TV não respondeu ao pedido de reprodução.'),
    );

    final status = (response['status'] as List?)?.cast<Map<String, dynamic>>();
    if (status != null && status.isNotEmpty) {
      _mediaSessionId = status.first['mediaSessionId'] as int?;
    }
  }

  Future<void> _launchReceiverApp() async {
    final requestId = ++_requestId;
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[requestId] = completer;

    _send(namespace: _namespaceReceiver, destinationId: _platformReceiverId, payload: {
      'type': 'LAUNCH',
      'appId': _defaultMediaReceiverAppId,
      'requestId': requestId,
    });

    final response = await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => throw TimeoutException('A TV não respondeu ao abrir o receptor de mídia.'),
    );

    final applications = (response['status']?['applications'] as List?)?.cast<Map<String, dynamic>>();
    if (applications == null || applications.isEmpty) {
      throw StateError('A TV não retornou uma aplicação de mídia ativa.');
    }

    final app = applications.first;
    _transportId = app['transportId'] as String?;
    _sessionId = app['sessionId'] as String?;
    if (_transportId == null) throw StateError('Sessão de cast sem transportId.');

    _send(namespace: _namespaceConnection, destinationId: _transportId!, payload: {'type': 'CONNECT'});
  }

  void play() => _sendMediaCommand('PLAY');

  void pause() => _sendMediaCommand('PAUSE');

  void stop() => _sendMediaCommand('STOP');

  void seek(Duration position) => _sendMediaCommand('SEEK', extra: {'currentTime': position.inSeconds});

  void _sendMediaCommand(String type, {Map<String, dynamic>? extra}) {
    if (_transportId == null || _mediaSessionId == null) return;
    _send(namespace: _namespaceMedia, destinationId: _transportId!, payload: {
      'type': type,
      'requestId': ++_requestId,
      'mediaSessionId': _mediaSessionId,
      ...?extra,
    });
  }

  void _send({required String namespace, required String destinationId, required Map<String, dynamic> payload}) {
    final socket = _socket;
    if (socket == null) return;
    final message = _CastMessage(
      sourceId: _senderId,
      destinationId: destinationId,
      namespace: namespace,
      payloadUtf8: json.encode(payload),
    );
    final encoded = message.encode();
    final lengthPrefix = ByteData(4)..setUint32(0, encoded.length, Endian.big);
    socket.add(lengthPrefix.buffer.asUint8List());
    socket.add(encoded);
  }

  void _onData(Uint8List chunk) {
    _recvBuffer.add(chunk);
    var buffer = _recvBuffer.takeBytes();

    while (buffer.length >= 4) {
      final length = ByteData.sublistView(buffer, 0, 4).getUint32(0, Endian.big);
      if (buffer.length < 4 + length) break;

      final messageBytes = buffer.sublist(4, 4 + length);
      buffer = buffer.sublist(4 + length);
      _handleMessage(_CastMessage.decode(messageBytes));
    }

    if (buffer.isNotEmpty) _recvBuffer.add(buffer);
  }

  void _handleMessage(_CastMessage message) {
    if (message.payloadUtf8 == null) return;

    Map<String, dynamic> payload;
    try {
      payload = json.decode(message.payloadUtf8!) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final type = payload['type'];

    if (type == 'PING') {
      _send(namespace: _namespaceHeartbeat, destinationId: message.sourceId, payload: {'type': 'PONG'});
      return;
    }

    if (type == 'MEDIA_STATUS') {
      final statusList = (payload['status'] as List?)?.cast<Map<String, dynamic>>();
      if (statusList != null && statusList.isNotEmpty) {
        _mediaSessionId = statusList.first['mediaSessionId'] as int? ?? _mediaSessionId;
        _mediaStatusController.add(statusList.first);
      }
    }

    final requestId = payload['requestId'];
    if (requestId is int && _pendingRequests.containsKey(requestId)) {
      _pendingRequests.remove(requestId)!.complete(payload);
    }
  }

  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    if (_transportId != null) {
      _send(namespace: _namespaceConnection, destinationId: _transportId!, payload: {'type': 'CLOSE'});
    }
    _send(namespace: _namespaceConnection, destinationId: _platformReceiverId, payload: {'type': 'CLOSE'});
    await _socket?.close();
    await _mediaStatusController.close();
  }
}

/// Minimal hand-rolled encoder/decoder for the `CastMessage` protobuf schema
/// (cast_channel.proto) — only the fields Sabuflix actually needs:
/// 1:protocol_version(varint) 2:source_id(string) 3:destination_id(string)
/// 4:namespace(string) 5:payload_type(varint) 6:payload_utf8(string)
class _CastMessage {
  final int protocolVersion;
  final String sourceId;
  final String destinationId;
  final String namespace;
  final int payloadType; // 0 = STRING, 1 = BINARY
  final String? payloadUtf8;

  _CastMessage({
    this.protocolVersion = 0,
    required this.sourceId,
    required this.destinationId,
    required this.namespace,
    this.payloadType = 0,
    this.payloadUtf8,
  });

  Uint8List encode() {
    final out = BytesBuilder();
    _writeVarintField(out, 1, protocolVersion);
    _writeStringField(out, 2, sourceId);
    _writeStringField(out, 3, destinationId);
    _writeStringField(out, 4, namespace);
    _writeVarintField(out, 5, payloadType);
    if (payloadUtf8 != null) _writeStringField(out, 6, payloadUtf8!);
    return out.toBytes();
  }

  static _CastMessage decode(Uint8List bytes) {
    int offset = 0;
    int protocolVersion = 0;
    String sourceId = '';
    String destinationId = '';
    String namespace = '';
    int payloadType = 0;
    String? payloadUtf8;

    while (offset < bytes.length) {
      final tag = _readVarint(bytes, offset);
      offset = tag.$2;
      final fieldNumber = tag.$1 >> 3;
      final wireType = tag.$1 & 0x7;

      if (wireType == 0) {
        final value = _readVarint(bytes, offset);
        offset = value.$2;
        if (fieldNumber == 1) protocolVersion = value.$1;
        if (fieldNumber == 5) payloadType = value.$1;
      } else if (wireType == 2) {
        final lengthResult = _readVarint(bytes, offset);
        offset = lengthResult.$2;
        final length = lengthResult.$1;
        final data = bytes.sublist(offset, offset + length);
        offset += length;

        switch (fieldNumber) {
          case 2:
            sourceId = utf8.decode(data);
            break;
          case 3:
            destinationId = utf8.decode(data);
            break;
          case 4:
            namespace = utf8.decode(data);
            break;
          case 6:
            payloadUtf8 = utf8.decode(data);
            break;
        }
      } else {
        break; // Unsupported wire type for this schema — nothing else is sent to us.
      }
    }

    return _CastMessage(
      protocolVersion: protocolVersion,
      sourceId: sourceId,
      destinationId: destinationId,
      namespace: namespace,
      payloadType: payloadType,
      payloadUtf8: payloadUtf8,
    );
  }

  static void _writeVarintField(BytesBuilder out, int fieldNumber, int value) {
    _writeVarint(out, (fieldNumber << 3) | 0);
    _writeVarint(out, value);
  }

  static void _writeStringField(BytesBuilder out, int fieldNumber, String value) {
    final bytes = utf8.encode(value);
    _writeVarint(out, (fieldNumber << 3) | 2);
    _writeVarint(out, bytes.length);
    out.add(bytes);
  }

  static void _writeVarint(BytesBuilder out, int value) {
    var v = value;
    while (true) {
      if (v & ~0x7F == 0) {
        out.addByte(v);
        return;
      }
      out.addByte((v & 0x7F) | 0x80);
      v >>= 7;
    }
  }

  /// Returns (value, newOffset).
  static (int, int) _readVarint(Uint8List bytes, int offset) {
    int result = 0;
    int shift = 0;
    int pos = offset;
    while (true) {
      final byte = bytes[pos];
      result |= (byte & 0x7F) << shift;
      pos++;
      if (byte & 0x80 == 0) break;
      shift += 7;
    }
    return (result, pos);
  }
}
