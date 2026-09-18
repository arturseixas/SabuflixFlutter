import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../providers/catalog_provider.dart';
import '../providers/continue_watching_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/watched_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_route.dart';
import '../utils/profile_icons.dart';
import '../widgets/cast_button.dart';
import '../widgets/continue_watching_row.dart';
import '../widgets/hero_banner.dart';
import '../widgets/home_skeleton.dart';
import '../widgets/media_row.dart';
import '../widgets/wordmark.dart';
import 'browse_screen.dart';
import 'my_list_screen.dart';
import 'profile_selection_screen.dart';

enum HomeFilter { all, movies, series }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeFilter _filter = HomeFilter.all;

  /// Seeds for the "Porque você assistiu" shelves: what the viewer is in the
  /// middle of, then what they finished most recently.
  void _refreshRecommendations() {
    final continueWatching = context.read<ContinueWatchingProvider>();
    final watched = context.read<WatchedProvider>();
    final seeds = <MediaItem>[
      ...continueWatching.entries.take(2).map((entry) => entry.media),
      ...watched.items.take(3),
    ];
    context.read<CatalogProvider>().loadRecommendations(seeds);
  }

  List<MediaItem> _filtered(List<MediaItem> items, SettingsProvider settings,
      {bool allowUnreleased = false}) {
    final visible = allowUnreleased ? items : settings.visibleItems(items);
    switch (_filter) {
      case HomeFilter.all:
        return visible;
      case HomeFilter.movies:
        return visible.where((item) => item.mediaType == 'movie').toList();
      case HomeFilter.series:
        return visible.where((item) => item.mediaType == 'tv').toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final settings = context.watch<SettingsProvider>();
    final profile = context.watch<ProfileProvider>().currentProfile;
    final favorites = context.watch<FavoritesProvider>().favorites;
    // Seeds change rarely; the provider ignores repeated identical requests.
    context.watch<ContinueWatchingProvider>();
    context.watch<WatchedProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshRecommendations();
    });

    final colors = SabuflixTheme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 800;
    final kids = profile?.isKids ?? false;

    final heroes = _filtered(
      catalog.heroes.isNotEmpty
          ? catalog.heroes
          : [
              if (catalog.heroItem != null) catalog.heroItem!,
              ...catalog.trending
            ],
      settings,
    ).take(CatalogProvider.heroCount).toList();

    final sections = catalog
        .sections(kids: kids)
        .map((section) => (
              section: section,
              items: _filtered(section.items, settings,
                  allowUnreleased: section.allowUnreleased),
            ))
        .where((entry) => entry.items.length >= (entry.section.ranked ? 3 : 1))
        .toList();

    return Scaffold(
      backgroundColor: colors.background,
      body: catalog.isLoading
          // Skeleton instead of a spinner: the page keeps its shape while the
          // catalogue loads, so the first paint doesn't jump.
          ? const HomeSkeleton()
          : !catalog.hasContent
              ? _CatalogError(onRetry: catalog.loadCatalog)
              : RefreshIndicator(
                  onRefresh: () => catalog.loadCatalog(),
                  color: colors.textPrimary,
                  backgroundColor: colors.surface,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (!isDesktop)
                        SliverAppBar(
                          floating: true,
                          backgroundColor: colors.background,
                          elevation: 0,
                          centerTitle: false,
                          title: const SabuflixWordmark(fontSize: 19),
                          actions: [
                            const CastButton(),
                            const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: _AccountBadge(),
                            ),
                          ],
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(isDesktop ? 40 : 20,
                              isDesktop ? 6 : 0, isDesktop ? 40 : 20, 10),
                          child: _FilterBar(
                            value: _filter,
                            onChanged: (value) =>
                                setState(() => _filter = value),
                          ),
                        ),
                      ),
                      if (catalog.errorMessage != null)
                        SliverToBoxAdapter(
                          child: _ConnectionNotice(
                            message: catalog.errorMessage!,
                            onRetry: catalog.loadCatalog,
                          ),
                        ),
                      if (heroes.isNotEmpty)
                        SliverToBoxAdapter(child: HeroCarousel(items: heroes)),
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            if (_filter == HomeFilter.all)
                              const ContinueWatchingRow(),
                            for (final entry in sections) ...[
                              if (entry.section.key == 'popular_movies' &&
                                  favorites.isNotEmpty &&
                                  _filtered(favorites, settings).isNotEmpty)
                                MediaRow(
                                  title: 'Minha lista',
                                  mediaItems: _filtered(
                                      favorites.reversed.toList(), settings),
                                  onSeeAll: () => Navigator.push(context,
                                      glassRoute(const MyListScreen())),
                                ),
                              MediaRow(
                                title: entry.section.title,
                                mediaItems: entry.items,
                                ranked: entry.section.ranked,
                                onSeeAll: entry.section.ranked ||
                                        entry.items.length < 8
                                    ? null
                                    : () => Navigator.push(
                                          context,
                                          glassRoute(BrowseScreen(
                                              title: entry.section.title,
                                              items: entry.items)),
                                        ),
                              ),
                            ],
                            // Clears the floating dock on phones.
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

/// Início · Filmes · Séries, the way every streaming home is organised.
class _FilterBar extends StatelessWidget {
  final HomeFilter value;
  final ValueChanged<HomeFilter> onChanged;
  const _FilterBar({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = SabuflixTheme.of(context);
    return Wrap(
      spacing: 8,
      children: [
        for (final option in const [
          (HomeFilter.all, 'Início', Icons.home_rounded),
          (HomeFilter.movies, 'Filmes', Icons.movie_outlined),
          (HomeFilter.series, 'Séries', Icons.live_tv_rounded),
        ])
          ChoiceChip(
            key: ValueKey('home-filter-${option.$1.name}'),
            avatar: Icon(option.$3,
                size: 16,
                color:
                    value == option.$1 ? Colors.white : colors.textSecondary),
            label: Text(option.$2),
            selected: value == option.$1,
            showCheckmark: false,
            onSelected: (_) => onChanged(option.$1),
          ),
      ],
    );
  }
}

class _CatalogError extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _CatalogError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 54,
              color: SabuflixTheme.of(context).textMuted,
            ),
            const SizedBox(height: 18),
            Text(
              'Catálogo indisponível',
              style: SabuflixTheme.of(context).title(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Verifique sua conexão e tente novamente.',
              textAlign: TextAlign.center,
              style: SabuflixTheme.of(context).body(fontSize: 14),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionNotice extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ConnectionNotice({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: SabuflixTheme.of(context).surface,
          borderRadius: SabuflixTheme.radiusMd,
          border: Border.all(color: SabuflixTheme.of(context).border),
        ),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 18,
              color: SabuflixTheme.of(context).textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: SabuflixTheme.of(context).caption(fontSize: 12)),
            ),
            TextButton(onPressed: onRetry, child: const Text('Atualizar')),
          ],
        ),
      ),
    );
  }
}

class _AccountBadge extends StatelessWidget {
  const _AccountBadge();

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, provider, child) {
        final profile = provider.currentProfile;
        if (profile == null) return const SizedBox.shrink();

        return IconButton(
          tooltip: 'Trocar perfil',
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ProfileSelectionScreen()),
            );
          },
          icon: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color(profile.colorValue),
              shape: BoxShape.circle,
            ),
            child: Icon(profileIcon(profile.avatar),
                size: 20, color: Colors.white),
          ),
        );
      },
    );
  }
}
