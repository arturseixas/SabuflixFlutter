import 'dart:async';
import 'dart:js_interop';

import 'package:media_kit/media_kit.dart';

import 'picture_in_picture_platform.dart';

@JS('sabuflixPip.isSupported')
external JSBoolean _isSupported(JSNumber handle);

@JS('sabuflixPip.isActive')
external JSBoolean _isActive(JSNumber handle);

@JS('sabuflixPip.attach')
external void _attach(JSNumber handle, JSFunction callback);

@JS('sabuflixPip.enter')
external JSPromise<JSBoolean> _enter(JSNumber handle);

@JS('sabuflixPip.exit')
external JSPromise<JSBoolean> _exit(JSNumber handle);

@JS('sabuflixPip.detach')
external void _detach(JSNumber handle);

PictureInPicturePlatform createPlatformImplementation() =>
    _WebPictureInPicturePlatform();

class _WebPictureInPicturePlatform implements PictureInPicturePlatform {
  final StreamController<bool> _states =
      StreamController<bool>.broadcast(sync: true);

  int? _handle;
  JSFunction? _callback;

  @override
  bool get isSupported {
    final handle = _handle;
    return handle != null && _isSupported(handle.toJS).toDart;
  }

  @override
  bool get isActive {
    final handle = _handle;
    return handle != null && _isActive(handle.toJS).toDart;
  }

  @override
  Stream<bool> get states => _states.stream;

  @override
  Future<void> attach(Player player) async {
    final handle = await player.handle;
    _handle = handle;
    _callback = ((JSBoolean active) {
      if (!_states.isClosed) _states.add(active.toDart);
    }).toJS;
    _attach(handle.toJS, _callback!);
  }

  @override
  Future<void> enter() async {
    final handle = _handle;
    if (handle == null || !isSupported) return;
    await _enter(handle.toJS).toDart;
  }

  @override
  Future<void> exit() async {
    final handle = _handle;
    if (handle == null || !isActive) return;
    await _exit(handle.toJS).toDart;
  }

  @override
  Future<void> dispose() async {
    final handle = _handle;
    if (handle != null) _detach(handle.toJS);
    _handle = null;
    _callback = null;
    await _states.close();
  }
}
