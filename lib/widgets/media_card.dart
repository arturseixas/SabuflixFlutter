import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/media_item.dart';
import '../theme/sabuflix_theme.dart';
import '../screens/media_details_screen.dart';

class MediaCard extends StatefulWidget {
  final MediaItem media;
  final double width;
  final double height;

  const MediaCard({
    Key? key,
    required this.media,
    this.width = 148,
    this.height = 222,
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MediaDetailsScreen(media: widget.media),
            ),
          );
        },
        child: AnimatedContainer(
          duration: SabuflixTheme.durationFast,
          curve: SabuflixTheme.curveStandard,
          width: widget.width,
          height: widget.height,
          transform: _isHovered
              ? Matrix4.diagonal3Values(1.035, 1.035, 1.0)
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: SabuflixTheme.surface,
            borderRadius: SabuflixTheme.radiusMd,
            border: Border.all(
              color: _isHovered ? SabuflixTheme.borderStrong : SabuflixTheme.border,
              width: 1,
            ),
            boxShadow: _isHovered ? SabuflixTheme.shadowMd : SabuflixTheme.shadowSm,
          ),
          child: ClipRRect(
            borderRadius: SabuflixTheme.radiusMd,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: widget.media.fullPosterPath,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: SabuflixTheme.surface,
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: SabuflixTheme.textMuted),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: SabuflixTheme.surface,
                    child: const Icon(Icons.movie_outlined, color: SabuflixTheme.textMuted, size: 32),
                  ),
                ),

                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedContainer(
                    duration: SabuflixTheme.durationFast,
                    padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: _isHovered ? 0.92 : 0.8),
                          Colors.black.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.media.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SabuflixTheme.title(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: SabuflixTheme.gold, size: 13),
                            const SizedBox(width: 3),
                            Text(
                              widget.media.formattedRating,
                              style: SabuflixTheme.body(fontSize: 11, fontWeight: FontWeight.w600, color: SabuflixTheme.textSecondary),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: widget.media.mediaType == 'tv' ? SabuflixTheme.tvBadge : SabuflixTheme.movieBadge,
                                borderRadius: SabuflixTheme.radiusSm,
                              ),
                              child: Text(
                                widget.media.mediaType == 'tv' ? 'SÉRIE' : 'FILME',
                                style: SabuflixTheme.label(fontSize: 8, color: Colors.white, letterSpacing: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
