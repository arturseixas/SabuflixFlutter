import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/download_item.dart';
import '../models/media_item.dart';
import '../models/cast_member.dart';
import '../theme/sabuflix_theme.dart';
import '../tv/tv_focus.dart';
import '../tv/tv_metrics.dart';
import '../tv/tv_platform.dart';
import '../services/tmdb_service.dart';
import '../providers/favorites_provider.dart';
import '../utils/app_route.dart';
import '../widgets/media_row.dart';
import '../widgets/glass_container.dart';
import '../services/froststream_service.dart';
import '../providers/continue_watching_provider.dart';
import '../providers/downloads_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/playlist_provider.dart';
import '../utils/playback.dart';
import 'video_player_screen.dart';

class MediaDetailsScreen extends StatefulWidget {
  final MediaItem media;

  const MediaDetailsScreen({Key? key, required this.media}) : super(key: key);

  @override
  State<MediaDetailsScreen> createState() => _MediaDetailsScreenState();
}

class _MediaDetailsScreenState extends State<MediaDetailsScreen> {
  final TMDBService _tmdbService = TMDBService();
  MediaItem? _detailedMedia;
  List<CastMember> _cast = [];
  List<MediaItem> _similar = [];
  List<dynamic> _episodes = [];
  int _seasonNumber = 1;
  List<int> _availableSeasons = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final details = await _tmdbService.fetchMediaDetails(widget.media.id, widget.media.mediaType);
      final castList = await _tmdbService.fetchCast(widget.media.id, widget.media.mediaType);
      final similarList = await _tmdbService.fetchSimilar(widget.media.id, widget.media.mediaType);

      List<dynamic> episodes = [];
      int sNum = 1;
      List<int> availableSeasons = [];
      if (widget.media.mediaType == 'tv' && details != null) {
         if (details.seasons != null && details.seasons!.isNotEmpty) {
           final validSeasons = details.seasons!.where((s) => s['season_number'] > 0).toList();
           if (validSeasons.isNotEmpty) {
             sNum = validSeasons.first['season_number'];
             availableSeasons = validSeasons.map<int>((s) => s['season_number'] as int).toList();
           }
         }
         episodes = await _tmdbService.fetchSeasonEpisodes(widget.media.id, sNum);
      }

