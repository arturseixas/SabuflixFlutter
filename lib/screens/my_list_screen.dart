import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/favorites_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../widgets/media_card.dart';

class MyListScreen extends StatelessWidget {
  const MyListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final favorites = favoritesProvider.favorites;
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = (screenWidth / 160).floor().clamp(2, 6);
    // Leave room for the floating dock so the last row stays reachable.
    final bottomInset = screenWidth < 800 ? 118.0 : 32.0;

    return Scaffold(
      backgroundColor: SabuflixTheme.background,
      appBar: AppBar(
        backgroundColor: SabuflixTheme.background,
        title: Row(
          children: [
            Text('Minha Lista', style: SabuflixTheme.title(fontSize: 20, fontWeight: FontWeight.w700)),
            if (favorites.isNotEmpty) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: SabuflixTheme.surfaceLight,
                  borderRadius: SabuflixTheme.radiusPill,
                  border: Border.all(color: SabuflixTheme.border),
                ),
                child: Text(
                  '${favorites.length}',
                  style: SabuflixTheme.label(fontSize: 12, color: SabuflixTheme.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
      body: favoritesProvider.isLoading
          ? const Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(color: SabuflixTheme.textPrimary, strokeWidth: 2.5),
              ),
            )
          : favorites.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(32, 0, 32, bottomInset),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bookmark_border_rounded, size: 52, color: SabuflixTheme.textMuted),
                        const SizedBox(height: 18),
                        Text(
                          'Sua lista está vazia',
                          style: SabuflixTheme.title(fontSize: 17),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Adicione filmes e séries para assistir mais tarde.',
                          textAlign: TextAlign.center,
                          style: SabuflixTheme.body(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              : GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 4, 16, bottomInset),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: favorites.length,
                  itemBuilder: (context, index) {
                    final item = favorites[index];
                    return MediaCard(media: item);
                  },
                ),
    );
  }
}
