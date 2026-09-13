import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../theme/sabuflix_theme.dart';
import '../providers/favorites_provider.dart';
import '../utils/app_route.dart';
import '../screens/media_details_screen.dart';

class HeroBanner extends StatelessWidget {
  final MediaItem media;
  const HeroBanner({super.key, required this.media});
  @override
  Widget build(BuildContext context) {
    final favorite = context.select<FavoritesProvider, bool>(
      (p) => p.isFavorite(media.id, mediaType: media.mediaType),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 800;
        final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final height =
            (desktop
                ? (constraints.maxWidth * .46).clamp(480.0, 660.0)
                : 520.0) +
            (textScale - 1).clamp(0.0, 2.0) * 240;
        return SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExcludeSemantics(
                child: CachedNetworkImage(
                  imageUrl: media.fullBackdropPath,
                  fit: BoxFit.cover,
                  alignment: desktop
                      ? Alignment.centerRight
                      : Alignment.topCenter,
                  placeholder: (_, url) =>
                      const ColoredBox(color: SabuflixTheme.surface),
                  errorWidget: (_, url, error) =>
                      const ColoredBox(color: SabuflixTheme.surface),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, .32, .72, 1],
                    colors: [
                      Colors.black26,
                      Colors.transparent,
                      Colors.black.withValues(alpha: .75),
                      SabuflixTheme.background,
                    ],
                  ),
                ),
              ),
              if (desktop)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: .55),
                        Colors.black.withValues(alpha: .22),
                        Colors.transparent,
                      ],
                      stops: const [0, .45, 1],
                    ),
                  ),
                ),
              Positioned(
                left: desktop ? 40 : 20,
                right: desktop ? constraints.maxWidth * .35 : 20,
                bottom: 48,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      media.mediaType == 'tv'
                          ? 'SÉRIE EM DESTAQUE'
                          : 'FILME EM DESTAQUE',
                      style: SabuflixTheme.label(
                        fontSize: 11,
                        color: Colors.white70,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      media.title.toUpperCase(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: SabuflixTheme.display(
                        fontSize: desktop ? 64 : 38,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        if (media.releaseDate?.isNotEmpty ?? false)
                          Text(
                            media.formattedYear,
                            style: SabuflixTheme.body(color: Colors.white70),
                          ),
                        if (media.voteCount > 0)
                          Text(
                            '★ ${media.formattedRating}',
                            style: SabuflixTheme.body(color: Colors.white70),
                          ),
                        if (media.genres?.isNotEmpty ?? false)
                          Text(
                            media.genres!.take(2).join(' · '),
                            style: SabuflixTheme.body(color: Colors.white70),
                          ),
                      ],
                    ),
                    if (media.overview?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 14),
                      Text(
                        media.overview!,
                        maxLines: desktop ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: SabuflixTheme.body(
                          fontSize: 15,
                          color: const Color(0xFFE0E0E5),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            glassRoute(MediaDetailsScreen(media: media)),
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(160, 50),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                          ),
                          icon: const Icon(
                            Icons.info_outline_rounded,
                            size: 21,
                          ),
                          label: const Text('Ver detalhes'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              await context
                                  .read<FavoritesProvider>()
                                  .toggleFavorite(media);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    favorite
                                        ? 'Removido da lista'
                                        : 'Adicionado à lista',
                                  ),
                                ),
                              );
                            } catch (_) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Não foi possível salvar. Tente novamente.',
                                  ),
                                ),
                              );
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(150, 50),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                          ),
                          icon: Icon(
                            favorite ? Icons.check_rounded : Icons.add_rounded,
                            size: 21,
                          ),
                          label: Text(
                            favorite ? 'Na minha lista' : 'Minha lista',
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
      },
    );
  }
}
