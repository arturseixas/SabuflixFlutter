import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/sabuflix_theme.dart';
import '../providers/catalog_provider.dart';
import '../widgets/hero_banner.dart';
import '../widgets/media_row.dart';

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
                  const CircularProgressIndicator(
                    color: SabuflixTheme.terracotta,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Carregando catálogo Sabuflix...',
                    style: SabuflixTheme.sansBody(
                      color: SabuflixTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => catalog.loadCatalog(),
              color: SabuflixTheme.terracotta,
              backgroundColor: SabuflixTheme.surface,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // App Bar for mobile view
                  if (!isDesktop)
                    SliverAppBar(
                      floating: true,
                      backgroundColor: SabuflixTheme.background.withValues(alpha: 0.95),
                      elevation: 0,
                      centerTitle: false,
                      title: Row(
                        children: [
                          const Text(
                            '✳',
                            style: TextStyle(
                              color: SabuflixTheme.terracotta,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'SABUFLIX',
                            style: SabuflixTheme.serifHeader(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: SabuflixTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: CircleAvatar(
                            radius: 15,
                            backgroundColor: SabuflixTheme.terracotta,
                            child: const Text('S', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),

                  // Hero Banner Section
                  if (catalog.heroItem != null)
                    SliverToBoxAdapter(
                      child: HeroBanner(media: catalog.heroItem!),
                    ),

                  // Media Catalog Rows
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
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
