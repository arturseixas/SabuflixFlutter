import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../providers/playback_controller.dart';
import '../screens/video_player_screen.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_route.dart';

/// Floating video window, modelled on the one Firefox pops out of a tab:
/// it hovers above whatever you are browsing, you drag it wherever you want,
/// it snaps to the nearest corner when released, and its controls stay out of
/// the way until you point at it.
class PipPlayer extends StatefulWidget {
  const PipPlayer({Key? key}) : super(key: key);

  @override
  State<PipPlayer> createState() => _PipPlayerState();
}

class _PipPlayerState extends State<PipPlayer> {
  static const double _margin = 16;
  static const double _minWidth = 180;
  static const double _maxWidth = 520;
  static const double _aspect = 16 / 9;

  /// Top-left corner. Null until the first layout picks the default corner.
  Offset? _origin;
  double _width = 300;

  bool _dragging = false;
  bool _resizing = false;
  bool _showControls = false;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  double get _height => _width / _aspect;

  void _revealControls() {
    setState(() => _showControls = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  /// Keeps the window fully on screen, which also handles the window being
  /// resized or the device being rotated under it.
  Offset _clamp(Offset value, Size bounds) {
    final maxX = bounds.width - _width - _margin;
    final maxY = bounds.height - _height - _margin;
    return Offset(
      value.dx.clamp(_margin, maxX < _margin ? _margin : maxX),
      value.dy.clamp(_margin, maxY < _margin ? _margin : maxY),
    );
  }

  /// Sends the window to whichever corner it was released nearest to.
  void _snap(Size bounds) {
    final origin = _origin;
    if (origin == null) return;

    final centerX = origin.dx + _width / 2;
    final centerY = origin.dy + _height / 2;

    final left = centerX < bounds.width / 2;
    final top = centerY < bounds.height / 2;

    setState(() {
      _origin = _clamp(
        Offset(
          left ? _margin : bounds.width - _width - _margin,
          top ? _margin : bounds.height - _height - _margin,
        ),
        bounds,
      );
    });
  }

  Future<void> _expand(BuildContext context, PlaybackController playback) async {
    final media = playback.media;
    if (media == null) return;

    playback.exitPip();
    await Navigator.push(
      context,
      glassRoute(VideoPlayerScreen(media: media, resumeSession: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<PlaybackController>();
    if (!playback.isPip || !playback.hasVideo) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = Size(constraints.maxWidth, constraints.maxHeight);

        // Default to the bottom-right corner, out of the way of the content
        // and of the mobile dock on the left.
        _origin ??= Offset(
          bounds.width - _width - _margin,
          bounds.height - _height - _margin * 5,
        );
        // A layout change can leave the window off screen; pull it back.
        final origin = _clamp(_origin!, bounds);

        return Stack(
          children: [
            AnimatedPositioned(
              duration: (_dragging || _resizing)
                  ? Duration.zero
                  : SabuflixTheme.durationFast,
              curve: SabuflixTheme.curveStandard,
              left: origin.dx,
              top: origin.dy,
              width: _width,
              height: _height,
              child: _buildWindow(context, playback, bounds),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWindow(
    BuildContext context,
    PlaybackController playback,
    Size bounds,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _revealControls,
      onPanStart: (_) => setState(() => _dragging = true),
      onPanUpdate: (details) {
        setState(() => _origin = _clamp(_origin! + details.delta, bounds));
      },
      onPanEnd: (_) {
        setState(() => _dragging = false);
        _snap(bounds);
      },
      child: Material(
        color: Colors.black,
        elevation: 16,
        borderRadius: SabuflixTheme.radiusMd,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Video(
              controller: playback.videoController!,
              controls: NoVideoControls,
              fill: Colors.black,
            ),

            if (playback.isBuffering)
              const Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: SabuflixTheme.accent,
                  ),
                ),
              ),

            AnimatedOpacity(
              duration: SabuflixTheme.durationFast,
              opacity: _showControls ? 1 : 0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: _buildControls(context, playback),
              ),
            ),

            // Resize grip. Firefox resizes from the window edges; a corner
            // grip is the same idea but hittable with a finger.
            Positioned(
              left: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => setState(() => _resizing = true),
                onPanUpdate: (details) {
                  setState(() {
                    // Dragging left grows the window, and the right edge is
                    // kept still so it does not crawl across the screen.
                    final right = _origin!.dx + _width;
                    final next = (_width - details.delta.dx)
                        .clamp(_minWidth, _maxWidth)
                        .toDouble();
                    _width = next;
                    _origin = _clamp(Offset(right - _width, _origin!.dy), bounds);
                  });
                },
                onPanEnd: (_) {
                  setState(() => _resizing = false);
                  _snap(bounds);
                },
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.bottomLeft,
                  padding: const EdgeInsets.all(6),
                  color: Colors.transparent,
                  child: Transform.rotate(
                    angle: 1.5708,
                    child: Icon(
                      Icons.open_in_full_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: _showControls ? 0.9 : 0.35),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context, PlaybackController playback) {
    final duration = playback.duration.inMilliseconds;
    final position = playback.position.inMilliseconds;
    final progress =
        duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0;

    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Stack(
        children: [
          Positioned(
            top: 2,
            right: 2,
            child: Row(
              children: [
                _iconButton(
                  icon: Icons.fullscreen_rounded,
                  tooltip: 'Voltar para tela cheia',
                  onPressed: () => _expand(context, playback),
                ),
                _iconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Fechar',
                  onPressed: () => playback.stop(),
                ),
              ],
            ),
          ),

          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _iconButton(
                  icon: Icons.replay_10_rounded,
                  tooltip: 'Voltar 10s',
                  size: 22,
                  onPressed: () {
                    playback.seekBy(const Duration(seconds: -10));
                    _revealControls();
                  },
                ),
                const SizedBox(width: 6),
                _iconButton(
                  icon: playback.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  tooltip: playback.isPlaying ? 'Pausar' : 'Reproduzir',
                  size: 30,
                  onPressed: () {
                    playback.playOrPause();
                    _revealControls();
                  },
                ),
                const SizedBox(width: 6),
                _iconButton(
                  icon: Icons.forward_10_rounded,
                  tooltip: 'Avançar 10s',
                  size: 22,
                  onPressed: () {
                    playback.seekBy(const Duration(seconds: 10));
                    _revealControls();
                  },
                ),
              ],
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation<Color>(SabuflixTheme.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    double size = 18,
  }) {
    return IconButton(
      tooltip: tooltip,
      iconSize: size,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(),
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: Colors.white),
      onPressed: onPressed,
    );
  }
}
