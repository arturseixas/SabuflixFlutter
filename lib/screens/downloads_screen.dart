import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/download_item.dart';
import '../providers/downloads_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_route.dart';
import 'video_player_screen.dart';

/// Offline library: everything the user downloaded, with live progress for
/// whatever is still transferring.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadsProvider>(
      builder: (context, provider, _) {
        final downloads = provider.downloads;

        return Scaffold(
          backgroundColor: SabuflixTheme.background,
          appBar: AppBar(
            backgroundColor: SabuflixTheme.background,
            elevation: 0,
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
              if (downloads.isNotEmpty)
                IconButton(
                  tooltip: 'Apagar todos',
                  icon: const Icon(Icons.delete_sweep_outlined, color: SabuflixTheme.textSecondary),
                  onPressed: () => _confirmClearAll(context, provider),
                ),
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
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.download_outlined, size: 52, color: SabuflixTheme.textMuted),
                            const SizedBox(height: 18),
                            Text('Nenhum download', style: SabuflixTheme.title(fontSize: 17)),
                            const SizedBox(height: 8),
                            Text(
                              'Baixe filmes e episódios para assistir sem internet.',
                              textAlign: TextAlign.center,
                              style: SabuflixTheme.body(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                      itemCount: downloads.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _DownloadTile(item: downloads[index]),
                    ),
        );
      },
    );
  }

  void _confirmClearAll(BuildContext context, DownloadsProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SabuflixTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusMd),
        title: Text('Apagar downloads?', style: SabuflixTheme.title(fontSize: 18, color: Colors.white)),
        content: Text(
          'Todos os arquivos baixados serão removidos do dispositivo. Essa ação não pode ser desfeita.',
          style: SabuflixTheme.body(color: SabuflixTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: SabuflixTheme.body(color: SabuflixTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              provider.clearAll();
              Navigator.pop(ctx);
            },
            child: Text('Apagar tudo', style: SabuflixTheme.body(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  final DownloadItem item;

  const _DownloadTile({required this.item});

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    const megabyte = 1024 * 1024;
    if (bytes < megabyte) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    final gigabyte = megabyte * 1024;
    if (bytes < gigabyte) return '${(bytes / megabyte).toStringAsFixed(0)} MB';
    return '${(bytes / gigabyte).toStringAsFixed(1)} GB';
  }

  String get _statusLine {
    switch (item.status) {
      case DownloadStatus.completed:
        return 'Baixado · ${_formatBytes(item.totalBytes)}';
      case DownloadStatus.failed:
        return 'Falhou · toque em tentar novamente';
      case DownloadStatus.paused:
        return item.totalBytes > 0
            ? 'Pausado · ${_formatBytes(item.receivedBytes)} de ${_formatBytes(item.totalBytes)}'
            : 'Pausado';
      case DownloadStatus.queued:
        return 'Na fila';
      case DownloadStatus.downloading:
        return item.totalBytes > 0
            ? '${(item.progress * 100).toStringAsFixed(0)}% · ${_formatBytes(item.receivedBytes)} de ${_formatBytes(item.totalBytes)}'
            : 'Baixando...';
    }
  }

  void _playOffline(BuildContext context) {
    Navigator.push(
      context,
      glassRoute(VideoPlayerScreen(
        media: item.media,
        videoUrl: item.filePath,
        season: item.season,
        episode: item.episode,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<DownloadsProvider>();

    return GestureDetector(
      onTap: item.isComplete ? () => _playOffline(context) : null,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: SabuflixTheme.surface,
          borderRadius: SabuflixTheme.radiusMd,
          border: Border.all(color: SabuflixTheme.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: SabuflixTheme.radiusSm,
              child: SizedBox(
                width: 104,
                height: 60,
                child: CachedNetworkImage(
                  imageUrl: item.media.fullBackdropPath,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: SabuflixTheme.surfaceLight),
                  errorWidget: (context, url, error) => Container(
                    color: SabuflixTheme.surfaceLight,
                    child: const Icon(Icons.image_outlined, color: SabuflixTheme.textMuted, size: 22),
                  ),
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
                    item.media.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SabuflixTheme.body(fontSize: 14, fontWeight: FontWeight.w700, color: SabuflixTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SabuflixTheme.caption(fontSize: 12, color: SabuflixTheme.textMuted),
                  ),
                  const SizedBox(height: 8),
                  if (!item.isComplete)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: item.totalBytes > 0 ? item.progress : null,
                        minHeight: 3,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          item.status == DownloadStatus.failed ? Colors.redAccent : SabuflixTheme.accent,
                        ),
                      ),
                    ),
                  if (!item.isComplete) const SizedBox(height: 6),
                  Text(
                    _statusLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SabuflixTheme.caption(
                      fontSize: 11,
                      color: item.status == DownloadStatus.failed ? Colors.redAccent : SabuflixTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            _buildAction(context, provider),
            IconButton(
              tooltip: 'Remover',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline_rounded, color: SabuflixTheme.textMuted, size: 20),
              onPressed: () => provider.remove(item.id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(BuildContext context, DownloadsProvider provider) {
    switch (item.status) {
      case DownloadStatus.completed:
        return IconButton(
          tooltip: 'Assistir offline',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.play_circle_fill_rounded, color: SabuflixTheme.accent, size: 26),
          onPressed: () => _playOffline(context),
        );
      case DownloadStatus.paused:
      case DownloadStatus.failed:
        return IconButton(
          tooltip: item.status == DownloadStatus.failed ? 'Tentar novamente' : 'Retomar',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            item.status == DownloadStatus.failed ? Icons.refresh_rounded : Icons.play_arrow_rounded,
            color: SabuflixTheme.accent,
            size: 24,
          ),
          onPressed: () => provider.resume(item.id),
        );
      case DownloadStatus.queued:
      case DownloadStatus.downloading:
        return IconButton(
          tooltip: 'Pausar',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.pause_rounded, color: SabuflixTheme.accent, size: 24),
          onPressed: () => provider.pause(item.id),
        );
    }
  }
}
