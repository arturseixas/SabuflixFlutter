import 'dart:async';

import 'package:flutter/foundation.dart';

import 'cast_device.dart';
import 'chromecast_client.dart';
import 'dlna_renderer.dart';

/// Protocol-agnostic handle on a TV that is playing (or about to play) for us.
///
/// Both implementations surface the same [status] stream so the remote-control
/// UI never needs to know whether it is talking to a Chromecast or a DLNA set.
abstract class CastSession {
  CastDevice get device;
  Stream<CastPlaybackStatus> get status;
  Stream<String> get errors;
  CastPlaybackStatus get lastStatus;

  /// Completes when the link to the device is gone, for whatever reason.
  Future<void> get closed;

  Future<void> load(CastMediaRequest request);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double level);
  Future<void> setMuted(bool muted);
  Future<void> disconnect();

  static Future<CastSession> open(CastDevice device) async {
    switch (device.protocol) {
      case CastProtocol.chromecast:
        final client = ChromecastClient(device);
        await client.connect();
        return _ChromecastSession(client);
      case CastProtocol.dlna:
        return _DlnaSession(device);
    }
  }
}

class _ChromecastSession implements CastSession {
  _ChromecastSession(this._client) {
    _poll = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_client.hasMediaSession) _client.refreshStatus();
    });
    _client.closed.then((_) => _poll?.cancel());
  }

  final ChromecastClient _client;
  Timer? _poll;

  @override
  CastDevice get device => _client.device;
  @override
  Stream<CastPlaybackStatus> get status => _client.statusStream;
  @override
  Stream<String> get errors => _client.errors;
  @override
  CastPlaybackStatus get lastStatus => _client.lastStatus;
  @override
  Future<void> get closed => _client.closed;

  @override
  Future<void> load(CastMediaRequest request) => _client.load(request);
  @override
  Future<void> play() => _client.play();
  @override
  Future<void> pause() => _client.pause();
  @override
  Future<void> stop() => _client.stop();
  @override
  Future<void> seek(Duration position) => _client.seek(position);
  @override
  Future<void> setVolume(double level) => _client.setVolume(level);
  @override
  Future<void> setMuted(bool muted) => _client.setMuted(muted);
  @override
  Future<void> disconnect() async {
    _poll?.cancel();
    await _client.disconnect();
  }
}

/// DLNA has no push channel, so the session polls the renderer once a second
/// while something is loaded and stops when the transport goes idle.
class _DlnaSession implements CastSession {
  _DlnaSession(this.device) : _renderer = DlnaRenderer(device);

  @override
  final CastDevice device;
  final DlnaRenderer _renderer;
  final StreamController<CastPlaybackStatus> _status =
      StreamController<CastPlaybackStatus>.broadcast();
  final StreamController<String> _errors = StreamController<String>.broadcast();
  final Completer<void> _closed = Completer<void>();
  CastPlaybackStatus _last = const CastPlaybackStatus();
  Timer? _poll;
  bool _polling = false;
  int _consecutiveFailures = 0;

  @override
  Stream<CastPlaybackStatus> get status => _status.stream;
  @override
  Stream<String> get errors => _errors.stream;
  @override
  CastPlaybackStatus get lastStatus => _last;
  @override
  Future<void> get closed => _closed.future;

  void _startPolling() {
    _poll ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _tick() async {
    if (_polling || _closed.isCompleted) return;
    _polling = true;
    try {
      final next = await _renderer.status(_last);
      _consecutiveFailures = 0;
      _emit(next);
    } on CastException catch (error) {
      _consecutiveFailures++;
      if (_consecutiveFailures >= 5) {
        _errors.add(error.message);
        _poll?.cancel();
        _poll = null;
        _consecutiveFailures = 0;
      }
    } catch (error) {
      debugPrint('DLNA poll failed: $error');
    } finally {
      _polling = false;
    }
  }

  void _emit(CastPlaybackStatus next) {
    _last = next;
    if (!_status.isClosed) _status.add(next);
  }

  @override
  Future<void> load(CastMediaRequest request) async {
    _emit(_last.copyWith(
        state: CastPlayerState.buffering, position: request.startAt));
    _startPolling();
    await _renderer.load(request);
  }

  @override
  Future<void> play() async {
    await _renderer.play();
    _emit(_last.copyWith(state: CastPlayerState.playing));
    _startPolling();
  }

  @override
  Future<void> pause() async {
    await _renderer.pause();
    _emit(_last.copyWith(state: CastPlayerState.paused));
  }

  @override
  Future<void> stop() async {
    _poll?.cancel();
    _poll = null;
    try {
      await _renderer.stop();
    } finally {
      _emit(_last.copyWith(
          state: CastPlayerState.stopped, position: Duration.zero));
    }
  }

  @override
  Future<void> seek(Duration position) async {
    await _renderer.seek(position);
    _emit(_last.copyWith(position: position));
  }

  @override
  Future<void> setVolume(double level) async {
    await _renderer.setVolume(level);
    _emit(_last.copyWith(volume: level.clamp(0.0, 1.0)));
  }

  @override
  Future<void> setMuted(bool muted) async {
    await _renderer.setMuted(muted);
    _emit(_last.copyWith(muted: muted));
  }

  @override
  Future<void> disconnect() async {
    if (_closed.isCompleted) return;
    _poll?.cancel();
    try {
      if (_last.isActive) await _renderer.stop();
    } catch (_) {
      // Best effort: the TV may already be off.
    }
    _renderer.dispose();
    _closed.complete();
    await _status.close();
    await _errors.close();
  }
}
