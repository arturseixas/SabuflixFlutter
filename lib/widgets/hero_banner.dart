import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../theme/sabuflix_theme.dart';
import '../providers/favorites_provider.dart';
import '../utils/app_route.dart';
import '../screens/media_details_screen.dart';

/// Hero height shared by the banner, the carousel and the skeleton.
double heroHeightFor(BuildContext context, double maxWidth) {
  final desktop = maxWidth >= 800;
  final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
  return (desktop ? (maxWidth * .46).clamp(480.0, 660.0) : 520.0) +
      (textScale - 1).clamp(0.0, 2.0) * 240;
}

/// Rotating hero: several featured titles with logo treatments, dots and
/// auto-advance. Falls back to a single [HeroBanner] with one item.
class HeroCarousel extends StatefulWidget {
  final List<MediaItem> items;
  const HeroCarousel({super.key, required this.items});

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant HeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _page = 0;
      _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (widget.items.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 9), (_) {
      if (!mounted || !_controller.hasClients) return;
      if (MediaQuery.disableAnimationsOf(context)) return;
      final next = (_page + 1) % widget.items.length;
      _controller.animateToPage(next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    if (widget.items.length == 1) return HeroBanner(media: widget.items.first);
    return LayoutBuilder(builder: (context, constraints) {
      final height = heroHeightFor(context, constraints.maxWidth);
      return SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Listener(
              onPointerDown: (_) => _timer?.cancel(),
              onPointerUp: (_) => _schedule(),
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.items.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) => HeroBanner(
                  media: widget.items[index],
                  badge: '${index + 1} de ${widget.items.length}',
                ),
              ),
            ),
            Positioned(
              right: 20,
              bottom: 22,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < widget.items.length; i++)
                    GestureDetector(
                      onTap: () => _controller.animateToPage(i,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic),
                      child: AnimatedContainer(
                        duration: SabuflixTheme.durationFast,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _page ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? Colors.white
                              : Colors.white.withValues(alpha: .4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class HeroBanner extends StatelessWidget {
  final MediaItem media;
  final String? badge;
  const HeroBanner({super.key, required this.media, this.badge});

  @override
  Widget build(BuildContext context) {
    final favorite = context.select<FavoritesProvider, bool>(
      (p) => p.isFavorite(media.id, mediaType: media.mediaType),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 800;
        final height = heroHeightFor(context, constraints.maxWidth);
        final logo = media.fullLogoPath;
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
                      SabuflixTheme.of(context).background,
                    ],
                  ),
                ),
              ),
              if (desktop)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: .62),
                        Colors.black.withValues(alpha: .25),
                        Colors.transparent,
                      ],
                      stops: const [0, .45, 1],
                    ),
                  ),
                ),
              Positioned(
                left: desktop ? 40 : 20,
                right: desktop
                    ? constraints.maxWidth -
                        (constraints.maxWidth * .55).clamp(520.0, 720.0)
                    : 20,
                bottom: 48,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          media.mediaType == 'tv'
                              ? 'SÉRIE EM DESTAQUE'
                              : 'FILME EM DESTAQUE',
                          style: SabuflixTheme.label(
                              fontSize: 11,
                              color: Colors.white70,
                              letterSpacing: 1.8),
                        ),
                        if (badge != null)
                          Text(badge!,
                              style: SabuflixTheme.label(
                                  fontSize: 10,
                                  color: Colors.white38,
                                  letterSpacing: .6)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (logo != null)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                            maxHeight: desktop ? 150 : 96,
                            maxWidth: desktop ? 460 : 320),
                        child: CachedNetworkImage(
                          imageUrl: logo,
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomLeft,
                          errorWidget: (_, __, ___) => Text(
                            media.title.toUpperCase(),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: SabuflixTheme.display(
                                fontSize: desktop ? 64 : 38, height: 1.08),
                          ),
                        ),
                      )
                    else
                      Text(
                        media.title.toUpperCase(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: SabuflixTheme.display(
                            fontSize: desktop ? 64 : 38, height: 1.08),
                      ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (media.releaseDate?.isNotEmpty ?? false)
                          Text(media.formattedYear,
                              style: SabuflixTheme.body(color: Colors.white70)),
                        if (media.voteCount > 0)
                          Text('★ ${media.formattedRating}',
                              style: SabuflixTheme.body(color: Colors.white70)),
                        if (media.genres?.isNotEmpty ?? false)
                          Text(media.genres!.take(2).join(' · '),
                              style: SabuflixTheme.body(color: Colors.white70))
                        else if (media.genreIds.isNotEmpty)
                          Text(
                              media.genreIds
                                  .take(2)
                                  .map((id) => _genreName(id))
                                  .join(' · '),
                              style: SabuflixTheme.body(color: Colors.white70)),
                      ],
                    ),
                    if (media.overview?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 14),
                      Text(
                        media.overview!,
                        maxLines: desktop ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: SabuflixTheme.body(
                            fontSize: 15, color: const Color(0xFFE0E0E5)),
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
                            glassRoute(MediaDetailsScreen(
                                media: media, autoPlay: true)),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(150, 52),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 26),
                          label: const Text('Assistir'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            glassRoute(MediaDetailsScreen(media: media)),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor:
                                Colors.white.withValues(alpha: .12),
                            side: BorderSide(
                                color: Colors.white.withValues(alpha: .24)),
                            minimumSize: const Size(150, 52),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                          ),
                          icon:
                              const Icon(Icons.info_outline_rounded, size: 21),
                          label: const Text('Ver detalhes'),
                        ),
                        IconButton.outlined(
                          tooltip: favorite
                              ? 'Remover da lista'
                              : 'Adicionar à lista',
                          onPressed: () async {
                            try {
                              await context
                                  .read<FavoritesProvider>()
                                  .toggleFavorite(media);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(favorite
                                      ? 'Removido da lista'
                                      : 'Adicionado à lista'),
                                ),
                              );
                            } catch (_) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Não foi possível salvar. Tente novamente.'),
                                ),
                              );
                            }
                          },
                          style: IconButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor:
                                Colors.white.withValues(alpha: .12),
                            side: BorderSide(
                                color: Colors.white.withValues(alpha: .24)),
                            minimumSize: const Size(52, 52),
                          ),
                          icon: Icon(favorite
                              ? Icons.check_rounded
                              : Icons.add_rounded),
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

  static String _genreName(int id) {
    const names = {
      28: 'Ação',
      12: 'Aventura',
      16: 'Animação',
      35: 'Comédia',
      80: 'Crime',
      99: 'Documentário',
      18: 'Drama',
      10751: 'Família',
      14: 'Fantasia',
      36: 'História',
      27: 'Terror',
      10402: 'Música',
      9648: 'Mistério',
      10749: 'Romance',
      878: 'Ficção científica',
      53: 'Suspense',
      10752: 'Guerra',
      37: 'Faroeste',
      10759: 'Ação e aventura',
      10762: 'Infantil',
      10764: 'Reality',
      10765: 'Sci-fi e fantasia',
      10768: 'Guerra e política',
    };
    return names[id] ?? 'Entretenimento';
  }
}
