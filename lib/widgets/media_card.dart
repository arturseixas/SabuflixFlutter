import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../providers/favorites_provider.dart';
import '../providers/continue_watching_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/watched_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_route.dart';
import '../screens/media_details_screen.dart';

/// Artwork-first card; home shelves use cinematic landscape stills.
class MediaCard extends StatefulWidget {
  final MediaItem media;
  final double width;
  final bool landscape;

  const MediaCard({
    super.key,
    required this.media,
    this.width = 148,
    this.landscape = false,
  });

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  void _showActions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SabuflixTheme.surface,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Consumer2<WatchedProvider, FavoritesProvider>(
            builder: (context, watched, favorites, child) {
              final isWatched = watched.isWatched(
                widget.media.id,
                mediaType: widget.media.mediaType,
              );
              final isFavorite = favorites.isFavorite(
                widget.media.id,
                mediaType: widget.media.mediaType,
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(
                      isWatched
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_rounded,
                    ),
                    title: Text(
                      isWatched
                          ? 'Marcar como não assistido'
                          : 'Marcar como assistido',
                    ),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await watched.toggle(widget.media);
                      if (!isWatched && mounted) {
                        await this.context
                            .read<ContinueWatchingProvider>()
                            .remove(
                              widget.media.id,
                              mediaType: widget.media.mediaType,
                            );
                      }
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      isFavorite
                          ? Icons.bookmark_remove_outlined
                          : Icons.bookmark_add_outlined,
                    ),
                    title: Text(
                      isFavorite
                          ? 'Remover da Minha Lista'
                          : 'Adicionar à Minha Lista',
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      favorites.toggleFavorite(widget.media);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('Ver detalhes'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      Navigator.push(
                        context,
                        glassRoute(MediaDetailsScreen(media: widget.media)),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = context.select<SettingsProvider, bool>(
      (p) => p.compactPosters,
    );
    final watched = context.select<WatchedProvider, bool>(
      (p) => p.isWatched(widget.media.id, mediaType: widget.media.mediaType),
    );

    return Semantics(
      button: true,
      label: '${widget.media.title}${watched ? ', assistido' : ''}',
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: SabuflixTheme.radiusMd,
            onFocusChange: (focused) => setState(() => _isFocused = focused),
            onTap: () {
              Navigator.push(
                context,
                glassRoute(MediaDetailsScreen(media: widget.media)),
              );
            },
            onLongPress: _showActions,
            onSecondaryTap: _showActions,
            child: SizedBox(
              width: widget.width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AnimatedScale(
                      scale: (_isHovered || _isFocused) ? 1.025 : 1.0,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : SabuflixTheme.durationFast,
                      curve: SabuflixTheme.curveSpring,
                      child: AnimatedContainer(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : SabuflixTheme.durationFast,
                        decoration: BoxDecoration(
                          borderRadius: SabuflixTheme.radiusMd,
                          border: _isFocused
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: const [],
                        ),
                        child: ClipRRect(
                          borderRadius: SabuflixTheme.radiusMd,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: widget.landscape
                                    ? widget.media.fullBackdropPath
                                    : widget.media.fullPosterPath,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    Container(color: SabuflixTheme.surface),
                                errorWidget: (context, url, error) => Container(
                                  color: SabuflixTheme.surface,
                                  child: const Icon(
                                    Icons.image_outlined,
                                    color: SabuflixTheme.textMuted,
                                    size: 28,
                                  ),
                                ),
                              ),
                              if (watched)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.68,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 17,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 10),
                    Text(
                      widget.landscape
                          ? widget.media.title.toUpperCase()
                          : widget.media.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SabuflixTheme.caption(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: SabuflixTheme.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
