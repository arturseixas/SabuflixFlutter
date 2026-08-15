import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_cast/dart_cast.dart' as native_cast;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../models/cast_target.dart';
import 'casting_contract.dart';

CastingService createCastingService() => _NativeCastingService();

class _NativeCastingService implements CastingService {
  static const MethodChannel _platformChannel =
      MethodChannel('sabuflix/casting');

  late final native_cast.CastService _castService = native_cast.CastService(
    discoveryProviders: [
      native_cast.ChromecastDiscoveryProvider(),
      native_cast.DlnaDiscoveryProvider(),
    ],
    sessionFactory: (device) {
      if (device.protocol == native_cast.CastProtocol.chromecast) {
        return native_cast.ChromecastSession(device: device);
      }
      throw StateError('A sessão DLNA exige a descrição do dispositivo.');
    },
  );

  final Map<String, native_cast.CastDevice> _nativeDevices = {};
  final Map<String, CastTarget> _targets = {};
  StreamSubscription<List<native_cast.CastDevice>>? _nativeDiscovery;
  StreamController<List<CastTarget>>? _discoveryController;
  RawDatagramSocket? _rokuSocket;
  StreamSubscription<RawSocketEvent>? _rokuSocketSubscription;
  Timer? _rokuRetryTimer;
  Timer? _discoveryTimer;
  native_cast.CastSession? _activeSession;
  CastTarget? _activeTarget;

  @override
  bool get isSupported => true;

  @override
  Stream<List<CastTarget>> discover({
    Duration timeout = const Duration(seconds: 10),
  }) {
    stopDiscovery();
    _targets.clear();
    _nativeDevices.clear();
    final controller = StreamController<List<CastTarget>>();
    _discoveryController = controller;
    unawaited(_setMulticastLock(true));

    _nativeDiscovery = _castService
        .startDiscovery(timeout: timeout)
        .listen(_handleNativeDevices, onError: controller.addError);
    unawaited(_startRokuDiscovery());

    _discoveryTimer = Timer(timeout, stopDiscovery);
    controller.onCancel = stopDiscovery;
    return controller.stream;
  }

  void _handleNativeDevices(List<native_cast.CastDevice> devices) {
    for (final device in devices) {
      final id = 'native:${device.protocol.name}:${device.id}';
      _nativeDevices[id] = device;
      _targets[id] = CastTarget(
        id: id,
        name: device.name,
        kind: _kindForNativeDevice(device),
        address: device.address.address,
        port: device.port,
      );
    }
    _emitTargets();
  }

  CastTargetKind _kindForNativeDevice(native_cast.CastDevice device) {
    if (device.protocol == native_cast.CastProtocol.chromecast) {
      return CastTargetKind.googleCast;
    }
    final identity = [
      device.name,
      device.metadata['manufacturer'],
      device.metadata['modelName'],
    ].whereType<String>().join(' ').toLowerCase();
    if (identity.contains('samsung')) return CastTargetKind.samsung;
    if (identity.contains('lg') || identity.contains('webos')) {
      return CastTargetKind.lg;
    }
    return CastTargetKind.dlna;
  }

