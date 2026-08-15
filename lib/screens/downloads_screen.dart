import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/download_item.dart';
import '../providers/downloads_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_route.dart';
import '../utils/formatters.dart';
import '../widgets/download_tile.dart';
import '../widgets/segmented_control.dart';
import 'series_downloads_screen.dart';

/// The offline library.
///
/// On a phone the whole page is centred in the viewport and capped to a
/// comfortable measure, so the content sits in the middle of the screen
/// instead of hugging the left edge, and every list clears the floating dock.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final bottomInset = isMobile ? 118.0 : 32.0;

    return Scaffold(
      backgroundColor: SabuflixTheme.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Consumer<DownloadsProvider>(
              builder: (context, downloads, child) {
                if (downloads.isLoading) {
                  return const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                          color: SabuflixTheme.textPrimary, strokeWidth: 2.5),
                    ),
                  );
                }

                final movies = downloads.movies;
                final series = downloads.series;

                if (!downloads.hasAnything) {
                  return _EmptyLibrary(bottomInset: bottomInset);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(downloads: downloads, centered: false),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                      child: SabuSegmentedControl(
                        segments: [
                          'Filmes${movies.isEmpty ? '' : ' (${movies.length})'}',
                          'Séries${series.isEmpty ? '' : ' (${series.length})'}',
                        ],
                        selectedIndex: _tab,
                        onChanged: (index) => setState(() => _tab = index),
                      ),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: SabuflixTheme.durationFast,
                        child: _tab == 0
                            ? _MoviesList(
                                key: const ValueKey('downloads-movies'),
                                movies: movies,
                                bottomInset: bottomInset,
                              )
                            : _SeriesList(
                                key: const ValueKey('downloads-series'),
                                groups: series,
                                bottomInset: bottomInset,
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final DownloadsProvider downloads;
  final bool centered;

  const _Header({required this.downloads, required this.centered});

  @override
  Widget build(BuildContext context) {
    final stalled = downloads.items.any(
      (item) =>
          item.status == DownloadStatus.paused ||
          item.status == DownloadStatus.failed,
    );

    final pieces = <String>[
      '${downloads.completedCount} ${downloads.completedCount == 1 ? 'título' : 'títulos'}',
      formatBytes(downloads.bytesUsed),
    ];
    if (downloads.activeCount > 0) {
      pieces.add('${downloads.activeCount} na fila');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment:
            centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            'Downloads',
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: SabuflixTheme.display(fontSize: 32),
          ),
          const SizedBox(height: 6),
          Text(
            pieces.join(' · '),
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: SabuflixTheme.caption(
                fontSize: 13, color: SabuflixTheme.textSecondary),
          ),
          if (stalled) ...[
            const SizedBox(height: 14),
            Align(
              alignment: centered ? Alignment.center : Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.read<DownloadsProvider>().resumeAll(),
                style: TextButton.styleFrom(
                  foregroundColor: SabuflixTheme.accent,
                  backgroundColor: SabuflixTheme.accent.withValues(alpha: 0.14),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(
                  'Retomar downloads',
                  style: SabuflixTheme.caption(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: SabuflixTheme.accent),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoviesList extends StatelessWidget {
  final List<DownloadItem> movies;
  final double bottomInset;

  const _MoviesList({Key? key, required this.movies, required this.bottomInset})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) {
      return _EmptySection(
        icon: Icons.movie_outlined,
        title: 'Nenhum filme baixado',
        message: 'Abra um filme e toque em Baixar para assistir sem internet.',
        bottomInset: bottomInset,
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottomInset),
      itemCount: movies.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => DownloadTile(item: movies[index]),
    );
  }
}

class _SeriesList extends StatelessWidget {
  final List<SeriesDownloadGroup> groups;
  final double bottomInset;

  const _SeriesList({Key? key, required this.groups, required this.bottomInset})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return _EmptySection(
        icon: Icons.live_tv_rounded,
        title: 'Nenhuma série baixada',
        message:
            'Baixe episódios pela tela da série. Eles ficam agrupados aqui.',
        bottomInset: bottomInset,
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottomInset),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _SeriesTile(group: groups[index]),
    );
  }
}

/// A whole show collapsed into one row — the point of keeping series out of
/// the flat movie list.
class _SeriesTile extends StatelessWidget {
  final SeriesDownloadGroup group;

  const _SeriesTile({required this.group});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SabuflixTheme.surface,
      borderRadius: SabuflixTheme.radiusLg,
      child: InkWell(
        borderRadius: SabuflixTheme.radiusLg,
        onTap: () => Navigator.push(
          context,
          glassRoute(SeriesDownloadsScreen(mediaId: group.series.id)),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: SabuflixTheme.radiusLg,
            border: Border.all(color: SabuflixTheme.border),
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: SabuflixTheme.radiusSm,
                child: CachedNetworkImage(
                  imageUrl: group.series.fullPosterPath,
                  width: 46,
                  height: 68,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                      color: SabuflixTheme.surface, width: 46, height: 68),
                  errorWidget: (context, url, error) => Container(
                    color: SabuflixTheme.surface,
                    width: 46,
                    height: 68,
                    child: const Icon(Icons.live_tv_rounded,
                        color: SabuflixTheme.textMuted, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      group.series.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SabuflixTheme.title(fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      group.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SabuflixTheme.caption(
                          fontSize: 12, color: SabuflixTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: SabuflixTheme.textMuted, size: 22),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  final double bottomInset;

  const _EmptyLibrary({required this.bottomInset});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(32, 0, 32, bottomInset),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.download_rounded,
                size: 34, color: SabuflixTheme.textSecondary),
          ),
          const SizedBox(height: 22),
          Text('Downloads',
              textAlign: TextAlign.center,
              style: SabuflixTheme.display(fontSize: 30)),
          const SizedBox(height: 10),
          Text(
            'Baixe filmes e episódios para assistir sem internet. Eles ficam guardados aqui, separados por filmes e séries.',
            textAlign: TextAlign.center,
            style: SabuflixTheme.body(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final double bottomInset;

  const _EmptySection({
    required this.icon,
    required this.title,
    required this.message,
    required this.bottomInset,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(32, 0, 32, bottomInset),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 42, color: SabuflixTheme.textMuted),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: SabuflixTheme.title(fontSize: 17)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: SabuflixTheme.body(fontSize: 14)),
        ],
      ),
    );
  }
}
