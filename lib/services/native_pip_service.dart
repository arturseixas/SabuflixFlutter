import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativePipService {
  NativePipService._();

  static final NativePipService instance = NativePipService._();
  static const _channel = MethodChannel('com.sabuflix.app/native_pip');

  ValueChanged<bool>? onPipChanged;
  bool isActive = false;

  Future<bool> isSupported() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.windows)) {
      return false;
    }
    _channel.setMethodCallHandler(_handleMethodCall);
    return await _channel.invokeMethod<bool>('isSupported') ?? false;
  }

  Future<bool> enter({int width = 16, int height = 9}) async {
    final entered = await _channel.invokeMethod<bool>('enter', {
          'width': width,
          'height': height,
        }) ??
        false;
    if (entered) _setActive(true);
    return entered;
  }

  Future<void> exit() async {
    if (!isActive) return;
    await _channel.invokeMethod<void>('exit');
    _setActive(false);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'pipChanged') {
      _setActive(call.arguments == true);
    }
  }

  void _setActive(bool value) {
    if (isActive == value) return;
    isActive = value;
    onPipChanged?.call(value);
  }
}
