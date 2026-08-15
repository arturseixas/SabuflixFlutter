import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/media_item.dart';
import '../providers/favorites_provider.dart';
import '../screens/media_details_screen.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_route.dart';

class HeroBanner extends StatelessWidget {
  final MediaItem media;

  const HeroBanner({super.key, required this.media});

  String get _shortOverview {
    final source = (media.overview ?? '').trim();
    if (source.isEmpty) return '';
    final words = source.split(RegExp(r'\s+'));
    if (words.length <= 20) return source;
    return '${words.take(20).join(' ')}...';
  }

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>();
    final isFavorite = favorites.isFavorite(media.id);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 800;

    return Padding(
      padding:
          EdgeInsets.fromLTRB(isDesktop ? 24 : 0, 0, isDesktop ? 24 : 0, 0),
      child: ClipRRect(
        borderRadius: isDesktop ? SabuflixTheme.radiusXl : BorderRadius.zero,
        child: SizedBox(
          height: isDesktop ? 590 : 510,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: media.fullBackdropPath,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                placeholder: (_, __) => Container(color: SabuflixTheme.surface),
                errorWidget: (_, __, ___) =>
                    Container(color: SabuflixTheme.surface),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const [0, 0.58, 1],
                    colors: [
                      SabuflixTheme.background.withValues(alpha: 0.96),
                      SabuflixTheme.background.withValues(alpha: 0.46),
                      SabuflixTheme.background.withValues(alpha: 0.08),
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.56, 1],
                    colors: [
                      SabuflixTheme.background.withValues(alpha: 0.16),
                      Colors.transparent,
                      SabuflixTheme.background,
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 42 : 22,
                    24,
                    isDesktop ? width * 0.42 : 22,
                    isDesktop ? 42 : 34,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (media.fullLogoPath != null)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: isDesktop ? 108 : 72,
                            maxWidth: isDesktop ? 420 : 280,
                          ),
                          child: CachedNetworkImage(
                            imageUrl: media.fullLogoPath!,
                            fit: BoxFit.contain,
                            alignment: Alignment.centerLeft,
                            errorWidget: (_, __, ___) =>
                                _Title(media: media, isDesktop: isDesktop),
                          ),
                        )
                      else
                        _Title(media: media, isDesktop: isDesktop),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(media.formattedYear,
                              style: SabuflixTheme.label(
                                  color: SabuflixTheme.textPrimary)),
                          Container(
                            height: 14,
                            width: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            color: SabuflixTheme.borderStrong,
                          ),
                          const Icon(Icons.star_rounded,
                              color: SabuflixTheme.accentHover, size: 15),
                          const SizedBox(width: 5),
                          Text(media.formattedRating,
                              style: SabuflixTheme.label(
                                  color: SabuflixTheme.textPrimary)),
                        ],
                      ),
                      if (_shortOverview.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          _shortOverview,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: SabuflixTheme.body(
                              fontSize: 15, color: SabuflixTheme.textSecondary),
                        ),
                      ],
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              glassRoute(MediaDetailsScreen(media: media)),
                            ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(142, 48),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 22),
                            ),
                            icon:
                                const Icon(Icons.play_arrow_rounded, size: 23),
                            label: const Text('Assistir'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              favorites.toggleFavorite(media);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(isFavorite
                                        ? 'Removido da lista'
                                        : 'Adicionado à lista')),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(142, 48),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 18),
                            ),
                            icon: Icon(
                                isFavorite
                                    ? Icons.check_rounded
                                    : Icons.add_rounded,
                                size: 20),
                            label:
                                Text(isFavorite ? 'Na lista' : 'Minha lista'),
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
    );
  }
}

class _Title extends StatelessWidget {
  final MediaItem media;
  final bool isDesktop;

  const _Title({required this.media, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Text(
      media.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: SabuflixTheme.display(fontSize: isDesktop ? 46 : 32),
    );
  }
}
