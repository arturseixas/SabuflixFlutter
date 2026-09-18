import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/download_item.dart';
import '../models/media_details.dart';
import '../models/media_item.dart';
import '../providers/cast_provider.dart';
import '../providers/continue_watching_provider.dart';
import '../providers/downloads_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/watched_provider.dart';
import '../services/cast/cast_device.dart';
import '../services/froststream_service.dart';
import '../services/playback_resolver.dart';
import '../services/tmdb_service.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_route.dart';
import '../utils/formatters.dart';
import '../utils/playback.dart';
import '../widgets/cast_button.dart';
import '../widgets/details/details_widgets.dart';
import '../widgets/details/stream_selector_sheet.dart';
import '../widgets/glass_container.dart';
import '../widgets/media_row.dart';
import 'cast_remote_screen.dart';
import 'video_player_screen.dart';

class MediaDetailsScreen extends StatefulWidget {
  final MediaItem media;

  const MediaDetailsScreen({super.key, required this.media});

  @override
  State<MediaDetailsScreen> createState() => _MediaDetailsScreenState();
}

class _MediaDetailsScreenState extends State<MediaDetailsScreen> {
  final TMDBService _tmdbService = TMDBService();
  final ScrollController _scroll = ScrollController();

  bool _loadingDetails = true;
  bool _loadingEpisodes = false;
  bool _resolvingQuickPlay = false;
  String? _detailsError;
  MediaDetails? _details;
  List<dynamic> _episodes = [];
  int _seasonNumber = 1;
  List<int> _availableSeasons = [];

