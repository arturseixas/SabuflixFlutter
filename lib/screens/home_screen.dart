import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/sabuflix_theme.dart';
import '../providers/catalog_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/continue_watching_row.dart';
import '../widgets/hero_banner.dart';
import '../widgets/home_skeleton.dart';
import '../widgets/media_row.dart';
import '../widgets/now_showing_grid.dart';
import '../widgets/wordmark.dart';
import 'profile_selection_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = Provider.of<CatalogProvider>(context);
    final settings = context.watch<SettingsProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    final heroes = settings.visibleItems([
      if (catalog.heroItem != null) catalog.heroItem!,
      ...catalog.trending,
    ]);
    // "Filme do dia": one pick from the head of the catalogue, rotating daily.
    final now = DateTime.now();
    final day = DateTime.utc(now.year, now.month, now.day)
        .difference(DateTime.utc(2024))
        .inDays;
    final hero =
        heroes.isEmpty ? null : heroes[day % heroes.length.clamp(1, 8)];
    final showing = settings
        .visibleItems(catalog.trending)
        .where((m) => m.storageKey != hero?.storageKey)
        .toList();
    return Scaffold(
      backgroundColor: SabuflixTheme.of(context).background,
      body: catalog.isLoading
          // Skeleton instead of a spinner: the page keeps its shape while the
          // catalogue loads, so the first paint doesn't jump.
          ? HomeSkeleton()
          : !catalog.hasContent
              ? _CatalogError(onRetry: catalog.loadCatalog)
              : RefreshIndicator(
                  onRefresh: () => catalog.loadCatalog(),
                  color: SabuflixTheme.of(context).textPrimary,
                  backgroundColor: SabuflixTheme.of(context).surface,
                  child: CustomScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (!isDesktop)
                        SliverAppBar(
                          floating: true,
                          backgroundColor: SabuflixTheme.of(context).background,
                          elevation: 0,
                          centerTitle: true,
                          title: SabuflixWordmark(fontSize: 18),
                          actions: [
                            Padding(
                              padding: EdgeInsets.only(right: 16),
                              child: _AccountBadge(),
                            ),
                          ],
                        ),
                      if (catalog.errorMessage != null)
                        SliverToBoxAdapter(
                          child: _ConnectionNotice(
                            message: catalog.errorMessage!,
                            onRetry: catalog.loadCatalog,
                          ),
                        ),
                      if (hero != null)
                        SliverToBoxAdapter(child: HeroBanner(media: hero)),
                      if (showing.isNotEmpty)
                        SliverToBoxAdapter(
                          child: NowShowingGrid(
                            items: showing.take(isDesktop ? 6 : 4).toList(),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 16),
                            ContinueWatchingRow(),
                            for (final section in catalog.fenixCatalogs.entries)
                              MediaRow(
                                title: section.key
                                    .replaceAll(
                                      RegExp(
                                        r'\s*·\s*(fenixflix|nebula)',
                                        caseSensitive: false,
                                      ),
                                      '',
                                    )
                                    .replaceAll(
                                      RegExp(
                                        r'fenixflix',
                                        caseSensitive: false,
                                      ),
                                      '',
                                    )
                                    .trim(),
                                mediaItems:
                                    settings.visibleItems(section.value),
                              ),
                            MediaRow(
                              title: 'Em Alta',
                              mediaItems:
                                  showing.skip(isDesktop ? 6 : 4).toList(),
                            ),
                            MediaRow(
                              title: 'Os Mais Vistos',
                              mediaItems: settings.visibleItems(
                                catalog.popularMovies,
                              ),
                            ),
                            MediaRow(
                              title: 'Séries em Destaque',
                              mediaItems:
                                  settings.visibleItems(catalog.popularTV),
                            ),
                            MediaRow(
                              title: 'Aclamados pela Crítica',
                              mediaItems:
                                  settings.visibleItems(catalog.topRated),
                            ),
                            MediaRow(
                              title: 'Ação e Aventura',
                              mediaItems: settings.visibleItems(
                                catalog.actionMovies,
                              ),
                            ),
                            MediaRow(
                              title: 'Comédias',
                              mediaItems: settings.visibleItems(
                                catalog.comedyMovies,
                              ),
                            ),
                            MediaRow(
                              title: 'Ficção Científica',
                              mediaItems: settings.visibleItems(
                                catalog.sciFiMovies,
                              ),
                            ),
                            // Clears the floating dock on phones.
                            SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 54,
              color: SabuflixTheme.of(context).textMuted,
            ),
            SizedBox(height: 18),
            Text(
              'Catálogo indisponível',
              style: SabuflixTheme.of(context).title(fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Verifique sua conexão e tente novamente.',
              textAlign: TextAlign.center,
              style: SabuflixTheme.of(context).body(fontSize: 14),
            ),
            SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh_rounded),
              label: Text('Tentar novamente'),
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
      padding: EdgeInsets.fromLTRB(20, 12, 20, 2),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: SabuflixTheme.of(context).caption(fontSize: 12)),
            ),
            TextButton(onPressed: onRetry, child: Text('Atualizar')),
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
        if (profile == null) return SizedBox.shrink();

        return IconButton(
          tooltip: 'Trocar perfil',
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => ProfileSelectionScreen()),
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
            child: Icon(Icons.person, size: 20, color: Colors.white),
          ),
        );
      },
    );
  }
}
