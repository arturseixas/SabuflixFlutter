import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

/// Shrinks the app window itself into a small always-on-top floating player
/// pinned to a screen corner, similar to Firefox's Picture-in-Picture on
/// desktop, so the video keeps playing while the user works in another app.
class DesktopPipService {
  DesktopPipService._();
  static final DesktopPipService instance = DesktopPipService._();

  static bool get isSupported =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  static const double pipWidth = 420;
  static const double pipHeight = pipWidth * 9 / 16;
  static const double _margin = 24;

  Rect? _savedBounds;
  bool _active = false;
  bool get isActive => _active;

  Future<void> enter() async {
    if (!isSupported || _active) return;

    _savedBounds = await windowManager.getBounds();

    Offset position = Offset(
      _savedBounds!.left,
      _savedBounds!.top,
    );
    try {
      final display = await ScreenRetriever.instance.getPrimaryDisplay();
      final screenSize = display.size;
      position = Offset(
        screenSize.width - pipWidth - _margin,
        screenSize.height - pipHeight - _margin,
      );
    } catch (_) {
      // Fall back to keeping the window where it already was.
    }

    await windowManager.setResizable(false);
    await windowManager.setBounds(
      Rect.fromLTWH(position.dx, position.dy, pipWidth, pipHeight),
    );
    await windowManager.setAlwaysOnTop(true);
    _active = true;
  }

  Future<void> exit() async {
    if (!isSupported || !_active) return;
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setResizable(true);
    if (_savedBounds != null) {
      await windowManager.setBounds(_savedBounds!);
    }
    _active = false;
  }
}
