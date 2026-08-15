import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/casting/casting_service.dart';

class CastingProvider extends ChangeNotifier {
  final CastingService _service = createCastingService();
  StreamSubscription<List<CastTarget>>? _discoverySubscription;
  List<CastTarget> _devices = const [];
  bool _isDiscovering = false;
  String? _connectingDeviceId;
  String? _error;
  CastTarget? _activeTarget;

  bool get isSupported => _service.isSupported;
  List<CastTarget> get devices => List.unmodifiable(_devices);
  bool get isDiscovering => _isDiscovering;
  String? get connectingDeviceId => _connectingDeviceId;
  String? get error => _error;
  CastTarget? get activeTarget => _activeTarget;
  bool get isConnected => _activeTarget != null;

  Future<void> startDiscovery() async {
    await _discoverySubscription?.cancel();
    _devices = const [];
    _error = null;
    _isDiscovering = isSupported;
    notifyListeners();

    if (!isSupported) return;
    _discoverySubscription = _service.discover().listen(
      (devices) {
        _devices = devices;
        notifyListeners();
      },
      onError: (Object error) {
        _error = 'Não foi possível procurar TVs nesta rede.';
        _isDiscovering = false;
        notifyListeners();
      },
      onDone: () {
        _isDiscovering = false;
        notifyListeners();
      },
    );
  }

  Future<bool> castTo(CastTarget target, CastMediaRequest media) async {
    _connectingDeviceId = target.id;
    _error = null;
    notifyListeners();
    try {
      await _service.cast(target, media);
      _activeTarget = target;
      return true;
    } catch (error) {
      _error = error.toString().replaceFirst('Bad state: ', '');
      return false;
    } finally {
      _connectingDeviceId = null;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    try {
      await _service.disconnect();
    } finally {
      _activeTarget = null;
      notifyListeners();
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_discoverySubscription?.cancel());
    unawaited(_service.dispose());
    super.dispose();
  }
}
