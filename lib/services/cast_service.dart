import 'dart:async';

import '../models/cast_device.dart';
import 'cast/android_multicast_lock.dart';
import 'cast/cast_playback_status.dart';
import 'cast/chromecast_client.dart';
import 'cast/chromecast_discovery.dart';
import 'cast/dlna_client.dart';
import 'cast/dlna_discovery.dart';

export 'cast/cast_playback_status.dart' show CastPlaybackStatus;

/// Unified facade over the two casting backends (Chromecast/CASTV2 and
/// DLNA/UPnP), so the player screen only ever talks to one API regardless
/// of which brand of TV it ends up on.
///
/// Owned by whichever screen needs it — created on open, `dispose()`d on
/// close — since it holds live sockets and shouldn't outlive a playback
/// session.
class CastService {
  final _devicesController = StreamController<List<CastDevice>>.broadcast();
  Stream<List<CastDevice>> get devices => _devicesController.stream;
  final Map<String, CastDevice> _discovered = {};

  StreamSubscription<CastDevice>? _chromecastDiscoverySub;
  StreamSubscription<CastDevice>? _dlnaDiscoverySub;

  ChromecastClient? _chromecastClient;
  DlnaClient? _dlnaClient;
  StreamSubscription<CastPlaybackStatus>? _statusSub;

  CastDevice? _connectedDevice;
  CastDevice? get connectedDevice => _connectedDevice;
  bool get isCasting => _connectedDevice != null;

  final _statusController = StreamController<CastPlaybackStatus>.broadcast();
  Stream<CastPlaybackStatus> get status => _statusController.stream;

  /// Starts (or restarts) a scan for receivers on the local network. Results
  /// stream in via [devices] as each one answers, instead of waiting for a
  /// single fixed timeout before showing anything.
  void startDiscovery({Duration timeout = const Duration(seconds: 6)}) {
    _chromecastDiscoverySub?.cancel();
    _dlnaDiscoverySub?.cancel();
    _discovered.clear();
    _devicesController.add(const []);

    AndroidMulticastLock.acquire();
    _chromecastDiscoverySub = discoverChromecastDevices(timeout: timeout).listen(_onDeviceFound);
    _dlnaDiscoverySub = discoverDlnaDevices(timeout: timeout).listen(_onDeviceFound);
    Timer(timeout + const Duration(seconds: 1), AndroidMulticastLock.release);
  }

  void stopDiscovery() {
    _chromecastDiscoverySub?.cancel();
    _dlnaDiscoverySub?.cancel();
    _chromecastDiscoverySub = null;
    _dlnaDiscoverySub = null;
    AndroidMulticastLock.release();
  }

  void _onDeviceFound(CastDevice device) {
    _discovered[device.id] = device;
    if (!_devicesController.isClosed) {
      _devicesController.add(_discovered.values.toList(growable: false));
    }
  }

  Future<void> connect(CastDevice device) async {
    await disconnect();

    if (device.protocol == CastProtocol.chromecast) {
      final client = ChromecastClient();
      await client.connect(device.host, device.port);
      _chromecastClient = client;
      _statusSub = client.status.listen(_statusController.add);
    } else {
      final client = DlnaClient(device);
      _dlnaClient = client;
      _statusSub = client.status.listen(_statusController.add);
    }
    _connectedDevice = device;
  }

  Future<void> loadMedia({
    required String contentUrl,
    required String title,
    String? imageUrl,
    Duration startAt = Duration.zero,
  }) async {
    final chromecast = _chromecastClient;
    final dlna = _dlnaClient;
    if (chromecast != null) {
      await chromecast.loadMedia(contentUrl: contentUrl, title: title, imageUrl: imageUrl, startAt: startAt);
    } else if (dlna != null) {
      await dlna.loadMedia(contentUrl: contentUrl, title: title, imageUrl: imageUrl, startAt: startAt);
    } else {
      throw StateError('Nenhuma TV conectada');
    }
  }

  Future<void> play() async {
    if (_chromecastClient != null) {
      await _chromecastClient!.play();
    } else if (_dlnaClient != null) {
      await _dlnaClient!.play();
    }
  }

  Future<void> pause() async {
    if (_chromecastClient != null) {
      await _chromecastClient!.pause();
    } else if (_dlnaClient != null) {
      await _dlnaClient!.pause();
    }
  }

  Future<void> seek(Duration position) async {
    if (_chromecastClient != null) {
      await _chromecastClient!.seek(position);
    } else if (_dlnaClient != null) {
      await _dlnaClient!.seek(position);
    }
  }

  /// Disconnects from the current receiver, if any. Safe to call whether or
  /// not something is connected.
  Future<void> disconnect() async {
    await _statusSub?.cancel();
    _statusSub = null;

    if (_chromecastClient != null) {
      final client = _chromecastClient!;
      _chromecastClient = null;
      await client.disconnect();
      await client.dispose();
    }
    if (_dlnaClient != null) {
      final client = _dlnaClient!;
      _dlnaClient = null;
      await client.disconnect();
      await client.dispose();
    }

    _connectedDevice = null;
    if (!_statusController.isClosed) {
      _statusController.add(const CastPlaybackStatus.disconnected());
    }
  }

  Future<void> dispose() async {
    stopDiscovery();
    await disconnect();
    await _devicesController.close();
    await _statusController.close();
  }
}