  MediaItem get _media => _details?.media ?? widget.media;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loadingDetails = true;
      _detailsError = null;
    });
    try {
      final details = await _tmdbService.fetchFullDetails(
          widget.media.id, widget.media.mediaType);
      if (details == null) throw StateError('Detalhes indisponíveis');

      List<dynamic> episodes = [];
      var season = 1;
      List<int> availableSeasons = [];
      if (widget.media.mediaType == 'tv') {
        final seasons = details.media.seasons;
        if (seasons != null && seasons.isNotEmpty) {
          final valid = seasons
              .whereType<Map>()
              .where((s) => ((s['season_number'] as num?)?.toInt() ?? 0) > 0)
              .toList();
          if (valid.isNotEmpty) {
            availableSeasons = valid
                .map<int>((s) => (s['season_number'] as num).toInt())
                .toList()
              ..sort();
            season = _initialSeason(availableSeasons);
          }
        }
        episodes =
            await _tmdbService.fetchSeasonEpisodes(widget.media.id, season);
      }

      if (!mounted) return;
      setState(() {
        _details = details;
        _episodes = episodes;
        _seasonNumber = season;
        _availableSeasons = availableSeasons;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _details ??= MediaDetails(media: widget.media);
        _detailsError = 'Não foi possível atualizar os detalhes.';
      });
    } finally {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  /// Opens on the season the viewer is watching, not always season one.
  int _initialSeason(List<int> seasons) {
    final progress = context
        .read<ContinueWatchingProvider>()
        .forMedia(widget.media.id, mediaType: 'tv');
    if (progress?.season != null && seasons.contains(progress!.season)) {
      return progress.season!;
    }
    final last =
        context.read<WatchedProvider>().lastWatchedEpisode(widget.media.id);
    if (last != null && seasons.contains(last.season)) return last.season;
    return seasons.first;
  }

  Future<void> _onSeasonChanged(int season) async {
    setState(() {
      _seasonNumber = season;
      _loadingEpisodes = true;
      _episodes = [];
    });
    try {
      final episodes =
          await _tmdbService.fetchSeasonEpisodes(widget.media.id, season);
      if (!mounted || _seasonNumber != season) return;
      setState(() {
        _episodes = episodes;
        _loadingEpisodes = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar episódios.')));
      if (_seasonNumber == season) setState(() => _loadingEpisodes = false);
    }
  }

  // --- Playback ------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _sourcesFor(
      {int? season, int? episode}) async {
    var imdbId = _media.imdbId;
    if (imdbId == null || imdbId.isEmpty) {
      final refreshed = await _tmdbService.fetchMediaDetails(
          widget.media.id, widget.media.mediaType);
      imdbId = refreshed?.imdbId;
    }
    if (imdbId == null || imdbId.isEmpty) return [];
    return FrostStreamService.fetchStreams(
      imdbId: imdbId,
      type: _media.mediaType,
      season: season,
      episode: episode,
    );
  }

  /// Starts playback of the title or one episode: on the connected TV, with
  /// quick play, or through the source picker.
  Future<void> _play({
    int? season,
    int? episode,
    String? episodeTitle,
    Duration startAt = Duration.zero,
  }) async {
    final media = _media;
    final cast = context.read<CastProvider>();
    final settings = context.read<SettingsProvider>();
    final sources = _sourcesFor(season: season, episode: episode);
    final subtitle = media.mediaType == 'tv'
        ? [formatEpisodeTag(season, episode), episodeTitle ?? '']
            .where((s) => s.isNotEmpty)
            .join(' · ')
        : null;

    Map<String, dynamic>? stream;
    if (settings.quickPlay && !cast.isConnected) {
      setState(() => _resolvingQuickPlay = true);
      try {
        stream = PlaybackResolver.pickBest(await sources,
            quality: settings.preferredQuality, audio: settings.preferredAudio);
      } catch (_) {}
      if (!mounted) return;
      setState(() => _resolvingQuickPlay = false);
    }
    stream ??= await showStreamSelector(
      context,
      sources: sources,
      title: media.title,
      subtitle: subtitle,
      castTargetName: cast.isConnected ? cast.device?.name : null,
    );
    if (stream == null || !mounted) return;
    final url = stream['url']?.toString();
    if (url == null || url.isEmpty) return;

    if (cast.isConnected) {
      try {
        await cast.cast(
          media: media,
          url: url,
          season: season,
          episode: episode,
          episodeTitle: episodeTitle,
          startAt: startAt,
        );
        if (!mounted) return;
        Navigator.push(context, glassRoute(const CastRemoteScreen()));
      } on CastException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    }

    Navigator.push(
      context,
      glassRoute(VideoPlayerScreen(
        media: media,
        videoUrl: url,
        season: season,
        episode: episode,
        episodeTitle: episodeTitle,
        startAt: startAt,
      )),
    );
  }

  Future<void> _download(
      {int? season, int? episode, String? episodeTitle}) async {
    final media = _media;
    final stream = await showStreamSelector(
      context,
      sources: _sourcesFor(season: season, episode: episode),
      title: media.title,
      subtitle: season != null ? formatEpisodeTag(season, episode) : null,
      forDownload: true,
    );
    if (stream == null || !mounted) return;
    final url = (stream['url'] ?? '').toString();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Esta fonte não oferece um link para download.')));
      return;
    }
    final quality =
        (stream['displayQuality'] ?? stream['title'] ?? stream['name'] ?? '')
            .toString();
    final added = await context.read<DownloadsProvider>().enqueue(
          media: media,
          url: url,
          quality: quality.split('\n').first.trim(),
          season: season,
          episode: episode,
          episodeTitle: episodeTitle,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(added
          ? 'Download iniciado. Acompanhe na Biblioteca.'
          : 'Este item já está na sua lista de downloads.'),
    ));
  }

  /// What the big button does for a series: resume, continue after the last
  /// watched episode, or start from the first one.
  ({int season, int episode, String? title, Duration startAt, String label})
      _seriesEntryPoint(BuildContext context) {
    final progress = context
        .watch<ContinueWatchingProvider>()
        .forMedia(_media.id, mediaType: 'tv');
    if (progress != null && progress.isEpisode && !progress.isFinished) {
      return (
        season: progress.season!,
        episode: progress.episode!,
        title: progress.episodeTitle,
        startAt: progress.position,
        label: progress.resumeLabel,
      );
    }
    final last = context.watch<WatchedProvider>().lastWatchedEpisode(_media.id);
    if (last != null) {
      final next = PlaybackResolver.nextEpisodeFromSeasons(
          _media.seasons ?? const [], last.season, last.episode);
      if (next != null) {
        return (
          season: next.season,
          episode: next.episode,
          title: _episodeTitleFor(next.season, next.episode),
          startAt: Duration.zero,
          label: 'Continuar ${formatEpisodeTag(next.season, next.episode)}',
        );
      }
    }
    final first = _availableSeasons.isNotEmpty ? _availableSeasons.first : 1;
    return (
      season: first,
      episode: 1,
      title: _episodeTitleFor(first, 1),
      startAt: Duration.zero,
      label: 'Assistir ${formatEpisodeTag(first, 1)}',
    );
  }

  String? _episodeTitleFor(int season, int episodeNumber) {
    if (season != _seasonNumber) return null;
    for (final episode in _episodes) {
      if (episode is Map &&
          (episode['episode_number'] as num?)?.toInt() == episodeNumber) {
        return episode['name']?.toString();
      }
    }
    return null;
  }

  // --- Secondary actions ---------------------------------------------------

  Future<void> _openTrailer() async {
    final key = _media.trailerKey;
    if (key == null || key.isEmpty) return;
    final url = Uri.parse('https://www.youtube.com/watch?v=$key');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o trailer.')));
    }
  }

  Future<void> _share() async {
    final media = _media;
    final link = 'https://www.themoviedb.org/${media.mediaType}/${media.id}';
    await Clipboard.setData(ClipboardData(text: '${media.title} · $link'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Link copiado. Cole onde quiser compartilhar.')));
  }

  Future<void> _openProviders() async {
    final link = _details?.providersLink;
    if (link == null) return;
    await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
  }

  void _showPlaylistsSelector(MediaItem media) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SabuflixTheme.of(context).surface,
      showDragHandle: true,
      builder: (ctx) => Consumer<PlaylistProvider>(
        builder: (context, provider, child) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Adicionar a uma playlist',
                      style: SabuflixTheme.of(context).title(fontSize: 20)),
                  const SizedBox(height: 16),
                  if (provider.playlists.isEmpty)
                    Text(
                        'Você ainda não tem playlists. Crie uma na Biblioteca.',
                        style: SabuflixTheme.of(context).body(fontSize: 14))
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: provider.playlists.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final p = provider.playlists[i];
                          final inPlaylist = p.items.any((item) =>
                              item.id == media.id &&
                              item.mediaType == media.mediaType);
                          return ListTile(
                            shape: RoundedRectangleBorder(
                                borderRadius: SabuflixTheme.radiusMd),
                            tileColor: SabuflixTheme.of(context).secondaryFill,
                            title: Text(p.name,
                                style: SabuflixTheme.of(context)
                                    .title(fontSize: 15)),
                            subtitle: Text(
                                '${p.items.length} ${p.items.length == 1 ? 'título' : 'títulos'}',
                                style: SabuflixTheme.of(context)
                                    .caption(fontSize: 12)),
                            trailing: Icon(
                                inPlaylist
                                    ? Icons.check_circle
                                    : Icons.add_circle_outline,
                                color: SabuflixTheme.of(context).accent),
                            onTap: () {
                              if (inPlaylist) {
                                provider.removeMediaFromPlaylist(p.id, media.id,
                                    mediaType: media.mediaType);
                              } else {
                                provider.addMediaToPlaylist(p.id, media);
                              }
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(inPlaylist
                                          ? 'Removido de ${p.name}'
                                          : 'Adicionado a ${p.name}')));
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  int _ageValue(String? rating) {
    if (rating == null ||
        rating.isEmpty ||
        rating == 'Livre' ||
        rating == 'L') {
      return 0;
    }
    return int.tryParse(rating.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  // --- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = SabuflixTheme.of(context);
    final media = _media;
    final details = _details;
    final favorites = context.watch<FavoritesProvider>();
    final watched = context.watch<WatchedProvider>();
    final profile = context.watch<ProfileProvider>().currentProfile;
    final cast = context.watch<CastProvider>();
    final savedProgress = context
        .watch<ContinueWatchingProvider>()
        .forMedia(media.id, mediaType: media.mediaType);
    final isFav = favorites.isFavorite(media.id, mediaType: media.mediaType);
    final isWatched = watched.isWatched(media.id, mediaType: media.mediaType);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final compact = width < 600;
    final isBlocked =
        _ageValue(media.ageRating) > _ageValue(profile?.maxAgeRating);
    final isTv = media.mediaType == 'tv';
    final entry = isTv ? _seriesEntryPoint(context) : null;
    final horizontalInset = wide ? 48.0 : 20.0;
    final heroHeight = (width * (compact ? 0.62 : 0.42)).clamp(260.0, 560.0);

    final ctaLabel = _resolvingQuickPlay
        ? 'Procurando a melhor fonte…'
        : cast.isConnected
            ? (isTv ? '${entry!.label} na TV' : 'Assistir na TV')
            : isTv
                ? entry!.label
                : savedProgress != null && !savedProgress.isFinished
                    ? savedProgress.resumeLabel
                    : 'Assistir agora';

    VoidCallback? onPrimary;
    if (!_loadingDetails && !isBlocked && !_resolvingQuickPlay) {
      onPrimary = () {
        if (isTv) {
          _play(
            season: entry!.season,
            episode: entry.episode,
            episodeTitle: entry.title,
            startAt: entry.startAt,
          );
        } else {
          _play(
              startAt: savedProgress != null && !savedProgress.isFinished
                  ? savedProgress.position
                  : Duration.zero);
        }
      };
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        controller: _scroll,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: heroHeight,
            pinned: true,
            stretch: true,
            backgroundColor: colors.background,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.all(6),
              child: IconButton(
                tooltip: 'Voltar',
                style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: .55),
                    foregroundColor: Colors.white),
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              DecoratedBox(
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .45),
                    shape: BoxShape.circle),
                child: const CastButton(color: Colors.white),
              ),
              const SizedBox(width: 4),
              DecoratedBox(
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .45),
                    shape: BoxShape.circle),
                child: IconButton(
                  tooltip: 'Compartilhar',
                  color: Colors.white,
                  onPressed: _share,
                  icon: const Icon(Icons.ios_share_rounded, size: 22),
                ),
              ),
              const SizedBox(width: 10),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: media.fullBackdropPath,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    placeholder: (_, __) => ColoredBox(color: colors.surface),
                    errorWidget: (_, __, ___) =>
                        ColoredBox(color: colors.surface),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.45, 1.0],
                        colors: [
                          Colors.black.withValues(alpha: .35),
                          Colors.transparent,
                          colors.background,
                        ],
                      ),
                    ),
                  ),
                  if (media.fullLogoPath != null)
                    Positioned(
                      left: horizontalInset,
                      right: wide ? width * .45 : horizontalInset,
                      bottom: 18,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxHeight: compact ? 90 : 130,
                              maxWidth: wide ? 420 : 300),
                          child: CachedNetworkImage(
                            imageUrl: media.fullLogoPath!,
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomLeft,
                            errorWidget: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_loadingDetails)
            const SliverToBoxAdapter(
                child: LinearProgressIndicator(minHeight: 2)),
          if (_detailsError != null)
            SliverToBoxAdapter(
              child: ListTile(
                leading:
                    Icon(Icons.cloud_off_rounded, color: colors.textSecondary),
                title: Text(_detailsError!, style: colors.body(fontSize: 13)),
                trailing: TextButton(
                    onPressed: _loadData,
                    child: const Text('Tentar novamente')),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  EdgeInsets.fromLTRB(horizontalInset, 12, horizontalInset, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & meta.
                  if (media.fullLogoPath == null)
                    Text(media.title,
                        style: colors.display(
                            fontSize: wide
                                ? 44
                                : compact
                                    ? 28
                                    : 34)),
                  if (media.fullLogoPath == null) const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (media.voteCount > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded,
                                color: colors.gold, size: 16),
                            const SizedBox(width: 3),
                            Text(media.formattedRating,
                                style: colors.body(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                          ],
                        ),
                      if (media.releaseDate?.isNotEmpty ?? false)
                        Text(media.formattedYear,
                            style: colors.body(fontSize: 14)),
                      if (media.lengthLabel != null)
                        Text(media.lengthLabel!,
                            style: colors.body(fontSize: 14)),
                      if (media.ageRating != null)
                        MetaChip(media.ageRating!,
                            color: _ageValue(media.ageRating) >= 16
                                ? colors.error
                                : _ageValue(media.ageRating) >= 12
                                    ? colors.gold
                                    : colors.success,
                            filled: true),
                      if (media.statusLabel != null)
                        MetaChip(media.statusLabel!),
                      if (media.isUnreleased)
                        MetaChip('Em breve', color: colors.accent),
                    ],
                  ),
                  if (media.tagline != null &&
                      media.tagline!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('“${media.tagline!.trim()}”',
                        style: colors.body(
                            fontSize: 15,
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 22),

                  // Primary action + progress.
                  if (isBlocked)
                    _BlockedNotice(rating: media.ageRating)
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          flex: wide ? 0 : 1,
                          child: SizedBox(
                            width: wide ? 320 : null,
                            child: ElevatedButton.icon(
                              onPressed: onPrimary,
                              icon: _resolvingQuickPlay
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : Icon(
                                      cast.isConnected
                                          ? Icons.cast_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 24),
                              label: Text(ctaLabel,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                        if (wide) const Spacer(),
                      ],
                    ),
                    if (savedProgress != null && !savedProgress.isFinished) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: wide ? 320 : double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(2)),
                              child: LinearProgressIndicator(
                                value: savedProgress.progress,
                                minHeight: 3,
                                backgroundColor: colors.border,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    colors.accent),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${savedProgress.subtitleLabel} · ${savedProgress.remainingLabel}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: colors.caption(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          DetailAction(
                            icon:
                                isFav ? Icons.check_rounded : Icons.add_rounded,
                            label: isFav ? 'Na lista' : 'Minha lista',
                            active: isFav,
                            onTap: () => favorites.toggleFavorite(media),
                          ),
                          if (!kIsWeb)
                            _DownloadAction(
                              mediaId: media.id,
                              season: isTv ? entry!.season : null,
                              episode: isTv ? entry!.episode : null,
                              onStart: () => _download(
                                season: isTv ? entry!.season : null,
                                episode: isTv ? entry!.episode : null,
                                episodeTitle: isTv ? entry!.title : null,
                              ),
                            ),
                          if (media.trailerKey != null &&
                              media.trailerKey!.isNotEmpty)
                            DetailAction(
                              icon: Icons.smart_display_outlined,
                              label: 'Trailer',
                              onTap: _openTrailer,
                            ),
                          DetailAction(
                            icon: Icons.playlist_add_rounded,
                            label: 'Playlist',
                            onTap: () => _showPlaylistsSelector(media),
                          ),
                          DetailAction(
                            icon: isWatched
                                ? Icons.visibility_rounded
                                : Icons.visibility_outlined,
                            label: isWatched ? 'Assistido' : 'Marcar visto',
                            active: isWatched,
                            activeColor: colors.success,
                            onTap: () async {
                              await watched.toggle(media);
                              if (!isWatched && context.mounted) {
                                await context
                                    .read<ContinueWatchingProvider>()
                                    .remove(media.id,
                                        mediaType: media.mediaType);
                              }
                            },
                          ),
                          DetailAction(
                            icon: Icons.ios_share_rounded,
                            label: 'Compartilhar',
                            onTap: _share,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),

                  // Overview and credits.
                  LayoutBuilder(builder: (context, constraints) {
                    final overview =
                        media.overview != null && media.overview!.isNotEmpty
                            ? media.overview!
                            : 'Nenhuma sinopse disponível em português.';
                    final credits =
                        _CreditsBlock(details: details, media: media);
                    if (constraints.maxWidth >= 820) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              flex: 3,
                              child: ExpandableOverview(
                                  text: overview, collapsedLines: 6)),
                          const SizedBox(width: 40),
                          Expanded(flex: 2, child: credits),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExpandableOverview(text: overview),
                        const SizedBox(height: 18),
                        credits,
                      ],
                    );
                  }),
                  if (media.genres != null && media.genres!.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final genre in media.genres!)
                          GlassContainer(
                            borderRadius: SabuflixTheme.radiusPill,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            child: Text(genre,
                                style: colors.caption(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary)),
                          ),
                      ],
                    ),
                  ],

                  // Episodes.
                  if (!isBlocked && isTv && _availableSeasons.isNotEmpty) ...[
                    const SizedBox(height: 34),
                    _EpisodesSection(
                      media: media,
                      season: _seasonNumber,
                      seasons: _availableSeasons,
                      episodes: _episodes,
                      loading: _loadingEpisodes || _loadingDetails,
                      savedProgress: savedProgress,
                      nextEpisode: details?.nextEpisode,
                      onSeason: _onSeasonChanged,
                      onPlay: (episode, title) => _play(
                        season: _seasonNumber,
                        episode: episode,
                        episodeTitle: title,
                        startAt: savedProgress != null &&
                                savedProgress.season == _seasonNumber &&
                                savedProgress.episode == episode &&
                                !savedProgress.isFinished
                            ? savedProgress.position
                            : Duration.zero,
                      ),
                      onDownload: (episode, title) => _download(
                          season: _seasonNumber,
                          episode: episode,
                          episodeTitle: title),
                    ),
                  ],

                  // Where to watch.
                  if (details != null && details.providers.isNotEmpty) ...[
                    const SizedBox(height: 34),
                    const DetailSectionTitle('Onde assistir oficialmente'),
                    WatchProvidersRow(
                        providers: details.providers, onOpen: _openProviders),
                  ],

                  // Cast.
                  if (details != null && details.cast.isNotEmpty) ...[
                    const SizedBox(height: 34),
                    const DetailSectionTitle('Elenco'),
                    CastRow(cast: details.cast),
                  ],

                  // Collection, recommendations, similar.
                  if (details?.collection != null) ...[
                    const SizedBox(height: 22),
                    MediaRow(
                      title: details!.collection!.name,
                      mediaItems: details.collection!.parts
                          .where((part) => part.id != media.id)
                          .toList(),
                      inset: 0,
                    ),
                  ],
                  if (details != null &&
                      details.recommendations.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    MediaRow(
                        title: 'Recomendados para você',
                        mediaItems: details.recommendations,
                        inset: 0),
                  ],
                  if (details != null && details.similar.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    MediaRow(
                        title: 'Títulos semelhantes',
                        mediaItems: details.similar,
                        inset: 0),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockedNotice extends StatelessWidget {
  final String? rating;
  const _BlockedNotice({required this.rating});

  @override
  Widget build(BuildContext context) {
    final colors = SabuflixTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.12),
        borderRadius: SabuflixTheme.radiusMd,
        border: Border.all(color: colors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: colors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Classificação ${rating ?? 'indicativa'} acima do permitido neste perfil. Troque de perfil ou ajuste o limite para assistir.',
              style: colors.body(
                  color: colors.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditsBlock extends StatelessWidget {
  final MediaDetails? details;
  final MediaItem media;
  const _CreditsBlock({required this.details, required this.media});

  @override
  Widget build(BuildContext context) {
    final lines = <Widget>[];
    if (details != null) {
      if (details!.creators.isNotEmpty) {
        lines.add(InfoLine(
            label: 'Criação',
            value: details!.creators.map((c) => c.name).join(', ')));
      }
      if (details!.directors.isNotEmpty) {
        lines.add(InfoLine(
            label: 'Direção',
            value: details!.directors.map((c) => c.name).take(3).join(', ')));
      }
      if (details!.writers.isNotEmpty) {
        lines.add(InfoLine(
            label: 'Roteiro',
            value: details!.writers
                .map((c) => c.name)
                .toSet()
                .take(3)
                .join(', ')));
      }
      if (details!.cast.isNotEmpty) {
        lines.add(InfoLine(
            label: 'Elenco',
            value: details!.cast.take(4).map((c) => c.name).join(', ')));
      }
      if (details!.networks.isNotEmpty) {
        lines.add(InfoLine(
            label: media.isSeries ? 'Emissora' : 'Produção',
            value: details!.networks.take(2).join(', ')));
      }
    }
    if (media.originalTitle != null &&
        media.originalTitle!.isNotEmpty &&
        media.originalTitle != media.title) {
      lines
          .add(InfoLine(label: 'Título original', value: media.originalTitle!));
    }
    if (lines.isEmpty) return const SizedBox.shrink();
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: lines);
  }
}

class _EpisodesSection extends StatelessWidget {
  final MediaItem media;
  final int season;
  final List<int> seasons;
  final List<dynamic> episodes;
  final bool loading;
  final dynamic savedProgress;
  final EpisodeSummary? nextEpisode;
  final ValueChanged<int> onSeason;
  final void Function(int episode, String title) onPlay;
  final void Function(int episode, String title) onDownload;

  const _EpisodesSection({
    required this.media,
    required this.season,
    required this.seasons,
    required this.episodes,
    required this.loading,
    required this.savedProgress,
    required this.nextEpisode,
    required this.onSeason,
    required this.onPlay,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final colors = SabuflixTheme.of(context);
    final watched = context.watch<WatchedProvider>();
    final watchedInSeason = watched.watchedCountInSeason(media.id, season);
    final allWatched =
        episodes.isNotEmpty && watchedInSeason >= episodes.length;
    final today = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailSectionTitle(
          'Episódios',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (episodes.isNotEmpty)
                Text('$watchedInSeason/${episodes.length} vistos',
                    style: colors.caption(fontSize: 12)),
              PopupMenuButton<String>(
                tooltip: 'Opções da temporada',
                icon:
                    Icon(Icons.more_horiz_rounded, color: colors.textSecondary),
                onSelected: (value) {
                  final numbers = episodes
                      .whereType<Map>()
                      .map((e) => (e['episode_number'] as num?)?.toInt())
                      .whereType<int>();
                  watched.markSeasonWatched(media.id, season, numbers,
                      watched: value == 'watch');
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                      value: allWatched ? 'unwatch' : 'watch',
                      child: Text(allWatched
                          ? 'Desmarcar temporada'
                          : 'Marcar temporada como assistida')),
                ],
              ),
            ],
          ),
        ),
        if (seasons.length > 1)
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: seasons.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final s = seasons[index];
                return ChoiceChip(
                  label: Text('Temporada $s'),
                  selected: s == season,
                  showCheckmark: false,
                  onSelected: (_) {
                    if (s != season) onSeason(s);
                  },
                );
              },
            ),
          ),
        if (nextEpisode != null && nextEpisode!.season == season) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: colors.accent),
              const SizedBox(width: 6),
              Text(
                'Próximo episódio ${formatEpisodeTag(nextEpisode!.season, nextEpisode!.episode)}'
                '${nextEpisode!.airDate != null ? ' em ${_date(nextEpisode!.airDate!)}' : ''}',
                style: colors.caption(fontSize: 12, color: colors.accent),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (episodes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('Nenhum episódio disponível nesta temporada.',
                style: colors.body()),
          )
        else
          for (var i = 0; i < episodes.length; i++)
            Builder(builder: (context) {
              final ep = episodes[i] as Map;
              final number = (ep['episode_number'] as num?)?.toInt() ?? i + 1;
              final name = (ep['name'] ?? 'Episódio $number').toString();
              final still = ep['still_path'];
              final airDate = ep['air_date']?.toString();
              final parsed = DateTime.tryParse(airDate ?? '');
              final unreleased = parsed != null && parsed.isAfter(today);
              final isCurrent = savedProgress != null &&
                  savedProgress.season == season &&
                  savedProgress.episode == number;
              return EpisodeTile(
                number: number,
                name: name,
                overview: ep['overview']?.toString(),
                runtime: (ep['runtime'] as num?)?.toInt(),
                airDate: airDate,
                imageUrl: still != null
                    ? 'https://image.tmdb.org/t/p/w300$still'
                    : media.fullBackdropPath,
                progress: isCurrent ? (savedProgress.progress as double) : 0,
                watched: watched.isEpisodeWatched(media.id, season, number),
                current: isCurrent,
                unreleased: unreleased,
                onPlay: () => onPlay(number, name),
                onToggleWatched: () =>
                    watched.toggleEpisode(media.id, season, number),
                downloadBadge: kIsWeb
                    ? null
                    : _EpisodeDownloadBadge(
                        mediaId: media.id,
                        season: season,
                        episode: number,
                        onStart: () => onDownload(number, name),
                      ),
              );
            }),
      ],
    );
  }

  static String _date(String iso) {
    final parts = iso.split('-');
    if (parts.length < 3) return iso;
    return '${parts[2]}/${parts[1]}';
  }
}

