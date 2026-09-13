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

  const DownloadTile(
      {super.key, required this.item, this.showEpisodeTag = false});

  @override
  Widget build(BuildContext context) {
    final downloads = context.read<DownloadsProvider>();

    return Material(
      color: SabuflixTheme.of(context).surfaceLight,
      borderRadius: SabuflixTheme.radiusLg,
      child: InkWell(
        borderRadius: SabuflixTheme.radiusLg,
        onTap: item.isCompleted
            ? () => playDownload(context, item)
            : () => _toggle(downloads),
        child: Padding(
          padding: EdgeInsets.all(10),
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
                  placeholder: (context, url) => Container(
                      color: SabuflixTheme.of(context).surface,
                      width: 46,
                      height: 68),
                  errorWidget: (context, url, error) => Container(
                    color: SabuflixTheme.of(context).surface,
                    width: 46,
                    height: 68,
                    child: Icon(Icons.movie_outlined,
                        color: SabuflixTheme.of(context).textMuted, size: 18),
                  ),
                ),
              ),
              SizedBox(width: 12),
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
                      style: SabuflixTheme.of(context).title(fontSize: 15),
                    ),
                    SizedBox(height: 3),
                    Text(
                      _metaLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SabuflixTheme.of(context).caption(
                        fontSize: 12,
                        color: item.status == DownloadStatus.failed
                            ? Color(0xFFFF453A)
                            : SabuflixTheme.of(context).textSecondary,
                      ),
                    ),
                    if (!item.isCompleted) ...[
                      SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(3)),
                        child: LinearProgressIndicator(
                          value: item.progress > 0 ? item.progress : null,
                          minHeight: 3,
                          backgroundColor:
                              SabuflixTheme.of(context).surfaceLight,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            item.status == DownloadStatus.failed
                                ? Color(0xFFFF453A)
                                : SabuflixTheme.of(context).accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8),
              _ActionButton(
                icon: _actionIcon,
                highlighted: item.isCompleted,
                onTap: item.isCompleted
                    ? () => playDownload(context, item)
                    : () => _toggle(downloads),
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
    if (item.isCompleted && quality.isNotEmpty) {
      return '$quality · ${item.sizeLabel}';
    }
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

  const _ActionButton(
      {required this.icon, required this.highlighted, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: icon == Icons.pause_rounded
          ? 'Pausar download'
          : 'Continuar download',
      style: IconButton.styleFrom(
        backgroundColor: highlighted
            ? SabuflixTheme.brandBlue
            : SabuflixTheme.of(context).secondaryFill,
        foregroundColor:
            highlighted ? Colors.white : SabuflixTheme.of(context).textPrimary,
        side: BorderSide(color: SabuflixTheme.of(context).borderStrong),
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

class _MoreButton extends StatelessWidget {
  final DownloadItem item;

  const _MoreButton({required this.item});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz_rounded,
          color: SabuflixTheme.of(context).textSecondary, size: 20),
      color: SabuflixTheme.of(context).elevated,
      shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusMd),
      onSelected: (value) async {
        final downloads = context.read<DownloadsProvider>();
        if (value != 'delete') return;
        final confirmed = await confirmDestructive(
          context,
          title: 'Excluir download',
          message:
              'O arquivo de "${item.displayTitle}" será apagado do aparelho.',
        );
        if (!confirmed) return;
        await downloads.remove(item.id);
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(
            'Excluir do aparelho',
            style: SabuflixTheme.of(context).body(
                fontSize: 14, color: SabuflixTheme.of(context).textPrimary),
          ),
        ),
      ],
    );
  }
}
