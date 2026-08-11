import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'cast_playback_status.dart';
import 'chromecast_protocol.dart';

/// A live session with one Chromecast (or "Chromecast built-in") receiver,
/// speaking the CASTV2 protocol directly over a TLS socket on port 8009.
///
/// Flow: TLS connect → CONNECT the virtual channel to the platform receiver
/// → LAUNCH the Default Media Receiver app → CONNECT to that app's own
/// transport → LOAD media on it. From then on PLAY/PAUSE/SEEK/STOP and
/// MEDIA_STATUS all address that app transport.
class ChromecastClient {
  static const _sourceId = 'sender-sabuflix';
  static const _receiverDestination = 'receiver-0';
  static const _namespaceConnection = 'urn:x-cast:com.google.cast.tp.connection';
  static const _namespaceHeartbeat = 'urn:x-cast:com.google.cast.tp.heartbeat';
  static const _namespaceReceiver = 'urn:x-cast:com.google.cast.receiver';
  static const _namespaceMedia = 'urn:x-cast:com.google.cast.media';
  static const _defaultMediaReceiverAppId = 'CC1AD845';

  Socket? _socket;
  StreamSubscription<Uint8List>? _socketSub;
  Timer? _heartbeatTimer;
  Timer? _statusPollTimer;
  String? _appTransportId;
  int? _mediaSessionId;
  int _requestId = 0;
  final List<int> _recvBuffer = [];
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};

  final _statusController = StreamController<CastPlaybackStatus>.broadcast();
  Stream<CastPlaybackStatus> get status => _statusController.stream;

  Future<void> connect(String host, int port) async {
    _socket = await SecureSocket.connect(
      host,
      port,
      // Chromecast devices present a self-signed, per-device certificate —
      // there is no public CA to validate it against.
      onBadCertificate: (_) => true,
      timeout: const Duration(seconds: 8),
    );
    _socketSub = _socket!.listen(_onData, onDone: _handleStreamClosed, onError: (_) => _handleStreamClosed());

    _send(_receiverDestination, _namespaceConnection, {'type': 'CONNECT'});
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _send(_receiverDestination, _namespaceHeartbeat, {'type': 'PING'});
      final transportId = _appTransportId;
      if (transportId != null) {
        _send(transportId, _namespaceHeartbeat, {'type': 'PING'});
      }
    });
  }

  Future<void> loadMedia({
    required String contentUrl,
    required String title,
    String? imageUrl,
    Duration startAt = Duration.zero,
  }) async {
    final launchResponse = await _sendAndWait(
      _receiverDestination,
      _namespaceReceiver,
      {'type': 'LAUNCH', 'appId': _defaultMediaReceiverAppId},
      timeout: const Duration(seconds: 12),
    );

    final apps = (launchResponse['status'] as Map<String, dynamic>?)?['applications'] as List? ?? const [];
    final app = apps.cast<Map<String, dynamic>?>().firstWhere(
          (a) => a?['appId'] == _defaultMediaReceiverAppId,
          orElse: () => null,
        );
    final transportId = app?['transportId'] as String?;
    if (transportId == null) {
      throw StateError('O Chromecast não conseguiu abrir o receptor de mídia');
    }
    _appTransportId = transportId;
    _send(transportId, _namespaceConnection, {'type': 'CONNECT'});

    final response = await _sendAndWait(
      transportId,
      _namespaceMedia,
      {
        'type': 'LOAD',
        'autoplay': true,
        'currentTime': startAt.inSeconds,
        'media': {
          'contentId': contentUrl,
          'contentType': guessMediaContentType(contentUrl),
          'streamType': 'BUFFERED',
          'metadata': {
            'metadataType': 0,
            'title': title,
            if (imageUrl != null && imageUrl.isNotEmpty)
              'images': [
                {'url': imageUrl},
              ],
          },
        },
      },
      timeout: const Duration(seconds: 15),
    );

    final statuses = response['status'] as List? ?? const [];
    if (statuses.isNotEmpty) {
      _mediaSessionId = (statuses.first as Map<String, dynamic>)['mediaSessionId'] as int?;
    }
    _startStatusPolling();
  }

  Future<void> play() => _mediaCommand('PLAY');

  Future<void> pause() => _mediaCommand('PAUSE');

  Future<void> stop() => _mediaCommand('STOP');

  Future<void> seek(Duration position) => _mediaCommand('SEEK', extra: {
        'currentTime': position.inSeconds,
        'resumeState': 'PLAYBACK_START',
      });

  Future<void> _mediaCommand(String type, {Map<String, dynamic>? extra}) async {
    final transportId = _appTransportId;
    final sessionId = _mediaSessionId;
    if (transportId == null || sessionId == null) return;
    await _sendAndWait(transportId, _namespaceMedia, {
      'type': type,
      'mediaSessionId': sessionId,
      ...?extra,
    });
  }

  void _startStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final transportId = _appTransportId;
      if (transportId == null) return;
      _send(transportId, _namespaceMedia, {'type': 'GET_STATUS', 'requestId': _nextRequestId()});
    });
  }

  int _nextRequestId() => ++_requestId;

  void _send(String destination, String namespace, Map<String, dynamic> payload) {
    final socket = _socket;
    if (socket == null) return;
    socket.add(CastMessageCodec.encodeFrame(
      sourceId: _sourceId,
      destinationId: destination,
      namespace: namespace,
      payloadUtf8: jsonEncode(payload),
    ));
  }

  Future<Map<String, dynamic>> _sendAndWait(
    String destination,
    String namespace,
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 8),
  }) {
    final requestId = _nextRequestId();
    final completer = Completer<Map<String, dynamic>>();
    _pending[requestId] = completer;
    _send(destination, namespace, {...payload, 'requestId': requestId});
    return completer.future.timeout(timeout, onTimeout: () {
      _pending.remove(requestId);
      throw TimeoutException('O Chromecast não respondeu a "${payload['type']}"');
    });
  }

  void _onData(Uint8List chunk) {
    _recvBuffer.addAll(chunk);
    while (true) {
      if (_recvBuffer.length < 4) return;
      final len = (_recvBuffer[0] << 24) | (_recvBuffer[1] << 16) | (_recvBuffer[2] << 8) | _recvBuffer[3];
      if (_recvBuffer.length < 4 + len) return;
      final body = Uint8List.fromList(_recvBuffer.sublist(4, 4 + len));
      _recvBuffer.removeRange(0, 4 + len);
      try {
        _handleMessage(CastMessageCodec.decodeBody(body));
      } catch (_) {
        // A malformed frame from the receiver shouldn't take the whole
        // session down — drop it and keep listening.
      }
    }
  }

  void _handleMessage(CastWireMessage msg) {
    final raw = msg.payloadUtf8;
    if (raw == null || raw.isEmpty) return;
    Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final type = json['type'] as String?;

    if (msg.namespace == _namespaceHeartbeat) {
      if (type == 'PING') {
        _send(msg.sourceId, _namespaceHeartbeat, {'type': 'PONG'});
      }
      return;
    }

    if (msg.namespace == _namespaceReceiver && type == 'RECEIVER_STATUS') {
      final apps = (json['status'] as Map<String, dynamic>?)?['applications'] as List? ?? const [];
      for (final app in apps) {
        if (app is Map<String, dynamic> && app['appId'] == _defaultMediaReceiverAppId) {
          _appTransportId = app['transportId'] as String?;
        }
      }
    }

    if (msg.namespace == _namespaceMedia && type == 'MEDIA_STATUS') {
      final statuses = json['status'] as List? ?? const [];
      if (statuses.isNotEmpty) {
        final s = statuses.first as Map<String, dynamic>;
        _mediaSessionId = s['mediaSessionId'] as int? ?? _mediaSessionId;
        final playerState = s['playerState'] as String?;
        final currentTime = (s['currentTime'] as num?)?.toDouble() ?? 0;
        final duration = ((s['media'] as Map<String, dynamic>?)?['duration'] as num?)?.toDouble();
        _statusController.add(CastPlaybackStatus(
          connected: true,
          playing: playerState == 'PLAYING',
          buffering: playerState == 'BUFFERING',
          position: Duration(milliseconds: (currentTime * 1000).round()),
          duration:
              duration != null && duration > 0 ? Duration(milliseconds: (duration * 1000).round()) : Duration.zero,
        ));
      }
    }

    final requestId = json['requestId'] as int?;
    if (requestId != null) {
      _pending.remove(requestId)?.complete(json);
    }
  }

  void _handleStreamClosed() {
    _heartbeatTimer?.cancel();
    _statusPollTimer?.cancel();
    if (!_statusController.isClosed) {
      _statusController.add(const CastPlaybackStatus.disconnected());
    }
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(StateError('Sessão do Chromecast encerrada'));
    }
    _pending.clear();
  }

  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _statusPollTimer?.cancel();
    final transportId = _appTransportId;
    if (transportId != null) {
      _send(transportId, _namespaceConnection, {'type': 'CLOSE'});
    }
    _send(_receiverDestination, _namespaceConnection, {'type': 'CLOSE'});
    await _socketSub?.cancel();
    await _socket?.close();
    _socket = null;
    _appTransportId = null;
    _mediaSessionId = null;
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(StateError('Sessão do Chromecast encerrada'));
    }
    _pending.clear();
  }

  Future<void> dispose() async {
    await disconnect();
    await _statusController.close();
  }
}
