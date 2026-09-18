import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cast_provider.dart';
import '../screens/cast_remote_screen.dart';
import '../services/cast/cast_device.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_route.dart';

/// Persistent strip shown while a title plays on the TV, so the viewer can
/// keep browsing and still pause or jump back to the remote.
class CastMiniBar extends StatelessWidget {
  const CastMiniBar({super.key});

  @override
  Widget build(BuildContext context) {
    final cast = context.watch<CastProvider>();
    final playing = cast.nowPlaying;
    if (playing == null || !cast.isConnected) return const SizedBox.shrink();
    final colors = SabuflixTheme.of(context);
    final status = cast.status;

    return Material(
      color: colors.surface,
      child: InkWell(
        onTap: () =>
            Navigator.push(context, glassRoute(const CastRemoteScreen())),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: status.progress,
              minHeight: 2,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: SabuflixTheme.radiusSm,
                    child: SizedBox(
                      width: 56,
                      height: 32,
                      child: CachedNetworkImage(
                        imageUrl: playing.media.fullBackdropPath,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            ColoredBox(color: colors.surfaceLight),
                        errorWidget: (_, __, ___) =>
                            ColoredBox(color: colors.surfaceLight),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(playing.media.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: colors.title(fontSize: 13)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.cast_connected_rounded,
                                size: 12, color: colors.accent),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${cast.device?.name ?? 'TV'} · ${playing.subtitle}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: colors.caption(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (status.state == CastPlayerState.buffering)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else
                    IconButton(
                      tooltip: status.isPlaying ? 'Pausar' : 'Reproduzir',
                      onPressed: () =>
                          cast.togglePlayPause().catchError((_) {}),
                      icon: Icon(status.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                    ),
                  IconButton(
                    tooltip: 'Parar na TV',
                    onPressed: () => cast.stop().catchError((_) {}),
                    icon: const Icon(Icons.stop_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
