import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/favorites_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../widgets/media_card.dart';

class MyListScreen extends StatelessWidget {
  const MyListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final favorites = favoritesProvider.favorites;
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = (screenWidth / 160).floor().clamp(2, 6);
    // Leave room for the floating dock so the last row stays reachable.
    final bottomInset = screenWidth < 800 ? 118.0 : 32.0;

    return Scaffold(
      backgroundColor: SabuflixTheme.of(context).background,
      appBar: AppBar(
        backgroundColor: SabuflixTheme.of(context).background,
        title: Row(
          children: [
            Text('Minha Lista',
                style: SabuflixTheme.of(context)
                    .title(fontSize: 20, fontWeight: FontWeight.w700)),
            if (favorites.isNotEmpty) ...[
              SizedBox(width: 10),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: SabuflixTheme.of(context).surfaceLight,
                  borderRadius: SabuflixTheme.radiusPill,
                  border: Border.all(color: SabuflixTheme.of(context).border),
                ),
                child: Text(
                  '${favorites.length}',
                  style: SabuflixTheme.of(context).label(
                      fontSize: 12,
                      color: SabuflixTheme.of(context).textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
      body: favoritesProvider.isLoading
          ? Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                    color: SabuflixTheme.of(context).textPrimary,
                    strokeWidth: 2.5),
              ),
            )
          : favorites.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(32, 0, 32, bottomInset),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bookmark_border_rounded,
                            size: 52,
                            color: SabuflixTheme.of(context).textMuted),
                        SizedBox(height: 18),
                        Text(
                          'Sua lista está vazia',
                          style: SabuflixTheme.of(context).title(fontSize: 17),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Adicione filmes e séries para assistir mais tarde.',
                          textAlign: TextAlign.center,
                          style: SabuflixTheme.of(context).body(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              : GridView.builder(
                  physics: BouncingScrollPhysics(),
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
