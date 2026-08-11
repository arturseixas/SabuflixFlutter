import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/media_item.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_route.dart';
import '../screens/media_details_screen.dart';

/// A poster card in the Apple Music / Apple TV idiom: artwork only, title
/// set below in small type. No badges, no overlays, no rating chip.
class MediaCard extends StatefulWidget {
  final MediaItem media;
  final double width;

  const MediaCard({
    Key? key,
    required this.media,
    this.width = 148,
  }) : super(key: key);

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.push(context, glassRoute(MediaDetailsScreen(media: widget.media)));
        },
        child: SizedBox(
          width: widget.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AnimatedScale(
                  scale: _isHovered ? 1.045 : 1.0,
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
                      child: CachedNetworkImage(
                        imageUrl: widget.media.fullPosterPath,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: SabuflixTheme.surface),
                        errorWidget: (context, url, error) => Container(
                          color: SabuflixTheme.surface,
                          child: const Icon(Icons.image_outlined, color: SabuflixTheme.textMuted, size: 28),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.media.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SabuflixTheme.caption(fontSize: 13, fontWeight: FontWeight.w600, color: SabuflixTheme.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
