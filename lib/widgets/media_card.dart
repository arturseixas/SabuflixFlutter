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

/// A poster card in the Apple Music / Apple TV idiom: artwork only, title
/// set below in small type. No badges, no overlays, no rating chip.
class MediaCard extends StatefulWidget {
  final MediaItem media;
  final double width;

  const MediaCard({
    super.key,
    required this.media,
    this.width = 148,
  });

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  bool _isHovered = false;

  void _showActions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SabuflixTheme.surface,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Consumer2<WatchedProvider, FavoritesProvider>(
            builder: (context, watched, favorites, child) {
              final isWatched = watched.isWatched(widget.media.id);
              final isFavorite = favorites.isFavorite(widget.media.id);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(isWatched
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_rounded),
                    title: Text(isWatched
                        ? 'Marcar como não assistido'
                        : 'Marcar como assistido'),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await watched.toggle(widget.media);
                      if (!isWatched && mounted) {
                        await this
                            .context
                            .read<ContinueWatchingProvider>()
                            .remove(widget.media.id);
                      }
                    },
                  ),
                  ListTile(
                    leading: Icon(isFavorite
                        ? Icons.bookmark_remove_outlined
                        : Icons.bookmark_add_outlined),
                    title: Text(isFavorite
                        ? 'Remover da Minha Lista'
                        : 'Adicionar à Minha Lista'),
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
                      Navigator.push(context,
                          glassRoute(MediaDetailsScreen(media: widget.media)));
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
    final compact = context.watch<SettingsProvider>().compactPosters;
    final watched = context.watch<WatchedProvider>().isWatched(widget.media.id);

    return Semantics(
      button: true,
      label: '${widget.media.title}${watched ? ', assistido' : ''}',
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            Navigator.push(
                context, glassRoute(MediaDetailsScreen(media: widget.media)));
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
                    scale: _isHovered ? 1.045 : 1.0,
                    duration: SabuflixTheme.durationFast,
                    curve: SabuflixTheme.curveSpring,
                    child: AnimatedContainer(
                      duration: SabuflixTheme.durationFast,
                      decoration: BoxDecoration(
                        borderRadius: SabuflixTheme.radiusLg,
                        boxShadow: _isHovered
                            ? SabuflixTheme.shadowMd
                            : SabuflixTheme.shadowSm,
                      ),
                      child: ClipRRect(
                        borderRadius: SabuflixTheme.radiusLg,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: widget.media.fullPosterPath,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  Container(color: SabuflixTheme.surface),
                              errorWidget: (context, url, error) => Container(
                                color: SabuflixTheme.surface,
                                child: const Icon(Icons.image_outlined,
                                    color: SabuflixTheme.textMuted, size: 28),
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
                                    color: Colors.black.withValues(alpha: 0.68),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: const Icon(Icons.check_rounded,
                                      color: Colors.white, size: 17),
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
                    widget.media.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SabuflixTheme.caption(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: SabuflixTheme.textPrimary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
