import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../screens/video_player_screen.dart';
import '../services/playback_service.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_navigator.dart';
import '../utils/app_route.dart';
import '../utils/haptics.dart';

/// The in-app Picture-in-Picture window.
///
/// Android hands PiP to the OS; on Windows, Linux, macOS, iOS and web this
/// draggable overlay is the PiP window. It sits above the navigator so the
/// film keeps playing while the user browses the catalogue.
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  static const double _width = 288;
  static const double _height = 162; // 16:9
  static const double _margin = 20;

  final PlaybackService _playback = PlaybackService.instance;

  Offset? _position;
  bool _hovering = false;

  void _expand() {
    final media = _playback.media;
    if (media == null) return;
    Haptics.selection();
    _playback.exitPip();
    appNavigatorKey.currentState?.push(
      glassRoute(VideoPlayerScreen(
        media: media,
        videoUrl: _playback.videoUrl,
        season: _playback.season,
        episode: _playback.episode,
        sourceLabel: _playback.sourceLabel,
        resumeExisting: true,
      )),
    );
  }

  void _close() {
    Haptics.selection();
    unawaited(_playback.stop());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _playback,
      builder: (context, _) {
        // Nothing to show when playback is full screen, stopped, or already
        // living in the system's own PiP window.
        if (!_playback.isPipActive || _playback.isSystemPip || !_playback.hasMedia) {
          return const SizedBox.shrink();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final maxX = (constraints.maxWidth - _width - _margin).clamp(0.0, double.infinity);
            final maxY = (constraints.maxHeight - _height - _margin).clamp(0.0, double.infinity);
            final position = _position ?? Offset(maxX, maxY);
            final clamped = Offset(
              position.dx.clamp(_margin, maxX < _margin ? _margin : maxX),
              position.dy.clamp(_margin, maxY < _margin ? _margin : maxY),
            );

            return Stack(
              children: [
                Positioned(
                  left: clamped.dx,
                  top: clamped.dy,
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _hovering = true),
                    onExit: (_) => setState(() => _hovering = false),
                    child: GestureDetector(
                      onTap: _expand,
                      onPanUpdate: (details) {
                        setState(() => _position = clamped + details.delta);
                      },
                      child: _buildWindow(),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildWindow() {
    final media = _playback.media!;
    final showChrome = _hovering;

    return Material(
      color: Colors.transparent,
      elevation: 18,
      borderRadius: SabuflixTheme.radiusMd,
      shadowColor: Colors.black.withValues(alpha: 0.6),
      child: ClipRRect(
        borderRadius: SabuflixTheme.radiusMd,
        child: SizedBox(
          width: _width,
          height: _height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_playback.hasVideo)
                Video(
                  controller: _playback.videoController!,
                  controls: NoVideoControls,
                  fill: Colors.black,
                )
              else
                CachedNetworkImage(
                  imageUrl: media.fullBackdropPath,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: SabuflixTheme.surface),
                ),

              if (_playback.isBuffering)
                const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                ),

              AnimatedOpacity(
                duration: SabuflixTheme.durationFast,
                opacity: showChrome ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !showChrome,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.45),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Row(
                            children: [
                              _MiniButton(
                                icon: Icons.open_in_full_rounded,
                                onPressed: _expand,
                              ),
                              _MiniButton(
                                icon: Icons.close_rounded,
                                onPressed: _close,
                              ),
                            ],
                          ),
                        ),
                        Center(
                          child: _MiniButton(
                            size: 34,
                            icon: _playback.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            onPressed: () {
                              Haptics.light();
                              _playback.playOrPause();
                            },
                          ),
                        ),
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 8,
                          child: Text(
                            _playback.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SabuflixTheme.body(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: _playback.duration.inSeconds > 0
                      ? (_playback.position.inSeconds / _playback.duration.inSeconds)
                          .clamp(0.0, 1.0)
                      : 0,
                  minHeight: 2.5,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation(SabuflixTheme.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;

  const _MiniButton({
    required this.icon,
    required this.onPressed,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    // No Tooltip here: the mini player is mounted above the navigator, so
    // there is no Overlay ancestor for a tooltip to render into.
    return IconButton(
      iconSize: size,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(),
      icon: Icon(icon, color: Colors.white),
      onPressed: onPressed,
    );
  }
}
