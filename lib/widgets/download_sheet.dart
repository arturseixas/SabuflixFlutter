import 'package:flutter/material.dart';

import '../models/download_task.dart';
import '../models/media_item.dart';
import '../services/download_service.dart';
import '../services/tmdb_service.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/haptics.dart';
import 'glass_container.dart';

/// The "Baixar" sheet.
///
/// For a film it is one button. For a series it is the season browser: each
/// season is a collapsible sub-container listing its episodes, with a button
/// to take a whole season — or the whole series — in one tap.
Future<void> showDownloadSheet({
  required BuildContext context,
  required MediaItem media,
  int? preselectedSeason,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _DownloadSheet(
      media: media,
      preselectedSeason: preselectedSeason,
    ),
  );
}

class _DownloadSheet extends StatefulWidget {
  final MediaItem media;
  final int? preselectedSeason;

  const _DownloadSheet({required this.media, this.preselectedSeason});

  @override
  State<_DownloadSheet> createState() => _DownloadSheetState();
}

class _DownloadSheetState extends State<_DownloadSheet> {
  final TMDBService _tmdb = TMDBService();
  final DownloadService _downloads = DownloadService.instance;

  final Map<int, List<dynamic>> _episodesBySeason = {};
  final Set<int> _loadingSeasons = {};
  int? _expandedSeason;
  bool _bulkBusy = false;

  List<int> get _seasonNumbers {
    final seasons = widget.media.seasons;
    if (seasons == null || seasons.isEmpty) {
      final fallback = widget.preselectedSeason ?? 1;
      return [fallback];
    }
    final numbers = seasons
        .map((s) => s['season_number'])
        .whereType<int>()
        .where((n) => n > 0)
        .toList()
      ..sort();
    return numbers.isEmpty ? [widget.preselectedSeason ?? 1] : numbers;
  }

  @override
  void initState() {
    super.initState();
    if (widget.media.mediaType == 'tv') {
      final initial = widget.preselectedSeason ?? _seasonNumbers.first;
      _expandedSeason = initial;
      _loadSeason(initial);
    }
  }

  Future<List<dynamic>> _loadSeason(int season) async {
    final cached = _episodesBySeason[season];
    if (cached != null) return cached;

    setState(() => _loadingSeasons.add(season));
    final episodes = await _tmdb.fetchSeasonEpisodes(widget.media.id, season);
    if (!mounted) return episodes;
    setState(() {
      _episodesBySeason[season] = episodes;
      _loadingSeasons.remove(season);
    });
    return episodes;
  }

  void _toggleSeason(int season) {
    Haptics.selection();
    setState(() => _expandedSeason = _expandedSeason == season ? null : season);
    if (_expandedSeason == season) _loadSeason(season);
  }

  void _downloadMovie() {
    Haptics.medium();
    _downloads.enqueueMovie(widget.media);
    _report('${widget.media.title} adicionado aos downloads.');
  }

  void _downloadEpisode(int season, Map<String, dynamic> episode) {
    Haptics.medium();
    _downloads.enqueueEpisode(
      media: widget.media,
      season: season,
      episode: episode['episode_number'] as int,
      episodeTitle: episode['name'] as String?,
      stillPath: episode['still_path'] as String?,
    );
    setState(() {});
  }

  Future<void> _downloadSeason(int season) async {
    Haptics.heavy();
    setState(() => _bulkBusy = true);
    final episodes = await _loadSeason(season);
    final added = _enqueueAll({season: episodes});
    if (!mounted) return;
    setState(() => _bulkBusy = false);
    _report(added == 0
        ? 'Temporada $season já está na fila.'
        : '$added ${added == 1 ? 'episódio adicionado' : 'episódios adicionados'} da temporada $season.');
  }

  Future<void> _downloadSeries() async {
    Haptics.heavy();
    setState(() => _bulkBusy = true);

    final bySeason = <int, List<dynamic>>{};
    for (final season in _seasonNumbers) {
      bySeason[season] = await _loadSeason(season);
    }

    final added = _enqueueAll(bySeason);
    if (!mounted) return;
    setState(() => _bulkBusy = false);
    _report(added == 0
        ? 'Todos os episódios já estão baixados ou na fila.'
        : '$added ${added == 1 ? 'episódio adicionado' : 'episódios adicionados'} à fila de download.');
  }

