import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/cast_device.dart';
import '../services/cast/cast_service.dart';
import '../services/screen_mirror.dart';

/// Owns "playing on the television": which sets were found, which one we are
/// connected to, and what it is doing right now.
///
/// The phone hands the TV a URL and then acts as a remote control — the video
/// never passes through the phone, so playback survives the app going to the
/// background and costs nothing in battery.
class CastProvider extends ChangeNotifier {
  final List<CastDevice> _devices = [];
  StreamSubscription<CastDevice>? _discovery;
  Timer? _statusTimer;

  CastSession? _session;
  CastDevice? _connectedDevice;
  CastStatus _status = const CastStatus();
  bool _isScanning = false;
  bool _isConnecting = false;
  String? _error;

  /// What is on the television, so the UI can label the casting panel.
  String? _castingTitle;
  String? _castingSubtitle;

  List<CastDevice> get devices => List.unmodifiable(_devices);
  bool get isScanning => _isScanning;
  bool get isConnecting => _isConnecting;
  bool get isCasting => _session != null;
  CastDevice? get connectedDevice => _connectedDevice;
  CastStatus get status => _status;
  String? get error => _error;
  String? get castingTitle => _castingTitle;
  String? get castingSubtitle => _castingSubtitle;
  bool get isSupported => CastService.isSupported;

  /// Sweeps the network. Safe to call again while a sweep is running — it
  /// restarts, which is what the refresh button in the picker does.
  Future<void> startDiscovery() async {
    if (!CastService.isSupported) return;

    await _discovery?.cancel();
    _devices.clear();
    _isScanning = true;
    _error = null;
    notifyListeners();

    // Android drops multicast packets to sleeping apps unless a lock is held,
    // which is the difference between finding every TV in the house and
    // finding none of them.
    await ScreenMirror.acquireMulticastLock();

    _discovery = CastService.discover().listen(
      (device) {
        _devices.add(device);
        notifyListeners();
      },
      onError: (Object error) {
        debugPrint('Cast: discovery failed: $error');
      },
      onDone: () async {
        _isScanning = false;
        await ScreenMirror.releaseMulticastLock();
        notifyListeners();
      },
    );
  }

  Future<void> stopDiscovery() async {
    await _discovery?.cancel();
    _discovery = null;
    if (_isScanning) {
      _isScanning = false;
      await ScreenMirror.releaseMulticastLock();
      notifyListeners();
    }
  }

  /// Connects to [device] and starts [url] on it.
  ///
  /// Returns false (with [error] set) when the television refused, so the
  /// caller can keep playing locally instead of dropping the user on a dead
  /// screen.
  Future<bool> castTo(
    CastDevice device, {
    required String url,
    required String title,
    String? subtitle,
    String? imageUrl,
    Duration startAt = Duration.zero,
  }) async {
    _isConnecting = true;
    _error = null;
    notifyListeners();

    try {
      await _session?.dispose();
      final session = CastService.sessionFor(device);
      await session.load(
        url: url,
        title: title,
        subtitle: subtitle,
        imageUrl: imageUrl,
        startAt: startAt,
      );

      _session = session;
      _connectedDevice = device;
      _castingTitle = title;
      _castingSubtitle = subtitle;
      _status = CastStatus(isPlaying: true, position: startAt);
      _isConnecting = false;
      _startStatusPolling();
      notifyListeners();
      return true;
    } catch (e) {
      _isConnecting = false;
      _error = e is CastException ? e.message : 'Não foi possível conectar a ${device.name}.';
      _session = null;
      _connectedDevice = null;
      notifyListeners();
      return false;
    }
  }

  Future<void> togglePlayPause() async {
    final session = _session;
    if (session == null) return;
    if (_status.isPlaying) {
      await session.pause();
      _status = _status.copyWith(isPlaying: false);
    } else {
      await session.play();
      _status = _status.copyWith(isPlaying: true);
    }
    notifyListeners();
  }

  Future<void> seekBy(Duration delta) async {
    final session = _session;
    if (session == null) return;
    var target = _status.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (_status.duration > Duration.zero && target > _status.duration) target = _status.duration;
    await session.seek(target);
    _status = _status.copyWith(position: target);
    notifyListeners();
  }

  Future<void> seekTo(Duration position) async {
    final session = _session;
    if (session == null) return;
    await session.seek(position);
    _status = _status.copyWith(position: position);
    notifyListeners();
  }

  /// Stops playback on the television and hangs up.
  Future<void> stopCasting() async {
    final session = _session;
    _statusTimer?.cancel();
    _statusTimer = null;
    _session = null;
    _connectedDevice = null;
    _castingTitle = null;
    _castingSubtitle = null;
    _status = const CastStatus();
    notifyListeners();

    if (session == null) return;
    try {
      await session.stop();
    } catch (e) {
      debugPrint('Cast: stop failed: $e');
    }
    await session.dispose();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  /// Televisions do not push their position, so it is read back on a timer —
  /// slowly, because each read is a round trip over Wi-Fi.
  void _startStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final session = _session;
      if (session == null) return;
      try {
        final status = await session.status();
        // A renderer that has not started yet reports a zero duration; keeping
        // the previous one avoids the progress bar jumping back to empty.
        _status = status.duration > Duration.zero ? status : status.copyWith(duration: _status.duration);
        notifyListeners();
      } catch (e) {
        debugPrint('Cast: status poll failed: $e');
      }
    });
  }

  @override
  void dispose() {
    _discovery?.cancel();
    _statusTimer?.cancel();
    _session?.dispose();
    super.dispose();
  }
}
