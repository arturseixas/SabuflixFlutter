import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cast_provider.dart';
import '../screens/cast_control_screen.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_route.dart';
import 'glass_container.dart';

/// The "playing on the TV" strip, shown over the whole app while a cast is
/// running.
///
/// Without it, walking out of the player would leave a television playing with
/// no way to pause or stop it short of finding the title again — the single
/// most common way a casting feature turns into a complaint.
class CastBar extends StatelessWidget {
  const CastBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cast = context.watch<CastProvider>();
    if (!cast.isCasting) return const SizedBox.shrink();

    final device = cast.connectedDevice;
    final title = cast.castingTitle ?? 'Sabuflix';

    return GlassContainer(
      borderRadius: SabuflixTheme.radiusMd,
      blur: 30,
      fillOpacity: 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: SabuflixTheme.radiusMd,
          onTap: () => Navigator.push(context, glassRoute(const CastControlScreen())),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Row(
              children: [
                const Icon(Icons.cast_connected_rounded, color: SabuflixTheme.accent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SabuflixTheme.caption(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: SabuflixTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Reproduzindo em ${device?.name ?? 'TV'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SabuflixTheme.caption(fontSize: 11, color: SabuflixTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: cast.status.isPlaying ? 'Pausar' : 'Continuar',
                  icon: Icon(
                    cast.status.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: SabuflixTheme.textPrimary,
                  ),
                  onPressed: cast.togglePlayPause,
                ),
                IconButton(
                  tooltip: 'Parar transmissão',
                  icon: const Icon(Icons.stop_rounded, color: SabuflixTheme.textSecondary),
                  onPressed: cast.stopCasting,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
