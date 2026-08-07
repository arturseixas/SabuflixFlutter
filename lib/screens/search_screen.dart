import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';
import '../services/tmdb_service.dart';
import '../theme/sabuflix_theme.dart';
import '../widgets/media_card.dart';
import '../widgets/glass_container.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchProvider = Provider.of<SearchProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = (screenWidth / 160).floor().clamp(2, 6);

    return Scaffold(
      backgroundColor: SabuflixTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: GlassContainer(
                borderRadius: SabuflixTheme.radiusPill,
                blur: 24,
                // An even fill instead of the default glass gradient, which runs
                // bright at one end and near-black at the other — the placeholder
                // was washed out on the light edge and lost on the dark one.
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.11),
                    Colors.white.withValues(alpha: 0.07),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16), width: 0.8),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  style: SabuflixTheme.body(fontSize: 15, color: SabuflixTheme.textPrimary),
                  onChanged: (val) => searchProvider.search(val),
                  decoration: InputDecoration(
                    hintText: 'Pesquisar filmes, séries e gêneros',
                    hintStyle: SabuflixTheme.body(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: SabuflixTheme.textSecondary,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: SabuflixTheme.accent, size: 22),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, color: SabuflixTheme.textSecondary, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              searchProvider.clearSearch();
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),

            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: TMDBService.genreMap.entries.map((entry) {
                  final isSelected = searchProvider.selectedGenreId == entry.key;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(entry.value),
                      selected: isSelected,
                      showCheckmark: false,
                      selectedColor: SabuflixTheme.accent,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      labelStyle: SabuflixTheme.body(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : SabuflixTheme.textSecondary,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                        side: BorderSide.none,
                      ),
                      onSelected: (_) {
                        if (isSelected) {
                          searchProvider.clearSearch();
                        } else {
                          searchProvider.filterByGenre(entry.key);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: searchProvider.isSearching
                  ? const Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(color: SabuflixTheme.textPrimary, strokeWidth: 2.5),
                      ),
                    )
                  : searchProvider.searchResults.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.search_rounded, size: 48, color: SabuflixTheme.textMuted),
                                const SizedBox(height: 16),
                                Text(
                                  searchProvider.query.isEmpty && searchProvider.selectedGenreId == null
                                      ? 'Digite o nome de um título ou escolha um gênero'
                                      : 'Nenhum resultado encontrado para "${searchProvider.query}"',
                                  textAlign: TextAlign.center,
                                  style: SabuflixTheme.body(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: searchProvider.searchResults.length,
                          itemBuilder: (context, index) {
                            final item = searchProvider.searchResults[index];
                            return MediaCard(media: item);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
