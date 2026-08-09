import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// Desktop picture-in-picture: the app's own window shrinks to a small,
/// borderless, always-on-top frame showing just the video.
///
/// A Flutter desktop app has one window, so "pop the video out" means
/// converting that window rather than opening a second one. The result is the
/// same as Firefox's: a small frame floating above every other program, which
/// you drag and resize with the mouse.
class DesktopPip {
  static const Size _pipSize = Size(440, 247); // 16:9

  static Size? _savedSize;
  static Offset? _savedPosition;
  static bool _active = false;

  static bool get isActive => _active;

  static bool get isSupported {
    if (kIsWeb) return false;
    try {
      return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  /// Must run before the app is shown, so the window can be manipulated later.
  static Future<void> init() async {
    if (!isSupported) return;
    try {
      await windowManager.ensureInitialized();
    } catch (e) {
      debugPrint('Sabuflix: window_manager indisponível: $e');
    }
  }

  /// Shrinks and pins the window. Returns false if the platform refused, so
  /// the caller can fall back to the in-app floating window.
  static Future<bool> enter() async {
    if (!isSupported || _active) return false;
    try {
      // Remembered so leaving picture-in-picture puts the window back exactly
      // where the user had it.
      _savedSize = await windowManager.getSize();
      _savedPosition = await windowManager.getPosition();

      await windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSize(_pipSize);
      await windowManager.setAlignment(Alignment.bottomRight);

      _active = true;
      return true;
    } catch (e) {
      debugPrint('Sabuflix: falha ao entrar no PiP de janela: $e');
      // Undo anything that did apply, so the window is not left half-converted.
      await _restore();
      return false;
    }
  }

  static Future<void> exit() async {
    if (!isSupported || !_active) return;
    await _restore();
  }

  static Future<void> _restore() async {
    try {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setTitleBarStyle(
        TitleBarStyle.normal,
        windowButtonVisibility: true,
      );
      final size = _savedSize;
      if (size != null) await windowManager.setSize(size);
      final position = _savedPosition;
      if (position != null) await windowManager.setPosition(position);
    } catch (e) {
      debugPrint('Sabuflix: falha ao restaurar a janela: $e');
    } finally {
      _active = false;
      _savedSize = null;
      _savedPosition = null;
    }
  }

  /// Lets the borderless window be dragged by its video area, since it no
  /// longer has a title bar to grab.
  static Future<void> startDragging() async {
    if (!isSupported || !_active) return;
    try {
      await windowManager.startDragging();
    } catch (_) {
      // Dragging is a convenience; failing it must not break playback.
    }
  }
}
