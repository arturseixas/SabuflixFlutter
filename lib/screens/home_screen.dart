import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      backgroundColor: const Color(0xFF09090E),
      body: catalog.isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFFE50914),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Carregando catálogo Sabuflix...',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => catalog.loadCatalog(),
              color: const Color(0xFFE50914),
              backgroundColor: const Color(0xFF14141F),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // App Bar for mobile view
                  if (!isDesktop)
                    SliverAppBar(
                      floating: true,
                      backgroundColor: const Color(0xFF09090E).withOpacity(0.9),
                      elevation: 0,
                      centerTitle: false,
                      title: Row(
                        children: [
                          const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFE50914), size: 26),
                          const SizedBox(width: 6),
                          Text(
                            'SABUFLIX',
                            style: TextStyle(
                              color: const Color(0xFFE50914),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              shadows: [
                                Shadow(
                                  color: const Color(0xFFE50914).withOpacity(0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.person, color: Colors.white),
                          onPressed: () {},
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
                        const SizedBox(height: 10),
                        MediaRow(
                          title: '🔥 Em Alta Hoje',
                          mediaItems: catalog.trending,
                        ),
                        MediaRow(
                          title: '🎬 Filmes Populares',
                          mediaItems: catalog.popularMovies,
                        ),
                        MediaRow(
                          title: '📺 Séries em Destaque',
                          mediaItems: catalog.popularTV,
                        ),
                        MediaRow(
                          title: '⭐ Mais Bem Avaliados',
                          mediaItems: catalog.topRated,
                        ),
                        MediaRow(
                          title: '💥 Ação e Aventura',
                          mediaItems: catalog.actionMovies,
                        ),
                        MediaRow(
                          title: '🎭 Comédias',
                          mediaItems: catalog.comedyMovies,
                        ),
                        MediaRow(
                          title: '🚀 Ficção Científica',
                          mediaItems: catalog.sciFiMovies,
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
