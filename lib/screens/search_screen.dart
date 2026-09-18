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
  final ScrollController _gridController = ScrollController();

  @override
  void initState() {
    super.initState();
    _gridController.addListener(() {
      if (!_gridController.hasClients) return;
      final position = _gridController.position;
      if (position.pixels >= position.maxScrollExtent - 600) {
        context.read<SearchProvider>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _gridController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = context.watch<SearchProvider>();
    final settings = context.watch<SettingsProvider>();
    final colors = SabuflixTheme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final crossAxisCount = (screenWidth / 172).floor().clamp(2, 8);
    final bottomInset = screenWidth < 800 ? 118.0 : 32.0;
    final results = settings.visibleItems(search.visibleResults);
    final isIdle = search.isIdle;
    final years = List<int>.generate(12, (i) => DateTime.now().year - i);

    return Scaffold(
      backgroundColor: colors.background,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      style:
                          colors.body(fontSize: 15, color: colors.textPrimary),
                      onChanged: context.read<SearchProvider>().scheduleSearch,
                      onSubmitted: context.read<SearchProvider>().search,
                      decoration: InputDecoration(
                        hintText: 'Filmes, séries, gêneros e anos',
                        hintStyle:
                            colors.body(fontSize: 15, color: colors.textMuted),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        fillColor: Colors.transparent,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                        prefixIcon: Icon(Icons.search_rounded,
                            color: colors.accent, size: 22),
                        suffixIcon: search.query.isNotEmpty || search.isBrowsing
                            ? IconButton(
                                tooltip: 'Limpar busca',
                                icon: Icon(Icons.close_rounded,
                                    color: colors.textMuted, size: 20),
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
            // Type + sort filters.
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                children: [
                  for (final option in const [
                    (SearchType.all, 'Tudo'),
                    (SearchType.movie, 'Filmes'),
                    (SearchType.tv, 'Séries'),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(option.$2),
                        selected: search.type == option.$1,
                        showCheckmark: false,
                        onSelected: (_) => search.setType(option.$1),
                      ),
                    ),
                  if (search.isBrowsing) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Center(
                          child: Container(
                              width: 1, height: 22, color: colors.border)),
                    ),
                    for (final sort in BrowseSort.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          avatar: Icon(
                              sort == BrowseSort.popular
                                  ? Icons.local_fire_department_outlined
                                  : sort == BrowseSort.rating
                                      ? Icons.star_outline_rounded
                                      : Icons.new_releases_outlined,
                              size: 16,
                              color: search.sort == sort
                                  ? Colors.white
                                  : colors.textSecondary),
                          label: Text(sort.label),
                          selected: search.sort == sort,
                          showCheckmark: false,
                          onSelected: (_) => search.setSort(sort),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: PopupMenuButton<int>(
                        tooltip: 'Filtrar por ano',
                        onSelected: (value) =>
                            search.setYear(value == 0 ? null : value),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                              value: 0, child: Text('Qualquer ano')),
                          for (final year in years)
                            PopupMenuItem(value: year, child: Text('$year')),
                        ],
                        child: Chip(
                          avatar: Icon(Icons.calendar_today_outlined,
                              size: 15,
                              color: search.year != null
                                  ? Colors.white
                                  : colors.textSecondary),
                          label: Text(search.year?.toString() ?? 'Ano'),
                          backgroundColor: search.year != null
                              ? SabuflixTheme.brandBlue
                              : colors.surface,
                          labelStyle: TextStyle(
                              color: search.year != null
                                  ? Colors.white
                                  : colors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Genres.
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: TMDBService.browseGenres.map((entry) {
                  final selected = search.selectedGenreId == entry.$1;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(entry.$2),
                      selected: selected,
                      showCheckmark: false,
                      onSelected: (_) {
                        _searchController.clear();
                        selected
                            ? search.clearSearch()
                            : search.filterByGenre(entry.$1);
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
                    ? Center(
                        key: const ValueKey('search-loading'),
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                              color: colors.textPrimary, strokeWidth: 2.5),
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
                                        : search.type != SearchType.all &&
                                                search.searchResults.isNotEmpty
                                            ? 'Nenhum resultado desse tipo. Tente "Tudo".'
                                            : 'Nenhum resultado encontrado.'),
                                onRetry: search.isBrowsing
                                    ? () => search.browse()
                                    : () => search.search(search.query),
                              )
                            : CustomScrollView(
                                key: const ValueKey('search-results'),
                                controller: _gridController,
                                physics: const BouncingScrollPhysics(),
                                slivers: [
                                  SliverPadding(
                                    padding:
                                        const EdgeInsets.fromLTRB(20, 8, 20, 8),
                                    sliver: SliverToBoxAdapter(
                                      child: Text(
                                        '${results.length}${search.hasMore ? '+' : ''} ${results.length == 1 ? 'título' : 'títulos'}',
                                        style: colors.caption(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  SliverPadding(
                                    padding:
                                        const EdgeInsets.fromLTRB(20, 0, 20, 8),
                                    sliver: SliverGrid.builder(
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        childAspectRatio:
                                            settings.compactPosters
                                                ? 0.72
                                                : 0.62,
                                        crossAxisSpacing: 14,
                                        mainAxisSpacing: 16,
                                      ),
                                      itemCount: results.length,
                                      itemBuilder: (context, index) =>
                                          MediaCard(media: results[index]),
                                    ),
                                  ),
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(
                                          20, 8, 20, bottomInset),
                                      child: search.isLoadingMore
                                          ? const Center(
                                              child: SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2)))
                                          : search.hasMore
                                              ? Center(
                                                  child: OutlinedButton(
                                                      onPressed:
                                                          search.loadMore,
                                                      child: const Text(
                                                          'Carregar mais')))
                                              : const SizedBox.shrink(),
                                    ),
                                  ),
                                ],
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
    final catalog = context.watch<CatalogProvider>();
    final colors = SabuflixTheme.of(context);
    final trending = settings.visibleItems(catalog.trending).take(12).toList();
    final newSeries = settings.visibleItems(catalog.onTheAir).take(12).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(22, 12, 22, bottomInset),
      children: [
        if (search.recentSearches.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                  child: Text('Buscas recentes',
                      style: colors.title(fontSize: 18))),
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
        Text('Em alta agora', style: colors.title(fontSize: 18)),
        const SizedBox(height: 14),
        if (trending.isEmpty)
          Text('O catálogo aparecerá aqui quando estiver disponível.',
              style: colors.body(fontSize: 13))
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
        if (newSeries.isNotEmpty) ...[
          const SizedBox(height: 30),
          Text('Séries com episódios novos', style: colors.title(fontSize: 18)),
          const SizedBox(height: 14),
          SizedBox(
            height: settings.compactPosters ? 222 : 252,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: newSeries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 15),
              itemBuilder: (context, index) =>
                  MediaCard(media: newSeries[index]),
            ),
          ),
        ],
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
            Icon(Icons.search_off_rounded,
                size: 50, color: SabuflixTheme.of(context).textMuted),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: SabuflixTheme.of(context).body(fontSize: 14)),
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