  int _enqueueAll(Map<int, List<dynamic>> bySeason) {
    final entries = <({int season, int episode, String? title, String? stillPath})>[];
    for (final season in bySeason.keys) {
      for (final raw in bySeason[season]!) {
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
    }
    return _downloads.enqueueEpisodes(media: widget.media, episodes: entries);
  }

  void _report(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isSeries = widget.media.mediaType == 'tv';
    final height = MediaQuery.of(context).size.height * (isSeries ? 0.75 : 0.35);

    return GlassContainer(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      blur: 40,
      fillOpacity: 0.4,
      child: SizedBox(
        height: height,
        child: ListenableBuilder(
          listenable: _downloads,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Baixar ${widget.media.title}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SabuflixTheme.title(fontSize: 20),
                    ),
                  ),
                  if (_bulkBusy)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: SabuflixTheme.accent,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'A melhor qualidade disponível é escolhida automaticamente. '
                'Dois arquivos baixam por vez.',
                style: SabuflixTheme.body(fontSize: 12, color: SabuflixTheme.textMuted),
              ),
              const SizedBox(height: 16),
              if (!isSeries)
                _buildMovieAction()
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _bulkBusy ? null : _downloadSeries,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SabuflixTheme.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.download_for_offline_rounded, size: 20),
                    label: const Text('Baixar série inteira'),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _seasonNumbers.length,
                    itemBuilder: (context, index) {
                      final season = _seasonNumbers[index];
                      return _buildSeasonContainer(season);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMovieAction() {
    final task = _downloads.taskFor(widget.media.id);
    final status = task?.status;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: status == DownloadStatus.completed ? null : _downloadMovie,
        style: ElevatedButton.styleFrom(
          backgroundColor: SabuflixTheme.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: SabuflixTheme.surfaceLight,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        icon: Icon(
          status == DownloadStatus.completed
              ? Icons.check_circle_rounded
              : Icons.download_rounded,
          size: 20,
        ),
        label: Text(
          status == null
              ? 'Baixar filme'
              : status == DownloadStatus.completed
                  ? 'Já baixado'
                  : 'Na fila (${status.label})',
        ),
      ),
    );
  }

  Widget _buildSeasonContainer(int season) {
    final isExpanded = _expandedSeason == season;
    final isLoading = _loadingSeasons.contains(season);
    final episodes = _episodesBySeason[season] ?? const [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: SabuflixTheme.radiusMd,
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: SabuflixTheme.radiusMd,
            onTap: () => _toggleSeason(season),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  TextButton(
                    onPressed: _bulkBusy ? null : () => _downloadSeason(season),
                    child: const Text('Baixar temporada'),
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
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(color: SabuflixTheme.accent),
                    )
                  : episodes.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Nenhum episódio encontrado nesta temporada.',
                            style: SabuflixTheme.body(
                              fontSize: 12,
                              color: SabuflixTheme.textMuted,
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            for (final raw in episodes)
                              _buildEpisodeRow(season, raw as Map<String, dynamic>),
                          ],
                        ),
            ),
        ],
      ),
    );
  }

  Widget _buildEpisodeRow(int season, Map<String, dynamic> episode) {
    final number = episode['episode_number'];
    if (number is! int) return const SizedBox.shrink();

    final task = _downloads.taskFor(widget.media.id, season: season, episode: number);
    final name = episode['name'] as String? ?? 'Episódio $number';

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              'E$number',
              style: SabuflixTheme.body(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: SabuflixTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SabuflixTheme.body(
                    fontSize: 13,
                    color: SabuflixTheme.textPrimary,
                  ),
                ),
                if (task != null)
                  Text(
                    task.status == DownloadStatus.completed
                        ? 'Baixado'
                        : '${task.status.label}${task.formattedSize.isEmpty ? '' : ' · ${task.formattedSize}'}',
                    style: SabuflixTheme.body(
                      fontSize: 11,
                      color: task.status == DownloadStatus.completed
                          ? SabuflixTheme.success
                          : SabuflixTheme.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (task == null)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.download_rounded, size: 20, color: SabuflixTheme.accent),
              onPressed: () => _downloadEpisode(season, episode),
            )
          else if (task.status == DownloadStatus.completed)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.check_circle_rounded, size: 20, color: SabuflixTheme.success),
            )
          else
            SizedBox(
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
            ),
        ],
      ),
    );
  }
}
