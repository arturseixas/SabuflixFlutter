import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/download_item.dart';
import '../models/playback_source.dart';
import '../providers/download_provider.dart';
import '../services/download_service.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_route.dart';
import '../widgets/source_tag.dart';
import 'video_player_screen.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, provider, child) {
        final items = provider.items;
        final pending = provider.pending;
        final completed = provider.completed;

        return Scaffold(
          backgroundColor: SabuflixTheme.background,
          appBar: AppBar(
            backgroundColor: SabuflixTheme.background,
            title: Row(
              children: [
                Text('Downloads', style: SabuflixTheme.title(fontSize: 20, fontWeight: FontWeight.w700)),
                if (items.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: SabuflixTheme.surfaceLight,
                      borderRadius: SabuflixTheme.radiusPill,
                      border: Border.all(color: SabuflixTheme.border),
                    ),
                    child: Text(
                      '${items.length}',
                      style: SabuflixTheme.label(fontSize: 12, color: SabuflixTheme.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Diagnóstico de armazenamento',
                icon: const Icon(Icons.bug_report_outlined, color: SabuflixTheme.textSecondary),
                onPressed: () => _showDiagnostics(context),
              ),
              if (completed.isNotEmpty)
                IconButton(
                  tooltip: 'Apagar todos os baixados',
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
              : items.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildStorageBar(provider),
                        if (pending.isNotEmpty) ...[
                          _buildSectionHeader('Em andamento', pending.length),
                          for (final item in pending) _DownloadTile(item: item),
                          const SizedBox(height: 12),
                        ],
                        if (completed.isNotEmpty) ...[
                          _buildSectionHeader('Disponíveis offline', completed.length),
                          for (final item in completed) _DownloadTile(item: item),
                        ],
                      ],
                    ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.download_outlined, size: 52, color: SabuflixTheme.textMuted),
            const SizedBox(height: 18),
            Text('Nenhum download ainda', style: SabuflixTheme.title(fontSize: 17)),
            const SizedBox(height: 8),
            Text(
              'Abra um título, escolha uma fonte e toque no ícone de download para assistir sem internet.',
              textAlign: TextAlign.center,
              style: SabuflixTheme.body(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageBar(DownloadProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          const Icon(Icons.sd_storage_outlined, size: 15, color: SabuflixTheme.textMuted),
          const SizedBox(width: 8),
          Text(
            '${DownloadItem.formatBytes(provider.usedBytes)} usados neste dispositivo',
            style: SabuflixTheme.caption(fontSize: 12, color: SabuflixTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
      child: Text(
        '${title.toUpperCase()} · $count',
        style: SabuflixTheme.label(fontSize: 11, color: SabuflixTheme.textMuted),
      ),
    );
  }

  /// Shows exactly what's on disk right now — the resolved storage
  /// folder, its files, and the raw persisted queue file — so a bug
  /// report can include hard facts instead of "it disappeared".
  Future<void> _showDiagnostics(BuildContext context) async {
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<String>(
        future: DownloadService.diagnostics(),
        builder: (ctx, snapshot) {
          final text = snapshot.data;
          return AlertDialog(
            backgroundColor: SabuflixTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusLg),
            title: Text('Diagnóstico', style: SabuflixTheme.title(fontSize: 18)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: text == null
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator(color: SabuflixTheme.accent)),
                      )
                    : SelectableText(
                        text,
                        style: SabuflixTheme.body(fontSize: 12, color: SabuflixTheme.textSecondary),
                      ),
              ),
            ),
            actions: [
              if (text != null)
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Diagnóstico copiado')),
                    );
                  },
                  child: const Text('Copiar'),
                ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, DownloadProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SabuflixTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusLg),
        title: Text('Apagar downloads?', style: SabuflixTheme.title(fontSize: 18)),
        content: Text(
          'Todos os títulos baixados serão removidos do dispositivo.',
          style: SabuflixTheme.body(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Apagar', style: SabuflixTheme.body(color: const Color(0xFFFF453A), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) await provider.removeAllCompleted();
  }
}

class _DownloadTile extends StatelessWidget {
  final DownloadItem item;

  const _DownloadTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DownloadProvider>(context, listen: false);
    final progress = item.progress;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SabuflixTheme.surface,
        borderRadius: SabuflixTheme.radiusMd,
        border: Border.all(color: SabuflixTheme.border, width: 0.6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: SabuflixTheme.radiusSm,
            child: CachedNetworkImage(
              imageUrl: item.media.fullPosterPath,
              width: 56,
              height: 82,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: SabuflixTheme.surfaceLight),
              errorWidget: (context, url, err) => Container(
                color: SabuflixTheme.surfaceLight,
                child: const Icon(Icons.movie_outlined, color: SabuflixTheme.textMuted, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SabuflixTheme.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: SabuflixTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (item.isCompleted)
                      const SourceTag(source: PlaybackSource.download, compact: true)
                    else
                      _StatusChip(item: item),
                    if (item.quality.isNotEmpty)
                      Text(
                        _shortQuality(item.quality),
                        style: SabuflixTheme.caption(fontSize: 11, color: SabuflixTheme.textMuted),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (!item.isCompleted) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: SabuflixTheme.surfaceLight,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        item.status == DownloadStatus.failed
                            ? const Color(0xFFFF453A)
                            : SabuflixTheme.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  item.status == DownloadStatus.failed && item.errorMessage != null
                      ? item.errorMessage!
                      : _detailLine(progress),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SabuflixTheme.caption(
                    fontSize: 11,
                    color: item.status == DownloadStatus.failed
                        ? const Color(0xFFFF453A)
                        : SabuflixTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPrimaryAction(context, provider),
              const SizedBox(height: 2),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Remover',
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: SabuflixTheme.textMuted),
                onPressed: () => _confirmRemove(context, provider),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _detailLine(double? progress) {
    final percent = progress != null ? '${(progress * 100).toStringAsFixed(0)}% · ' : '';
    if (item.isCompleted) return item.sizeLabel;
    return '$percent${item.sizeLabel}';
  }

  String _shortQuality(String quality) {
    final firstLine = quality.split('\n').first.trim();
    return firstLine.length > 32 ? '${firstLine.substring(0, 32)}…' : firstLine;
  }

  Widget _buildPrimaryAction(BuildContext context, DownloadProvider provider) {
    if (item.isCompleted) {
      return IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: 'Assistir offline',
        icon: const Icon(Icons.play_circle_fill_rounded, size: 30, color: SabuflixTheme.success),
        onPressed: () => _playOffline(context),
      );
    }
    if (item.status == DownloadStatus.failed) {
      return IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: 'Tentar novamente',
        icon: const Icon(Icons.refresh_rounded, size: 24, color: SabuflixTheme.accent),
        onPressed: () => provider.retry(item.id),
      );
    }
    if (item.status == DownloadStatus.paused) {
      return IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: 'Continuar',
        icon: const Icon(Icons.play_circle_outline_rounded, size: 26, color: SabuflixTheme.accent),
        onPressed: () => provider.resume(item.id),
      );
    }
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: 'Pausar',
      icon: const Icon(Icons.pause_circle_outline_rounded, size: 26, color: SabuflixTheme.textSecondary),
      onPressed: () => provider.pause(item.id),
    );
  }

  Future<void> _playOffline(BuildContext context) async {
    final path = await DownloadService.filePath(item.fileName);
    if (!context.mounted) return;
    Navigator.push(
      context,
      glassRoute(VideoPlayerScreen(
        media: item.media,
        videoUrl: path,
        source: PlaybackSource.download,
      )),
    );
  }

  Future<void> _confirmRemove(BuildContext context, DownloadProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SabuflixTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusLg),
        title: Text('Remover download?', style: SabuflixTheme.title(fontSize: 18)),
        content: Text(
          '"${item.displayTitle}" será apagado do dispositivo.',
          style: SabuflixTheme.body(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remover', style: SabuflixTheme.body(color: const Color(0xFFFF453A), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) await provider.remove(item.id);
  }
}

class _StatusChip extends StatelessWidget {
  final DownloadItem item;

  const _StatusChip({required this.item});

  @override
  Widget build(BuildContext context) {
    Color color = SabuflixTheme.textSecondary;
    IconData icon = Icons.schedule_rounded;
    switch (item.status) {
      case DownloadStatus.downloading:
        color = SabuflixTheme.accent;
        icon = Icons.downloading_rounded;
        break;
      case DownloadStatus.queued:
        color = SabuflixTheme.textSecondary;
        icon = Icons.schedule_rounded;
        break;
      case DownloadStatus.paused:
        color = SabuflixTheme.gold;
        icon = Icons.pause_rounded;
        break;
      case DownloadStatus.failed:
        color = const Color(0xFFFF453A);
        icon = Icons.error_outline_rounded;
        break;
      case DownloadStatus.completed:
        color = SabuflixTheme.success;
        icon = Icons.download_done_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: SabuflixTheme.radiusPill,
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            item.statusLabel.toUpperCase(),
            style: SabuflixTheme.label(fontSize: 9, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}
