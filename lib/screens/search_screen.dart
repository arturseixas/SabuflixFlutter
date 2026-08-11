import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';
import '../services/tmdb_service.dart';
import '../theme/sabuflix_theme.dart';
import '../tv/tv_focus.dart';
import '../tv/tv_metrics.dart';
import '../widgets/media_card.dart';
import '../widgets/glass_container.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  /// Whether the text field holds the focus, so the search box can show the
  /// same ring every other TV control uses. A caret alone is invisible from
  /// the sofa.
  bool _searchFocused = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchProvider = Provider.of<SearchProvider>(context);
    final metrics = TvMetrics.of(context);

    return Scaffold(
      backgroundColor: SabuflixTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(metrics.gutter, metrics.isTv ? 28 : 16, metrics.gutter, 8),
              child: Focus(
                canRequestFocus: false,
                skipTraversal: true,
                onFocusChange: (focused) => setState(() => _searchFocused = focused),
                child: AnimatedContainer(
                  duration: SabuflixTheme.durationFast,
                  decoration: tvFocusDecoration(
                    focused: _searchFocused,
                    borderRadius: SabuflixTheme.radiusPill,
                    ringWidth: metrics.focusRingWidth,
                  ),
                  child: GlassContainer(
                    borderRadius: SabuflixTheme.radiusPill,
                    blur: 24,
                    fillOpacity: 0.35,
                    padding: EdgeInsets.symmetric(horizontal: metrics.isTv ? 24 : 16),
                    child: TextField(
                      controller: _searchController,
                      style: SabuflixTheme.body(fontSize: metrics.bodySize, color: SabuflixTheme.textPrimary),
                      onChanged: (val) => searchProvider.search(val),
                      // The TV keyboards (the Android TV IME, the Tizen and
                      // webOS virtual keyboards) commit with a "search" action;
                      // without this the remote's OK only dismisses them.
                      textInputAction: TextInputAction.search,
                      onSubmitted: searchProvider.search,
                      decoration: InputDecoration(
                        hintText: 'Pesquisar filmes, séries e gêneros',
                        hintStyle: SabuflixTheme.body(fontSize: metrics.bodySize, color: SabuflixTheme.textMuted),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        fillColor: Colors.transparent,
                        contentPadding: EdgeInsets.symmetric(vertical: metrics.isTv ? 20 : 14),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: SabuflixTheme.accent,
                          size: metrics.iconSize,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: SabuflixTheme.textMuted,
                                  size: metrics.iconSize - 2,
                                ),
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
              ),
            ),

            SizedBox(
              height: metrics.isTv ? 72 : 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: metrics.isTv ? const ClampingScrollPhysics() : const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: metrics.gutter, vertical: 6),
                children: TMDBService.genreMap.entries.map((entry) {
                  final isSelected = searchProvider.selectedGenreId == entry.key;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _GenreChip(
                      label: entry.value,
                      selected: isSelected,
                      onPressed: () {
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
                                Icon(
                                  Icons.search_rounded,
                                  size: metrics.isTv ? 72 : 48,
                                  color: SabuflixTheme.textMuted,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  searchProvider.query.isEmpty && searchProvider.selectedGenreId == null
                                      ? 'Digite o nome de um título ou escolha um gênero'
                                      : 'Nenhum resultado encontrado para "${searchProvider.query}"',
                                  textAlign: TextAlign.center,
                                  style: SabuflixTheme.body(fontSize: metrics.bodySize),
                                ),
                              ],
                            ),
                          ),
                        )
                      : GridView.builder(
                          physics: metrics.isTv ? const ClampingScrollPhysics() : const BouncingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(metrics.gutter, 4, metrics.gutter, metrics.bottomInset),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: metrics.gridCrossAxisCount,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: metrics.isTv ? 20 : 12,
                            mainAxisSpacing: metrics.isTv ? 26 : 12,
                          ),
                          itemCount: searchProvider.searchResults.length,
                          itemBuilder: (context, index) {
                            final item = searchProvider.searchResults[index];
                            // The cell fixes the width; the card must not.
                            return MediaCard(media: item, width: double.infinity);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Genre filter pill.
///
/// A [FilterChip] cannot show a focus state a remote user can see, so the chip
/// is rebuilt on top of [TvFocusable] — same look on touch, unmistakable
/// highlight on a TV.
class _GenreChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _GenreChip({required this.label, required this.selected, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final metrics = TvMetrics.of(context);

    return TvFocusable(
      onPressed: onPressed,
      showRing: false,
      scaleOnFocus: false,
      semanticLabel: label,
      builder: (context, focused, child) => AnimatedContainer(
        duration: SabuflixTheme.durationFast,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: metrics.isTv ? 24 : 14, vertical: metrics.isTv ? 12 : 8),
        decoration: BoxDecoration(
          color: focused
              ? SabuflixTheme.textPrimary
              : selected
                  ? SabuflixTheme.accent
                  : Colors.white.withValues(alpha: 0.08),
          borderRadius: SabuflixTheme.radiusPill,
        ),
        child: Text(
          label,
          style: SabuflixTheme.body(
            fontSize: metrics.isTv ? 17 : 13,
            fontWeight: selected || focused ? FontWeight.w700 : FontWeight.w500,
            color: focused
                ? SabuflixTheme.background
                : selected
                    ? Colors.white
                    : SabuflixTheme.textSecondary,
          ),
        ),
      ),
      child: const SizedBox.shrink(),
    );
  }
}
