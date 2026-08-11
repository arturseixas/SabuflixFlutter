import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../tv/tv_focus.dart';
import '../tv/tv_metrics.dart';
import '../utils/app_route.dart';
import 'search_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({Key? key}) : super(key: key);

  static const List<Map<String, dynamic>> categoryCards = [
    {'id': 28, 'name': 'Ação & Aventura', 'icon': Icons.flash_on_rounded, 'color': Color(0xFF0A84FF)},
    {'id': 35, 'name': 'Comédia', 'icon': Icons.sentiment_satisfied_rounded, 'color': Color(0xFFFF9F0A)},
    {'id': 27, 'name': 'Terror & Suspense', 'icon': Icons.visibility_rounded, 'color': Color(0xFF5E5CE6)},
    {'id': 878, 'name': 'Ficção Científica', 'icon': Icons.rocket_launch_rounded, 'color': Color(0xFF64D2FF)},
    {'id': 16, 'name': 'Animação', 'icon': Icons.animation_rounded, 'color': Color(0xFF63E6E2)},
    {'id': 18, 'name': 'Drama', 'icon': Icons.theater_comedy_rounded, 'color': Color(0xFFAC8E68)},
    {'id': 99, 'name': 'Documentários', 'icon': Icons.camera_roll_rounded, 'color': Color(0xFF40C8E0)},
    {'id': 10749, 'name': 'Romance', 'icon': Icons.favorite_rounded, 'color': Color(0xFFFF375F)},
  ];

  @override
  Widget build(BuildContext context) {
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    final metrics = TvMetrics.of(context);

    return Scaffold(
      backgroundColor: SabuflixTheme.background,
      appBar: AppBar(
        backgroundColor: SabuflixTheme.background,
        toolbarHeight: metrics.isTv ? 84 : kToolbarHeight,
        title: Text(
          'Categorias',
          style: SabuflixTheme.title(fontSize: metrics.isTv ? 34 : 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(metrics.gutter, 20, metrics.gutter, metrics.bottomInset),
        child: GridView.builder(
          physics: metrics.isTv ? const ClampingScrollPhysics() : const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: metrics.categoryCrossAxisCount,
            childAspectRatio: 1.7,
            crossAxisSpacing: metrics.isTv ? 20 : 14,
            mainAxisSpacing: metrics.isTv ? 20 : 14,
          ),
          itemCount: categoryCards.length,
          itemBuilder: (context, index) {
            final cat = categoryCards[index];
            final Color catColor = cat['color'] as Color;

            return TvFocusable(
              showRing: false,
              scaleOnFocus: false,
              semanticLabel: cat['name'] as String,
              onPressed: () {
                searchProvider.filterByGenre(cat['id'] as int);
                Navigator.push(context, glassRoute(const SearchScreen()));
              },
              // Flat fills instead of the frosted panels used on phones: a
              // grid of live BackdropFilters is more than a TV's GPU will
              // render at 60fps while the focus highlight animates over it.
              builder: (context, focused, child) => AnimatedContainer(
                duration: SabuflixTheme.durationFast,
                curve: SabuflixTheme.curveStandard,
                padding: EdgeInsets.all(metrics.isTv ? 26 : 18),
                decoration: tvFocusDecoration(
                  focused: focused,
                  borderRadius: SabuflixTheme.radiusLg,
                  ringWidth: metrics.focusRingWidth,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      catColor.withValues(alpha: focused ? 0.55 : 0.28),
                      SabuflixTheme.surface.withValues(alpha: focused ? 0.9 : 0.6),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      cat['icon'] as IconData,
                      size: metrics.isTv ? 38 : 24,
                      color: focused ? SabuflixTheme.textPrimary : catColor,
                    ),
                    Text(
                      cat['name'] as String,
                      style: SabuflixTheme.body(
                        fontSize: metrics.isTv ? 22 : 14,
                        fontWeight: FontWeight.w600,
                        color: SabuflixTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              child: const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }
}
