import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/cast_device.dart';
import '../models/media_item.dart';
import 'cast/chromecast_client.dart';
import 'cast/dlna_client.dart';
import 'cast/local_media_server.dart';
import 'cast/roku_client.dart';

/// Finds TVs on the local network and mirrors playback to them.
///
/// Three protocols cover effectively every TV people own: DLNA/UPnP (Samsung,
/// LG, Sony, Philips, most receivers), Roku ECP, and Google Cast (Chromecast,
/// Google TV, Android TV).
class CastService extends ChangeNotifier {
  CastService._();

  static final CastService instance = CastService._();

  final List<CastDevice> _devices = [];
  bool _isDiscovering = false;
  bool _isConnecting = false;
  CastDevice? _connectedDevice;
  ChromecastClient? _chromecast;
  MediaItem? _castingMedia;
  String? _castingTitle;
  bool _isPlaying = false;
  String? _lastError;

  List<CastDevice> get devices => List.unmodifiable(_devices);
  bool get isDiscovering => _isDiscovering;
  bool get isConnecting => _isConnecting;
  CastDevice? get connectedDevice => _connectedDevice;
  bool get isCasting => _connectedDevice != null;
  bool get isPlaying => _isPlaying;
  MediaItem? get castingMedia => _castingMedia;
  String? get castingTitle => _castingTitle;
  String? get lastError => _lastError;

  /// Sweeps the network. Devices are published as they answer.
  Future<void> discover({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (_isDiscovering) return;
    _isDiscovering = true;
    _lastError = null;
    notifyListeners();

    await Future.wait([
      DlnaClient.discover(timeout: timeout, onDevice: _add),
      ChromecastClient.discover(timeout: timeout, onDevice: _add),
    ]);

    _isDiscovering = false;
    notifyListeners();
  }

  void _add(CastDevice device) {
    if (_devices.contains(device)) return;
    _devices.add(device);
    notifyListeners();

    // Roku announces itself with only an IP; ask it for the name the user
    // gave it, then swap the placeholder entry out.
    if (device.protocol == CastProtocol.roku) {
      RokuClient.enrich(device).then((enriched) {
        final index = _devices.indexOf(device);
        if (index == -1) return;
        _devices[index] = enriched;
        notifyListeners();
      });
    }
  }

  void clearDevices() {
    _devices.clear();
    notifyListeners();
  }

  /// Starts playing [url] on [device].
  ///
  /// Local files (downloads) are published over the LAN first, since a TV
  /// cannot read the app's sandbox.
  Future<bool> castTo({
    required CastDevice device,
    required String url,
    required MediaItem media,
    String? title,
    String? imageUrl,
    Duration startAt = Duration.zero,
  }) async {
    _isConnecting = true;
    _lastError = null;
    notifyListeners();

    final resolvedUrl = await _resolveUrl(url);
    if (resolvedUrl == null) {
      _fail('Não foi possível compartilhar este arquivo na rede local.');
      return false;
    }

    final displayTitle = title ?? media.title;
    var success = false;

    switch (device.protocol) {
      case CastProtocol.dlna:
        success = await DlnaClient.setUriAndPlay(
          device,
          url: resolvedUrl,
          title: displayTitle,
          imageUrl: imageUrl,
        );
        if (success && startAt > Duration.zero) {
          await DlnaClient.seek(device, startAt);
        }
        break;

      case CastProtocol.roku:
        success = await RokuClient.launchVideo(
          device,
          url: resolvedUrl,
          title: displayTitle,
        );
        break;

      case CastProtocol.googleCast:
        await _chromecast?.disconnect();
        final client = ChromecastClient(device);
        if (await client.connect()) {
          success = await client.loadMedia(
            url: resolvedUrl,
            title: displayTitle,
            subtitle: media.overview,
            imageUrl: imageUrl,
            startFrom: startAt,
          );
        }
        if (success) {
          _chromecast = client;
        } else {
          await client.disconnect();
        }
        break;
    }

    _isConnecting = false;
    if (!success) {
      _fail('Não foi possível iniciar a transmissão em ${device.name}.');
      return false;
    }

    _connectedDevice = device;
    _castingMedia = media;
    _castingTitle = displayTitle;
    _isPlaying = true;
    notifyListeners();
    return true;
  }

  Future<String?> _resolveUrl(String url) async {
    final isRemote = url.startsWith('http://') || url.startsWith('https://');
    if (isRemote) return url;
    final path = url.startsWith('file://') ? Uri.parse(url).toFilePath() : url;
    return LocalMediaServer.instance.publish(path);
  }

  Future<void> togglePlayPause() async {
    final device = _connectedDevice;
    if (device == null) return;

    switch (device.protocol) {
      case CastProtocol.dlna:
        if (_isPlaying) {
          await DlnaClient.pause(device);
        } else {
          await DlnaClient.play(device);
        }
        break;
      case CastProtocol.roku:
        await RokuClient.togglePlayPause(device);
        break;
      case CastProtocol.googleCast:
        if (_isPlaying) {
          await _chromecast?.pause();
        } else {
          await _chromecast?.play();
        }
        break;
    }

    _isPlaying = !_isPlaying;
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    final device = _connectedDevice;
    if (device == null) return;
    switch (device.protocol) {
      case CastProtocol.dlna:
        await DlnaClient.seek(device, position);
        break;
      case CastProtocol.googleCast:
        await _chromecast?.seek(position);
        break;
      case CastProtocol.roku:
        // ECP exposes no absolute seek — the TV's own remote handles it.
        break;
    }
  }

  /// Reads back where the TV actually is, when the protocol can tell us.
  Future<Duration?> currentPosition() async {
    final device = _connectedDevice;
    if (device?.protocol == CastProtocol.dlna) {
      return DlnaClient.position(device!);
    }
    return null;
  }

  Future<void> stopCasting() async {
    final device = _connectedDevice;
    if (device != null) {
      switch (device.protocol) {
        case CastProtocol.dlna:
          await DlnaClient.stop(device);
          break;
        case CastProtocol.roku:
          await RokuClient.stop(device);
          break;
        case CastProtocol.googleCast:
          await _chromecast?.stopCasting();
          break;
      }
    }

    _chromecast = null;
    _connectedDevice = null;
    _castingMedia = null;
    _castingTitle = null;
    _isPlaying = false;
    await LocalMediaServer.instance.stop();
    notifyListeners();
  }

  void _fail(String message) {
    _lastError = message;
    _isConnecting = false;
    notifyListeners();
  }
}