/// Mirrors the offline state of the title in the action row.
class _DownloadAction extends StatelessWidget {
  final int mediaId;
  final int? season;
  final int? episode;
  final VoidCallback onStart;

  const _DownloadAction({
    required this.mediaId,
    required this.onStart,
    this.season,
    this.episode,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadsProvider>(
      builder: (context, downloads, child) {
        final item = downloads.find(mediaId, season: season, episode: episode);
        final colors = SabuflixTheme.of(context);
        IconData icon = Icons.download_rounded;
        String label = 'Baixar';
        VoidCallback? onTap = onStart;
        bool active = false;
        Color? activeColor;
        Widget? child;
        if (item != null) {
          switch (item.status) {
            case DownloadStatus.completed:
              icon = Icons.download_done_rounded;
              label = 'Baixado';
              active = true;
              activeColor = colors.success;
              onTap = () => playDownload(context, item);
              break;
            case DownloadStatus.downloading:
            case DownloadStatus.queued:
              label = item.totalBytes > 0
                  ? '${(item.progress * 100).round()}%'
                  : 'Baixando';
              onTap = () => downloads.pause(item.id);
              child = SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  value: item.progress > 0 ? item.progress : null,
                  strokeWidth: 2.5,
                  color: colors.accent,
                ),
              );
              break;
            case DownloadStatus.paused:
              icon = Icons.pause_circle_outline_rounded;
              label = 'Pausado';
              onTap = () => downloads.resume(item.id);
              break;
            case DownloadStatus.failed:
              icon = Icons.refresh_rounded;
              label = 'Tentar de novo';
              onTap = () => downloads.resume(item.id);
              break;
          }
        }
        return DetailAction(
          icon: icon,
          label: label,
          onTap: onTap,
          active: active,
          activeColor: activeColor,
          child: child,
        );
      },
    );
  }
}

