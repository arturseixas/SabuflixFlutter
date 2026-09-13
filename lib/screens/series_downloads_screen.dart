import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/downloads_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/formatters.dart';
import '../utils/playback.dart';
import '../widgets/download_tile.dart';

/// Every downloaded episode of a single show, split by season.
///
/// Reads the group straight from the provider by id so the screen keeps
/// updating while episodes finish downloading or get deleted underneath it.
class SeriesDownloadsScreen extends StatelessWidget {
  final int mediaId;

  const SeriesDownloadsScreen({super.key, required this.mediaId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SabuflixTheme.of(context).background,
      body: Consumer<DownloadsProvider>(
        builder: (context, downloads, child) {
          final group = downloads.seriesById(mediaId);

          // The last episode was just removed — step back to the library.
          if (group == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.canPop(context)) Navigator.pop(context);
            });
            return SizedBox.shrink();
          }

          final seasons = group.seasons;

          return CustomScrollView(
            physics: BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 232,
                backgroundColor: SabuflixTheme.of(context).background,
                actions: [
                  IconButton(
                    tooltip: 'Excluir todos os episódios',
                    icon: Icon(Icons.delete_outline_rounded,
                        color: SabuflixTheme.of(context).textSecondary),
                    onPressed: () async {
                      final confirmed = await confirmDestructive(
                        context,
                        title: 'Excluir downloads',
                        message:
                            'Todos os ${group.episodes.length} episódios baixados de "${group.series.title}" '
                            'serão apagados do aparelho.',
                        confirmLabel: 'Excluir tudo',
                      );
                      if (!confirmed) return;
                      await downloads.removeSeries(mediaId);
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: EdgeInsets.fromLTRB(56, 0, 56, 14),
                  centerTitle: true,
                  title: Text(
                    group.series.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SabuflixTheme.of(context).title(fontSize: 16),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: group.series.fullBackdropPath,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        placeholder: (context, url) =>
                            Container(color: SabuflixTheme.of(context).surface),
                        errorWidget: (context, url, error) =>
                            Container(color: SabuflixTheme.of(context).surface),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.0, 0.55, 1.0],
                            colors: [
                              SabuflixTheme.of(context)
                                  .background
                                  .withValues(alpha: 0.45),
                              SabuflixTheme.of(context)
                                  .background
                                  .withValues(alpha: 0.55),
                              SabuflixTheme.of(context).background,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 6, 20, 18),
                  child: Center(
                    child: Text(
                      '${group.episodes.length} ${group.episodes.length == 1 ? 'episódio' : 'episódios'}'
                      ' · ${formatBytes(group.totalBytes)}',
                      style: SabuflixTheme.of(context).caption(
                          fontSize: 13,
                          color: SabuflixTheme.of(context).textSecondary),
                    ),
                  ),
                ),
              ),
              for (final season in seasons) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
                    child: Text(
                      'TEMPORADA $season',
                      style: SabuflixTheme.of(context).label(
                          fontSize: 11,
                          color: SabuflixTheme.of(context).textMuted),
                    ),
                  ),
                ),
                SliverList.separated(
                  itemCount: group.episodesOfSeason(season).length,
                  separatorBuilder: (_, __) => SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final episodes = group.episodesOfSeason(season);
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: DownloadTile(
                          item: episodes[index], showEpisodeTag: true),
                    );
                  },
                ),
              ],
              SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }
}
