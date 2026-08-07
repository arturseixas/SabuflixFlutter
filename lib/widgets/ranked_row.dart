import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/media_item.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_route.dart';
import '../screens/media_details_screen.dart';

/// The Top 10, with the rank set as an outlined numeral beside the poster.
/// Rank is the whole point of the row, so it is typographic, not a badge.
class RankedRow extends StatelessWidget {
  final String title;
  final List<MediaItem> mediaItems;

  const RankedRow({
    Key? key,
    required this.title,
    required this.mediaItems,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (mediaItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
          child: Text(
            title,
            style: SabuflixTheme.title(fontSize: 19, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: mediaItems.length,
            itemBuilder: (context, index) {
              return _RankedCard(rank: index + 1, media: mediaItems[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _RankedCard extends StatelessWidget {
  final int rank;
  final MediaItem media;

  const _RankedCard({required this.rank, required this.media});

  @override
  Widget build(BuildContext context) {
    // Two digits need more room than one, so the numeral column flexes.
    final numeralWidth = rank >= 10 ? 78.0 : 48.0;

    return GestureDetector(
      onTap: () => Navigator.push(context, glassRoute(MediaDetailsScreen(media: media))),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: numeralWidth,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.right,
                  style: SabuflixTheme.headline(fontSize: 108, fontWeight: FontWeight.w700).copyWith(
                    height: 0.78,
                    letterSpacing: -6,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 2.5
                      ..color = SabuflixTheme.borderStrong,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ClipRRect(
                borderRadius: SabuflixTheme.radiusLg,
                child: CachedNetworkImage(
                  imageUrl: media.fullPosterPath,
                  width: 124,
                  height: 186,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(width: 124, height: 186, color: SabuflixTheme.surface),
                  errorWidget: (context, url, error) => Container(
                    width: 124,
                    height: 186,
                    color: SabuflixTheme.surface,
                    child: const Icon(Icons.image_outlined, color: SabuflixTheme.textMuted, size: 28),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
