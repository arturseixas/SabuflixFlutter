import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../main.dart' show navigatorKey;
import '../providers/pip_controller.dart';
import '../screens/video_player_screen.dart';

/// Draggable floating mini-player shown above every screen in the app
/// while a video has been minimized (used on platforms without a native
/// OS-level Picture-in-Picture, e.g. iOS, Windows, macOS, Linux and web).
class PipOverlay extends StatelessWidget {
  const PipOverlay({Key? key}) : super(key: key);

  static const double _width = 168;
  static const double _height = 94;

  @override
  Widget build(BuildContext context) {
    return Consumer<PipController>(
      builder: (context, pip, _) {
        if (!pip.isActive) return const SizedBox.shrink();

        final session = pip.session!;
        final screenSize = MediaQuery.of(context).size;
        final maxX = (screenSize.width - _width).clamp(0.0, double.infinity);
        final maxY = (screenSize.height - _height).clamp(0.0, double.infinity);
        final clampedOffset = Offset(
          pip.offset.dx.clamp(0.0, maxX),
          pip.offset.dy.clamp(0.0, maxY),
        );

        return Positioned(
          left: clampedOffset.dx,
          top: clampedOffset.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              final updated = pip.offset + details.delta;
              pip.updateOffset(Offset(
                updated.dx.clamp(0.0, maxX),
                updated.dy.clamp(0.0, maxY),
              ));
            },
            onTap: () => _expand(pip),
            child: Material(
              color: Colors.black,
              elevation: 12,
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: _width,
                height: _height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Video(
                      controller: session.videoController,
                      controls: NoVideoControls,
                      fill: Colors.black,
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: _MiniButton(
                        icon: Icons.close_rounded,
                        onTap: pip.close,
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      left: 2,
                      child: StreamBuilder<bool>(
                        stream: session.player.stream.playing,
                        initialData: session.player.state.playing,
                        builder: (context, snapshot) {
                          final playing = snapshot.data ?? false;
                          return _MiniButton(
                            icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            onTap: session.player.playOrPause,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _expand(PipController pip) {
    final session = pip.session!;
    pip.clearWithoutDispose();
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          media: session.media,
          existingPlayer: session.player,
          existingController: session.videoController,
        ),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MiniButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 14),
      ),
    );
  }
}