  Future<void> _startRokuDiscovery() async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _rokuSocket = socket;
      socket.broadcastEnabled = true;
      _rokuSocketSubscription = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket.receive();
        if (datagram == null) return;
        final response = utf8.decode(datagram.data, allowMalformed: true);
        unawaited(_handleRokuResponse(response));
      });

      _sendRokuSearch(socket);
      _rokuRetryTimer = Timer(
        const Duration(milliseconds: 700),
        () => _sendRokuSearch(socket),
      );
    } catch (_) {
      // Chromecast and DLNA discovery may still succeed on this network.
    }
  }

  void _sendRokuSearch(RawDatagramSocket socket) {
    const request = 'M-SEARCH * HTTP/1.1\r\n'
        'HOST: 239.255.255.250:1900\r\n'
        'MAN: "ssdp:discover"\r\n'
        'MX: 3\r\n'
        'ST: roku:ecp\r\n\r\n';
    socket.send(
      utf8.encode(request),
      InternetAddress('239.255.255.250'),
      1900,
    );
  }

  Future<void> _handleRokuResponse(String response) async {
    final headers = <String, String>{};
    for (final line in response.split(RegExp(r'\r?\n')).skip(1)) {
      final separator = line.indexOf(':');
      if (separator <= 0) continue;
      headers[line.substring(0, separator).trim().toLowerCase()] =
          line.substring(separator + 1).trim();
    }
    if (!(headers['st'] ?? '').toLowerCase().contains('roku:ecp')) return;
    final location = headers['location'];
    if (location == null) return;

    final uri = Uri.tryParse(location);
    if (uri == null || uri.host.isEmpty) return;
    final usn = headers['usn'] ?? uri.host;
    final id = 'roku:$usn';
    if (_targets.containsKey(id)) return;

    var name = 'Roku';
    try {
      final infoUri = Uri(
        scheme: 'http',
        host: uri.host,
        port: uri.hasPort ? uri.port : 8060,
        path: '/query/device-info',
      );
      final info = await http.get(infoUri).timeout(const Duration(seconds: 3));
      if (info.statusCode == 200) {
        name = _xmlValue(info.body, 'friendly-device-name') ??
            _xmlValue(info.body, 'user-device-name') ??
            _xmlValue(info.body, 'model-name') ??
            name;
      }
    } catch (_) {}

    _targets[id] = CastTarget(
      id: id,
      name: name,
      kind: CastTargetKind.roku,
      address: uri.host,
      port: uri.hasPort ? uri.port : 8060,
    );
    _emitTargets();
  }

  String? _xmlValue(String xml, String tag) {
    final match = RegExp(
      '<$tag>([^<]+)</$tag>',
      caseSensitive: false,
    ).firstMatch(xml);
    return match?.group(1)?.trim();
  }

  void _emitTargets() {
    if (_discoveryController?.isClosed != false) return;
    final devices = _targets.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _discoveryController!.add(devices);
  }

  @override
  void stopDiscovery() {
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    _rokuRetryTimer?.cancel();
    _rokuRetryTimer = null;
    unawaited(_nativeDiscovery?.cancel());
    _nativeDiscovery = null;
    _castService.stopDiscovery();
    unawaited(_rokuSocketSubscription?.cancel());
    _rokuSocketSubscription = null;
    _rokuSocket?.close();
    _rokuSocket = null;
    unawaited(_setMulticastLock(false));
    if (_discoveryController?.isClosed == false) {
      unawaited(_discoveryController!.close());
    }
    _discoveryController = null;
  }

  Future<void> _setMulticastLock(bool enabled) async {
    try {
      await _platformChannel.invokeMethod<void>(
        enabled ? 'acquireMulticastLock' : 'releaseMulticastLock',
      );
    } on MissingPluginException {
      // Only Android needs an explicit multicast lock.
    } on PlatformException {
      // Discovery still works on platforms that do not expose this channel.
    }
  }

  @override
  Future<void> cast(CastTarget target, CastMediaRequest media) async {
    await disconnect();
    if (target.kind == CastTargetKind.roku) {
      await _castToRoku(target, media);
      _activeTarget = target;
      return;
    }

    final device = _nativeDevices[target.id];
    if (device == null) {
      throw StateError('A TV não está mais disponível na rede.');
    }

    native_cast.CastSession session;
    if (device.protocol == native_cast.CastProtocol.dlna) {
      session = native_cast.DlnaSession.fromDevice(device);
      await session.connect();
    } else {
      session = await _castService.connect(device);
    }

    await session.loadMedia(
      native_cast.CastMedia(
        url: media.url,
        type: _mediaType(media.url),
        title: media.title,
        imageUrl: media.imageUrl,
        startPosition: media.startPosition,
      ),
    );
    _activeSession = session;
    _activeTarget = target;
  }

  native_cast.CastMediaType _mediaType(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8') || lower.contains('hls')) {
      return native_cast.CastMediaType.hls;
    }
    if (lower.contains('.mkv')) return native_cast.CastMediaType.mkv;
    if (lower.contains('.ts')) return native_cast.CastMediaType.mpegTs;
    return native_cast.CastMediaType.mp4;
  }

  Future<void> _castToRoku(
    CastTarget target,
    CastMediaRequest media,
  ) async {
    final launch = Uri(
      scheme: 'http',
      host: target.address,
      port: target.port,
      path: '/launch/15985',
    );
    final launchResponse =
        await http.post(launch).timeout(const Duration(seconds: 5));
    if (launchResponse.statusCode < 200 || launchResponse.statusCode >= 400) {
      throw StateError(
        'Instale o Roku Media Player e habilite o controle por apps móveis.',
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 900));
    final lower = media.url.toLowerCase();
    final format = lower.contains('.m3u8')
        ? 'hls'
        : lower.contains('.mkv')
            ? 'mkv'
            : 'mp4';
    final input = Uri(
      scheme: 'http',
      host: target.address,
      port: target.port,
      path: '/input/15985',
      queryParameters: {
        't': 'v',
        'u': media.url,
        'videoName': media.title,
        'videoFormat': format,
      },
    );
    final response = await http.post(input).timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw StateError('O Roku recusou a reprodução desta fonte.');
    }
  }

  @override
  Future<void> disconnect() async {
    if (_activeSession != null) {
      try {
        await _activeSession!.stop();
      } catch (_) {}
      await _activeSession!.disconnect();
      _activeSession = null;
    }
    if (_activeTarget?.kind == CastTargetKind.roku) {
      try {
        await http
            .post(
              Uri(
                scheme: 'http',
                host: _activeTarget!.address,
                port: _activeTarget!.port,
                path: '/keypress/Home',
              ),
            )
            .timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
    _activeTarget = null;
  }

  @override
  Future<void> dispose() async {
    stopDiscovery();
    await disconnect();
    await _castService.dispose();
  }
}
