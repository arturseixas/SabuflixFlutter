import 'package:flutter/material.dart';

import '../../theme/sabuflix_theme.dart';

/// `1:02:03` / `02:03`.
String formatPlayerTime(Duration duration) {
  if (duration.isNegative) duration = Duration.zero;
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

/// Round translucent control used across the player chrome.
class PlayerIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final bool active;
  final Widget? badge;

  const PlayerIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 24,
    this.active = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: size,
      style: IconButton.styleFrom(
        foregroundColor: active ? SabuflixTheme.accent : Colors.white,
        disabledForegroundColor: Colors.white38,
        backgroundColor: Colors.transparent,
        minimumSize: const Size(44, 44),
        shape: const CircleBorder(),
      ),
      icon: Icon(icon),
    );
    if (badge == null) return button;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(right: 4, top: 4, child: badge!),
      ],
    );
  }
}

/// The big play/pause disc in the middle of the screen.
class PlayerPrimaryButton extends StatelessWidget {
  final bool playing;
  final bool buffering;
  final VoidCallback onPressed;
  final double diameter;

  const PlayerPrimaryButton({
    super.key,
    required this.playing,
    required this.buffering,
    required this.onPressed,
    this.diameter = 72,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SabuflixTheme.accent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: SabuflixTheme.accent.withValues(alpha: 0.45),
            blurRadius: 22,
            spreadRadius: 2,
          ),
        ],
      ),
      child: buffering && playing
          ? SizedBox(
              width: diameter * .45,
              height: diameter * .45,
              child: const CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 3),
            )
          : IconButton(
              tooltip: playing ? 'Pausar' : 'Reproduzir',
              iconSize: diameter * .55,
              icon: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
              ),
              onPressed: onPressed,
            ),
    );
  }
}

/// Seek bar with the buffered range drawn behind the played range.
class PlayerSeekBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final ValueChanged<Duration>? onChanged;
  final ValueChanged<Duration>? onChangeStart;
  final ValueChanged<Duration>? onChangeEnd;

  const PlayerSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.buffered,
    this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds > 0 ? duration.inMilliseconds : 1;
    final value = position.inMilliseconds.clamp(0, total).toDouble();
    final bufferedFraction = (buffered.inMilliseconds / total).clamp(0.0, 1.0);
    return SizedBox(
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(2)),
              child: LinearProgressIndicator(
                value: bufferedFraction,
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: .18),
                valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: .32)),
              ),
            ),
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: SabuflixTheme.accent,
              inactiveTrackColor: Colors.transparent,
              thumbColor: SabuflixTheme.accent,
              overlayColor: SabuflixTheme.accent.withValues(alpha: .2),
              trackShape: const RectangularSliderTrackShape(),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: total.toDouble(),
              onChangeStart: onChangeStart == null
                  ? null
                  : (v) => onChangeStart!(Duration(milliseconds: v.round())),
              onChanged: onChanged == null
                  ? null
                  : (v) => onChanged!(Duration(milliseconds: v.round())),
              onChangeEnd: onChangeEnd == null
                  ? null
                  : (v) => onChangeEnd!(Duration(milliseconds: v.round())),
            ),
          ),
        ],
      ),
    );
  }
}

/// Transient "+10s" / "-10s" pill that fades after a double tap.
class SeekFeedback extends StatelessWidget {
  final int seconds;
  final bool visible;
  const SeekFeedback({super.key, required this.seconds, required this.visible});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: visible ? 1 : 0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .55),
            borderRadius: SabuflixTheme.radiusPill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                  seconds < 0
                      ? Icons.fast_rewind_rounded
                      : Icons.fast_forward_rounded,
                  color: Colors.white),
              const SizedBox(width: 8),
              Text(
                '${seconds < 0 ? '-' : '+'}${seconds.abs()}s',
                style: SabuflixTheme.title(fontSize: 16, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vertical volume indicator shown while dragging on the right edge.
class VolumeFeedback extends StatelessWidget {
  final double volume; // 0-100
  final bool visible;
  const VolumeFeedback(
      {super.key, required this.volume, required this.visible});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: visible ? 1 : 0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .55),
            borderRadius: SabuflixTheme.radiusPill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                volume <= 0
                    ? Icons.volume_off_rounded
                    : volume < 50
                        ? Icons.volume_down_rounded
                        : Icons.volume_up_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                  child: LinearProgressIndicator(
                    value: (volume / 100).clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: Colors.white24,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${volume.round()}',
                  style: SabuflixTheme.caption(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Next episode" card with a countdown ring, shown near the end of an episode.
class NextEpisodeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final int? secondsLeft;
  final bool resolving;
  final VoidCallback onPlay;
  final VoidCallback onCancel;

  const NextEpisodeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onPlay,
    required this.onCancel,
    this.imageUrl,
    this.secondsLeft,
    this.resolving = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .78),
        borderRadius: SabuflixTheme.radiusLg,
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
        boxShadow: SabuflixTheme.shadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('PRÓXIMO EPISÓDIO',
              style: SabuflixTheme.label(
                  fontSize: 10, color: Colors.white70, letterSpacing: 1.6)),
          const SizedBox(height: 8),
          Row(
            children: [
              if (imageUrl != null && imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: SabuflixTheme.radiusSm,
                  child: SizedBox(
                    width: 96,
                    height: 54,
                    child: Image.network(imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const ColoredBox(color: SabuflixTheme.surface)),
                  ),
                ),
              if (imageUrl != null && imageUrl!.isNotEmpty)
                const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subtitle,
                        style: SabuflixTheme.caption(
                            fontSize: 11, color: Colors.white70)),
                    const SizedBox(height: 2),
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SabuflixTheme.title(
                            fontSize: 14, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: resolving ? null : onPlay,
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 14)),
                  icon: resolving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.skip_next_rounded, size: 20),
                  label: Text(
                    secondsLeft != null
                        ? 'Assistir em ${secondsLeft}s'
                        : 'Assistir agora',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44)),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
