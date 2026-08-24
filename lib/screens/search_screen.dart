import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/catalog_provider.dart';
import '../providers/search_provider.dart';
import '../providers/settings_provider.dart';
import '../services/tmdb_service.dart';
import '../theme/sabuflix_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/media_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

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
    final search = context.watch<SearchProvider>();
    final settings = context.watch<SettingsProvider>();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final contentWidth = screenWidth >= 800 ? screenWidth - 240 : screenWidth;
    final crossAxisCount = (contentWidth / 172).floor().clamp(2, 7);
    final bottomInset = screenWidth < 800 ? 118.0 : 32.0;
    final results = settings.visibleItems(search.searchResults);
    final isIdle =
        search.query.trim().isEmpty && search.selectedGenreId == null;

    return Scaffold(
      backgroundColor: SabuflixTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: GlassContainer(
                    borderRadius: SabuflixTheme.radiusPill,
                    blur: 24,
                    fillOpacity: 0.35,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      style: SabuflixTheme.body(
                          fontSize: 15, color: SabuflixTheme.textPrimary),
                      onChanged: context.read<SearchProvider>().scheduleSearch,
                      onSubmitted: context.read<SearchProvider>().search,
                      decoration: InputDecoration(
                        hintText: 'Filmes, séries e gêneros',
                        hintStyle: SabuflixTheme.body(
                            fontSize: 15, color: SabuflixTheme.textMuted),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        fillColor: Colors.transparent,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: SabuflixTheme.accent, size: 22),
                        suffixIcon: search.query.isNotEmpty
                            ? IconButton(
                                tooltip: 'Limpar busca',
                                icon: const Icon(Icons.close_rounded,
                                    color: SabuflixTheme.textMuted, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  context.read<SearchProvider>().clearSearch();
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: TMDBService.genreMap.entries.take(20).map((entry) {
                  final selected = search.selectedGenreId == entry.key;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(entry.value),
                      selected: selected,
                      showCheckmark: false,
                      onSelected: (_) {
                        _searchController.clear();
                        selected
                            ? search.clearSearch()
                            : search.filterByGenre(entry.key);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: AnimatedSwitcher(
                duration: SabuflixTheme.durationFast,
                child: search.isSearching
                    ? const Center(
                        key: ValueKey('search-loading'),
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                              color: SabuflixTheme.textPrimary,
                              strokeWidth: 2.5),
                        ),
                      )
                    : isIdle
                        ? _DiscoveryState(
                            key: const ValueKey('search-discovery'),
                            bottomInset: bottomInset,
                            controller: _searchController,
                          )
                        : results.isEmpty
                            ? _SearchEmptyState(
                                key: const ValueKey('search-empty'),
                                message: search.errorMessage ??
                                    (settings.hideUnreleased &&
                                            search.searchResults.isNotEmpty
                                        ? 'Os resultados encontrados ainda não foram lançados.'
                                        : 'Nenhum resultado encontrado.'),
                                onRetry: search.selectedGenreId != null
                                    ? () => search
                                        .filterByGenre(search.selectedGenreId!)
                                    : () => search.search(search.query),
                              )
                            : GridView.builder(
                                key: const ValueKey('search-results'),
                                physics: const BouncingScrollPhysics(),
                                padding:
                                    EdgeInsets.fromLTRB(20, 8, 20, bottomInset),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  childAspectRatio:
                                      settings.compactPosters ? 0.72 : 0.65,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 16,
                                ),
                                itemCount: results.length,
                                itemBuilder: (context, index) =>
                                    MediaCard(media: results[index]),
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryState extends StatelessWidget {
  final double bottomInset;
  final TextEditingController controller;

  const _DiscoveryState(
      {super.key, required this.bottomInset, required this.controller});

  @override
  Widget build(BuildContext context) {
    final search = context.watch<SearchProvider>();
    final settings = context.watch<SettingsProvider>();
    final trending = settings
        .visibleItems(context.watch<CatalogProvider>().trending)
        .take(12)
        .toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(22, 12, 22, bottomInset),
      children: [
        if (search.recentSearches.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                  child: Text('Buscas recentes',
                      style: SabuflixTheme.title(fontSize: 18))),
              TextButton(
                  onPressed: search.clearRecentSearches,
                  child: const Text('Limpar')),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: search.recentSearches.map((value) {
              return ActionChip(
                avatar: const Icon(Icons.history_rounded, size: 16),
                label: Text(value),
                onPressed: () {
                  controller.text = value;
                  controller.selection =
                      TextSelection.collapsed(offset: value.length);
                  search.search(value);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 30),
        ],
        Text('Em alta agora', style: SabuflixTheme.title(fontSize: 18)),
        const SizedBox(height: 14),
        if (trending.isEmpty)
          Text('O catálogo aparecerá aqui quando estiver disponível.',
              style: SabuflixTheme.body(fontSize: 13))
        else
          SizedBox(
            height: settings.compactPosters ? 222 : 252,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: trending.length,
              separatorBuilder: (_, __) => const SizedBox(width: 15),
              itemBuilder: (context, index) =>
                  MediaCard(media: trending[index]),
            ),
          ),
      ],
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _SearchEmptyState(
      {super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 50, color: SabuflixTheme.textMuted),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: SabuflixTheme.body(fontSize: 14)),
            const SizedBox(height: 14),
            TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente')),
          ],
        ),
      ),
    );
  }
}
