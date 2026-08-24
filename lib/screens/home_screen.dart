import 'dart:ui';
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

    return Scaffold(
      backgroundColor: SabuflixTheme.background,
      body: catalog.isLoading
          // Skeleton instead of a spinner: the page keeps its shape while the
          // catalogue loads, so the first paint doesn't jump.
          ? const HomeSkeleton()
          : !catalog.hasContent
              ? _CatalogError(onRetry: catalog.loadCatalog)
              : RefreshIndicator(
                  onRefresh: () => catalog.loadCatalog(),
                  color: SabuflixTheme.textPrimary,
                  backgroundColor: SabuflixTheme.surface,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      if (!isDesktop)
                        SliverAppBar(
                          floating: true,
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          centerTitle: false,
                          flexibleSpace: ClipRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                              child: Container(
                                  color: SabuflixTheme.background
                                      .withValues(alpha: 0.5)),
                            ),
                          ),
                          title: const SabuflixWordmark(fontSize: 19),
                          actions: const [
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
                      if (catalog.heroItem != null)
                        SliverToBoxAdapter(
                          child: HeroBanner(media: catalog.heroItem!),
                        ),
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            const ContinueWatchingRow(),
                            MediaRow(
                              title: 'Em Alta Hoje',
                              mediaItems:
                                  settings.visibleItems(catalog.trending),
                            ),
                            MediaRow(
                              title: 'Filmes Populares',
                              mediaItems:
                                  settings.visibleItems(catalog.popularMovies),
                            ),
                            MediaRow(
                              title: 'Séries em Destaque',
                              mediaItems:
                                  settings.visibleItems(catalog.popularTV),
                            ),
                            MediaRow(
                              title: 'Mais Bem Avaliados',
                              mediaItems:
                                  settings.visibleItems(catalog.topRated),
                            ),
                            MediaRow(
                              title: 'Ação e Aventura',
                              mediaItems:
                                  settings.visibleItems(catalog.actionMovies),
                            ),
                            MediaRow(
                              title: 'Comédias',
                              mediaItems:
                                  settings.visibleItems(catalog.comedyMovies),
                            ),
                            MediaRow(
                              title: 'Ficção Científica',
                              mediaItems:
                                  settings.visibleItems(catalog.sciFiMovies),
                            ),
                            // Clears the floating dock on phones.
                            SizedBox(height: isDesktop ? 40 : 120),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 54, color: SabuflixTheme.textMuted),
            const SizedBox(height: 18),
            Text('Catálogo indisponível',
                style: SabuflixTheme.title(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Verifique sua conexão e tente novamente.',
              textAlign: TextAlign.center,
              style: SabuflixTheme.body(fontSize: 14),
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
          color: SabuflixTheme.surface,
          borderRadius: SabuflixTheme.radiusMd,
          border: Border.all(color: SabuflixTheme.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 18, color: SabuflixTheme.textSecondary),
            const SizedBox(width: 10),
            Expanded(
                child:
                    Text(message, style: SabuflixTheme.caption(fontSize: 12))),
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

        return GestureDetector(
          onTap: () {
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => const ProfileSelectionScreen()));
          },
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color(profile.colorValue),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, size: 20, color: Colors.white),
          ),
        );
      },
    );
  }
}
