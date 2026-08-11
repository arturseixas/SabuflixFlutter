import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/watch_progress.dart';
import '../providers/continue_watching_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../tv/tv_focus.dart';
import '../tv/tv_metrics.dart';
import '../utils/playback.dart';

/// The "Continuar Assistindo" shelf: wide 16:9 cards with a progress line,
/// the way Apple TV surfaces half-watched titles.
class ContinueWatchingRow extends StatelessWidget {
  const ContinueWatchingRow({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ContinueWatchingProvider>(
      builder: (context, provider, child) {
        final entries = provider.entries;
        if (entries.isEmpty) return const SizedBox.shrink();

        final metrics = TvMetrics.of(context);
        final cardWidth = metrics.continueCardWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                metrics.gutter + 8,
                metrics.isTv ? 30 : 20,
                metrics.gutter,
                metrics.isTv ? 18 : 14,
              ),
              child: Text(
                'Continuar Assistindo',
                style: SabuflixTheme.title(fontSize: metrics.sectionTitleSize, fontWeight: FontWeight.w800),
              ),
            ),
            SizedBox(
              height: metrics.continueRowHeight,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: metrics.isTv ? const ClampingScrollPhysics() : const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: metrics.gutter),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _ContinueCard(entry: entries[index], width: cardWidth),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final WatchProgress entry;
  final double width;

  const _ContinueCard({required this.entry, required this.width});

  @override
  Widget build(BuildContext context) {
    final metrics = TvMetrics.of(context);

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TvFocusable(
            onPressed: () => resumeWatching(context, entry),
            borderRadius: SabuflixTheme.radiusMd,
            semanticLabel: 'Continuar ${entry.media.title}',
            child: ClipRRect(
              borderRadius: SabuflixTheme.radiusMd,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: entry.media.fullBackdropPath,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: SabuflixTheme.surface),
                      errorWidget: (context, url, error) => Container(color: SabuflixTheme.surface),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.65),
                          ],
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.42),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.remainingLabel,
                            style: SabuflixTheme.caption(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: const BorderRadius.all(Radius.circular(2)),
                            child: LinearProgressIndicator(
                              value: entry.progress,
                              minHeight: 3,
                              backgroundColor: Colors.white.withValues(alpha: 0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(SabuflixTheme.accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // A 24-pixel target in the corner of a card is fine for a
                    // finger and impossible for a D-pad, so the TV gets its
                    // own focusable button underneath instead.
                    if (!metrics.isTv)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: _RemoveButton(mediaId: entry.media.id),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            entry.media.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SabuflixTheme.caption(
              fontSize: metrics.cardLabelSize,
              fontWeight: FontWeight.w700,
              color: SabuflixTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.subtitleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SabuflixTheme.caption(
                    fontSize: metrics.isTv ? 14 : 11,
                    color: SabuflixTheme.textMuted,
                  ),
                ),
              ),
              if (metrics.isTv)
                TvFocusable(
                  showRing: false,
                  scaleOnFocus: false,
                  semanticLabel: 'Remover ${entry.media.title} da lista',
                  onPressed: () => context.read<ContinueWatchingProvider>().remove(entry.media.id),
                  builder: (context, focused, child) => AnimatedContainer(
                    duration: SabuflixTheme.durationFast,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: focused ? SabuflixTheme.textPrimary : Colors.white.withValues(alpha: 0.08),
                      borderRadius: SabuflixTheme.radiusPill,
                    ),
                    child: Text(
                      'Remover',
                      style: SabuflixTheme.caption(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: focused ? SabuflixTheme.background : SabuflixTheme.textSecondary,
                      ),
                    ),
                  ),
                  child: const SizedBox.shrink(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  final int mediaId;

  const _RemoveButton({required this.mediaId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<ContinueWatchingProvider>().remove(mediaId),
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
      ),
    );
  }
}
