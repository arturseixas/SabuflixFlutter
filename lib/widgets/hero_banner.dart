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

          // Vertical readability gradient.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.4, 0.78, 1.0],
                colors: [
                  SabuflixTheme.background.withValues(alpha: 0.55),
                  SabuflixTheme.background.withValues(alpha: 0.15),
                  SabuflixTheme.background.withValues(alpha: 0.9),
                  SabuflixTheme.background,
                ],
              ),
            ),
          ),
          // Horizontal readability gradient for the text column.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const [0.0, 0.55, 1.0],
                colors: [
                  SabuflixTheme.background.withValues(alpha: 0.9),
                  SabuflixTheme.background.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 44,
            left: isDesktop ? 56 : 24,
            right: isDesktop ? screenWidth * 0.4 : 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: SabuflixTheme.accent,
                        borderRadius: SabuflixTheme.radiusSm,
                      ),
                      child: Text(
                        'ORIGINAL SABUFLIX',
                        style: SabuflixTheme.label(fontSize: 10, color: Colors.white, letterSpacing: 0.8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: SabuflixTheme.tagDecoration(),
                      child: Text(
                        '4K ULTRA HD',
                        style: SabuflixTheme.label(fontSize: 10, color: SabuflixTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Text(
                  media.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SabuflixTheme.headline(
                    fontSize: isDesktop ? 46 : 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: SabuflixTheme.gold, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      media.formattedRating,
                      style: SabuflixTheme.body(fontSize: 14, fontWeight: FontWeight.w700, color: SabuflixTheme.textPrimary),
                    ),
                    const SizedBox(width: 14),
                    Text(media.formattedYear, style: SabuflixTheme.body(fontSize: 14)),
                    const SizedBox(width: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: SabuflixTheme.tagDecoration(),
                      child: Text(
                        '16+',
                        style: SabuflixTheme.body(fontSize: 11, fontWeight: FontWeight.w700, color: SabuflixTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (media.overview != null && media.overview!.isNotEmpty)
                  Text(
                    media.overview!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: SabuflixTheme.body(fontSize: 14, height: 1.55),
                  ),
                const SizedBox(height: 26),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => VideoPlayerScreen(media: media)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SabuflixTheme.textPrimary,
                        foregroundColor: SabuflixTheme.background,
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusSm),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 24, color: SabuflixTheme.background),
                      label: Text(
                        'Assistir',
                        style: SabuflixTheme.body(fontSize: 15, fontWeight: FontWeight.w700, color: SabuflixTheme.background),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        favoritesProvider.toggleFavorite(media);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isFav ? 'Removido da Minha Lista' : 'Adicionado à Minha Lista',
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SabuflixTheme.textPrimary,
                        backgroundColor: SabuflixTheme.surface.withValues(alpha: 0.75),
                        side: const BorderSide(color: SabuflixTheme.borderStrong),
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusSm),
                      ),
                      icon: Icon(isFav ? Icons.check_rounded : Icons.add_rounded, size: 20),
                      label: Text(
                        isFav ? 'Na Lista' : 'Minha Lista',
                        style: SabuflixTheme.body(fontSize: 14, fontWeight: FontWeight.w600, color: SabuflixTheme.textPrimary),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => MediaDetailsScreen(media: media)),
                        );
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: SabuflixTheme.surface.withValues(alpha: 0.75),
                        padding: const EdgeInsets.all(15),
                        shape: CircleBorder(side: BorderSide(color: SabuflixTheme.border)),
                      ),
                      icon: const Icon(Icons.info_outline_rounded, color: SabuflixTheme.textPrimary, size: 22),
                      tooltip: 'Mais informações',
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
