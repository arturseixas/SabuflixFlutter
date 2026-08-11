import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cast_provider.dart';
import '../theme/sabuflix_theme.dart';

/// Full-screen remote control, shown while a television is playing.
///
/// Deliberately not a miniature player: there is nothing to watch here, so the
/// space goes to the device name and to controls big enough to hit without
/// looking away from the TV.
class CastingPanel extends StatelessWidget {
  final String title;
  final String subtitle;

  /// Stops playback on the television. The player screen also uses this to
  /// pick local playback back up where the TV left off.
  final Future<void> Function() onStop;

  final VoidCallback onBack;

  const CastingPanel({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.onStop,
    required this.onBack,
  }) : super(key: key);

  static String formatDuration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final cast = context.watch<CastProvider>();
    final status = cast.status;
    final deviceName = cast.connectedDevice?.name ?? 'TV';

    return Container(
      color: Colors.black.withValues(alpha: 0.92),
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
                onPressed: onBack,
              ),
            ),
            const Spacer(),
            const Icon(Icons.cast_connected_rounded, color: SabuflixTheme.accent, size: 54),
            const SizedBox(height: 18),
            Text(
              'Reproduzindo em $deviceName',
              textAlign: TextAlign.center,
              style: SabuflixTheme.title(fontSize: 20, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                subtitle.isEmpty ? title : '$title · $subtitle',
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: SabuflixTheme.body(fontSize: 14, color: SabuflixTheme.textSecondary),
              ),
            ),
            const Spacer(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(3)),
                    child: LinearProgressIndicator(
                      value: status.progress,
                      minHeight: 4,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(SabuflixTheme.accent),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatDuration(status.position),
                        style: SabuflixTheme.caption(fontSize: 12, color: Colors.white70),
                      ),
                      Text(
                        // A renderer reports no duration until it has parsed
                        // the container, which can take a few seconds.
                        status.duration > Duration.zero ? formatDuration(status.duration) : '--:--',
                        style: SabuflixTheme.caption(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                  onPressed: () => cast.seekBy(const Duration(seconds: -10)),
                ),
                const SizedBox(width: 26),
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: SabuflixTheme.accent, shape: BoxShape.circle),
                  child: IconButton(
                    iconSize: 38,
                    icon: Icon(
                      status.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                    ),
                    onPressed: cast.togglePlayPause,
                  ),
                ),
                const SizedBox(width: 26),
                IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                  onPressed: () => cast.seekBy(const Duration(seconds: 10)),
                ),
              ],
            ),
            const SizedBox(height: 26),

            TextButton.icon(
              onPressed: onStop,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.stop_rounded, size: 20),
              label: Text(
                'Parar transmissão',
                style: SabuflixTheme.body(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
