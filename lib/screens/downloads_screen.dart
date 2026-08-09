import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/download_task.dart';
import '../providers/download_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_route.dart';
import '../widgets/glass_container.dart';
import 'video_player_screen.dart';

/// Offline library: what is on the device, and what is still coming down.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, downloads, child) {
        if (downloads.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: SabuflixTheme.accent),
          );
        }

        final pending = downloads.inProgress;
        final ready = downloads.completed;

        if (pending.isEmpty && ready.isEmpty) {
          // An unreadable library is not an empty one; saying "no downloads"
          // here is what made the earlier data loss look like normal state.
          final failure = downloads.loadError;
          if (failure != null) return _LoadFailure(message: failure);
          return const _EmptyState();
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
          children: [
            _StorageHeader(downloads: downloads),
            if (downloads.isBlockedByNetwork) ...[
              const SizedBox(height: 14),
              const _WifiNotice(),
            ],
            if (pending.isNotEmpty) ...[
              const SizedBox(height: 26),
              _SectionHeader(
                title: 'Baixando',
                count: pending.length,
                action: downloads.hasActiveWork
                    ? _HeaderAction(
                        label: 'Pausar tudo',
                        icon: Icons.pause_rounded,
                        onTap: downloads.pauseAll,
                      )
                    : _HeaderAction(
                        label: 'Retomar tudo',
                        icon: Icons.play_arrow_rounded,
                        onTap: downloads.resumeAll,
                      ),
              ),
              const SizedBox(height: 12),
              for (final task in pending)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PendingTile(task: task, downloads: downloads),
                ),
            ],
            if (ready.isNotEmpty) ...[
              const SizedBox(height: 26),
              _SectionHeader(
                title: 'Disponíveis offline',
                count: ready.length,
                action: _HeaderAction(
                  label: 'Limpar',
                  icon: Icons.delete_sweep_outlined,
                  onTap: () => _confirmClearAll(context, downloads),
                ),
              ),
              const SizedBox(height: 12),
              for (final task in ready)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ReadyTile(task: task, downloads: downloads),
                ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _confirmClearAll(
    BuildContext context,
    DownloadProvider downloads,
  ) async {
    final confirmed = await _confirm(
      context,
      title: 'Apagar todos os downloads?',
      message:
          'Os ${downloads.completed.length} títulos baixados serão removidos do dispositivo. '
          'Você poderá baixá-los novamente depois.',
      confirmLabel: 'Apagar tudo',
    );
    if (confirmed) await downloads.removeCompleted();
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: SabuflixTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusLg),
      title: Text(title, style: SabuflixTheme.title(fontSize: 18)),
      content: Text(
        message,
        style: SabuflixTheme.body(fontSize: 14, color: SabuflixTheme.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            'Cancelar',
            style: SabuflixTheme.body(color: SabuflixTheme.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmLabel,
            style: SabuflixTheme.body(
              color: SabuflixTheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _StorageHeader extends StatelessWidget {
  final DownloadProvider downloads;

  const _StorageHeader({required this.downloads});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: SabuflixTheme.radiusLg,
      blur: 30,
      fillOpacity: 0.45,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: SabuflixTheme.accent.withValues(alpha: 0.18),
                  borderRadius: SabuflixTheme.radiusMd,
                ),
                child: const Icon(
                  Icons.sd_storage_outlined,
                  color: SabuflixTheme.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatBytes(downloads.usedBytes),
                      style: SabuflixTheme.title(fontSize: 20),
                    ),
                    Text(
                      'ocupados por downloads',
                      style: SabuflixTheme.caption(
                        fontSize: 12,
                        color: SabuflixTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28, color: SabuflixTheme.border),
          Row(
            children: [
              const Icon(Icons.wifi_rounded, size: 19, color: SabuflixTheme.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Baixar somente no Wi-Fi',
                      style: SabuflixTheme.body(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: SabuflixTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Evita consumir o pacote de dados móveis',
                      style: SabuflixTheme.caption(
                        fontSize: 11,
                        color: SabuflixTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: downloads.wifiOnly,
                activeThumbColor: SabuflixTheme.accent,
                onChanged: downloads.setWifiOnly,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WifiNotice extends StatelessWidget {
  const _WifiNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SabuflixTheme.gold.withValues(alpha: 0.12),
        borderRadius: SabuflixTheme.radiusMd,
        border: Border.all(color: SabuflixTheme.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: SabuflixTheme.gold, size: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Downloads pausados: aguardando uma rede Wi-Fi.',
              style: SabuflixTheme.body(fontSize: 13, color: SabuflixTheme.gold),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final _HeaderAction? action;

  const _SectionHeader({required this.title, required this.count, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: SabuflixTheme.title(fontSize: 19)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: SabuflixTheme.surfaceLight,
            borderRadius: SabuflixTheme.radiusPill,
          ),
          child: Text(
            '$count',
            style: SabuflixTheme.caption(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: SabuflixTheme.textSecondary,
            ),
          ),
        ),
        const Spacer(),
        if (action != null)
          TextButton.icon(
            onPressed: action!.onTap,
            style: TextButton.styleFrom(
              foregroundColor: SabuflixTheme.accent,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: Icon(action!.icon, size: 17),
            label: Text(
              action!.label,
              style: SabuflixTheme.body(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: SabuflixTheme.accent,
              ),
            ),
          ),
      ],
    );
  }
}

/// Poster thumbnail shared by both tile styles.
class _Poster extends StatelessWidget {
  final DownloadTask task;

  const _Poster({required this.task});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: SabuflixTheme.radiusSm,
      child: CachedNetworkImage(
        imageUrl: task.media.fullPosterPath,
        width: 62,
        height: 90,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: SabuflixTheme.surfaceLight),
        errorWidget: (_, __, ___) => Container(
          color: SabuflixTheme.surfaceLight,
          child: const Icon(Icons.movie_outlined, color: SabuflixTheme.textMuted),
        ),
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  final DownloadTask task;
  final DownloadProvider downloads;

  const _PendingTile({required this.task, required this.downloads});

  @override
  Widget build(BuildContext context) {
    final isDownloading = task.status == DownloadStatus.downloading;
    final progress = task.progress;

    return GlassContainer(
      borderRadius: SabuflixTheme.radiusMd,
      blur: 24,
      fillOpacity: 0.38,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Poster(task: task),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SabuflixTheme.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: SabuflixTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: SabuflixTheme.radiusPill,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: SabuflixTheme.surfaceLight,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      task.status == DownloadStatus.failed
                          ? SabuflixTheme.error
                          : SabuflixTheme.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusLine(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SabuflixTheme.caption(
                    fontSize: 11,
                    color: task.status == DownloadStatus.failed
                        ? SabuflixTheme.error
                        : SabuflixTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: isDownloading ? 'Pausar' : 'Retomar',
                icon: Icon(
                  isDownloading ? Icons.pause_circle_outline : Icons.play_circle_outline,
                  color: SabuflixTheme.accent,
                  size: 26,
                ),
                onPressed: () => isDownloading
                    ? downloads.pause(task)
                    : downloads.resume(task),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Cancelar',
                icon: const Icon(
                  Icons.close_rounded,
                  color: SabuflixTheme.textMuted,
                  size: 20,
                ),
                onPressed: () => _confirmCancel(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await _confirm(
      context,
      title: 'Cancelar download?',
      message: 'O que já foi baixado de "${task.displayTitle}" será descartado.',
      confirmLabel: 'Cancelar download',
    );
    if (confirmed) await downloads.remove(task);
  }

  String _statusLine() {
    final size = task.totalBytes > 0
        ? '${formatBytes(task.bytesReceived)} de ${formatBytes(task.totalBytes)}'
        : formatBytes(task.bytesReceived);

    switch (task.status) {
      case DownloadStatus.downloading:
        final percent = task.progress != null
            ? '${(task.progress! * 100).toStringAsFixed(0)}% · '
            : '';
        final speed = downloads.bytesPerSecond > 0
            ? ' · ${formatBytes(downloads.bytesPerSecond)}/s'
            : '';
        final eta = _formatEta(downloads.secondsRemaining);
        return '$percent$size$speed$eta';
      case DownloadStatus.queued:
        return 'Na fila · $size';
      case DownloadStatus.paused:
        return 'Pausado · $size';
      case DownloadStatus.failed:
        return 'Falhou: ${task.error ?? "erro desconhecido"} · toque em ▶ para tentar de novo';
      case DownloadStatus.completed:
        return size;
    }
  }

  String _formatEta(int? seconds) {
    if (seconds == null || seconds <= 0) return '';
    if (seconds < 60) return ' · ${seconds}s restantes';
    final minutes = (seconds / 60).round();
    if (minutes < 60) return ' · ${minutes}min restantes';
    final hours = (minutes / 60).floor();
    final rest = minutes % 60;
    return ' · ${hours}h${rest.toString().padLeft(2, '0')} restantes';
  }
}

class _ReadyTile extends StatelessWidget {
  final DownloadTask task;
  final DownloadProvider downloads;

  const _ReadyTile({required this.task, required this.downloads});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: SabuflixTheme.radiusMd,
      blur: 24,
      fillOpacity: 0.38,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _Poster(task: task),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SabuflixTheme.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: SabuflixTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 13,
                      color: SabuflixTheme.success,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '${formatBytes(task.bytesReceived)} · ${task.quality.isNotEmpty ? task.quality : task.sourceName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SabuflixTheme.caption(
                          fontSize: 11,
                          color: SabuflixTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Assistir offline',
            icon: const Icon(
              Icons.play_circle_fill_rounded,
              color: SabuflixTheme.accent,
              size: 34,
            ),
            onPressed: () => _playOffline(context),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Excluir',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: SabuflixTheme.textMuted,
              size: 21,
            ),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  Future<void> _playOffline(BuildContext context) async {
    final path = await downloads.localPathFor(task);
    if (!context.mounted) return;

    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Arquivo não encontrado no dispositivo.')),
      );
      return;
    }

    Navigator.push(
      context,
      glassRoute(
        VideoPlayerScreen(
          media: task.media,
          videoUrl: path,
          isOffline: true,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await _confirm(
      context,
      title: 'Excluir download?',
      message:
          '"${task.displayTitle}" será removido do dispositivo, liberando ${formatBytes(task.bytesReceived)}.',
      confirmLabel: 'Excluir',
    );
    if (confirmed) await downloads.remove(task);
  }
}

/// Shown when the stored library could not be read, so a real failure is
/// never mistaken for "you have no downloads".
class _LoadFailure extends StatelessWidget {
  final String message;

  const _LoadFailure({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 46,
              color: SabuflixTheme.error,
            ),
            const SizedBox(height: 18),
            Text(
              'Não foi possível ler seus downloads',
              style: SabuflixTheme.title(fontSize: 19),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Os arquivos continuam no dispositivo. Feche e abra o app para '
              'tentar de novo.\n\n$message',
              textAlign: TextAlign.center,
              style: SabuflixTheme.body(
                fontSize: 13,
                color: SabuflixTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: SabuflixTheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: SabuflixTheme.border),
              ),
              child: const Icon(
                Icons.download_for_offline_outlined,
                size: 42,
                color: SabuflixTheme.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nenhum download ainda',
              style: SabuflixTheme.title(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Abra um filme ou episódio, toque em Baixar e escolha a fonte. '
              'Ele fica salvo aqui para assistir sem internet.',
              textAlign: TextAlign.center,
              style: SabuflixTheme.body(
                fontSize: 14,
                color: SabuflixTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
