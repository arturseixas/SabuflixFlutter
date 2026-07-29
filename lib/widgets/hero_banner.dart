import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../theme/sabuflix_theme.dart';
import '../providers/favorites_provider.dart';
import '../utils/app_route.dart';
import '../screens/media_details_screen.dart';
import '../screens/video_player_screen.dart';
import 'glass_container.dart';

class HeroBanner extends StatelessWidget {
  final MediaItem media;

  const HeroBanner({Key? key, required this.media}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final isFav = favoritesProvider.isFavorite(media.id);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return SizedBox(
      height: 560,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: media.fullBackdropPath,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            placeholder: (context, url) => Container(color: SabuflixTheme.surface),
            errorWidget: (context, url, err) => Container(color: SabuflixTheme.surface),
          ),

          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.4, 0.78, 1.0],
                colors: [
                  SabuflixTheme.background.withValues(alpha: 0.55),
                  SabuflixTheme.background.withValues(alpha: 0.1),
                  SabuflixTheme.background.withValues(alpha: 0.9),
                  SabuflixTheme.background,
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const [0.0, 0.55, 1.0],
                colors: [
                  SabuflixTheme.background.withValues(alpha: 0.85),
                  SabuflixTheme.background.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 44,
            left: isDesktop ? 56 : 24,
            right: isDesktop ? screenWidth * 0.42 : 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  media.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SabuflixTheme.headline(
                    fontSize: isDesktop ? 44 : 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: SabuflixTheme.gold, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      media.formattedRating,
                      style: SabuflixTheme.body(fontSize: 14, fontWeight: FontWeight.w600, color: SabuflixTheme.textPrimary),
                    ),
                    const SizedBox(width: 10),
                    Text('·', style: SabuflixTheme.body(fontSize: 14, color: SabuflixTheme.textMuted)),
                    const SizedBox(width: 10),
                    Text(media.formattedYear, style: SabuflixTheme.body(fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 16),

                if (media.overview != null && media.overview!.isNotEmpty)
                  Text(
                    media.overview!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: SabuflixTheme.body(fontSize: 15, height: 1.5, color: SabuflixTheme.textSecondary),
                  ),
                const SizedBox(height: 26),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: SabuflixTheme.radiusPill,
                        gradient: const LinearGradient(
                          colors: [SabuflixTheme.accent, SabuflixTheme.accentHover],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: SabuflixTheme.accent.withValues(alpha: 0.38),
                            blurRadius: 18,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(context, glassRoute(VideoPlayerScreen(media: media)));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 24, color: Colors.white),
                        label: Text(
                          'Assistir',
                          style: SabuflixTheme.body(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                    GlassContainer(
                      borderRadius: SabuflixTheme.radiusPill,
                      blur: 28,
                      fillOpacity: 0.3,
                      hasGlow: isFav,
                      glowColor: SabuflixTheme.accent,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: SabuflixTheme.radiusPill,
                          onTap: () {
                            favoritesProvider.toggleFavorite(media);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isFav ? 'Removido da lista' : 'Adicionado à lista')),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isFav ? Icons.check_rounded : Icons.add_rounded,
                                  size: 20,
                                  color: isFav ? SabuflixTheme.accent : SabuflixTheme.textPrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isFav ? 'Na Lista' : 'Minha Lista',
                                  style: SabuflixTheme.body(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isFav ? SabuflixTheme.accent : SabuflixTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    GlassContainer(
                      borderRadius: SabuflixTheme.radiusPill,
                      blur: 28,
                      fillOpacity: 0.3,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: SabuflixTheme.radiusPill,
                          onTap: () {
                            Navigator.push(context, glassRoute(MediaDetailsScreen(media: media)));
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(14),
                            child: Icon(Icons.info_outline_rounded, color: SabuflixTheme.textPrimary, size: 22),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
