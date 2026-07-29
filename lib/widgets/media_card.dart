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
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: widget.width,
          height: widget.height,
          transform: _isHovered
              ? (Matrix4.identity()..scale(1.06, 1.06))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: SabuflixTheme.surface,
            borderRadius: BorderRadius.circular(16), // Apple TV 16px corner radius
            border: Border.all(
              color: _isHovered
                  ? SabuflixTheme.terracotta.withValues(alpha: 0.8)
                  : SabuflixTheme.border,
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: SabuflixTheme.terracotta.withValues(alpha: 0.35),
                      blurRadius: 20,
                      spreadRadius: 1,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: widget.media.fullPosterPath,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: SabuflixTheme.surface,
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: SabuflixTheme.terracotta,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: SabuflixTheme.surface,
                    child: const Icon(Icons.movie, color: SabuflixTheme.textMuted, size: 40),
                  ),
                ),

                // Apple TV Vignette overlay at bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          SabuflixTheme.background.withValues(alpha: _isHovered ? 0.98 : 0.85),
                          SabuflixTheme.background.withValues(alpha: 0.4),
                          Colors.transparent,
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
                          style: SabuflixTheme.serifHeader(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: SabuflixTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: SabuflixTheme.amber, size: 14),
                            const SizedBox(width: 3),
                            Text(
                              widget.media.formattedRating,
                              style: SabuflixTheme.sansBody(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: SabuflixTheme.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: widget.media.mediaType == 'tv'
                                    ? const Color(0xFF10B981)
                                    : SabuflixTheme.terracotta,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.media.mediaType == 'tv' ? 'SÉRIE' : 'FILME',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
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
