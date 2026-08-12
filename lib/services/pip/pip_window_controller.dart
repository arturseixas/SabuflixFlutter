import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/media_item.dart';
import '../../screens/video_player_screen.dart';
import '../../utils/app_route.dart';
import 'pip_window_args.dart';

/// Lets the floating PiP window navigate back into the main window (the
/// "expand" action) without a BuildContext of its own — it's driven by a
/// cross-engine method call, not a widget tree, so this is how it reaches
/// the app's `Navigator`.
final GlobalKey<NavigatorState> pipNavigatorKey = GlobalKey<NavigatorState>();

/// Owns the Windows Picture-in-Picture floating window from the main
/// window's side: creates it, and reacts when it hands playback back
/// ("restore") or closes.
///
/// The floating window (`PipPlayerWindow`) runs its own independent
/// media_kit player in a separate Flutter engine — once opened, it has no
/// further dependency on this controller or the main window at all, which
/// is exactly what makes it survive navigating away, minimizing, or
/// switching to a different application.
///
/// Windows-only; a safe no-op everywhere else since `desktop_multi_window`
/// isn't even registered as a plugin on other platforms.
class PipWindowController {
  PipWindowController._();
  static final PipWindowController instance = PipWindowController._();

  static bool get isSupported => Platform.isWindows;

  WindowController? _windowController;
  _PipContext? _context;
  WindowMethodChannel? _channel;

  /// Completed when the floating window reports it has finished sizing and
  /// positioning itself and is on screen.
  Completer<void>? _readyCompleter;

  bool get isActive => _windowController != null;

  /// Returns whether the floating window actually made it on screen, so the
  /// caller can keep the full-screen player instead of dropping the user on
  /// a blank screen when it didn't.
  Future<bool> open({
    required MediaItem media,
    int? season,
    int? episode,
    String? episodeTitle,
    required String videoUrl,
    required String title,
    String? imageUrl,
    required Duration startAt,
  }) async {
    if (!isSupported) return false;

    // Only one floating window at a time — starting a new one replaces
    // whatever was already floating.
    await close();

    _context = _PipContext(
      media: media,
      season: season,
      episode: episode,
      episodeTitle: episodeTitle,
      videoUrl: videoUrl,
    );

    final channelName = '${PipWindowArgs.defaultChannelName}_${DateTime.now().microsecondsSinceEpoch}';
    final channel = WindowMethodChannel(channelName);
    await channel.setMethodCallHandler(_handleMessage);
    _channel = channel;

    final args = PipWindowArgs(
      videoUrl: videoUrl,
      title: title,
      imageUrl: imageUrl,
      startAtSeconds: startAt.inSeconds,
      channelName: channelName,
    );

    final ready = Completer<void>();
    _readyCompleter = ready;
    try {
      final controller = await WindowController.create(
        WindowConfiguration(hiddenAtLaunch: true, arguments: args.toArguments()),
      );
      _windowController = controller;

      // The window is created hidden so it can size and position itself
      // before appearing, instead of flashing at the default 800x600 in the
      // corner. If it never reports back, show it anyway — a slightly ugly
      // window beats an invisible one the user can't find or close.
      try {
        await ready.future.timeout(const Duration(seconds: 6));
      } on TimeoutException {
        await controller.show();
      }
      return true;
    } catch (_) {
      _windowController = null;
      _context = null;
      _releaseChannel();
      return false;
    } finally {
      _readyCompleter = null;
    }
  }

  /// Drops this session's channel handler. Not awaited on purpose — it is
  /// often called from inside a handler for that very channel.
  void _releaseChannel() {
    final channel = _channel;
    _channel = null;
    channel?.setMethodCallHandler(null).catchError((_) {});
  }

  Future<dynamic> _handleMessage(MethodCall call) async {
    switch (call.method) {
      case 'ready':
        if (_readyCompleter?.isCompleted == false) _readyCompleter!.complete();
        break;
      case 'restore':
        final seconds = (call.arguments as num?)?.toInt() ?? 0;
        _restore(Duration(seconds: seconds));
        break;
      case 'closed':
        _windowController = null;
        _context = null;
        _releaseChannel();
        break;
    }
    return null;
  }

  void _restore(Duration position) {
    final ctx = _context;
    _windowController = null;
    _context = null;
    _releaseChannel();
    if (ctx == null) return;
    pipNavigatorKey.currentState?.push(
      glassRoute(
        VideoPlayerScreen(
          media: ctx.media,
          videoUrl: ctx.videoUrl,
          season: ctx.season,
          episode: ctx.episode,
          episodeTitle: ctx.episodeTitle,
          startAt: position,
        ),
      ),
    );
  }

  /// Asks the floating window to close itself, if one is open — lets it
  /// tear its own player down cleanly instead of force-killing the window.
  /// Safe to call with none active.
  Future<void> close() async {
    final channel = _channel;
    if (_windowController == null) {
      _releaseChannel();
      return;
    }
    _windowController = null;
    _context = null;
    try {
      await channel?.invokeMethod('close');
    } catch (_) {}
    _releaseChannel();
  }
}

class _PipContext {
  final MediaItem media;
  final int? season;
  final int? episode;
  final String? episodeTitle;
  final String videoUrl;

  _PipContext({
    required this.media,
    this.season,
    this.episode,
    this.episodeTitle,
    required this.videoUrl,
  });
}
