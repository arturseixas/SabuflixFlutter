import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../providers/catalog_provider.dart';
import '../providers/search_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_route.dart';
import 'search_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});
  static const _genres = [
    (28, 'Ação e aventura'),
    (35, 'Comédia'),
    (27, 'Terror e suspense'),
    (878, 'Ficção científica'),
    (16, 'Animação'),
    (18, 'Drama'),
    (99, 'Documentários'),
    (10749, 'Romance')
  ];

  @override
  Widget build(BuildContext context) {
    final colors = SabuflixTheme.of(context);
    final catalog = context.watch<CatalogProvider>();
    final items = [
      ...catalog.trending,
      ...catalog.popularMovies,
      ...catalog.actionMovies,
      ...catalog.comedyMovies,
      ...catalog.sciFiMovies
    ];
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
          child: CustomScrollView(slivers: [
        SliverPadding(
            padding: EdgeInsets.fromLTRB(width >= 800 ? 40 : 20, 36, 20, 32),
            sliver: SliverToBoxAdapter(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('DESCUBRA',
                      style: colors.display(fontSize: width >= 800 ? 48 : 34)),
                  const SizedBox(height: 12),
                  Text('Outras histórias. Novos pontos de vista.',
                      style: colors.body(fontSize: 17)),
                ]))),
        SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: width >= 800 ? 40 : 20),
            sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: width >= 1100
                        ? 3
                        : width >= 600
                            ? 2
                            : 1,
                    childAspectRatio: 1.65,
                    mainAxisSpacing: 24,
                    crossAxisSpacing: 24),
                itemCount: _genres.length,
                itemBuilder: (context, index) {
                  final genre = _genres[index];
                  MediaItem? artwork;
                  for (final item in items) {
                    if (item.genreIds.contains(genre.$1) &&
                        item.backdropPath != null) {
                      artwork = item;
                      break;
                    }
                  }
                  final hasImage = artwork != null;
                  return Material(
                      color: colors.surface,
                      borderRadius: SabuflixTheme.radiusMd,
                      clipBehavior: Clip.antiAlias,
                      child: Stack(fit: StackFit.expand, children: [
                        if (hasImage)
                          CachedNetworkImage(
                              imageUrl: artwork.fullBackdropPath,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const ColoredBox(
                                  color: SabuflixTheme.surface)),
                        if (hasImage)
                          const DecoratedBox(
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                Colors.black12,
                                Colors.black87
                              ]))),
                        InkWell(
                            onTap: () {
                              context
                                  .read<SearchProvider>()
                                  .filterByGenre(genre.$1);
                              Navigator.push(
                                  context, glassRoute(const SearchScreen()));
                            },
                            child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(genre.$2.toUpperCase(),
                                          style: colors.headline(
                                              fontSize: 24,
                                              color: hasImage
                                                  ? Colors.white
                                                  : colors.textPrimary)),
                                      const SizedBox(height: 12),
                                      Row(children: [
                                        Text('Explorar filmes',
                                            style: colors.caption(
                                                color: hasImage
                                                    ? Colors.white
                                                    : colors.accent)),
                                        const SizedBox(width: 8),
                                        Icon(Icons.arrow_forward,
                                            size: 18,
                                            color: hasImage
                                                ? Colors.white
                                                : colors.accent)
                                      ]),
                                    ]))),
                      ]));
                })),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ])),
    );
  }
}
