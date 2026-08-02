import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/download_task.dart';
import '../models/media_item.dart';
import '../services/download_service.dart';
import '../services/tmdb_service.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/haptics.dart';

/// Season-by-season episode browser used on a series page.
///
/// Replaces the old single horizontal strip: each season is its own
/// collapsible sub-container, and every episode row can be played or
/// downloaded on the spot.
class SeasonEpisodesSection extends StatefulWidget {
  final MediaItem media;
  final int initialSeason;
  final void Function(int season, int episode) onPlay;

  const SeasonEpisodesSection({
    super.key,
    required this.media,
    required this.initialSeason,
    required this.onPlay,
  });

  @override
  State<SeasonEpisodesSection> createState() => _SeasonEpisodesSectionState();
}

class _SeasonEpisodesSectionState extends State<SeasonEpisodesSection> {
  final TMDBService _tmdb = TMDBService();
  final DownloadService _downloads = DownloadService.instance;

  final Map<int, List<dynamic>> _episodesBySeason = {};
  final Set<int> _loading = {};
  late int? _expandedSeason;

  List<int> get _seasons {
    final seasons = widget.media.seasons;
    if (seasons == null || seasons.isEmpty) return [widget.initialSeason];
    final numbers = seasons
        .map((s) => s['season_number'])
        .whereType<int>()
        .where((n) => n > 0)
        .toList()
      ..sort();
    return numbers.isEmpty ? [widget.initialSeason] : numbers;
  }

  @override
  void initState() {
    super.initState();
    _expandedSeason = widget.initialSeason;
    _load(widget.initialSeason);
  }

  Future<List<dynamic>> _load(int season) async {
    final cached = _episodesBySeason[season];
    if (cached != null) return cached;

    setState(() => _loading.add(season));
    final episodes = await _tmdb.fetchSeasonEpisodes(widget.media.id, season);
    if (!mounted) return episodes;
    setState(() {
      _episodesBySeason[season] = episodes;
      _loading.remove(season);
    });
    return episodes;
  }

  void _toggle(int season) {
    Haptics.selection();
    setState(() => _expandedSeason = _expandedSeason == season ? null : season);
    if (_expandedSeason == season) _load(season);
  }

  void _downloadEpisode(int season, Map<String, dynamic> episode) {
    final number = episode['episode_number'];
    if (number is! int) return;
    Haptics.medium();
    _downloads.enqueueEpisode(
      media: widget.media,
      season: season,
      episode: number,
      episodeTitle: episode['name'] as String?,
      stillPath: episode['still_path'] as String?,
    );
  }

  Future<void> _downloadSeason(int season) async {
    Haptics.heavy();
    final episodes = await _load(season);
    final entries = <({int season, int episode, String? title, String? stillPath})>[];
    for (final raw in episodes) {
      final episode = raw as Map<String, dynamic>;
      final number = episode['episode_number'];
      if (number is! int) continue;
      entries.add((
        season: season,
        episode: number,
        title: episode['name'] as String?,
        stillPath: episode['still_path'] as String?,
      ));
    }

    final added = _downloads.enqueueEpisodes(media: widget.media, episodes: entries);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(added == 0
            ? 'Temporada $season já está na fila.'
            : '$added ${added == 1 ? 'episódio adicionado' : 'episódios adicionados'} à fila.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _downloads,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Episódios', style: SabuflixTheme.title(fontSize: 19)),
          const SizedBox(height: 14),
          for (final season in _seasons) _buildSeason(season),
        ],
      ),
    );
  }

  Widget _buildSeason(int season) {
    final isExpanded = _expandedSeason == season;
    final isLoading = _loading.contains(season);
    final episodes = _episodesBySeason[season] ?? const [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: SabuflixTheme.radiusMd,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: SabuflixTheme.radiusMd,
            onTap: () => _toggle(season),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Temporada $season',
                      style: SabuflixTheme.body(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: SabuflixTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (episodes.isNotEmpty)
                    Text(
                      '${episodes.length} ep.',
                      style: SabuflixTheme.body(fontSize: 12, color: SabuflixTheme.textMuted),
                    ),
                  IconButton(
                    tooltip: 'Baixar temporada',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.download_rounded,
                        size: 20, color: SabuflixTheme.textSecondary),
                    onPressed: () => _downloadSeason(season),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: SabuflixTheme.durationFast,
                    child: const Icon(Icons.expand_more_rounded,
                        color: SabuflixTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: SabuflixTheme.accent),
                    )
                  : episodes.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Nenhum episódio disponível.',
                            style: SabuflixTheme.body(
                              fontSize: 12,
                              color: SabuflixTheme.textMuted,
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            for (final raw in episodes)
                              _buildEpisode(season, raw as Map<String, dynamic>),
                          ],
                        ),
            ),
        ],
      ),
    );
  }

  Widget _buildEpisode(int season, Map<String, dynamic> episode) {
    final number = episode['episode_number'];
    if (number is! int) return const SizedBox.shrink();

    final name = episode['name'] as String? ?? 'Episódio $number';
    final stillPath = episode['still_path'] as String?;
    final overview = episode['overview'] as String?;
    final runtime = episode['runtime'];
    final task = _downloads.taskFor(widget.media.id, season: season, episode: number);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        borderRadius: SabuflixTheme.radiusSm,
        onTap: () {
          Haptics.medium();
          widget.onPlay(season, number);
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 110,
                  height: 62,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: stillPath != null
                            ? 'https://image.tmdb.org/t/p/w300$stillPath'
                            : widget.media.fullBackdropPath,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: SabuflixTheme.surface),
                        errorWidget: (_, __, ___) => Container(color: SabuflixTheme.surface),
                      ),
                      Container(
                        color: Colors.black.withValues(alpha: 0.28),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$number. $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SabuflixTheme.body(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: SabuflixTheme.textPrimary,
                      ),
                    ),
                    if (runtime is int) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$runtime min',
                        style: SabuflixTheme.body(fontSize: 11, color: SabuflixTheme.textMuted),
                      ),
                    ],
                    if (overview != null && overview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        overview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SabuflixTheme.body(
                          fontSize: 12,
                          color: SabuflixTheme.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (task != null && task.status != DownloadStatus.completed) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: task.totalBytes > 0 ? task.progress : null,
                          minHeight: 3,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          valueColor: const AlwaysStoppedAnimation(SabuflixTheme.accent),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildEpisodeAction(season, episode, task),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodeAction(
    int season,
    Map<String, dynamic> episode,
    DownloadTask? task,
  ) {
    if (task == null) {
      return IconButton(
        tooltip: 'Baixar episódio',
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.download_rounded, size: 20, color: SabuflixTheme.accent),
        onPressed: () => _downloadEpisode(season, episode),
      );
    }
    if (task.status == DownloadStatus.completed) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.download_done_rounded, size: 20, color: SabuflixTheme.success),
      );
    }
    if (task.status == DownloadStatus.failed) {
      return IconButton(
        tooltip: 'Tentar novamente',
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFFFF453A)),
        onPressed: () {
          Haptics.medium();
          _downloads.retry(task.id);
        },
      );
    }
    return SizedBox(
      width: 34,
      height: 34,
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value: task.totalBytes > 0 ? task.progress : null,
          color: SabuflixTheme.accent,
        ),
      ),
    );
  }
}
