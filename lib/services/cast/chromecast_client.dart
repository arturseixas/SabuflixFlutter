import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'cast_channel_codec.dart';
import 'cast_device.dart';

/// Google Cast v2 sender written directly on top of a TLS socket.
///
/// The flow is the same one the official SDK performs: open a virtual
/// connection to the platform receiver, keep it alive with heartbeats, launch
/// the Default Media Receiver, connect to the transport it reports, then talk
/// to it on the media namespace.
class ChromecastClient {
  ChromecastClient(this.device);

  final CastDevice device;

  static const String defaultMediaReceiver = 'CC1AD845';

  SecureSocket? _socket;
  StreamSubscription<List<int>>? _subscription;
  final CastFrameReader _reader = CastFrameReader();
  Timer? _heartbeat;
  int _requestId = 1;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};

  String? _transportId;
  String? _sessionId;
  int? _mediaSessionId;

  final StreamController<CastPlaybackStatus> _status =
      StreamController<CastPlaybackStatus>.broadcast();
  final StreamController<String> _errors = StreamController<String>.broadcast();
  final Completer<void> _closed = Completer<void>();
  CastPlaybackStatus _last = const CastPlaybackStatus();

  Stream<CastPlaybackStatus> get statusStream => _status.stream;
  Stream<String> get errors => _errors.stream;
  Future<void> get closed => _closed.future;
  CastPlaybackStatus get lastStatus => _last;
  bool get isConnected => _socket != null && !_closed.isCompleted;
  bool get hasMediaSession => _mediaSessionId != null;

  Future<void> connect() async {
    try {
      _socket = await SecureSocket.connect(
        device.host,
        device.port,
        // Cast devices present self-signed certificates by design.
        onBadCertificate: (_) => true,
        timeout: const Duration(seconds: 8),
      );
    } catch (error) {
      throw CastException('Não foi possível conectar a ${device.name}.');
    }
    _subscription = _socket!.listen(
      _onBytes,
      onError: (Object error) => _close('Conexão com ${device.name} perdida.'),
      onDone: () => _close(null),
      cancelOnError: true,
    );
    _send(CastChannelMessage.connectionNamespace,
        CastChannelMessage.platformReceiver, {'type': 'CONNECT'});
    _heartbeat = Timer.periodic(const Duration(seconds: 5), (_) {
      _send(CastChannelMessage.heartbeatNamespace,
          CastChannelMessage.platformReceiver, {'type': 'PING'});
    });
    await _launchReceiver();
  }

  Future<void> _launchReceiver() async {
    final status = await _request(
      CastChannelMessage.receiverNamespace,
      CastChannelMessage.platformReceiver,
      {'type': 'GET_STATUS'},
    );
    var app = _findApplication(status);
    if (app == null || app['appId'] != defaultMediaReceiver) {
      final launched = await _request(
        CastChannelMessage.receiverNamespace,
        CastChannelMessage.platformReceiver,
        {'type': 'LAUNCH', 'appId': defaultMediaReceiver},
        timeout: const Duration(seconds: 15),
      );
      app = _findApplication(launched);
      if (app == null) {
        throw const CastException(
            'A TV não conseguiu abrir o receptor de mídia.');
      }
    }
    _transportId = app['transportId']?.toString();
    _sessionId = app['sessionId']?.toString();
    if (_transportId == null) {
      throw const CastException('Receptor de mídia sem canal de transporte.');
    }
    _send(CastChannelMessage.connectionNamespace, _transportId!,
        {'type': 'CONNECT'});
    _applyReceiverVolume(status);
  }

  Map<String, dynamic>? _findApplication(Map<String, dynamic> message) {
    final status = message['status'];
    if (status is! Map) return null;
    final applications = status['applications'];
    if (applications is! List) return null;
    for (final app in applications) {
      if (app is Map) {
        final map = Map<String, dynamic>.from(app);
        if (map['appId'] == defaultMediaReceiver) return map;
      }
    }
    return null;
  }

  Future<void> load(CastMediaRequest request) async {
    final transport = _transportId;
    if (transport == null) throw const CastException('Receptor não iniciado.');
    final tracks = <Map<String, dynamic>>[];
    if (request.subtitleUrl != null &&
        request.subtitleUrl!.toLowerCase().endsWith('.vtt')) {
      tracks.add({
        'trackId': 1,
        'type': 'TEXT',
        'subtype': 'SUBTITLES',
        'trackContentId': request.subtitleUrl,
        'trackContentType': 'text/vtt',
        'language': request.subtitleLanguage ?? 'pt-BR',
        'name': 'Legenda',
      });
    }
    final response = await _request(
      CastChannelMessage.mediaNamespace,
      transport,
      {
        'type': 'LOAD',
        'autoplay': true,
        'currentTime': request.startAt.inMilliseconds / 1000,
        'media': {
          'contentId': request.url,
          'contentUrl': request.url,
          'streamType':
              request.contentType.contains('mpegURL') ? 'LIVE' : 'BUFFERED',
          'contentType': request.contentType,
          'metadata': {
            'metadataType': 0,
            'title': request.title,
            if (request.subtitle != null) 'subtitle': request.subtitle,
            if (request.imageUrl != null)
              'images': [
                {'url': request.imageUrl}
              ],
          },
          if (tracks.isNotEmpty) 'tracks': tracks,
          if (tracks.isNotEmpty)
            'textTrackStyle': {
              'backgroundColor': '#00000099',
              'foregroundColor': '#FFFFFFFF',
              'edgeType': 'DROP_SHADOW',
            },
        },
        if (tracks.isNotEmpty) 'activeTrackIds': [1],
      },
      timeout: const Duration(seconds: 20),
    );
    if (response['type'] == 'LOAD_FAILED' || response['type'] == 'ERROR') {
      throw const CastException(
          'A TV não conseguiu abrir esta fonte. Tente outra qualidade.');
    }
    _applyMediaStatus(response);
  }

  Future<void> play() => _mediaCommand('PLAY');
  Future<void> pause() => _mediaCommand('PAUSE');

  Future<void> stop() async {
    if (_mediaSessionId != null) {
      try {
        await _mediaCommand('STOP');
      } on CastException {
        // Already idle.
      }
    }
    _mediaSessionId = null;
    _emit(_last.copyWith(
        state: CastPlayerState.stopped, position: Duration.zero));
  }

  Future<void> seek(Duration position) => _mediaCommand('SEEK', {
        'currentTime': position.inMilliseconds / 1000,
        'resumeState': 'PLAYBACK_START',
      });

  Future<void> refreshStatus() async {
    final transport = _transportId;
    if (transport == null) return;
    try {
      final response = await _request(
          CastChannelMessage.mediaNamespace, transport, {'type': 'GET_STATUS'});
      _applyMediaStatus(response);
    } on CastException {
      // A missed poll is not fatal; the next heartbeat will tell if the link died.
    }
  }

  Future<void> setVolume(double level) async {
    final response = await _request(
      CastChannelMessage.receiverNamespace,
      CastChannelMessage.platformReceiver,
      {
        'type': 'SET_VOLUME',
        'volume': {'level': level.clamp(0.0, 1.0)},
      },
    );
    _applyReceiverVolume(response);
  }

  Future<void> setMuted(bool muted) async {
    final response = await _request(
      CastChannelMessage.receiverNamespace,
      CastChannelMessage.platformReceiver,
      {
        'type': 'SET_VOLUME',
        'volume': {'muted': muted},
      },
    );
    _applyReceiverVolume(response);
  }

  /// Closes the media app on the TV and drops the connection.
  Future<void> disconnect({bool stopReceiver = true}) async {
    if (stopReceiver && _sessionId != null && isConnected) {
      _send(
          CastChannelMessage.receiverNamespace,
          CastChannelMessage.platformReceiver,
          {'type': 'STOP', 'sessionId': _sessionId, 'requestId': _requestId++});
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    _close(null);
  }

  Future<void> _mediaCommand(String type, [Map<String, dynamic>? extra]) async {
    final transport = _transportId;
    final session = _mediaSessionId;
    if (transport == null || session == null) {
      throw const CastException('Nada sendo reproduzido na TV.');
    }
    final response =
        await _request(CastChannelMessage.mediaNamespace, transport, {
      'type': type,
      'mediaSessionId': session,
      ...?extra,
    });
    _applyMediaStatus(response);
  }

  void _applyReceiverVolume(Map<String, dynamic> message) {
    final status = message['status'];
    if (status is! Map) return;
    final volume = status['volume'];
    if (volume is! Map) return;
    final level = (volume['level'] as num?)?.toDouble();
    final muted = volume['muted'] == true;
    _emit(_last.copyWith(volume: level ?? _last.volume, muted: muted));
  }

  void _applyMediaStatus(Map<String, dynamic> message) {
    if (message['type'] != 'MEDIA_STATUS') return;
    final list = message['status'];
    if (list is! List || list.isEmpty) {
      // An empty status means the media session ended (finished or stopped).
      if (_mediaSessionId != null) {
        _mediaSessionId = null;
        _emit(_last.copyWith(state: CastPlayerState.idle));
      }
      return;
    }
    final status = Map<String, dynamic>.from(list.first as Map);
    _mediaSessionId =
        (status['mediaSessionId'] as num?)?.toInt() ?? _mediaSessionId;
    final state = switch (status['playerState']?.toString()) {
      'PLAYING' => CastPlayerState.playing,
      'PAUSED' => CastPlayerState.paused,
      'BUFFERING' => CastPlayerState.buffering,
      'IDLE' => CastPlayerState.idle,
      _ => _last.state,
    };
    if (state == CastPlayerState.idle && status['idleReason'] == 'ERROR') {
      _errors.add('A TV interrompeu a reprodução: formato não suportado.');
    }
    final media = status['media'];
    final duration =
        media is Map ? (media['duration'] as num?)?.toDouble() : null;
    final position = (status['currentTime'] as num?)?.toDouble();
    final volume = status['volume'];
    _emit(_last.copyWith(
      state: state,
      position: position != null
          ? Duration(milliseconds: (position * 1000).round())
          : _last.position,
      duration: duration != null
          ? Duration(milliseconds: (duration * 1000).round())
          : _last.duration,
      volume: volume is Map
          ? (volume['level'] as num?)?.toDouble() ?? _last.volume
          : _last.volume,
      muted: volume is Map ? volume['muted'] == true : _last.muted,
    ));
  }

  void _emit(CastPlaybackStatus status) {
    _last = status;
    if (!_status.isClosed) _status.add(status);
  }

  Future<Map<String, dynamic>> _request(
    String namespace,
    String destination,
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!isConnected) throw CastException('Sem conexão com ${device.name}.');
    final id = _requestId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _send(namespace, destination, {...payload, 'requestId': id});
    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      throw CastException('${device.name} demorou para responder.');
    } finally {
      _pending.remove(id);
    }
  }

  void _send(
      String namespace, String destination, Map<String, dynamic> payload) {
    final socket = _socket;
    if (socket == null) return;
    final message = CastChannelMessage(
      sourceId: CastChannelMessage.platformSender,
      destinationId: destination,
      namespace: namespace,
      payload: jsonEncode(payload),
    );
    try {
      socket.add(message.toFrame());
    } catch (error) {
      _close('Conexão com ${device.name} perdida.');
    }
  }

  void _onBytes(List<int> chunk) {
    List<CastChannelMessage> messages;
    try {
      messages = _reader.add(chunk);
    } catch (error) {
      debugPrint('Dropping undecodable Cast frame: $error');
      return;
    }
    for (final message in messages) {
      final json = message.json;
      if (json == null) continue;
      final type = json['type']?.toString();
      if (message.namespace == CastChannelMessage.heartbeatNamespace) {
        if (type == 'PING') {
          _send(CastChannelMessage.heartbeatNamespace, message.sourceId,
              {'type': 'PONG'});
        }
        continue;
      }
      if (message.namespace == CastChannelMessage.connectionNamespace &&
          type == 'CLOSE') {
        if (message.sourceId == _transportId) {
          _mediaSessionId = null;
          _transportId = null;
          _emit(_last.copyWith(state: CastPlayerState.idle));
          _errors.add('O receptor de mídia foi fechado na TV.');
        }
        continue;
      }
      final requestId = (json['requestId'] as num?)?.toInt();
      if (requestId != null && _pending.containsKey(requestId)) {
        _pending[requestId]!.complete(json);
        // Fall through: a MEDIA_STATUS answer also refreshes the snapshot.
      }
      if (message.namespace == CastChannelMessage.mediaNamespace) {
        _applyMediaStatus(json);
        if (type == 'LOAD_FAILED' || type == 'ERROR') {
          _errors.add('A TV não conseguiu reproduzir esta fonte.');
        }
      } else if (message.namespace == CastChannelMessage.receiverNamespace &&
          type == 'RECEIVER_STATUS') {
        _applyReceiverVolume(json);
        if (_transportId != null && _findApplication(json) == null) {
          _mediaSessionId = null;
          _emit(_last.copyWith(state: CastPlayerState.idle));
        }
      }
    }
  }

  void _close(String? error) {
    if (_closed.isCompleted) return;
    _heartbeat?.cancel();
    _subscription?.cancel();
    try {
      _socket?.destroy();
    } catch (_) {}
    _socket = null;
    for (final pending in _pending.values) {
      if (!pending.isCompleted) {
        pending.completeError(CastException(error ?? 'Conexão encerrada.'));
      }
    }
    _pending.clear();
    if (error != null && !_errors.isClosed) _errors.add(error);
    _closed.complete();
    _status.close();
    _errors.close();
  }
}
