import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_route.dart';
import '../widgets/glass_container.dart';
import 'search_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static const List<Map<String, dynamic>> categoryCards = [
    {
      'id': 28,
      'name': 'Ação & Aventura',
      'icon': Icons.flash_on_rounded,
      'color': Color(0xFF0A84FF)
    },
    {
      'id': 35,
      'name': 'Comédia',
      'icon': Icons.sentiment_satisfied_rounded,
      'color': Color(0xFFFF9F0A)
    },
    {
      'id': 27,
      'name': 'Terror & Suspense',
      'icon': Icons.visibility_rounded,
      'color': Color(0xFF5E5CE6)
    },
    {
      'id': 878,
      'name': 'Ficção Científica',
      'icon': Icons.rocket_launch_rounded,
      'color': Color(0xFF64D2FF)
    },
    {
      'id': 16,
      'name': 'Animação',
      'icon': Icons.animation_rounded,
      'color': Color(0xFF63E6E2)
    },
    {
      'id': 18,
      'name': 'Drama',
      'icon': Icons.theater_comedy_rounded,
      'color': Color(0xFFAC8E68)
    },
    {
      'id': 99,
      'name': 'Documentários',
      'icon': Icons.camera_roll_rounded,
      'color': Color(0xFF40C8E0)
    },
    {
      'id': 10749,
      'name': 'Romance',
      'icon': Icons.favorite_rounded,
      'color': Color(0xFFFF375F)
    },
  ];

  @override
  Widget build(BuildContext context) {
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount =
        screenWidth < 430 ? 1 : (screenWidth / 220).floor().clamp(2, 4);

    return Scaffold(
      backgroundColor: SabuflixTheme.background,
      appBar: AppBar(
        backgroundColor: SabuflixTheme.background,
        title: Text('Descobrir',
            style:
                SabuflixTheme.title(fontSize: 20, fontWeight: FontWeight.w700)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                child: Text(
                  'Encontre sua próxima história por gênero.',
                  style: SabuflixTheme.body(fontSize: 14),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                      20, 4, 20, screenWidth < 800 ? 118 : 28),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: screenWidth < 430 ? 2.5 : 1.7,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: categoryCards.length,
                  itemBuilder: (context, index) {
                    final cat = categoryCards[index];
                    final Color catColor = cat['color'] as Color;

                    return GlassContainer(
                      borderRadius: SabuflixTheme.radiusLg,
                      blur: 24,
                      fillOpacity: 0.25,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            searchProvider.filterByGenre(cat['id'] as int);
                            Navigator.push(
                                context, glassRoute(const SearchScreen()));
                          },
                          borderRadius: SabuflixTheme.radiusLg,
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(cat['icon'] as IconData,
                                    size: 24, color: catColor),
                                Text(
                                  cat['name'] as String,
                                  style: SabuflixTheme.body(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: SabuflixTheme.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
