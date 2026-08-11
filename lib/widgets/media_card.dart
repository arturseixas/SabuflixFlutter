import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/media_item.dart';
import '../theme/sabuflix_theme.dart';
import '../tv/tv_focus.dart';
import '../tv/tv_metrics.dart';
import '../utils/app_route.dart';
import '../screens/media_details_screen.dart';

/// A poster card in the Apple Music / Apple TV idiom: artwork only, title
/// set below in small type. No badges, no overlays, no rating chip.
///
/// The same card serves the phone and the television — it takes D-pad focus,
/// grows and rings itself when selected, and pulls its size from [TvMetrics]
/// so a shelf reads at arm's length and from the sofa alike.
class MediaCard extends StatelessWidget {
  final MediaItem media;

  /// Overrides the width from [TvMetrics]; used by the fixed-width grids.
  final double? width;

  final bool autofocus;

  const MediaCard({
    Key? key,
    required this.media,
    this.width,
    this.autofocus = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final metrics = TvMetrics.of(context);
    final cardWidth = width ?? metrics.posterWidth;

    return TvFocusable(
      autofocus: autofocus,
      borderRadius: SabuflixTheme.radiusLg,
      semanticLabel: media.title,
      onPressed: () {
        Navigator.push(context, glassRoute(MediaDetailsScreen(media: media)));
      },
      builder: (context, focused, child) => AnimatedScale(
        scale: focused ? metrics.focusScale : 1.0,
        duration: SabuflixTheme.durationFast,
        curve: SabuflixTheme.curveStandard,
        child: SizedBox(
          width: cardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: SabuflixTheme.durationFast,
                  decoration: BoxDecoration(
                    borderRadius: SabuflixTheme.radiusLg,
                    border: Border.all(
                      color: focused ? SabuflixTheme.textPrimary : Colors.transparent,
                      width: focused ? metrics.focusRingWidth : 0,
                    ),
                    boxShadow: focused ? SabuflixTheme.shadowMd : SabuflixTheme.shadowSm,
                  ),
                  child: ClipRRect(
                    borderRadius: SabuflixTheme.radiusLg,
                    child: CachedNetworkImage(
                      imageUrl: media.fullPosterPath,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: SabuflixTheme.surface),
                      errorWidget: (context, url, error) => Container(
                        color: SabuflixTheme.surface,
                        child: Icon(Icons.image_outlined, color: SabuflixTheme.textMuted, size: metrics.iconSize),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: metrics.isTv ? 14 : 10),
              Text(
                media.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SabuflixTheme.caption(
                  fontSize: metrics.cardLabelSize,
                  fontWeight: FontWeight.w600,
                  // The unfocused title stays quiet so the focused one reads
                  // as the current selection from across the room.
                  color: focused || !metrics.isTv ? SabuflixTheme.textPrimary : SabuflixTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
      child: const SizedBox.shrink(),
    );
  }
}