      if (!mounted) return;
      setState(() {
        _detailedMedia = details ?? widget.media;
        _cast = castList;
        _similar = similarList;
        _episodes = episodes;
        _seasonNumber = sNum;
        _availableSeasons = availableSeasons;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _detailedMedia = widget.media);
    }
  }

  Future<void> _onSeasonChanged(int season) async {
    setState(() {
      _seasonNumber = season;
      _episodes = [];
    });
    try {
      final episodes = await _tmdbService.fetchSeasonEpisodes(widget.media.id, season);
      if (!mounted) return;
      setState(() {
        _episodes = episodes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao carregar episódios.')));
    }
  }

  /// Source picker, used both to start playback and to queue a download.
  Future<void> _showStreamSelector({
    int? season,
    int? episode,
    String? episodeTitle,
    bool forDownload = false,
    Duration startAt = Duration.zero,
  }) async {
    final media = _detailedMedia ?? widget.media;
    final imdbId = media.imdbId;
    if (imdbId == null || imdbId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID do IMDB não encontrado para buscar as fontes.')));
      return;
    }

    await _showChooser(
      title: forDownload ? 'Baixar de qual fonte?' : 'Selecione uma Fonte',
      builder: (ctx) => FutureBuilder<List<Map<String, dynamic>>>(
        future: FrostStreamService.fetchStreams(
          imdbId: imdbId,
          type: media.mediaType,
          season: season,
          episode: episode,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: SabuflixTheme.accent));
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('Nenhuma fonte encontrada', style: SabuflixTheme.body(color: Colors.white)));
          }

          final streams = snapshot.data!;
          return ListView.separated(
            shrinkWrap: true,
            itemCount: streams.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final s = streams[i];
              return _ChooserTile(
                title: (s['name'] ?? 'Stream').toString(),
                subtitle: (s['title'] ?? 'Qualidade desconhecida').toString(),
                icon: forDownload ? Icons.download_for_offline_rounded : Icons.play_circle_fill_rounded,
                // The list arrives after the sheet opens, so the first source
                // has to claim the focus itself or the remote has nothing to
                // act on.
                autofocus: i == 0,
                onPressed: () {
                  Navigator.pop(ctx);
                  if (forDownload) {
                    _startDownload(
                      media: media,
                      stream: s,
                      season: season,
                      episode: episode,
                      episodeTitle: episodeTitle,
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    glassRoute(VideoPlayerScreen(
                      media: media,
                      videoUrl: s['url'],
                      season: season,
                      episode: episode,
                      episodeTitle: episodeTitle,
                      startAt: startAt,
                    )),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Presents a pick-one list the way the current device expects it: a sheet
  /// rising from the bottom edge on a phone, a centred panel on a TV.
  ///
  /// A bottom sheet is the wrong shape for a remote — it sits in the overscan
  /// zone, and its drag-to-dismiss handle means nothing without a finger.
  Future<void> _showChooser({
    required String title,
    required WidgetBuilder builder,
  }) async {
    final metrics = TvMetrics.of(context);

    Widget panel(BuildContext ctx) => GlassContainer(
          borderRadius: metrics.isTv
              ? SabuflixTheme.radiusLg
              : const BorderRadius.vertical(top: Radius.circular(24)),
          padding: EdgeInsets.all(metrics.isTv ? 32 : 24),
          blur: 40,
          fillOpacity: 0.4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: SabuflixTheme.title(fontSize: metrics.isTv ? 28 : 20)),
              SizedBox(height: metrics.isTv ? 22 : 16),
              Flexible(child: builder(ctx)),
            ],
          ),
        );

    if (!metrics.isTv) {
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: panel,
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: metrics.screen.width * 0.6,
            maxHeight: metrics.screen.height * 0.75,
          ),
          child: Material(color: Colors.transparent, child: panel(ctx)),
        ),
      ),
    );
  }

  /// Queues a source for offline playback.
  Future<void> _startDownload({
    required MediaItem media,
    required Map<String, dynamic> stream,
    int? season,
    int? episode,
    String? episodeTitle,
  }) async {
    final url = (stream['url'] ?? '').toString();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta fonte não oferece um link para download.')),
      );
      return;
    }

    final rawQuality = (stream['title'] ?? stream['name'] ?? '').toString();
    final quality = rawQuality.split('\n').first.trim();

    final added = await context.read<DownloadsProvider>().enqueue(
          media: media,
          url: url,
          quality: quality,
          season: season,
          episode: episode,
          episodeTitle: episodeTitle,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? 'Download iniciado. Acompanhe na aba Downloads.'
              : 'Este item já está na sua lista de downloads.',
        ),
      ),
    );
  }

  Future<void> _showPlaylistsSelector(MediaItem media) async {
    await _showChooser(
      title: 'Adicionar a qual Playlist?',
      builder: (ctx) => Consumer<PlaylistProvider>(
        builder: (context, provider, child) {
          if (provider.playlists.isEmpty) {
            return Text(
              'Você ainda não tem playlists criadas.',
              style: SabuflixTheme.body(color: SabuflixTheme.textSecondary),
            );
          }
          return ListView.separated(
            shrinkWrap: true,
            itemCount: provider.playlists.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final p = provider.playlists[i];
              final isInPlaylist = p.items.any((item) => item.id == media.id);
              return _ChooserTile(
                title: p.name,
                icon: isInPlaylist ? Icons.check_circle : Icons.add_circle_outline,
                autofocus: i == 0,
                onPressed: () {
                  if (!isInPlaylist) {
                    provider.addMediaToPlaylist(p.id, media);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Adicionado à ${p.name}')),
                    );
                  }
                  Navigator.pop(ctx);
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Episode name from the loaded season, when it is already known.
  String? _episodeTitleFor(int episodeNumber) {
    for (final episode in _episodes) {
      if (episode is Map && (episode['episode_number'] as num?)?.toInt() == episodeNumber) {
        final name = episode['name'];
        if (name != null) return name.toString();
      }
    }
    return null;
  }

  int _getAgeValue(String? rating) {
    if (rating == null || rating.isEmpty || rating == 'Livre' || rating == 'L') return 0;
    return int.tryParse(rating.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final media = _detailedMedia ?? widget.media;
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    final savedProgress = context.watch<ContinueWatchingProvider>().forMedia(media.id);
    final isFav = favoritesProvider.isFavorite(media.id);
    final metrics = TvMetrics.of(context);
    final screenWidth = metrics.screen.width;
    final isDesktop = screenWidth >= 600;

    final mediaAge = _getAgeValue(media.ageRating);
    final profileAge = _getAgeValue(profileProvider.currentProfile?.maxAgeRating);
    final isBlocked = mediaAge > profileAge;

    return Scaffold(
      backgroundColor: SabuflixTheme.background,
      body: CustomScrollView(
        physics: metrics.isTv ? const ClampingScrollPhysics() : const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: metrics.isTv ? metrics.screen.height * 0.55 : 400,
            pinned: true,
            toolbarHeight: metrics.isTv ? 80 : kToolbarHeight,
            backgroundColor: SabuflixTheme.background,
            // The remote's own Back button is the real way out of this screen;
            // the on-screen arrow stays for touch and mouse, and is skipped by
            // the D-pad so the first press does not land on it.
            automaticallyImplyLeading: !metrics.isTv,
            leading: metrics.isTv
                ? null
                : Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                    ),
                  ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: media.fullBackdropPath,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.45, 1.0],
                        colors: [
                          SabuflixTheme.background.withValues(alpha: 0.5),
                          SabuflixTheme.background.withValues(alpha: 0.3),
                          SabuflixTheme.background,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: metrics.isTv ? metrics.gutter : 28, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: media.fullLogoPath != null
                            ? Align(
                                alignment: Alignment.centerLeft,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: metrics.isTv ? 130 : 75,
                                    maxWidth: metrics.isTv ? 520 : 320,
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: media.fullLogoPath!,
                                    fit: BoxFit.contain,
                                    alignment: Alignment.centerLeft,
                                    errorWidget: (context, url, err) => Text(
                                      media.title,
                                      style: SabuflixTheme.headline(fontSize: metrics.headlineSize),
                                    ),
                                  ),
                                ),
                              )
                            : Text(
                                media.title,
                                style: SabuflixTheme.headline(fontSize: metrics.headlineSize),
                              ),
                      ),
                      // On a TV this lives in the button row below, where the
                      // D-pad can reach it alongside Assistir.
                      if (!metrics.isTv)
                        IconButton(
                          onPressed: () => favoritesProvider.toggleFavorite(media),
                          icon: Icon(
                            isFav ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: isFav ? SabuflixTheme.accent : SabuflixTheme.textSecondary,
                            size: 28,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Icon(Icons.star_rounded, color: SabuflixTheme.gold, size: metrics.isTv ? 24 : 16),
                      const SizedBox(width: 4),
                      Text(
                        media.formattedRating,
                        style: SabuflixTheme.body(
                          color: SabuflixTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: metrics.bodySize,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('·', style: SabuflixTheme.body(fontSize: metrics.bodySize, color: SabuflixTheme.textMuted)),
                      const SizedBox(width: 10),
                      Text(media.formattedYear, style: SabuflixTheme.body(fontSize: metrics.bodySize)),
                      if (media.ageRating != null) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: metrics.isTv ? 10 : 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.3),
                            borderRadius: SabuflixTheme.radiusSm,
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            media.ageRating!,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: metrics.isTv ? 14 : 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (isBlocked)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: SabuflixTheme.radiusMd,
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Este conteúdo possui classificação superior à permitida pelo seu perfil.',
                              style: SabuflixTheme.body(color: Colors.redAccent, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Wrap(
                      spacing: metrics.isTv ? 16 : 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _ActionButton(
                          icon: Icons.play_arrow_rounded,
                          label: savedProgress != null
                              ? savedProgress.resumeLabel
                              : (media.mediaType == 'tv' ? 'Assistir S$_seasonNumber:E1' : 'Assistir Agora'),
                          primary: true,
                          // Opening a title with the remote should leave the
                          // cursor on the one button everybody came for.
                          autofocus: metrics.isTv,
                          minWidth: isDesktop ? 220 : 180,
                          onPressed: () {
                            if (savedProgress != null) {
                              resumeWatching(context, savedProgress);
                            } else if (media.mediaType == 'tv') {
                              _showStreamSelector(season: _seasonNumber, episode: 1);
                            } else {
                              _showStreamSelector();
                            }
                          },
                        ),
                        // The bookmark icon in the header is out of a D-pad's
                        // reach, so on a TV the list toggle joins the row.
                        if (metrics.isTv)
                          _ActionButton(
                            icon: isFav ? Icons.check_rounded : Icons.add_rounded,
                            label: isFav ? 'Na Lista' : 'Minha Lista',
                            highlighted: isFav,
                            onPressed: () => favoritesProvider.toggleFavorite(media),
                          ),
                        // Downloads need a filesystem the TV browsers do not
                        // expose; the button would only ever fail there.
                        if (TvPlatform.supportsDownloads)
                          _DownloadActionButton(
                            mediaId: media.id,
                            season: media.mediaType == 'tv' ? _seasonNumber : null,
                            episode: media.mediaType == 'tv' ? 1 : null,
                            onStart: () => _showStreamSelector(
                              forDownload: true,
                              season: media.mediaType == 'tv' ? _seasonNumber : null,
                              episode: media.mediaType == 'tv' ? 1 : null,
                              episodeTitle: media.mediaType == 'tv' ? _episodeTitleFor(1) : null,
                            ),
                          ),
                        _ActionButton(
                          icon: Icons.featured_play_list_outlined,
                          label: metrics.isTv ? 'Playlists' : null,
                          onPressed: () => _showPlaylistsSelector(media),
                        ),
                      ],
                    ),
                  if (!isBlocked && savedProgress != null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 260,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.all(Radius.circular(2)),
                            child: LinearProgressIndicator(
                              value: savedProgress.progress,
                              minHeight: 3,
                              backgroundColor: Colors.white.withValues(alpha: 0.16),
                              valueColor: const AlwaysStoppedAnimation<Color>(SabuflixTheme.accent),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            '${savedProgress.subtitleLabel} · ${savedProgress.remainingLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SabuflixTheme.caption(fontSize: 12, color: SabuflixTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  if (media.genres != null && media.genres!.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: media.genres!
                          .map(
                            (g) => GlassContainer(
                              borderRadius: SabuflixTheme.radiusPill,
                              blur: 16,
                              fillOpacity: 0.25,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text(g, style: SabuflixTheme.body(fontSize: 12, fontWeight: FontWeight.w500, color: SabuflixTheme.textPrimary)),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (!isBlocked && (media.mediaType == 'tv' && _availableSeasons.isNotEmpty)) ...[
                    Text('Episódios', style: SabuflixTheme.title(fontSize: metrics.sectionTitleSize)),
                    const SizedBox(height: 12),
                    // A dropdown menu is a mouse control: it opens over the
                    // content and traps the focus. A scrollable row of season
                    // pills is one D-pad press away and always visible.
                    SizedBox(
                      height: metrics.isTv ? 62 : 46,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: metrics.isTv ? const ClampingScrollPhysics() : const BouncingScrollPhysics(),
                        itemCount: _availableSeasons.length,
                        itemBuilder: (context, index) {
                          final season = _availableSeasons[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: _SeasonPill(
                              season: season,
                              selected: season == _seasonNumber,
                              onPressed: () {
                                if (season != _seasonNumber) _onSeasonChanged(season);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_episodes.isEmpty)
                      SizedBox(
                        height: metrics.episodeRowHeight,
                        child: const Center(child: CircularProgressIndicator(color: SabuflixTheme.accent)),
                      )
                    else
                      SizedBox(
                        height: metrics.episodeRowHeight,
                        child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _episodes.length,
                        physics: metrics.isTv ? const ClampingScrollPhysics() : const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final ep = _episodes[index];
                          final stillPath = ep['still_path'];
                          final int epNum = (ep['episode_number'] as num?)?.toInt() ?? (index + 1);
                          final String epName = (ep['name'] ?? 'Episódio $epNum').toString();
                          final fullStillPath = stillPath != null ? 'https://image.tmdb.org/t/p/w300$stillPath' : media.fullBackdropPath;

                          return TvFocusable(
                            borderRadius: SabuflixTheme.radiusMd,
                            semanticLabel: 'Episódio $epNum, $epName',
                            onPressed: () => _showStreamSelector(
                              season: _seasonNumber,
                              episode: epNum,
                              episodeTitle: epName,
                            ),
                            builder: (context, focused, child) => AnimatedScale(
                              scale: focused ? metrics.focusScale : 1.0,
                              duration: SabuflixTheme.durationFast,
                              curve: SabuflixTheme.curveStandard,
                              child: Container(
                                width: metrics.episodeCardWidth,
                                margin: const EdgeInsets.only(right: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: SabuflixTheme.radiusMd,
                                        border: Border.all(
                                          color: focused ? SabuflixTheme.textPrimary : Colors.transparent,
                                          width: focused ? metrics.focusRingWidth : 0,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: SabuflixTheme.radiusMd,
                                        child: AspectRatio(
                                          aspectRatio: 16 / 9,
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              CachedNetworkImage(
                                                imageUrl: fullStillPath,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) => Container(color: SabuflixTheme.surface),
                                                errorWidget: (context, url, err) => Container(color: SabuflixTheme.surface),
                                              ),
                                              Center(
                                                child: Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.5),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.play_arrow_rounded,
                                                    color: Colors.white,
                                                    size: metrics.isTv ? 34 : 24,
                                                  ),
                                                ),
                                              ),
                                              // The badge is a tap target, not
                                              // a focus target: on a TV the
                                              // episode row keeps one stop per
                                              // card, and downloading is done
                                              // from the button row above.
                                              if (TvPlatform.supportsDownloads && !metrics.isTv)
                                                Positioned(
                                                  right: 6,
                                                  bottom: 6,
                                                  child: _EpisodeDownloadBadge(
                                                    mediaId: media.id,
                                                    season: _seasonNumber,
                                                    episode: epNum,
                                                    onStart: () => _showStreamSelector(
                                                      forDownload: true,
                                                      season: _seasonNumber,
                                                      episode: epNum,
                                                      episodeTitle: epName,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '$epNum. $epName',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: SabuflixTheme.body(
                                        color: SabuflixTheme.textPrimary,
                                        fontSize: metrics.cardLabelSize,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (ep['runtime'] != null)
                                      Text(
                                        '${ep['runtime']} min',
                                        style: SabuflixTheme.body(
                                          color: SabuflixTheme.textMuted,
                                          fontSize: metrics.isTv ? 15 : 11,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            child: const SizedBox.shrink(),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  Text('Sinopse', style: SabuflixTheme.title(fontSize: metrics.sectionTitleSize)),
                  const SizedBox(height: 10),
                  Text(
                    media.overview != null && media.overview!.isNotEmpty
                        ? media.overview!
                        : 'Nenhuma sinopse disponível em português.',
                    style: SabuflixTheme.body(fontSize: metrics.isTv ? 20 : 15, height: 1.6),
                  ),
                  const SizedBox(height: 32),

                  if (_cast.isNotEmpty) ...[
                    Text('Elenco Principal', style: SabuflixTheme.title(fontSize: metrics.sectionTitleSize)),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: metrics.castRowHeight,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _cast.length,
                        itemBuilder: (context, index) {
                          final actor = _cast[index];
                          final avatarSize = metrics.isTv ? 112.0 : 72.0;
                          return Container(
                            width: metrics.castCardWidth,
                            margin: const EdgeInsets.only(right: 16),
                            child: Column(
                              children: [
                                ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: actor.fullProfilePath,
                                    width: avatarSize,
                                    height: avatarSize,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, err) => Container(
                                      color: SabuflixTheme.surface,
                                      child: const Icon(Icons.person, color: SabuflixTheme.textMuted),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  actor.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: SabuflixTheme.body(
                                    color: SabuflixTheme.textPrimary,
                                    fontSize: metrics.isTv ? 16 : 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  actor.character,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: SabuflixTheme.body(
                                    color: SabuflixTheme.textMuted,
                                    fontSize: metrics.isTv ? 14 : 10,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  if (_similar.isNotEmpty) ...[
                    MediaRow(title: 'Títulos Semelhantes', mediaItems: _similar),
                    const SizedBox(height: 40),
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

/// Pill that mirrors the offline state of the title: download, in progress,
/// or already saved. Scoped to its own [Consumer] so download progress ticks
/// never rebuild the whole details page.
class _DownloadActionButton extends StatelessWidget {
  final int mediaId;
  final int? season;
  final int? episode;
  final VoidCallback onStart;

  const _DownloadActionButton({
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

        IconData icon = Icons.download_rounded;
        String label = 'Baixar';
        VoidCallback? onTap = onStart;

        if (item != null) {
          switch (item.status) {
            case DownloadStatus.completed:
              icon = Icons.check_circle_rounded;
              label = 'Baixado';
              onTap = null;
              break;
            case DownloadStatus.downloading:
            case DownloadStatus.queued:
              icon = Icons.downloading_rounded;
              label = item.totalBytes > 0 ? '${(item.progress * 100).round()}%' : 'Baixando';
              onTap = () => downloads.pause(item.id);
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

        final isDone = item?.isCompleted ?? false;

        return _ActionButton(
          icon: icon,
          label: label,
          highlighted: isDone,
          highlightColor: SabuflixTheme.success,
          onPressed: onTap,
        );
      },
    );
  }
}

/// The pill used by every action on this screen.
///
/// One widget for all of them so the focus treatment is identical, and so the
/// D-pad walks a single row of same-height targets instead of a mixture of
/// buttons, icon buttons and glass panels.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool primary;
  final bool highlighted;
  final Color? highlightColor;
  final bool autofocus;
  final double? minWidth;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    this.label,
    this.onPressed,
    this.primary = false,
    this.highlighted = false,
    this.highlightColor,
    this.autofocus = false,
    this.minWidth,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = TvMetrics.of(context);
    final enabled = onPressed != null;

    return TvFocusable(
      autofocus: autofocus && enabled,
      onPressed: onPressed,
      showRing: false,
      scaleOnFocus: false,
      semanticLabel: label,
      builder: (context, focused, child) {
        final Color background = focused
            ? SabuflixTheme.textPrimary
            : primary
                ? SabuflixTheme.accent
                : Colors.white.withValues(alpha: 0.14);
        final Color foreground = focused
            ? SabuflixTheme.background
            : highlighted
                ? (highlightColor ?? SabuflixTheme.accent)
                : SabuflixTheme.textPrimary;

        return Opacity(
          opacity: enabled ? 1 : 0.65,
          child: AnimatedContainer(
            duration: SabuflixTheme.durationFast,
            curve: SabuflixTheme.curveStandard,
            constraints: BoxConstraints(minWidth: minWidth ?? 0, minHeight: metrics.isTv ? 66 : 52),
            padding: EdgeInsets.symmetric(horizontal: metrics.isTv ? 28 : 18),
            decoration: BoxDecoration(
              color: background,
              borderRadius: SabuflixTheme.radiusPill,
              border: Border.all(
                color: focused ? SabuflixTheme.textPrimary : Colors.white.withValues(alpha: 0.16),
                width: focused ? metrics.focusRingWidth : 1,
              ),
              boxShadow: focused
                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 24, offset: const Offset(0, 10))]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: metrics.isTv ? 28 : 22, color: foreground),
                if (label != null) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SabuflixTheme.body(
                        fontSize: metrics.isTv ? 19 : 15,
                        fontWeight: FontWeight.w700,
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      child: const SizedBox.shrink(),
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

        IconData icon = Icons.download_rounded;
        Color color = Colors.white;
        VoidCallback? onTap = onStart;

        if (item != null) {
          switch (item.status) {
            case DownloadStatus.completed:
              icon = Icons.check_rounded;
              color = SabuflixTheme.success;
              onTap = null;
              break;
            case DownloadStatus.downloading:
            case DownloadStatus.queued:
              icon = Icons.downloading_rounded;
              color = SabuflixTheme.accent;
              onTap = () => downloads.pause(item.id);
              break;
            case DownloadStatus.paused:
              icon = Icons.pause_rounded;
              color = SabuflixTheme.accent;
              onTap = () => downloads.resume(item.id);
              break;
            case DownloadStatus.failed:
              icon = Icons.refresh_rounded;
              color = const Color(0xFFFF453A);
              onTap = () => downloads.resume(item.id);
              break;
          }
        }

        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 0.8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
        );
      },
    );
  }
}

/// One row of a pick-one list (a stream source, a playlist).
///
/// [ListTile] cannot show a focus state loud enough for a TV, so the row is
/// built on [TvFocusable]: identical on touch, unmistakable under a remote.
class _ChooserTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool autofocus;
  final VoidCallback onPressed;

  const _ChooserTile({
    required this.title,
    required this.icon,
    required this.onPressed,
    this.subtitle,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = TvMetrics.of(context);

    return TvFocusable(
      autofocus: autofocus,
      onPressed: onPressed,
      showRing: false,
      scaleOnFocus: false,
      semanticLabel: title,
      builder: (context, focused, child) => AnimatedContainer(
        duration: SabuflixTheme.durationFast,
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: metrics.isTv ? 18 : 12),
        decoration: tvFocusDecoration(
          focused: focused,
          borderRadius: SabuflixTheme.radiusMd,
          ringWidth: metrics.focusRingWidth,
          fill: Colors.white.withValues(alpha: focused ? 0.2 : 0.08),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: SabuflixTheme.body(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontSize: metrics.isTv ? 20 : 16,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        subtitle!,
                        style: SabuflixTheme.body(
                          fontSize: metrics.isTv ? 16 : 13,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon, color: SabuflixTheme.accent, size: metrics.isTv ? 42 : 36),
          ],
        ),
      ),
      child: const SizedBox.shrink(),
    );
  }
}

/// Season selector entry, in place of the dropdown menu.
class _SeasonPill extends StatelessWidget {
  final int season;
  final bool selected;
  final VoidCallback onPressed;

  const _SeasonPill({required this.season, required this.selected, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final metrics = TvMetrics.of(context);

    return TvFocusable(
      onPressed: onPressed,
      showRing: false,
      scaleOnFocus: false,
      semanticLabel: 'Temporada $season',
      builder: (context, focused, child) => AnimatedContainer(
        duration: SabuflixTheme.durationFast,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: metrics.isTv ? 26 : 16),
        decoration: BoxDecoration(
          color: focused
              ? SabuflixTheme.textPrimary
              : selected
                  ? SabuflixTheme.accent
                  : Colors.white.withValues(alpha: 0.1),
          borderRadius: SabuflixTheme.radiusPill,
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Text(
          'Temporada $season',
          style: SabuflixTheme.body(
            fontSize: metrics.isTv ? 18 : 14,
            fontWeight: FontWeight.w700,
            color: focused ? SabuflixTheme.background : Colors.white,
          ),
        ),
      ),
      child: const SizedBox.shrink(),
    );
  }
}
