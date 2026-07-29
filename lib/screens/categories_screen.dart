import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tmdb_service.dart';
import '../providers/search_provider.dart';
import 'search_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({Key? key}) : super(key: key);

  static const List<Map<String, dynamic>> categoryCards = [
    {'id': 28, 'name': 'Ação & Aventura', 'icon': Icons.flash_on_rounded, 'color': Color(0xFFE50914)},
    {'id': 35, 'name': 'Comédia', 'icon': Icons.sentiment_very_satisfied_rounded, 'color': Color(0xFFFF9800)},
    {'id': 27, 'name': 'Terror & Suspense', 'icon': Icons.dark_mode_rounded, 'color': Color(0xFF9C27B0)},
    {'id': 878, 'name': 'Ficção Científica', 'icon': Icons.rocket_launch_rounded, 'color': Color(0xFF00BCD4)},
    {'id': 16, 'name': 'Animação', 'icon': Icons.animation_rounded, 'color': Color(0xFF4CAF50)},
    {'id': 18, 'name': 'Drama', 'icon': Icons.theater_comedy_rounded, 'color': Color(0xFF3F51B5)},
    {'id': 99, 'name': 'Documentários', 'icon': Icons.camera_roll_rounded, 'color': Color(0xFF795548)},
    {'id': 10749, 'name': 'Romance', 'icon': Icons.favorite_rounded, 'color': Color(0xFFE91E63)},
  ];

  @override
  Widget build(BuildContext context) {
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = (screenWidth / 180).floor().clamp(2, 4);

    return Scaffold(
      backgroundColor: const Color(0xFF09090E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D14),
        elevation: 0,
        title: const Text(
          'Categorias Sabuflix',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: categoryCards.length,
          itemBuilder: (context, index) {
            final cat = categoryCards[index];
            final Color catColor = cat['color'] as Color;

            return InkWell(
              onTap: () {
                searchProvider.filterByGenre(cat['id'] as int);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SearchScreen()),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      catColor.withOpacity(0.85),
                      const Color(0xFF14141F),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: catColor.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(cat['icon'] as IconData, size: 36, color: Colors.white),
                    const SizedBox(height: 10),
                    Text(
                      cat['name'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
