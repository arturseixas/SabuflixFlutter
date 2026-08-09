import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/download_item.dart';
import '../models/watch_progress.dart';
import '../providers/continue_watching_provider.dart';
import '../providers/downloads_provider.dart';
import '../screens/media_details_screen.dart';
import '../screens/video_player_screen.dart';
import '../theme/sabuflix_theme.dart';
import 'app_route.dart';

/// Opens a finished download from local storage, resuming where it stopped.
Future<void> playDownload(BuildContext context, DownloadItem item) async {
  final downloads = context.read<DownloadsProvider>();
  final continueWatching = context.read<ContinueWatchingProvider>();
  final path = await downloads.localPathOf(item);

  if (!context.mounted) return;

  if (path == null) {
    // The file went missing behind our back — re-sync so the library shows
    // the real state instead of failing again on the next tap.
    await downloads.refreshFromDisk();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('O arquivo não está mais no aparelho. Baixe novamente.')),
    );
    return;
  }

  final saved = continueWatching.forMedia(item.media.id);
  final sameEpisode = saved != null && saved.season == item.season && saved.episode == item.episode;

  Navigator.push(
    context,
    glassRoute(
      VideoPlayerScreen(
        media: item.media,
        videoUrl: path,
        season: item.season,
        episode: item.episode,
        episodeTitle: item.episodeTitle,
        startAt: sameEpisode ? saved.position : Duration.zero,
      ),
    ),
  );
}

/// Resumes a "Continuar Assistindo" entry.
///
/// Prefers the offline copy when the title has been downloaded, falls back to
/// the source it was streaming from, and finally opens the details screen when
/// neither is available any more.
Future<void> resumeWatching(BuildContext context, WatchProgress entry) async {
  final downloads = context.read<DownloadsProvider>();
  final download = downloads.find(entry.media.id, season: entry.season, episode: entry.episode);

  if (download != null && download.isCompleted) {
    await playDownload(context, download);
    return;
  }

  final source = entry.sourceUrl;
  if (source == null || source.isEmpty) {
    if (!context.mounted) return;
    Navigator.push(context, glassRoute(MediaDetailsScreen(media: entry.media)));
    return;
  }

  if (!context.mounted) return;
  Navigator.push(
    context,
    glassRoute(
      VideoPlayerScreen(
        media: entry.media,
        videoUrl: source,
        season: entry.season,
        episode: entry.episode,
        episodeTitle: entry.episodeTitle,
        startAt: entry.position,
      ),
    ),
  );
}

/// Confirmation sheet shared by the destructive actions in the library.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Excluir',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: SabuflixTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusLg),
      title: Text(title, style: SabuflixTheme.title(fontSize: 18)),
      content: Text(message, style: SabuflixTheme.body(fontSize: 14)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text('Cancelar', style: SabuflixTheme.body(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(
            confirmLabel,
            style: SabuflixTheme.body(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFFFF453A)),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
