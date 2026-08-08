import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/download_item.dart';
import '../providers/downloads_provider.dart';
import '../services/download_service.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_route.dart';
import 'video_player_screen.dart';

/// The offline library: everything the profile has downloaded, plus whatever
/// is still transferring.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadsProvider>(
      builder: (context, provider, child) {
        final downloads = provider.downloads;

        return Scaffold(
          backgroundColor: SabuflixTheme.background,
          appBar: AppBar(
            backgroundColor: SabuflixTheme.background,
            title: Row(
              children: [
                Text('Downloads', style: SabuflixTheme.title(fontSize: 20, fontWeight: FontWeight.w700)),
                if (downloads.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: SabuflixTheme.surfaceLight,
                      borderRadius: SabuflixTheme.radiusPill,
                      border: Border.all(color: SabuflixTheme.border),
                    ),
                    child: Text(
                      '${downloads.length}',
                      style: SabuflixTheme.label(fontSize: 12, color: SabuflixTheme.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (provider.completed.isNotEmpty)
                TextButton(
                  onPressed: () => _confirmClear(context, provider),
                  child: Text(
                    'Limpar',
                    style: SabuflixTheme.body(fontSize: 14, fontWeight: FontWeight.w600, color: SabuflixTheme.accent),
                  ),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: provider.isLoading
              ? const Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(color: SabuflixTheme.textPrimary, strokeWidth: 2.5),
                  ),
                )
              : downloads.isEmpty
                  ? const _EmptyDownloads()
                  : Column(
                      children: [
                        if (provider.totalBytesOnDisk > 0)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                            child: Row(
                              children: [
                                const Icon(Icons.sd_storage_outlined, size: 15, color: SabuflixTheme.textMuted),
                                const SizedBox(width: 6),
                                Text(
                                  '${DownloadService.formatBytes(provider.totalBytesOnDisk)} usados neste dispositivo',
                                  style: SabuflixTheme.caption(fontSize: 12, color: SabuflixTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                            physics: const BouncingScrollPhysics(),
                            itemCount: downloads.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) =>
                                _DownloadTile(item: downloads[index], provider: provider),
                          ),
                        ),
                      ],
                    ),
        );
      },
    );
  }

  Future<void> _confirmClear(BuildContext context, DownloadsProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SabuflixTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusLg),
        title: Text('Limpar downloads', style: SabuflixTheme.title(fontSize: 18)),
        content: Text(
          'Todos os títulos já baixados serão removidos deste dispositivo.',
          style: SabuflixTheme.body(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Limpar', style: SabuflixTheme.body(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) await provider.clearCompleted();
  }
}

class _DownloadTile extends StatelessWidget {
  final DownloadItem item;
  final DownloadsProvider provider;

  const _DownloadTile({Key? key, required this.item, required this.provider}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isComplete = item.status == DownloadStatus.completed;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SabuflixTheme.surface,
        borderRadius: SabuflixTheme.radiusMd,
        border: Border.all(color: SabuflixTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: SabuflixTheme.radiusSm,
            child: CachedNetworkImage(
              imageUrl: item.media.fullPosterPath,
              width: 58,
              height: 87,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: SabuflixTheme.surfaceLight),
              errorWidget: (context, url, err) => Container(
                color: SabuflixTheme.surfaceLight,
                child: const Icon(Icons.movie_outlined, color: SabuflixTheme.textMuted, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SabuflixTheme.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: SabuflixTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.sourceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SabuflixTheme.caption(fontSize: 11, color: SabuflixTheme.textMuted),
                ),
                const SizedBox(height: 10),
                _StatusLine(item: item),
                if (item.status == DownloadStatus.downloading || item.status == DownloadStatus.paused) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: SabuflixTheme.radiusPill,
                    child: LinearProgressIndicator(
                      value: item.progress,
                      minHeight: 4,
                      backgroundColor: SabuflixTheme.surfaceLight,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        item.status == DownloadStatus.paused ? SabuflixTheme.textMuted : SabuflixTheme.accent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isComplete)
                _CircleAction(
                  icon: Icons.play_arrow_rounded,
                  color: SabuflixTheme.accent,
                  tooltip: 'Assistir offline',
                  onTap: () => _playOffline(context),
                )
              else if (item.status == DownloadStatus.downloading || item.status == DownloadStatus.queued)
                _CircleAction(
                  icon: Icons.pause_rounded,
                  tooltip: 'Pausar',
                  onTap: () => provider.pause(item.id),
                )
              else
                _CircleAction(
                  icon: Icons.refresh_rounded,
                  tooltip: item.status == DownloadStatus.failed ? 'Tentar novamente' : 'Retomar',
                  onTap: () => provider.resume(item.id),
                ),
              const SizedBox(height: 6),
              _CircleAction(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Excluir',
                onTap: () => _confirmRemove(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _playOffline(BuildContext context) {
    final path = provider.filePathFor(item);
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Arquivo indisponível neste dispositivo.')),
      );
      return;
    }
    Navigator.push(context, glassRoute(VideoPlayerScreen(media: item.media, videoUrl: path)));
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SabuflixTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusLg),
        title: Text('Excluir download', style: SabuflixTheme.title(fontSize: 18)),
        content: Text(
          '“${item.displayTitle}” será removido deste dispositivo.',
          style: SabuflixTheme.body(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Excluir', style: SabuflixTheme.body(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) await provider.remove(item.id);
  }
}

class _StatusLine extends StatelessWidget {
  final DownloadItem item;

  const _StatusLine({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    late final String text;
    late final Color color;

    switch (item.status) {
      case DownloadStatus.completed:
        icon = Icons.check_circle_rounded;
        color = SabuflixTheme.success;
        text = 'Disponível offline · ${DownloadService.formatBytes(item.bytesReceived)}';
        break;
      case DownloadStatus.downloading:
        icon = Icons.downloading_rounded;
        color = SabuflixTheme.accent;
        final percent = item.progress;
        text = percent != null
            ? '${(percent * 100).toStringAsFixed(0)}% · '
                '${DownloadService.formatBytes(item.bytesReceived)} de ${DownloadService.formatBytes(item.totalBytes)}'
            : 'Baixando · ${DownloadService.formatBytes(item.bytesReceived)}';
        break;
      case DownloadStatus.queued:
        icon = Icons.schedule_rounded;
        color = SabuflixTheme.textMuted;
        text = 'Na fila';
        break;
      case DownloadStatus.paused:
        icon = Icons.pause_circle_outline_rounded;
        color = SabuflixTheme.textMuted;
        final percent = item.progress;
        text = percent != null
            ? 'Pausado em ${(percent * 100).toStringAsFixed(0)}%'
            : 'Pausado · ${DownloadService.formatBytes(item.bytesReceived)}';
        break;
      case DownloadStatus.failed:
        icon = Icons.error_outline_rounded;
        color = Colors.redAccent;
        text = item.error ?? 'Falha no download';
        break;
    }

    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SabuflixTheme.caption(fontSize: 12, color: color),
          ),
        ),
      ],
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const _CircleAction({
    Key? key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: SabuflixTheme.surfaceLight,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: color ?? SabuflixTheme.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.download_for_offline_outlined, size: 52, color: SabuflixTheme.textMuted),
            const SizedBox(height: 18),
            Text('Nenhum download', style: SabuflixTheme.title(fontSize: 17)),
            const SizedBox(height: 8),
            Text(
              'Toque no ícone de download na página de um filme ou episódio para assistir sem internet.',
              textAlign: TextAlign.center,
              style: SabuflixTheme.body(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
