import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/watch_history_item.dart';
import '../providers/watch_history_provider.dart';
import '../theme/sabuflix_theme.dart';
import 'stream_selector_sheet.dart';

/// "Continuar assistindo" row: shows the last titles the user watched with
/// a progress bar, letting them jump back in (or remove/clear the history).
class ContinueWatchingRow extends StatelessWidget {
  const ContinueWatchingRow({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<WatchHistoryProvider>(
      builder: (context, historyProvider, _) {
        final history = historyProvider.history;
        if (history.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Continuar Assistindo',
                    style: SabuflixTheme.title(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                  TextButton(
                    onPressed: () => _confirmClearHistory(context, historyProvider),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                    child: Text(
                      'Limpar',
                      style: SabuflixTheme.body(fontSize: 13, fontWeight: FontWeight.w600, color: SabuflixTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 172,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _ContinueWatchingCard(item: item),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmClearHistory(BuildContext context, WatchHistoryProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SabuflixTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusMd),
        title: Text('Apagar histórico?', style: SabuflixTheme.title(fontSize: 18, color: Colors.white)),
        content: Text(
          'Isso vai remover todos os títulos de "Continuar assistindo". Essa ação não pode ser desfeita.',
          style: SabuflixTheme.body(color: SabuflixTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: SabuflixTheme.body(color: SabuflixTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              provider.clearHistory();
              Navigator.pop(ctx);
            },
            child: Text('Apagar tudo', style: SabuflixTheme.body(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _ContinueWatchingCard extends StatelessWidget {
  final WatchHistoryItem item;
  static const double _width = 220;

  const _ContinueWatchingCard({required this.item});

  String get _subtitle {
    final media = item.media;
    if (media.mediaType == 'tv' && item.season != null && item.episode != null) {
      return 'T${item.season} : E${item.episode}';
    }
    final remainingSeconds = (item.durationSeconds - item.positionSeconds).clamp(0.0, item.durationSeconds);
    final minutesLeft = (remainingSeconds / 60).ceil();
    return minutesLeft > 0 ? '$minutesLeft min restantes' : 'Assistido';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showStreamSelectorSheet(context, media: item.media, season: item.season, episode: item.episode),
      child: SizedBox(
        width: _width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: SabuflixTheme.radiusLg,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: item.media.fullBackdropPath,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: SabuflixTheme.surface),
                      errorWidget: (context, url, error) => Container(
                        color: SabuflixTheme.surface,
                        child: const Icon(Icons.image_outlined, color: SabuflixTheme.textMuted, size: 28),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.45)],
                        ),
                      ),
                    ),
                    const Center(
                      child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 38),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => context.read<WatchHistoryProvider>().removeFromHistory(item.media.id),
                        child: Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 15),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SizedBox(
                        height: 4,
                        child: Stack(
                          children: [
                            Container(color: Colors.white.withValues(alpha: 0.25)),
                            FractionallySizedBox(
                              widthFactor: item.progress,
                              alignment: Alignment.centerLeft,
                              child: Container(color: SabuflixTheme.accent),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.media.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SabuflixTheme.caption(fontSize: 13, fontWeight: FontWeight.w600, color: SabuflixTheme.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              _subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SabuflixTheme.caption(fontSize: 12, color: SabuflixTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
