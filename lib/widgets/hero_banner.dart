import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../theme/sabuflix_theme.dart';
import '../providers/favorites_provider.dart';
import '../screens/media_details_screen.dart';
import '../screens/video_player_screen.dart';

class HeroBanner extends StatelessWidget {
  final MediaItem media;

  const HeroBanner({Key? key, required this.media}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final isFav = favoritesProvider.isFavorite(media.id);
    final screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      height: 520,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Backdrop Image
          CachedNetworkImage(
            imageUrl: media.fullBackdropPath,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            placeholder: (context, url) => Container(color: SabuflixTheme.background),
            errorWidget: (context, url, err) => Container(color: SabuflixTheme.background),
          ),

          // Multi-stage Warm Dark Gradients (Anthropic Style)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.35, 0.75, 1.0],
                colors: [
                  SabuflixTheme.background.withValues(alpha: 0.6),
                  SabuflixTheme.background.withValues(alpha: 0.25),
                  SabuflixTheme.background.withValues(alpha: 0.85),
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
                  SabuflixTheme.background.withValues(alpha: 0.95),
                  SabuflixTheme.background.withValues(alpha: 0.45),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // Content Info Overlay (Apple TV + Anthropic Style)
          Positioned(
            bottom: 40,
            left: screenWidth > 800 ? 50 : 24,
            right: screenWidth > 800 ? screenWidth * 0.38 : 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Anthropic Star Tagline Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: SabuflixTheme.terracotta,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('✳ ', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          Text(
                            'SABUFLIX ORIGINAL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(color: SabuflixTheme.textSecondary, width: 1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '4K ULTRA HD',
                        style: SabuflixTheme.sansBody(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: SabuflixTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Media Title (Serif Typography)
                Text(
                  media.title,
                  style: SabuflixTheme.serifHeader(
                    fontSize: screenWidth > 800 ? 44 : 34,
                    fontWeight: FontWeight.bold,
                    color: SabuflixTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                // Rating & Metadata row
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: SabuflixTheme.amber, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      media.formattedRating,
                      style: SabuflixTheme.sansBody(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: SabuflixTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      media.formattedYear,
                      style: SabuflixTheme.sansBody(
                        fontSize: 14,
                        color: SabuflixTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: SabuflixTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: SabuflixTheme.border),
                      ),
                      child: Text(
                        '16+',
                        style: SabuflixTheme.sansBody(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: SabuflixTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Overview text
                if (media.overview != null && media.overview!.isNotEmpty)
                  Text(
                    media.overview!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: SabuflixTheme.sansBody(
                      fontSize: 14,
                      color: SabuflixTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                const SizedBox(height: 24),

                // Apple TV Pill Action Buttons
                Wrap(
                  spacing: 14,
                  runSpacing: 12,
                  children: [
                    // Terracotta Play Button
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoPlayerScreen(media: media),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SabuflixTheme.terracotta,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30), // Apple TV Pill
                        ),
                        elevation: 6,
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 28, color: Colors.white),
                      label: Text(
                        'Assistir Agora',
                        style: SabuflixTheme.sansBody(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    // Translucent Warm Glass My List Button
                    OutlinedButton.icon(
                      onPressed: () {
                        favoritesProvider.toggleFavorite(media);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isFav ? 'Removido da Minha Lista' : 'Adicionado à Minha Lista!',
                              style: SabuflixTheme.sansBody(color: Colors.white),
                            ),
                            duration: const Duration(seconds: 2),
                            backgroundColor: SabuflixTheme.terracotta,
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SabuflixTheme.textPrimary,
                        backgroundColor: SabuflixTheme.surface.withValues(alpha: 0.7),
                        side: const BorderSide(color: SabuflixTheme.border, width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      icon: Icon(
                        isFav ? Icons.check : Icons.add,
                        size: 22,
                        color: SabuflixTheme.textPrimary,
                      ),
                      label: Text(
                        isFav ? 'Na Lista' : 'Minha Lista',
                        style: SabuflixTheme.sansBody(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: SabuflixTheme.textPrimary,
                        ),
                      ),
                    ),

                    // Info Button
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MediaDetailsScreen(media: media),
                          ),
                        );
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: SabuflixTheme.surface.withValues(alpha: 0.7),
                        padding: const EdgeInsets.all(14),
                        shape: CircleBorder(
                          side: BorderSide(color: SabuflixTheme.border),
                        ),
                      ),
                      icon: const Icon(Icons.info_outline_rounded, color: SabuflixTheme.textPrimary, size: 24),
                      tooltip: 'Mais Informações',
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
