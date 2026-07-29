import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';
import '../services/tmdb_service.dart';
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

    return Scaffold(
      backgroundColor: const Color(0xFF09090E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D14),
        elevation: 0,
        title: TextField(
          controller: _searchController,
          autofocus: false,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          onChanged: (val) => searchProvider.search(val),
          decoration: InputDecoration(
            hintText: 'Pesquisar filmes, séries, gêneros...',
            hintStyle: const TextStyle(color: Colors.white38),
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search, color: Color(0xFFE50914)),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white54),
                    onPressed: () {
                      _searchController.clear();
                      searchProvider.clearSearch();
                    },
                  )
                : null,
          ),
        ),
      ),
      body: Column(
        children: [
          // Genre Chips Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: TMDBService.genreMap.entries.map((entry) {
                final isSelected = searchProvider.selectedGenreId == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(entry.value),
                    selected: isSelected,
                    selectedColor: const Color(0xFFE50914),
                    backgroundColor: const Color(0xFF14141F),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFFE50914) : Colors.white10,
                      ),
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

          // Main Results Grid or Empty State
          Expanded(
            child: searchProvider.isSearching
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE50914)),
                  )
                : searchProvider.searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.movie_filter_outlined,
                              size: 64,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              searchProvider.query.isEmpty && searchProvider.selectedGenreId == null
                                  ? 'Digite o nome de um filme ou escolha um gênero acima'
                                  : 'Nenhum resultado encontrado para "${searchProvider.query}"',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white54, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
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
    );
  }
}
