import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';
import '../services/tmdb_service.dart';
import '../theme/sabuflix_theme.dart';
import '../widgets/media_card.dart';

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
    final bottomInset = screenWidth < 800 ? 118.0 : 32.0;

    return Scaffold(
      backgroundColor: SabuflixTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Encontre sua próxima história',
                      style: SabuflixTheme.headline(fontSize: 25)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    style: SabuflixTheme.body(
                        fontSize: 15, color: SabuflixTheme.textPrimary),
                    onChanged: (val) => searchProvider.search(val),
                    decoration: InputDecoration(
                      hintText: 'Pesquisar filmes, séries e gêneros',
                      hintStyle: SabuflixTheme.body(
                          fontSize: 15, color: SabuflixTheme.textMuted),
                      fillColor: SabuflixTheme.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: SabuflixTheme.textSecondary, size: 22),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: SabuflixTheme.textMuted, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                searchProvider.clearSearch();
                              },
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: TMDBService.genreMap.entries.map((entry) {
                  final isSelected =
                      searchProvider.selectedGenreId == entry.key;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(entry.value),
                      selected: isSelected,
                      showCheckmark: false,
                      selectedColor: SabuflixTheme.accent,
                      backgroundColor: SabuflixTheme.surfaceLight,
                      labelStyle: SabuflixTheme.body(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : SabuflixTheme.textSecondary,
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
                  ? const _SearchSkeleton()
                  : searchProvider.searchResults.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: SabuflixTheme.surface,
                                    borderRadius: SabuflixTheme.radiusLg,
                                    border:
                                        Border.all(color: SabuflixTheme.border),
                                  ),
                                  child: const Icon(Icons.search_rounded,
                                      size: 30, color: SabuflixTheme.textMuted),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  searchProvider.query.isEmpty &&
                                          searchProvider.selectedGenreId == null
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
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(16, 4, 16, bottomInset),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: 0.58,
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

class _SearchSkeleton extends StatelessWidget {
  const _SearchSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.62,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 9,
      itemBuilder: (_, index) => Container(
        decoration: BoxDecoration(
          color:
              index.isEven ? SabuflixTheme.surface : SabuflixTheme.surfaceLight,
          borderRadius: SabuflixTheme.radiusMd,
        ),
      ),
    );
  }
}
