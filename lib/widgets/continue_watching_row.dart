import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/watch_history_entry.dart';
import '../providers/watch_history_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_route.dart';
import '../screens/media_details_screen.dart';

class ContinueWatchingRow extends StatelessWidget {
  final List<WatchHistoryEntry> entries;

  const ContinueWatchingRow({Key? key, required this.entries}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
          child: Text(
            'Continuar Assistindo',
            style: SabuflixTheme.title(fontSize: 19, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: 168,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _ContinueWatchingCard(entry: entry),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ContinueWatchingCard extends StatelessWidget {
  final WatchHistoryEntry entry;

  const _ContinueWatchingCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, glassRoute(MediaDetailsScreen(media: entry.media)));
      },
      child: SizedBox(
        width: 230,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: SabuflixTheme.radiusLg,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: entry.media.fullBackdropPath,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: SabuflixTheme.surface),
                      errorWidget: (context, url, error) => Container(color: SabuflixTheme.surface),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: () {
                          Provider.of<WatchHistoryProvider>(context, listen: false).removeEntry(entry.media.id);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.35),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: entry.progress,
                            minHeight: 4,
                            backgroundColor: Colors.white.withValues(alpha: 0.25),
                            valueColor: const AlwaysStoppedAnimation<Color>(SabuflixTheme.accent),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Icon(Icons.play_arrow_rounded, color: Colors.white.withValues(alpha: 0.85), size: 34),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              entry.media.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SabuflixTheme.caption(fontSize: 13, fontWeight: FontWeight.w600, color: SabuflixTheme.textPrimary),
            ),
            if (entry.episodeLabel != null)
              Text(
                entry.episodeLabel!,
                style: SabuflixTheme.caption(fontSize: 11, color: SabuflixTheme.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}
