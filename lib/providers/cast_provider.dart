import 'dart:async';
import 'package:flutter/material.dart';
import '../models/cast_device.dart';
import '../services/chromecast_service.dart';
import '../services/dlna_cast_service.dart';
import '../services/multicast_lock_service.dart';

/// Unifies DLNA/UPnP and Chromecast under one API so the rest of the app
/// doesn't need to care which protocol a given TV actually speaks.
class CastProvider extends ChangeNotifier {
  final DlnaCastService _dlnaService = DlnaCastService();
  final ChromecastService _chromecastDiscovery = ChromecastService();

  List<CastDevice> _devices = [];
  List<CastDevice> get devices => _devices;

  bool _isDiscovering = false;
  bool get isDiscovering => _isDiscovering;

  CastDevice? _connectedDevice;
  CastDevice? get connectedDevice => _connectedDevice;
  bool get isCasting => _connectedDevice != null;

  String? _castingTitle;
  String? get castingTitle => _castingTitle;

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  String? _lastError;
  String? get lastError => _lastError;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  Duration _position = Duration.zero;
  Duration get position => _position;

  Duration _mediaDuration = Duration.zero;
  Duration get mediaDuration => _mediaDuration;

  ChromecastSession? _chromecastSession;
  StreamSubscription<Map<String, dynamic>>? _mediaStatusSub;

  /// Scans the local network for both DLNA and Chromecast receivers.
  Future<void> discover() async {
    if (_isDiscovering) return;
    _isDiscovering = true;
    _devices = [];
    notifyListeners();

    await MulticastLockService.acquire();
    try {
      final results = await Future.wait([
        _dlnaService.discover(),
        _chromecastDiscovery.discover(),
      ]);
      _devices = [...results[0], ...results[1]];
    } catch (e) {
      print('Cast discovery error: $e');
    } finally {
      await MulticastLockService.release();
      _isDiscovering = false;
      notifyListeners();
    }
  }

  Future<void> castTo(
    CastDevice device, {
    required String mediaUrl,
    required String title,
    String? posterUrl,
    Duration startAt = Duration.zero,
  }) async {
    await disconnect();

    _isConnecting = true;
    _lastError = null;
    notifyListeners();

    try {
      if (device.protocol == CastProtocol.chromecast) {
        final session = ChromecastSession(device);
        await session.connect();
        await session.loadMedia(mediaUrl: mediaUrl, title: title, posterUrl: posterUrl, startAt: startAt);
        _chromecastSession = session;
        _mediaStatusSub = session.mediaStatusStream.listen(_onChromecastStatus);
      } else {
        await _dlnaService.setAndPlay(device, mediaUrl: mediaUrl, title: title);
      }

      _connectedDevice = device;
      _castingTitle = title;
      _isPlaying = true;
      _position = startAt;
    } catch (e) {
      _lastError = 'Não foi possível transmitir para ${device.name}.';
      print('Cast error: $e');
      rethrow;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  void _onChromecastStatus(Map<String, dynamic> status) {
    final playerState = status['playerState'];
    if (playerState is String) _isPlaying = playerState == 'PLAYING';

    final currentTime = status['currentTime'];
    if (currentTime is num) _position = Duration(milliseconds: (currentTime * 1000).round());

    final media = status['media'];
    final durationSeconds = media is Map ? media['duration'] : null;
    if (durationSeconds is num) {
      _mediaDuration = Duration(milliseconds: (durationSeconds * 1000).round());
    }

    notifyListeners();
  }

  Future<void> play() async {
    final device = _connectedDevice;
    if (device == null) return;
    if (device.protocol == CastProtocol.chromecast) {
      _chromecastSession?.play();
    } else {
      await _dlnaService.play(device);
    }
    _isPlaying = true;
    notifyListeners();
  }

  Future<void> pause() async {
    final device = _connectedDevice;
    if (device == null) return;
    if (device.protocol == CastProtocol.chromecast) {
      _chromecastSession?.pause();
    } else {
      await _dlnaService.pause(device);
    }
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    final device = _connectedDevice;
    if (device == null) return;
    if (device.protocol == CastProtocol.chromecast) {
      _chromecastSession?.seek(position);
    } else {
      await _dlnaService.seek(device, position);
    }
    _position = position;
    notifyListeners();
  }

  /// Stops playback on the TV and forgets the current session.
  Future<void> disconnect() async {
    final device = _connectedDevice;
    if (device != null) {
      try {
        if (device.protocol == CastProtocol.chromecast) {
          _chromecastSession?.stop();
        } else {
          await _dlnaService.stop(device);
        }
      } catch (e) {
        print('Error stopping cast session: $e');
      }
    }

    await _mediaStatusSub?.cancel();
    await _chromecastSession?.disconnect();

    _chromecastSession = null;
    _mediaStatusSub = null;
    _connectedDevice = null;
    _castingTitle = null;
    _isPlaying = false;
    _position = Duration.zero;
    _mediaDuration = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
