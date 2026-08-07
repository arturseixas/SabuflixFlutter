import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/watch_progress.dart';
import '../providers/watch_history_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_route.dart';
import '../screens/media_details_screen.dart';
import '../screens/video_player_screen.dart';

/// "Continuar assistindo" — landscape cards carrying a progress bar, in the
/// Apple TV idiom. Hidden entirely when there is nothing to resume.
class ContinueWatchingRow extends StatelessWidget {
  const ContinueWatchingRow({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<WatchHistoryProvider>(
      builder: (context, history, child) {
        final entries = history.entries;
        if (entries.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
              child: Text(
                'Continuar assistindo',
                style: SabuflixTheme.title(fontSize: 19, fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(
              height: 196,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _ContinueWatchingCard(entry: entries[index]),
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

class _ContinueWatchingCard extends StatefulWidget {
  final WatchProgress entry;

  const _ContinueWatchingCard({required this.entry});

  @override
  State<_ContinueWatchingCard> createState() => _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends State<_ContinueWatchingCard> {
  static const double _cardWidth = 236;

  bool _isHovered = false;

  void _resume() {
    final entry = widget.entry;
    final url = entry.videoUrl;

    // Without a stored source — or when the stored one has been dropped — the
    // details screen is where a fresh one gets picked.
    if (url == null || url.isEmpty) {
      Navigator.push(context, glassRoute(MediaDetailsScreen(media: entry.media)));
      return;
    }

    Navigator.push(
      context,
      glassRoute(VideoPlayerScreen(
        media: entry.media,
        videoUrl: url,
        season: entry.season,
        episode: entry.episode,
        resumeFrom: entry.position,
      )),
    );
  }

  Future<void> _removeFromRow() async {
    final history = Provider.of<WatchHistoryProvider>(context, listen: false);
    await history.remove(widget.entry.media.id);
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final subtitle = [
      if (entry.episodeLabel != null) entry.episodeLabel!,
      entry.remainingLabel,
    ].join(' · ');

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _resume,
        onLongPress: _removeFromRow,
        child: SizedBox(
          width: _cardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedScale(
                scale: _isHovered ? 1.035 : 1.0,
                duration: SabuflixTheme.durationFast,
                curve: SabuflixTheme.curveSpring,
                child: AnimatedContainer(
                  duration: SabuflixTheme.durationFast,
                  decoration: BoxDecoration(
                    borderRadius: SabuflixTheme.radiusLg,
                    boxShadow: _isHovered ? SabuflixTheme.shadowMd : SabuflixTheme.shadowSm,
                  ),
                  child: ClipRRect(
                    borderRadius: SabuflixTheme.radiusLg,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: entry.media.fullBackdropPath,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: SabuflixTheme.surface),
                            errorWidget: (context, url, error) => Container(
                              color: SabuflixTheme.surface,
                              child: const Icon(Icons.image_outlined, color: SabuflixTheme.textMuted, size: 28),
                            ),
                          ),

                          // Keeps the play glyph and the progress bar legible
                          // over bright artwork.
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.1),
                                  Colors.black.withValues(alpha: 0.55),
                                ],
                              ),
                            ),
                          ),

                          Center(
                            child: Container(
                              width: 46,
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
                              ),
                              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                            ),
                          ),

                          if (_isHovered)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Material(
                                color: Colors.black.withValues(alpha: 0.55),
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: _removeFromRow,
                                  child: const Padding(
                                    padding: EdgeInsets.all(5),
                                    child: Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            ),

                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 10,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.all(Radius.circular(999)),
                              child: LinearProgressIndicator(
                                value: entry.fraction,
                                minHeight: 3.5,
                                backgroundColor: Colors.white.withValues(alpha: 0.28),
                                valueColor: const AlwaysStoppedAnimation<Color>(SabuflixTheme.accent),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                entry.media.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SabuflixTheme.caption(fontSize: 13, fontWeight: FontWeight.w600, color: SabuflixTheme.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SabuflixTheme.caption(fontSize: 11, color: SabuflixTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
