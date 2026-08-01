import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../providers/downloads_provider.dart';
import '../services/froststream_service.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_route.dart';
import '../screens/video_player_screen.dart';
import 'cast_device_sheet.dart';
import 'glass_container.dart';

/// Fetches the available sources for [media] (and [season]/[episode] for TV)
/// and lets the user pick one to play or download. Shared between the details
/// screen and the "Continuar assistindo" row so both open the same picker.
///
/// If the title is already downloaded, playback starts straight from the local
/// file — no network round-trip, works offline.
Future<void> showStreamSelectorSheet(
  BuildContext context, {
  required MediaItem media,
  int? season,
  int? episode,
}) async {
  final localPath = context.read<DownloadsProvider>().localPathFor(
        media.id,
        season: season,
        episode: episode,
      );
  if (localPath != null) {
    Navigator.push(context, glassRoute(VideoPlayerScreen(
      media: media,
      videoUrl: localPath,
      season: season,
      episode: episode,
    )));
    return;
  }

  final imdbId = media.imdbId;
  if (imdbId == null || imdbId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ID do IMDB não encontrado para buscar as fontes.')),
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return GlassContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        padding: const EdgeInsets.all(24),
        blur: 40,
        fillOpacity: 0.4,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: FrostStreamService.fetchStreams(
            imdbId: imdbId,
            type: media.mediaType,
            season: season,
            episode: episode,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: SabuflixTheme.accent));
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text('Nenhuma fonte encontrada', style: SabuflixTheme.body(color: Colors.white)));
            }

            final streams = snapshot.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Selecione uma Fonte', style: SabuflixTheme.title(fontSize: 20)),
                const SizedBox(height: 4),
                Text(
                  'Toque para assistir ou baixe para ver offline.',
                  style: SabuflixTheme.caption(fontSize: 12, color: SabuflixTheme.textMuted),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: streams.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final s = streams[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusMd),
                        tileColor: Colors.white.withValues(alpha: 0.08),
                        title: Text(s['name'] ?? 'Stream', style: SabuflixTheme.body(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 16)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            s['title'] ?? 'Qualidade desconhecida',
                            style: SabuflixTheme.body(fontSize: 13, color: Colors.white70, height: 1.4),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Transmitir para TV',
                              icon: const Icon(Icons.cast_rounded, color: Colors.white70, size: 24),
                              onPressed: () => _castStream(context, ctx, media, s, season, episode),
                            ),
                            IconButton(
                              tooltip: 'Baixar',
                              icon: const Icon(Icons.download_rounded, color: Colors.white70, size: 24),
                              onPressed: () => _startDownload(context, ctx, media, s, season, episode),
                            ),
                            const Icon(Icons.play_circle_fill_rounded, color: SabuflixTheme.accent, size: 36),
                          ],
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(context, glassRoute(VideoPlayerScreen(
                            media: media,
                            videoUrl: s['url'],
                            season: season,
                            episode: episode,
                          )));
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

void _castStream(
  BuildContext pageContext,
  BuildContext sheetContext,
  MediaItem media,
  Map<String, dynamic> stream,
  int? season,
  int? episode,
) {
  final url = stream['url'];
  if (url == null || url.toString().isEmpty) return;

  Navigator.pop(sheetContext);
  showCastDeviceSheet(
    pageContext,
    mediaUrl: url.toString(),
    title: media.title,
    posterUrl: media.fullBackdropPath,
  );
}

Future<void> _startDownload(
  BuildContext pageContext,
  BuildContext sheetContext,
  MediaItem media,
  Map<String, dynamic> stream,
  int? season,
  int? episode,
) async {
  final url = stream['url'];
  if (url == null || url.toString().isEmpty) return;

  final provider = pageContext.read<DownloadsProvider>();
  final added = await provider.enqueue(
    media: media,
    sourceUrl: url.toString(),
    qualityLabel: stream['name']?.toString() ?? 'Download',
    season: season,
    episode: episode,
  );

  if (sheetContext.mounted) Navigator.pop(sheetContext);
  if (!pageContext.mounted) return;

  ScaffoldMessenger.of(pageContext).showSnackBar(
    SnackBar(
      content: Text(added
          ? 'Download iniciado — acompanhe na aba Downloads.'
          : 'Esse título já está na sua lista de downloads.'),
    ),
  );
}
