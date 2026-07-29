import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';
import '../theme/sabuflix_theme.dart';
import 'search_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({Key? key}) : super(key: key);

  static const List<Map<String, dynamic>> categoryCards = [
    {'id': 28, 'name': 'Ação & Aventura', 'icon': Icons.flash_on_rounded, 'color': Color(0xFFD97757)},
    {'id': 35, 'name': 'Comédia', 'icon': Icons.sentiment_satisfied_rounded, 'color': Color(0xFFE8B65A)},
    {'id': 27, 'name': 'Terror & Suspense', 'icon': Icons.visibility_rounded, 'color': Color(0xFF9B8AA6)},
    {'id': 878, 'name': 'Ficção Científica', 'icon': Icons.rocket_launch_rounded, 'color': Color(0xFF7C9AA3)},
    {'id': 16, 'name': 'Animação', 'icon': Icons.animation_rounded, 'color': Color(0xFF8A9A6E)},
    {'id': 18, 'name': 'Drama', 'icon': Icons.theater_comedy_rounded, 'color': Color(0xFFA3897A)},
    {'id': 99, 'name': 'Documentários', 'icon': Icons.camera_roll_rounded, 'color': Color(0xFF9C8064)},
    {'id': 10749, 'name': 'Romance', 'icon': Icons.favorite_rounded, 'color': Color(0xFFC17A6E)},
  ];

  @override
  Widget build(BuildContext context) {
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = (screenWidth / 200).floor().clamp(2, 4);

    return Scaffold(
      backgroundColor: SabuflixTheme.background,
      appBar: AppBar(
        backgroundColor: SabuflixTheme.background,
        title: Text('Categorias', style: SabuflixTheme.title(fontSize: 20, fontWeight: FontWeight.w700)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.7,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: categoryCards.length,
          itemBuilder: (context, index) {
            final cat = categoryCards[index];
            final Color catColor = cat['color'] as Color;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  searchProvider.filterByGenre(cat['id'] as int);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SearchScreen()),
                  );
                },
                borderRadius: SabuflixTheme.radiusMd,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: SabuflixTheme.surface,
                    borderRadius: SabuflixTheme.radiusMd,
                    border: Border.all(color: SabuflixTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.16),
                          borderRadius: SabuflixTheme.radiusSm,
                        ),
                        child: Icon(cat['icon'] as IconData, size: 19, color: catColor),
                      ),
                      Text(
                        cat['name'] as String,
                        style: SabuflixTheme.body(fontSize: 14, fontWeight: FontWeight.w600, color: SabuflixTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
