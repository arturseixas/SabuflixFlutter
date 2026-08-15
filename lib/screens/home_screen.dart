import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/sabuflix_theme.dart';
import '../providers/catalog_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/continue_watching_row.dart';
import '../widgets/hero_banner.dart';
import '../widgets/home_skeleton.dart';
import '../widgets/media_row.dart';
import '../widgets/wordmark.dart';
import 'profile_selection_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final catalog = Provider.of<CatalogProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return Scaffold(
      backgroundColor: SabuflixTheme.background,
      body: catalog.isLoading
          // Skeleton instead of a spinner: the page keeps its shape while the
          // catalogue loads, so the first paint doesn't jump.
          ? const HomeSkeleton()
          : RefreshIndicator(
              onRefresh: () => catalog.loadCatalog(),
              color: SabuflixTheme.textPrimary,
              backgroundColor: SabuflixTheme.surface,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  if (!isDesktop)
                    SliverAppBar(
                      floating: true,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      centerTitle: false,
                      flexibleSpace: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                          child: Container(
                              color: SabuflixTheme.background
                                  .withValues(alpha: 0.5)),
                        ),
                      ),
                      title: const SabuflixWordmark(fontSize: 19),
                      actions: const [
                        Padding(
                          padding: EdgeInsets.only(right: 16),
                          child: _AccountBadge(),
                        ),
                      ],
                    ),
                  if (catalog.heroItem != null)
                    SliverToBoxAdapter(
                      child: HeroBanner(media: catalog.heroItem!),
                    ),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        const ContinueWatchingRow(),
                        MediaRow(
                          title: 'Em Alta Hoje',
                          mediaItems: catalog.trending,
                        ),
                        MediaRow(
                          title: 'Filmes Populares',
                          mediaItems: catalog.popularMovies,
                        ),
                        MediaRow(
                          title: 'Séries em Destaque',
                          mediaItems: catalog.popularTV,
                        ),
                        MediaRow(
                          title: 'Mais Bem Avaliados',
                          mediaItems: catalog.topRated,
                        ),
                        MediaRow(
                          title: 'Ação e Aventura',
                          mediaItems: catalog.actionMovies,
                        ),
                        MediaRow(
                          title: 'Comédias',
                          mediaItems: catalog.comedyMovies,
                        ),
                        MediaRow(
                          title: 'Ficção Científica',
                          mediaItems: catalog.sciFiMovies,
                        ),
                        // Clears the floating dock on phones.
                        SizedBox(height: isDesktop ? 40 : 120),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _AccountBadge extends StatelessWidget {
  const _AccountBadge();

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, provider, child) {
        final profile = provider.currentProfile;
        if (profile == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => const ProfileSelectionScreen()));
          },
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SabuflixTheme.accentSoft,
              shape: BoxShape.circle,
              border: Border.all(
                  color: SabuflixTheme.accent.withValues(alpha: 0.5)),
            ),
            child: const Icon(Icons.person_outline_rounded,
                size: 19, color: SabuflixTheme.accentHover),
          ),
        );
      },
    );
  }
}
