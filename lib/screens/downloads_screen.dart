import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/download_task.dart';
import '../services/download_service.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_route.dart';
import '../utils/haptics.dart';
import '../widgets/glass_container.dart';
import 'video_player_screen.dart';

/// Offline library.
///
/// A series is one card; inside it every season is its own sub-container, so
/// a 10-season show is a short list of seasons instead of 200 loose episode
/// rows.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SabuflixTheme.background,
      body: SafeArea(
        child: Consumer<DownloadService>(
          builder: (context, downloads, child) {
            final groups = downloads.groups;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                    child: _Header(downloads: downloads),
                  ),
                ),
                if (groups.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(),
                  )
                else
                  SliverList.builder(
                    itemCount: groups.length,
                    itemBuilder: (context, index) => Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        6,
                        20,
                        index == groups.length - 1 ? 120 : 6,
                      ),
                      child: _GroupCard(group: groups[index]),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final DownloadService downloads;

  const _Header({required this.downloads});

  @override
  Widget build(BuildContext context) {
    final active = downloads.activeTasks.length;
    final paused = downloads.tasks
        .where((t) => t.status == DownloadStatus.paused)
        .length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Downloads', style: SabuflixTheme.headline(fontSize: 30)),
              const SizedBox(height: 4),
              Text(
                active > 0
                    ? '$active ${active == 1 ? 'item baixando' : 'itens baixando'}'
                    : 'Assista offline, sem gastar dados',
                style: SabuflixTheme.body(fontSize: 13),
              ),
            ],
          ),
        ),
        if (active > 0)
          TextButton.icon(
            onPressed: () {
              Haptics.selection();
              downloads.pauseAll();
            },
            icon: const Icon(Icons.pause_rounded, size: 18),
            label: const Text('Pausar tudo'),
          )
        else if (paused > 0)
          TextButton.icon(
            onPressed: () {
              Haptics.selection();
              downloads.resumeAll();
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Retomar'),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.download_rounded, size: 46, color: SabuflixTheme.textMuted),
            const SizedBox(height: 16),
            Text('Nada baixado ainda', style: SabuflixTheme.title(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Abra um filme ou série e toque em Baixar. '
              'Em séries dá para baixar a temporada ou a série inteira de uma vez.',
              textAlign: TextAlign.center,
              style: SabuflixTheme.body(fontSize: 13, color: SabuflixTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// One film or one series.
class _GroupCard extends StatefulWidget {
  final DownloadGroup group;

  const _GroupCard({required this.group});

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _expanded = false;

  Future<void> _confirmRemoveGroup() async {
    Haptics.heavy();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SabuflixTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusMd),
        title: Text('Remover download', style: SabuflixTheme.title(fontSize: 18)),
        content: Text(
          'Apagar todos os arquivos baixados de "${widget.group.media.title}"?',
          style: SabuflixTheme.body(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apagar', style: TextStyle(color: Color(0xFFFF453A))),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<DownloadService>().removeGroup(widget.group.media.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final isSeries = group.isSeries;

    return GlassContainer(
      borderRadius: SabuflixTheme.radiusLg,
      blur: 24,
      fillOpacity: 0.28,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: SabuflixTheme.radiusLg,
            onTap: () {
              Haptics.selection();
              if (isSeries) {
                setState(() => _expanded = !_expanded);
              } else {
                _playTask(context, group.tasks.first);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: SabuflixTheme.radiusSm,
                    child: CachedNetworkImage(
                      imageUrl: group.media.fullPosterPath,
                      width: 56,
                      height: 82,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: SabuflixTheme.surface),
                      errorWidget: (_, __, ___) => Container(color: SabuflixTheme.surface),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.media.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SabuflixTheme.title(fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isSeries
                              ? '${group.completedCount}/${group.tasks.length} episódios'
                                  '${group.activeCount > 0 ? ' · ${group.activeCount} na fila' : ''}'
                              : group.tasks.first.status.label,
                          style: SabuflixTheme.body(
                            fontSize: 12,
                            color: SabuflixTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: group.progress,
                            minHeight: 4,
                            backgroundColor: Colors.white.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation(
                              group.progress >= 1
                                  ? SabuflixTheme.success
                                  : SabuflixTheme.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: SabuflixTheme.textMuted),
                    onPressed: _confirmRemoveGroup,
                  ),
                  if (isSeries)
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: SabuflixTheme.durationFast,
                      child: const Icon(Icons.expand_more_rounded,
                          color: SabuflixTheme.textSecondary),
                    )
                  else
                    const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          if (isSeries && _expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  for (final entry in group.seasons.entries)
                    _SeasonContainer(seasonNumber: entry.key, tasks: entry.value),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The per-season sub-container inside a series card.
class _SeasonContainer extends StatefulWidget {
  final int seasonNumber;
  final List<DownloadTask> tasks;

  const _SeasonContainer({required this.seasonNumber, required this.tasks});

  @override
  State<_SeasonContainer> createState() => _SeasonContainerState();
}

class _SeasonContainerState extends State<_SeasonContainer> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final completed = widget.tasks
        .where((t) => t.status == DownloadStatus.completed)
        .length;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: SabuflixTheme.radiusMd,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: SabuflixTheme.radiusMd,
            onTap: () {
              Haptics.selection();
              setState(() => _expanded = !_expanded);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.folder_rounded, size: 18, color: SabuflixTheme.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Temporada ${widget.seasonNumber}',
                      style: SabuflixTheme.body(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: SabuflixTheme.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '$completed/${widget.tasks.length}',
                    style: SabuflixTheme.body(fontSize: 12, color: SabuflixTheme.textMuted),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: SabuflixTheme.durationFast,
                    child: const Icon(Icons.expand_more_rounded,
                        size: 20, color: SabuflixTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                children: [
                  for (final task in widget.tasks) _TaskRow(task: task),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final DownloadTask task;

  const _TaskRow({required this.task});

  @override
  Widget build(BuildContext context) {
    final downloads = context.read<DownloadService>();
    final isCompleted = task.status == DownloadStatus.completed;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        borderRadius: SabuflixTheme.radiusSm,
        onTap: isCompleted ? () => _playTask(context, task) : null,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 74,
                  height: 42,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: task.fullStillPath,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: SabuflixTheme.surface),
                        errorWidget: (_, __, ___) => Container(color: SabuflixTheme.surface),
                      ),
                      if (isCompleted)
                        Container(
                          color: Colors.black.withValues(alpha: 0.35),
                          child: const Icon(Icons.play_arrow_rounded,
                              size: 20, color: Colors.white),
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
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SabuflixTheme.body(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: SabuflixTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _statusLine(task),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SabuflixTheme.body(
                        fontSize: 11,
                        color: task.status == DownloadStatus.failed
                            ? const Color(0xFFFF453A)
                            : SabuflixTheme.textMuted,
                      ),
                    ),
                    if (!isCompleted) ...[
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
              const SizedBox(width: 6),
              _actionButton(downloads),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18, color: SabuflixTheme.textMuted),
                onPressed: () {
                  Haptics.light();
                  downloads.remove(task.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(DownloadService downloads) {
    switch (task.status) {
      case DownloadStatus.completed:
        return const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.check_circle_rounded, size: 20, color: SabuflixTheme.success),
        );
      case DownloadStatus.failed:
        return IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.refresh_rounded, size: 20, color: SabuflixTheme.accent),
          onPressed: () {
            Haptics.medium();
            downloads.retry(task.id);
          },
        );
      case DownloadStatus.paused:
        return IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.play_arrow_rounded, size: 20, color: SabuflixTheme.accent),
          onPressed: () {
            Haptics.medium();
            downloads.resume(task.id);
          },
        );
      case DownloadStatus.queued:
      case DownloadStatus.resolving:
      case DownloadStatus.downloading:
        return IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.pause_rounded, size: 20, color: SabuflixTheme.textSecondary),
          onPressed: () {
            Haptics.light();
            downloads.pause(task.id);
          },
        );
    }
  }

  static String _statusLine(DownloadTask task) {
    if (task.status == DownloadStatus.failed) {
      return task.error ?? 'Falhou';
    }
    if (task.status == DownloadStatus.completed) {
      final size = task.formattedSize;
      return size.isEmpty ? 'Baixado' : 'Baixado · $size';
    }
    final size = task.formattedSize;
    final quality = task.qualityLabel;
    return [
      task.status.label,
      if (size.isNotEmpty) size,
      if (quality != null && quality.isNotEmpty) quality,
    ].join(' · ');
  }
}

/// Plays a finished download from disk.
void _playTask(BuildContext context, DownloadTask task) {
  if (task.status != DownloadStatus.completed || task.filePath == null) {
    Haptics.error();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Este item ainda não terminou de baixar.')),
    );
    return;
  }

  Haptics.medium();
  Navigator.push(
    context,
    glassRoute(VideoPlayerScreen(
      media: task.media,
      videoUrl: task.filePath,
      season: task.season,
      episode: task.episode,
      sourceLabel: 'Download',
    )),
  );
}
