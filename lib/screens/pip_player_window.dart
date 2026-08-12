import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../services/pip/pip_window_args.dart';
import '../theme/sabuflix_theme.dart';

const _pipSize = Size(400, 225); // 16:9
const _pipMargin = 24.0;

/// The Windows Picture-in-Picture floating window itself — a small,
/// frameless, always-on-top window running its own independent media_kit
/// player. It has no dependency on the main window staying open or even
/// visible: closing/minimizing the main Sabuflix window, switching to a
/// different app, or alt-tabbing away all leave this window floating and
/// playing right where it is, the same shape as Firefox's own PiP.
///
/// Runs as its own `runApp` root inside a separate Flutter engine spawned
/// by `desktop_multi_window` — see `main.dart`'s `multi_window` branch.
class PipPlayerWindow extends StatefulWidget {
  final PipWindowArgs args;

  const PipPlayerWindow({super.key, required this.args});

  @override
  State<PipPlayerWindow> createState() => _PipPlayerWindowState();
}

class _PipPlayerWindowState extends State<PipPlayerWindow> with WindowListener {
  /// Named by the main window, unique to this session — see
  /// [PipWindowArgs.channelName].
  late final WindowMethodChannel _pipChannel = WindowMethodChannel(widget.args.channelName);

  late final Player _player;
  late final VideoController _videoController;
  bool _isPlaying = true;
  bool _showControls = true;
  Timer? _hideTimer;
  StreamSubscription? _playingSub;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // Registered before anything else: the channel pairs the two engines, and
    // the `ready` handshake below is dropped if the main window isn't paired
    // yet by the time it fires.
    _pipChannel.setMethodCallHandler(_handleMessage);
    _setUpPlayer();
    _setUpWindow();
    _startHideTimer();
  }

  Future<void> _setUpWindow() async {
    Offset position = Offset(_pipMargin, _pipMargin);
    try {
      final display = await screenRetriever.getPrimaryDisplay();
      final screenSize = display.visibleSize ?? display.size;
      position = Offset(
        screenSize.width - _pipSize.width - _pipMargin,
        screenSize.height - _pipSize.height - _pipMargin,
      );
    } catch (_) {
      // Fall back to a top-left placement if the primary display can't be
      // read — still floats on top, just not in the usual corner.
    }

    const options = WindowOptions(
      size: _pipSize,
      minimumSize: Size(240, 135),
      backgroundColor: Colors.black,
      skipTaskbar: true,
      alwaysOnTop: true,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );

    try {
      await windowManager.waitUntilReadyToShow(options, () async {
        // Cosmetics are best-effort — none of them are worth leaving the
        // window hidden over, since it launches with SW_HIDE and only the
        // show() below puts it on screen.
        try {
          await windowManager.setAsFrameless();
          await windowManager.setAspectRatio(_pipSize.width / _pipSize.height);
          await windowManager.setPosition(position);
          await windowManager.setPreventClose(true);
        } catch (_) {}
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (_) {
      // Last resort: get it visible even if the configuration pass blew up.
      try {
        await windowManager.show();
      } catch (_) {}
    }
    _notifyReady();
  }

  void _notifyReady() {
    // Lets the main window stop waiting and hand playback over. If this never
    // arrives it falls back to showing the window itself.
    _pipChannel.invokeMethod('ready').catchError((_) => null);
  }

  void _setUpPlayer() {
    _player = Player();
    _videoController = VideoController(_player);
    _playingSub = _player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });

    _player.open(Media(widget.args.videoUrl));
    final startAt = widget.args.startAtSeconds;
    if (startAt > 0) {
      _player.stream.duration.first.then((_) => _player.seek(Duration(seconds: startAt)));
    }
  }

  Future<dynamic> _handleMessage(MethodCall call) async {
    if (call.method == 'close') {
      await _closeAndNotify();
    }
    return null;
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControlsVisible() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  /// "Expand" — hands playback back to the main window's full player at the
  /// exact position this window stopped at, then closes itself.
  Future<void> _restore() async {
    try {
      await _pipChannel.invokeMethod('restore', _player.state.position.inSeconds);
    } catch (_) {}
    await _teardown();
  }

  /// User-initiated close (our own "X", or the OS close affordance via
  /// `onWindowClose`) — just stops, no handoff back to the main window.
  Future<void> _closeAndNotify() async {
    try {
      await _pipChannel.invokeMethod('closed');
    } catch (_) {}
    await _teardown();
  }

  Future<void> _teardown() async {
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  @override
  void onWindowClose() {
    _closeAndNotify();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _hideTimer?.cancel();
    _playingSub?.cancel();
    _pipChannel.setMethodCallHandler(null);
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: SabuflixTheme.themeData,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => windowManager.startDragging(),
          onTap: _toggleControlsVisible,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Video(controller: _videoController, controls: NoVideoControls, fill: Colors.black),
              if (_showControls) Container(color: Colors.black.withValues(alpha: 0.35)),
              if (_showControls)
                Positioned(
                  top: 6,
                  left: 6,
                  child: _PipButton(icon: Icons.open_in_full_rounded, onTap: _restore),
                ),
              if (_showControls)
                Positioned(
                  top: 6,
                  right: 6,
                  child: _PipButton(icon: Icons.close_rounded, onTap: _closeAndNotify),
                ),
              if (_showControls)
                Center(
                  child: _PipButton(
                    size: 40,
                    icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    onTap: () => _isPlaying ? _player.pause() : _player.play(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PipButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _PipButton({required this.icon, required this.onTap, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: size * 0.55),
      ),
    );
  }
}
