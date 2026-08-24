import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/downloads_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/watched_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_route.dart';
import '../widgets/glass_container.dart';
import '../widgets/media_card.dart';
import 'downloads_screen.dart';
import 'my_list_screen.dart';
import 'playlists_screen.dart';
import 'watched_history_screen.dart';

/// A single, product-level home for everything the viewer owns or saved.
/// It replaces three competing navigation destinations on small screens.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 800;
    final favorites = context.watch<FavoritesProvider>().favorites;
    final playlists = context.watch<PlaylistProvider>().playlists;
    final downloads = context.watch<DownloadsProvider>();
    final watched = context.watch<WatchedProvider>().items;

    return Scaffold(
      backgroundColor: SabuflixTheme.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Biblioteca',
                            style: SabuflixTheme.headline(
                                fontSize: width < 500 ? 28 : 34)),
                        const SizedBox(height: 8),
                        Text(
                          'Seus títulos, playlists e downloads em um só lugar.',
                          style: SabuflixTheme.body(fontSize: 14),
                        ),
                        const SizedBox(height: 26),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 840
                                ? 4
                                : constraints.maxWidth >= 520
                                    ? 2
                                    : 1;
                            const spacing = 12.0;
                            final cardWidth = (constraints.maxWidth -
                                    (columns - 1) * spacing) /
                                columns;
                            return Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              children: [
                                _LibraryTile(
                                  width: cardWidth,
                                  icon: Icons.bookmark_rounded,
                                  title: 'Minha Lista',
                                  detail:
                                      '${favorites.length} ${favorites.length == 1 ? 'título' : 'títulos'}',
                                  onTap: () => Navigator.push(context,
                                      glassRoute(const MyListScreen())),
                                ),
                                _LibraryTile(
                                  width: cardWidth,
                                  icon: Icons.featured_play_list_rounded,
                                  title: 'Playlists',
                                  detail:
                                      '${playlists.length} ${playlists.length == 1 ? 'coleção' : 'coleções'}',
                                  onTap: () => Navigator.push(context,
                                      glassRoute(const PlaylistsScreen())),
                                ),
                                _LibraryTile(
                                  width: cardWidth,
                                  icon: Icons.download_done_rounded,
                                  title: 'Downloads',
                                  detail: downloads.activeCount > 0
                                      ? '${downloads.activeCount} em andamento'
                                      : '${downloads.completedCount} disponíveis',
                                  badge: downloads.activeCount > 0,
                                  onTap: () => Navigator.push(context,
                                      glassRoute(const DownloadsScreen())),
                                ),
                                _LibraryTile(
                                  width: cardWidth,
                                  icon: Icons.visibility_rounded,
                                  title: 'Já assistidos',
                                  detail:
                                      '${watched.length} ${watched.length == 1 ? 'título' : 'títulos'}',
                                  onTap: () => Navigator.push(context,
                                      glassRoute(const WatchedHistoryScreen())),
                                ),
                              ],
                            );
                          },
                        ),
                        if (favorites.isNotEmpty) ...[
                          const SizedBox(height: 36),
                          _SectionHeading(
                            title: 'Salvos recentemente',
                            onTap: () => Navigator.push(
                                context, glassRoute(const MyListScreen())),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 252,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: favorites.take(10).length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 16),
                              itemBuilder: (context, index) => MediaCard(
                                  media: favorites.reversed.elementAt(index)),
                            ),
                          ),
                        ],
                        SizedBox(height: isMobile ? 124 : 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryTile extends StatefulWidget {
  final double width;
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;
  final bool badge;

  const _LibraryTile({
    required this.width,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    this.badge = false,
  });

  @override
  State<_LibraryTile> createState() => _LibraryTileState();
}

class _LibraryTileState extends State<_LibraryTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.015 : 1,
        duration: SabuflixTheme.durationFast,
        child: SizedBox(
          width: widget.width,
          height: 118,
          child: GlassContainer(
            borderRadius: SabuflixTheme.radiusLg,
            fillOpacity: _hovered ? 0.4 : 0.24,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: SabuflixTheme.radiusLg,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color:
                                  SabuflixTheme.accent.withValues(alpha: 0.13),
                              borderRadius: SabuflixTheme.radiusMd,
                            ),
                            child: Icon(widget.icon,
                                color: SabuflixTheme.accent, size: 24),
                          ),
                          if (widget.badge)
                            const Positioned(
                              top: -2,
                              right: -2,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                    color: SabuflixTheme.accent,
                                    shape: BoxShape.circle),
                                child: SizedBox(width: 9, height: 9),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.title,
                                style: SabuflixTheme.title(fontSize: 15)),
                            const SizedBox(height: 5),
                            Text(widget.detail,
                                style: SabuflixTheme.caption(fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: SabuflixTheme.textMuted),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _SectionHeading({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: SabuflixTheme.title(fontSize: 19))),
        TextButton(onPressed: onTap, child: const Text('Ver tudo')),
      ],
    );
  }
}
