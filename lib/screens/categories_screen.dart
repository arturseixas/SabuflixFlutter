import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/search_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_route.dart';
import 'search_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static const List<Map<String, dynamic>> categoryCards = [
    {
      'id': 28,
      'name': 'Ação e aventura',
      'icon': Icons.bolt_rounded,
      'copy': 'Ritmo alto e grandes jornadas'
    },
    {
      'id': 35,
      'name': 'Comédia',
      'icon': Icons.sentiment_satisfied_alt_rounded,
      'copy': 'Histórias para assistir sem pressa'
    },
    {
      'id': 27,
      'name': 'Terror e suspense',
      'icon': Icons.visibility_rounded,
      'copy': 'Tensão até o último minuto'
    },
    {
      'id': 878,
      'name': 'Ficção científica',
      'icon': Icons.public_rounded,
      'copy': 'Outros mundos, novas ideias'
    },
    {
      'id': 16,
      'name': 'Animação',
      'icon': Icons.animation_rounded,
      'copy': 'Imaginação em movimento'
    },
    {
      'id': 18,
      'name': 'Drama',
      'icon': Icons.theater_comedy_rounded,
      'copy': 'Personagens que ficam com você'
    },
    {
      'id': 99,
      'name': 'Documentários',
      'icon': Icons.videocam_outlined,
      'copy': 'Histórias reais bem contadas'
    },
    {
      'id': 10749,
      'name': 'Romance',
      'icon': Icons.favorite_border_rounded,
      'copy': 'Encontros, escolhas e afetos'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final search = context.read<SearchProvider>();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 800;

    return Scaffold(
      appBar: AppBar(
          title:
              Text('Categorias', style: SabuflixTheme.headline(fontSize: 24))),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth - 40;
          final regularWidth = isDesktop
              ? ((contentWidth - 32) / 3).clamp(220.0, 360.0)
              : (contentWidth - 12) / 2;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 10, 20, isDesktop ? 36 : 126),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var index = 0; index < categoryCards.length; index++)
                  SizedBox(
                    width: !isDesktop && (index == 0 || index == 5)
                        ? contentWidth
                        : regularWidth,
                    height:
                        !isDesktop && (index == 0 || index == 5) ? 142 : 126,
                    child: _CategoryTile(
                      category: categoryCards[index],
                      emphasized: index == 0 || index == 5,
                      onTap: () {
                        search.filterByGenre(categoryCards[index]['id'] as int);
                        Navigator.push(
                            context, glassRoute(const SearchScreen()));
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Map<String, dynamic> category;
  final bool emphasized;
  final VoidCallback onTap;

  const _CategoryTile(
      {required this.category, required this.emphasized, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600 && !emphasized;
    return Material(
      color: emphasized ? SabuflixTheme.accentSoft : SabuflixTheme.surface,
      borderRadius: SabuflixTheme.radiusLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: SabuflixTheme.radiusLg,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: SabuflixTheme.radiusLg,
            border: Border.all(
              color: emphasized
                  ? SabuflixTheme.accent.withValues(alpha: 0.36)
                  : SabuflixTheme.border,
            ),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CategoryIcon(
                        category: category, emphasized: false, size: 34),
                    const Spacer(),
                    Text(
                      category['name'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SabuflixTheme.title(fontSize: 14),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CategoryIcon(category: category, emphasized: emphasized),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(category['name'] as String,
                              style: SabuflixTheme.title(fontSize: 16)),
                          const SizedBox(height: 5),
                          Text(
                            category['copy'] as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: SabuflixTheme.caption(
                                fontSize: 12, color: SabuflixTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_outward_rounded,
                        color: SabuflixTheme.textMuted, size: 18),
                  ],
                ),
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  final Map<String, dynamic> category;
  final bool emphasized;
  final double size;

  const _CategoryIcon(
      {required this.category, required this.emphasized, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: emphasized ? SabuflixTheme.accent : SabuflixTheme.surfaceLight,
        borderRadius: SabuflixTheme.radiusMd,
      ),
      child: Icon(category['icon'] as IconData,
          color: SabuflixTheme.textPrimary, size: 20),
    );
  }
}
