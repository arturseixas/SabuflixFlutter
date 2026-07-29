import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/sabuflix_theme.dart';
import '../providers/catalog_provider.dart';
import '../widgets/hero_banner.dart';
import '../widgets/media_row.dart';
import '../widgets/wordmark.dart';

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
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: SabuflixTheme.textPrimary,
                      strokeWidth: 2.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Carregando catálogo...',
                    style: SabuflixTheme.body(fontSize: 14),
                  ),
                ],
              ),
            )
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
                          child: Container(color: SabuflixTheme.background.withValues(alpha: 0.5)),
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
                        const SizedBox(height: 60),
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
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SabuflixTheme.elevated,
        shape: BoxShape.circle,
        border: Border.all(color: SabuflixTheme.borderStrong),
      ),
      child: Text(
        'S',
        style: SabuflixTheme.body(color: SabuflixTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
