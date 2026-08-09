import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/download_item.dart';
import '../providers/downloads_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/playback.dart';

/// One row of the offline library: artwork, title, live state and the single
/// action that makes sense right now (play, pause, resume or retry).
class DownloadTile extends StatelessWidget {
  final DownloadItem item;

  /// Episodes are listed under their series, so the row leads with the episode
  /// tag instead of repeating the show's name.
  final bool showEpisodeTag;

  const DownloadTile({Key? key, required this.item, this.showEpisodeTag = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final downloads = context.read<DownloadsProvider>();

    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: SabuflixTheme.radiusLg,
      child: InkWell(
        borderRadius: SabuflixTheme.radiusLg,
        onTap: item.isCompleted ? () => playDownload(context, item) : () => _toggle(downloads),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: SabuflixTheme.radiusSm,
                child: CachedNetworkImage(
                  imageUrl: item.media.fullPosterPath,
                  width: 46,
                  height: 68,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: SabuflixTheme.surface, width: 46, height: 68),
                  errorWidget: (context, url, error) => Container(
                    color: SabuflixTheme.surface,
                    width: 46,
                    height: 68,
                    child: const Icon(Icons.movie_outlined, color: SabuflixTheme.textMuted, size: 18),
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
                      showEpisodeTag && item.episodeTag.isNotEmpty
                          ? '${item.episodeTag} · ${item.displayTitle}'
                          : item.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SabuflixTheme.title(fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _metaLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SabuflixTheme.caption(
                        fontSize: 12,
                        color: item.status == DownloadStatus.failed
                            ? const Color(0xFFFF453A)
                            : SabuflixTheme.textSecondary,
                      ),
                    ),
                    if (!item.isCompleted) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: const BorderRadius.all(Radius.circular(3)),
                        child: LinearProgressIndicator(
                          value: item.progress > 0 ? item.progress : null,
                          minHeight: 3,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            item.status == DownloadStatus.failed
                                ? const Color(0xFFFF453A)
                                : SabuflixTheme.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: _actionIcon,
                highlighted: item.isCompleted,
                onTap: item.isCompleted ? () => playDownload(context, item) : () => _toggle(downloads),
              ),
              _MoreButton(item: item),
            ],
          ),
        ),
      ),
    );
  }

  String get _metaLine {
    final quality = item.quality.trim();
    if (item.isCompleted && quality.isNotEmpty) return '$quality · ${item.sizeLabel}';
    return item.statusLabel;
  }

  IconData get _actionIcon {
    switch (item.status) {
      case DownloadStatus.completed:
        return Icons.play_arrow_rounded;
      case DownloadStatus.downloading:
      case DownloadStatus.queued:
        return Icons.pause_rounded;
      case DownloadStatus.paused:
        return Icons.download_rounded;
      case DownloadStatus.failed:
        return Icons.refresh_rounded;
    }
  }

  void _toggle(DownloadsProvider downloads) {
    switch (item.status) {
      case DownloadStatus.downloading:
      case DownloadStatus.queued:
        downloads.pause(item.id);
        break;
      case DownloadStatus.paused:
      case DownloadStatus.failed:
        downloads.resume(item.id);
        break;
      case DownloadStatus.completed:
        break;
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final bool highlighted;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.highlighted, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? SabuflixTheme.accent : Colors.white.withValues(alpha: 0.10),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: highlighted ? Colors.white : SabuflixTheme.textPrimary),
        ),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  final DownloadItem item;

  const _MoreButton({required this.item});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded, color: SabuflixTheme.textSecondary, size: 20),
      color: SabuflixTheme.elevated,
      shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusMd),
      onSelected: (value) async {
        final downloads = context.read<DownloadsProvider>();
        if (value != 'delete') return;
        final confirmed = await confirmDestructive(
          context,
          title: 'Excluir download',
          message: 'O arquivo de "${item.displayTitle}" será apagado do aparelho.',
        );
        if (!confirmed) return;
        await downloads.remove(item.id);
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(
            'Excluir do aparelho',
            style: SabuflixTheme.body(fontSize: 14, color: SabuflixTheme.textPrimary),
          ),
        ),
      ],
    );
  }
}