/// Compact download control layered onto an episode thumbnail.
class _EpisodeDownloadBadge extends StatelessWidget {
  final int mediaId;
  final int season;
  final int episode;
  final VoidCallback onStart;

  const _EpisodeDownloadBadge({
    required this.mediaId,
    required this.season,
    required this.episode,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadsProvider>(
      builder: (context, downloads, child) {
        final item = downloads.find(mediaId, season: season, episode: episode);
        final colors = SabuflixTheme.of(context);
        IconData icon = Icons.download_rounded;
        Color color = Colors.white;
        VoidCallback? onTap = onStart;
        String tooltip = 'Baixar episódio';
        if (item != null) {
          switch (item.status) {
            case DownloadStatus.completed:
              icon = Icons.check_rounded;
              color = colors.success;
              tooltip = 'Baixado · toque para assistir offline';
              onTap = () => playDownload(context, item);
              break;
            case DownloadStatus.downloading:
            case DownloadStatus.queued:
              icon = Icons.downloading_rounded;
              color = colors.accent;
              tooltip = 'Pausar download';
              onTap = () => downloads.pause(item.id);
              break;
            case DownloadStatus.paused:
              icon = Icons.pause_rounded;
              color = colors.accent;
              tooltip = 'Continuar download';
              onTap = () => downloads.resume(item.id);
              break;
            case DownloadStatus.failed:
              icon = Icons.refresh_rounded;
              color = const Color(0xFFFF453A);
              tooltip = 'Tentar novamente';
              onTap = () => downloads.resume(item.id);
              break;
          }
        }
        return Tooltip(
          message: tooltip,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22), width: 0.8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
          ),
        );
      },
    );
  }
}
