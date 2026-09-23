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

  /// Eyebrow above the title; defaults to the daily pick.
  final String? label;
  const HeroBanner({super.key, required this.media, this.label});
  @override
  Widget build(BuildContext context) {
    final favorite = context.select<FavoritesProvider, bool>(
      (p) => p.isFavorite(media.id, mediaType: media.mediaType),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 800;
        final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final height = (desktop
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
                  alignment:
                      desktop ? Alignment.centerRight : Alignment.topCenter,
                  placeholder: (_, url) =>
                      const ColoredBox(color: Color(0xFF111111)),
                  errorWidget: (_, url, error) =>
                      const ColoredBox(color: Color(0xFF111111)),
                ),
              ),
              // Stills keep their own colour; a plain black scrim holds the
              // type, and the banner ends on a hard edge like a print.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, .3, .62, 1],
                    colors: [
                      Color(0x59000000),
                      Colors.transparent,
                      Color(0x99000000),
                      Color(0xE6000000),
                    ],
                  ),
                ),
              ),
              if (desktop)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: .6),
                        Colors.black.withValues(alpha: .2),
                        Colors.transparent,
                      ],
                      stops: const [0, .45, 1],
                    ),
                  ),
                ),
              Positioned(
                left: desktop ? 48 : 20,
                right: desktop
                    ? constraints.maxWidth -
                        (constraints.maxWidth * .55).clamp(520.0, 720.0)
                    : 20,
                bottom: desktop ? 56 : 32,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label ??
                          (media.mediaType == 'tv'
                              ? 'SÉRIE DO DIA'
                              : 'FILME DO DIA'),
                      style: SabuflixTheme.label(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 2.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      media.title.toUpperCase(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: SabuflixTheme.display(
                        fontSize: desktop ? 68 : 40,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                        letterSpacing: desktop ? -2 : -1.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (media.directorLine != null) ...[
                      Text(
                        media.directorLine!,
                        style: SabuflixTheme.body(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: [
                            if (media.genres?.isNotEmpty ?? false)
                              media.genres!.take(2).join(', '),
                            if (media.originLine.isNotEmpty) media.originLine,
                          ].join('  ·  '),
                        ),
                        if (media.voteCount > 0) ...[
                          const TextSpan(text: '    '),
                          const WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Icon(Icons.star_rounded,
                                size: 16, color: Colors.white),
                          ),
                          TextSpan(text: ' ${media.starRating}'),
                        ],
                      ]),
                      style: SabuflixTheme.body(
                        fontSize: 14,
                        color: const Color(0xFFD6D6D6),
                      ),
                    ),
                    if (media.overview?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 14),
                      Text(
                        media.overview!,
                        maxLines: desktop ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: SabuflixTheme.body(
                          fontSize: 15,
                          color: const Color(0xFFE6E6E6),
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
                            minimumSize: const Size(160, 52),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                          ),
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
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
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.transparent,
                            side: const BorderSide(
                                color: Colors.white, width: 1.2),
                            minimumSize: const Size(150, 52),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
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
