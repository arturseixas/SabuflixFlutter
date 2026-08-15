import 'dart:async';

import 'package:media_kit/media_kit.dart';

import 'picture_in_picture_platform.dart';

/// Owns the browser Picture-in-Picture session for a single player route.
///
/// Keeping this lifecycle outside the widget prevents the HTML video element
/// from being disposed while the browser still has it attached to a PiP window.
class PictureInPictureController {
  final PictureInPicturePlatform _platform = createPictureInPicturePlatform();

  StreamSubscription<bool>? _stateSubscription;
  final StreamController<bool> _states =
      StreamController<bool>.broadcast(sync: true);

  bool _isActive = false;
  bool _isSupported = false;

  bool get isActive => _isActive;
  bool get isSupported => _isSupported;
  Stream<bool> get states => _states.stream;

  Future<void> attach(Player player) async {
    await _platform.attach(player);
    _isSupported = _platform.isSupported;
    _isActive = _platform.isActive;
    _stateSubscription = _platform.states.listen((active) {
      _isActive = active;
      if (!_states.isClosed) _states.add(active);
    });
    if (!_states.isClosed) _states.add(_isActive);
  }

  Future<void> toggle() async {
    if (!_isSupported) return;
    if (_isActive) {
      await exit();
    } else {
      await _platform.enter();
    }
  }

  Future<void> exit() async {
    if (!_isActive) return;
    await _platform.exit();
  }

  Future<void> dispose() async {
    // The route closes PiP before navigation. This extra exit protects against
    // replacement/removal paths that bypass the visible back button.
    try {
      await _platform.exit();
    } catch (_) {
      // The browser may already have destroyed its PiP document during app
      // shutdown. Cleanup must still continue without surfacing an async error.
    }
    await _stateSubscription?.cancel();
    await _platform.dispose();
    await _states.close();
  }
}
