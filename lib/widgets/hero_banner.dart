import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../theme/sabuflix_theme.dart';
import '../providers/favorites_provider.dart';
import '../tv/tv_focus.dart';
import '../tv/tv_metrics.dart';
import '../utils/app_route.dart';
import '../screens/media_details_screen.dart';

class HeroBanner extends StatelessWidget {
  final MediaItem media;

  const HeroBanner({Key? key, required this.media}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final isFav = favoritesProvider.isFavorite(media.id);
    final metrics = TvMetrics.of(context);
    final screenWidth = metrics.screen.width;
    final isWide = metrics.isWide;

    return SizedBox(
      height: metrics.heroHeight,
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
            bottom: metrics.isTv ? 56 : 44,
            left: isWide ? metrics.gutter + 12 : 24,
            right: isWide ? screenWidth * 0.4 : 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (media.fullLogoPath != null) ...[
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: metrics.isTv ? 190 : (isWide ? 120 : 80),
                      maxWidth: metrics.isTv ? 620 : (isWide ? 440 : 290),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: media.fullLogoPath!,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                      errorWidget: (context, url, err) => Text(
                        media.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SabuflixTheme.headline(
                          fontSize: metrics.isTv ? 62 : (isWide ? 44 : 30),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    media.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SabuflixTheme.headline(
                      fontSize: metrics.isTv ? 62 : (isWide ? 44 : 30),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                SizedBox(height: metrics.isTv ? 18 : 14),

                Row(
                  children: [
                    Icon(Icons.star_rounded, color: SabuflixTheme.gold, size: metrics.isTv ? 24 : 16),
                    const SizedBox(width: 4),
                    Text(
                      media.formattedRating,
                      style: SabuflixTheme.body(
                        fontSize: metrics.bodySize,
                        fontWeight: FontWeight.w600,
                        color: SabuflixTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('·', style: SabuflixTheme.body(fontSize: metrics.bodySize, color: SabuflixTheme.textMuted)),
                    const SizedBox(width: 10),
                    Text(media.formattedYear, style: SabuflixTheme.body(fontSize: metrics.bodySize)),
                  ],
                ),
                SizedBox(height: metrics.isTv ? 20 : 16),

                if (media.overview != null && media.overview!.isNotEmpty)
                  Text(
                    media.overview!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: SabuflixTheme.body(
                      fontSize: metrics.isTv ? 21 : 15,
                      height: 1.5,
                      color: SabuflixTheme.textSecondary,
                    ),
                  ),
                SizedBox(height: metrics.isTv ? 34 : 26),

                Wrap(
                  spacing: metrics.isTv ? 18 : 12,
                  runSpacing: 12,
                  children: [
                    _HeroButton(
                      icon: Icons.play_arrow_rounded,
                      label: 'Assistir',
                      primary: true,
                      // The first thing a remote should land on when the home
                      // screen opens.
                      autofocus: metrics.isTv,
                      onPressed: () {
                        Navigator.push(context, glassRoute(MediaDetailsScreen(media: media)));
                      },
                    ),
                    _HeroButton(
                      icon: isFav ? Icons.check_rounded : Icons.add_rounded,
                      label: isFav ? 'Na Lista' : 'Minha Lista',
                      primary: false,
                      highlighted: isFav,
                      onPressed: () {
                        favoritesProvider.toggleFavorite(media);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isFav ? 'Removido da lista' : 'Adicionado à lista')),
                        );
                      },
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

/// The hero's call to action, focusable by remote.
///
/// Solid fills instead of the frosted glass used elsewhere: a `BackdropFilter`
/// behind a moving focus highlight is the fastest way to drop frames on a TV.
class _HeroButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final bool highlighted;
  final bool autofocus;
  final VoidCallback onPressed;

  const _HeroButton({
    required this.icon,
    required this.label,
    required this.primary,
    required this.onPressed,
    this.highlighted = false,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = TvMetrics.of(context);

    return TvFocusable(
      autofocus: autofocus,
      onPressed: onPressed,
      showRing: false,
      scaleOnFocus: false,
      semanticLabel: label,
      builder: (context, focused, child) {
        final Color background = focused
            ? SabuflixTheme.textPrimary
            : primary
                ? SabuflixTheme.accent
                : Colors.white.withValues(alpha: 0.16);
        final Color foreground = focused
            ? SabuflixTheme.background
            : highlighted
                ? SabuflixTheme.accent
                : Colors.white;

        return AnimatedContainer(
          duration: SabuflixTheme.durationFast,
          curve: SabuflixTheme.curveStandard,
          padding: EdgeInsets.symmetric(
            horizontal: metrics.isTv ? 34 : 24,
            vertical: metrics.isTv ? 18 : 14,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: SabuflixTheme.radiusPill,
            border: Border.all(
              color: focused ? SabuflixTheme.textPrimary : Colors.white.withValues(alpha: 0.16),
              width: focused ? metrics.focusRingWidth : 1,
            ),
            boxShadow: focused
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 26, offset: const Offset(0, 10))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: metrics.isTv ? 30 : 22, color: foreground),
              const SizedBox(width: 10),
              Text(
                label,
                style: SabuflixTheme.body(
                  fontSize: metrics.isTv ? 20 : 15,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ],
          ),
        );
      },
      child: const SizedBox.shrink(),
    );
  }
}
