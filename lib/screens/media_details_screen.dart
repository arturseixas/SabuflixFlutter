import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/download_item.dart';
import '../models/media_item.dart';
import '../models/cast_member.dart';
import '../theme/sabuflix_theme.dart';
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
import '../providers/watched_provider.dart';
import '../utils/playback.dart';
import 'video_player_screen.dart';

class MediaDetailsScreen extends StatefulWidget {
  final MediaItem media;

  const MediaDetailsScreen({super.key, required this.media});

  @override
  State<MediaDetailsScreen> createState() => _MediaDetailsScreenState();
}

class _MediaDetailsScreenState extends State<MediaDetailsScreen> {
  final TMDBService _tmdbService = TMDBService();
  bool _loadingDetails = true;
  bool _loadingEpisodes = false;
  String? _detailsError;
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
    setState(() {
      _loadingDetails = true;
      _detailsError = null;
    });
    try {
      final results = await Future.wait([
        _tmdbService.fetchMediaDetails(widget.media.id, widget.media.mediaType),
        _tmdbService.fetchCast(widget.media.id, widget.media.mediaType),
        _tmdbService.fetchSimilar(widget.media.id, widget.media.mediaType),
      ]);
      final details = results[0] as MediaItem?;
      final castList = results[1] as List<CastMember>;
      final similarList = results[2] as List<MediaItem>;
      if (details == null) throw StateError('Detalhes indisponíveis');

      List<dynamic> episodes = [];
      int sNum = 1;
      List<int> availableSeasons = [];
      if (widget.media.mediaType == 'tv') {
        if (details.seasons != null && details.seasons!.isNotEmpty) {
          final validSeasons =
              details.seasons!.where((s) => s['season_number'] > 0).toList();
          if (validSeasons.isNotEmpty) {
            sNum = validSeasons.first['season_number'];
            availableSeasons = validSeasons
                .map<int>((s) => s['season_number'] as int)
                .toList();
          }
        }
        episodes =
            await _tmdbService.fetchSeasonEpisodes(widget.media.id, sNum);
      }

      if (!mounted) return;
      setState(() {
        _detailedMedia = details;
        _cast = castList;
        _similar = similarList;
        _episodes = episodes;
        _seasonNumber = sNum;
        _availableSeasons = availableSeasons;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _detailedMedia = widget.media;
        _detailsError = 'Não foi possível atualizar os detalhes.';
      });
    } finally {
      if (mounted) setState(() => _loadingDetails = false);
    }
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao carregar episódios.')));
      if (_seasonNumber == season) setState(() => _loadingEpisodes = false);
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Este título ainda não tem fontes disponíveis. Tente novamente mais tarde.')));
      return;
    }

    final sources = FrostStreamService.fetchStreams(
        imdbId: imdbId,
        type: media.mediaType,
        season: season,
        episode: episode);
    showModalBottomSheet(
        context: context,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return GlassContainer(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            padding: EdgeInsets.all(24),
            blur: 40,
            fillOpacity: 0.4,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: sources,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: CircularProgressIndicator(
                          color: SabuflixTheme.of(context).accent));
                }
                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  return Center(
                      child: Text('Nenhuma fonte encontrada',
                          style: SabuflixTheme.of(context).body(
                              color: SabuflixTheme.of(context).textPrimary)));
                }

                final streams = snapshot.data!;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      forDownload
                          ? 'Escolha a qualidade do download'
                          : 'Escolha como assistir',
                      style: SabuflixTheme.of(context).title(fontSize: 20),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '${streams.length} ${streams.length == 1 ? 'opção disponível' : 'opções disponíveis'}',
                      style: SabuflixTheme.of(context).caption(fontSize: 12),
                    ),
                    SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        itemCount: streams.length,
                        separatorBuilder: (_, __) => SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final s = streams[i];
                          return ListTile(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: SabuflixTheme.radiusMd),
                            tileColor: SabuflixTheme.of(context).secondaryFill,
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: SabuflixTheme.of(context)
                                    .accent
                                    .withValues(alpha: 0.14),
                                borderRadius: SabuflixTheme.radiusSm,
                              ),
                              child: Icon(
                                forDownload
                                    ? Icons.download_rounded
                                    : Icons.play_arrow_rounded,
                                color: SabuflixTheme.of(context).accent,
                                size: 22,
                              ),
                            ),
                            title: Text(s['displayName'] ?? 'Sabuflix',
                                style: SabuflixTheme.of(context).body(
                                    fontWeight: FontWeight.w700,
                                    color:
                                        SabuflixTheme.of(context).textPrimary,
                                    fontSize: 15)),
                            subtitle: Padding(
                              padding: EdgeInsets.only(top: 6.0),
                              child: Text(
                                s['displayDescription'] ??
                                    'Qualidade automática',
                                style: SabuflixTheme.of(context).body(
                                    fontSize: 13,
                                    color:
                                        SabuflixTheme.of(context).textSecondary,
                                    height: 1.4),
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              color: SabuflixTheme.of(context).textMuted,
                            ),
                            onTap: () {
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
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        });
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
        SnackBar(
            content: Text('Esta fonte não oferece um link para download.')),
      );
      return;
    }

    final rawQuality =
        (stream['displayQuality'] ?? stream['title'] ?? stream['name'] ?? '')
            .toString();
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
              ? 'Download iniciado. Acompanhe na Biblioteca.'
              : 'Este item já está na sua lista de downloads.',
        ),
      ),
    );
  }

  void _showPlaylistsSelector(MediaItem media) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return GlassContainer(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            padding: EdgeInsets.all(24),
            blur: 40,
            fillOpacity: 0.4,
            child: Consumer<PlaylistProvider>(
              builder: (context, provider, child) {
                if (provider.playlists.isEmpty) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Nenhuma Playlist',
                          style: SabuflixTheme.of(context).title(fontSize: 20)),
                      SizedBox(height: 16),
                      Text('Você ainda não tem playlists criadas.',
                          style: SabuflixTheme.of(context).body(
                              color: SabuflixTheme.of(context).textSecondary)),
                    ],
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Adicionar a qual Playlist?',
                        style: SabuflixTheme.of(context).title(fontSize: 20)),
                    SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        itemCount: provider.playlists.length,
                        separatorBuilder: (_, __) => SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final p = provider.playlists[i];
                          final isInPlaylist =
                              p.items.any((item) => item.id == media.id);
                          return ListTile(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: SabuflixTheme.radiusMd),
                            tileColor: SabuflixTheme.of(context).secondaryFill,
                            title: Text(p.name,
                                style: SabuflixTheme.of(context).body(
                                    fontWeight: FontWeight.w700,
                                    color:
                                        SabuflixTheme.of(context).textPrimary,
                                    fontSize: 16)),
                            trailing: Icon(
                                isInPlaylist
                                    ? Icons.check_circle
                                    : Icons.add_circle_outline,
                                color: SabuflixTheme.of(context).accent),
                            onTap: () {
                              if (!isInPlaylist) {
                                provider.addMediaToPlaylist(p.id, media);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Adicionado à ${p.name}')));
                              }
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        });
  }

  /// Episode name from the loaded season, when it is already known.
  String? _episodeTitleFor(int episodeNumber) {
    for (final episode in _episodes) {
      if (episode is Map &&
          (episode['episode_number'] as num?)?.toInt() == episodeNumber) {
        final name = episode['name'];
        if (name != null) return name.toString();
      }
    }
    return null;
  }

  int _getAgeValue(String? rating) {
    if (rating == null ||
        rating.isEmpty ||
        rating == 'Livre' ||
        rating == 'L') {
      return 0;
    }
    return int.tryParse(rating.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final media = _detailedMedia ?? widget.media;
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final watchedProvider = context.watch<WatchedProvider>();
    final profileProvider = Provider.of<ProfileProvider>(context);
    final savedProgress = context
        .watch<ContinueWatchingProvider>()
        .forMedia(media.id, mediaType: media.mediaType);
    final isFav =
        favoritesProvider.isFavorite(media.id, mediaType: media.mediaType);
    final isWatched =
        watchedProvider.isWatched(media.id, mediaType: media.mediaType);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 600;

    final mediaAge = _getAgeValue(media.ageRating);
    final profileAge =
        _getAgeValue(profileProvider.currentProfile?.maxAgeRating);
    final isBlocked = mediaAge > profileAge;

    return Scaffold(
      backgroundColor: SabuflixTheme.of(context).background,
      body: CustomScrollView(
        physics: BouncingScrollPhysics(),
        slivers: [
          if (_loadingDetails)
            SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
          if (_detailsError != null)
            SliverToBoxAdapter(
                child: SafeArea(
                    bottom: false,
                    child: ListTile(
                        title: Text(_detailsError!),
                        trailing: TextButton(
                            onPressed: _loadData,
                            child: Text('Tentar novamente'))))),
          SliverAppBar(
            expandedHeight: isDesktop ? 480 : 280,
            pinned: true,
            backgroundColor: SabuflixTheme.of(context).background,
            leading: Padding(
              padding: const EdgeInsets.all(6),
              child: IconButton(
                tooltip: 'Voltar',
                style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: .65),
                    foregroundColor: Colors.white),
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
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
                        stops: [0.0, 0.8, 1.0],
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          SabuflixTheme.of(context).background,
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
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(media.title.toUpperCase(),
                      style: SabuflixTheme.of(context)
                          .display(fontSize: isDesktop ? 48 : 32)),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.star_rounded,
                          color: SabuflixTheme.of(context).gold, size: 16),
                      SizedBox(width: 4),
                      Text(
                        media.formattedRating,
                        style: SabuflixTheme.of(context).body(
                            color: SabuflixTheme.of(context).textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                      SizedBox(width: 10),
                      Text('·',
                          style: SabuflixTheme.of(context).body(
                              fontSize: 14,
                              color: SabuflixTheme.of(context).textMuted)),
                      SizedBox(width: 10),
                      Text(media.formattedYear,
                          style: SabuflixTheme.of(context).body(fontSize: 14)),
                      if (media.ageRating != null) ...[
                        SizedBox(width: 10),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.3),
                            borderRadius: SabuflixTheme.radiusSm,
                            border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            media.ageRating!,
                            style: TextStyle(
                                color: SabuflixTheme.of(context).textPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 24),
                  if (isBlocked)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: SabuflixTheme.radiusMd,
                        border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.redAccent),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Este conteúdo possui classificação superior à permitida pelo seu perfil.',
                              style: SabuflixTheme.of(context).body(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: isDesktop ? 240 : 210,
                          child: ElevatedButton.icon(
                            onPressed: _loadingDetails || _detailsError != null
                                ? null
                                : () {
                                    if (savedProgress != null) {
                                      resumeWatching(context, savedProgress);
                                    } else if (media.mediaType == 'tv') {
                                      _showStreamSelector(
                                          season: _seasonNumber, episode: 1);
                                    } else {
                                      _showStreamSelector();
                                    }
                                  },
                            icon: Icon(Icons.play_arrow_rounded,
                                size: 22, color: Colors.white),
                            label: Text(
                              savedProgress != null
                                  ? savedProgress.resumeLabel
                                  : (media.mediaType == 'tv'
                                      ? 'Assistir S$_seasonNumber:E1'
                                      : 'Assistir Agora'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SabuflixTheme.of(context).body(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              favoritesProvider.toggleFavorite(media),
                          icon: Icon(isFav ? Icons.check : Icons.add),
                          label: Text(isFav ? 'Na minha lista' : 'Minha lista'),
                        ),
                        if (!kIsWeb)
                          _DownloadActionButton(
                            mediaId: media.id,
                            season:
                                media.mediaType == 'tv' ? _seasonNumber : null,
                            episode: media.mediaType == 'tv' ? 1 : null,
                            onStart: () => _showStreamSelector(
                              forDownload: true,
                              season: media.mediaType == 'tv'
                                  ? _seasonNumber
                                  : null,
                              episode: media.mediaType == 'tv' ? 1 : null,
                              episodeTitle: media.mediaType == 'tv'
                                  ? _episodeTitleFor(1)
                                  : null,
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => _showPlaylistsSelector(media),
                          icon: const Icon(Icons.featured_play_list_outlined),
                          label: const Text('Playlists'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await watchedProvider.toggle(media);
                            if (!isWatched && context.mounted) {
                              await context
                                  .read<ContinueWatchingProvider>()
                                  .remove(media.id, mediaType: media.mediaType);
                            }
                          },
                          icon: Icon(isWatched
                              ? Icons.visibility_rounded
                              : Icons.visibility_outlined),
                          label: Text(
                              isWatched ? 'Assistido' : 'Marcar assistido'),
                        ),
                      ],
                    ),
                  if (!isBlocked && savedProgress != null) ...[
                    SizedBox(height: 16),
                    SizedBox(
                      width: 260,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.all(Radius.circular(2)),
                            child: LinearProgressIndicator(
                              value: savedProgress.progress,
                              minHeight: 3,
                              backgroundColor: SabuflixTheme.of(context).border,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  SabuflixTheme.of(context).accent),
                            ),
                          ),
                          SizedBox(height: 7),
                          Text(
                            '${savedProgress.subtitleLabel} · ${savedProgress.remainingLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SabuflixTheme.of(context).caption(
                                fontSize: 12,
                                color: SabuflixTheme.of(context).textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 24),
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
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Text(g,
                                  style: SabuflixTheme.of(context).body(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: SabuflixTheme.of(context)
                                          .textPrimary)),
                            ),
                          )
                          .toList(),
                    ),
                    SizedBox(height: 24),
                  ],
                  if (!isBlocked &&
                      (media.mediaType == 'tv' &&
                          _availableSeasons.isNotEmpty)) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Episódios',
                            style:
                                SabuflixTheme.of(context).title(fontSize: 19)),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: SabuflixTheme.of(context).secondaryFill,
                            borderRadius: SabuflixTheme.radiusSm,
                            border: Border.all(
                                color: SabuflixTheme.of(context).border),
                          ),
                          child: DropdownButton<int>(
                            value: _seasonNumber,
                            dropdownColor: SabuflixTheme.of(context).surface,
                            style: SabuflixTheme.of(context).body(
                                color: SabuflixTheme.of(context).textPrimary,
                                fontWeight: FontWeight.bold),
                            underline: SizedBox(),
                            icon: Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Icon(Icons.arrow_drop_down,
                                  color: SabuflixTheme.of(context).accent),
                            ),
                            items: _availableSeasons.map((season) {
                              return DropdownMenuItem<int>(
                                value: season,
                                child: Text('Temporada $season'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null && value != _seasonNumber) {
                                _onSeasonChanged(value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14),
                    if (_loadingEpisodes || _loadingDetails)
                      SizedBox(
                        height: 150,
                        child: Center(
                            child: CircularProgressIndicator(
                                color: SabuflixTheme.of(context).accent)),
                      )
                    else if (_episodes.isEmpty)
                      Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                              'Nenhum episódio disponível nesta temporada.',
                              style: SabuflixTheme.of(context).body()))
                    else
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _episodes.length,
                          physics: BouncingScrollPhysics(),
                          itemBuilder: (context, index) {
                            final ep = _episodes[index];
                            final stillPath = ep['still_path'];
                            final int epNum =
                                (ep['episode_number'] as num?)?.toInt() ??
                                    (index + 1);
                            final String epName =
                                (ep['name'] ?? 'Episódio $epNum').toString();
                            final fullStillPath = stillPath != null
                                ? 'https://image.tmdb.org/t/p/w300$stillPath'
                                : media.fullBackdropPath;

                            return GestureDetector(
                              onTap: () => _showStreamSelector(
                                season: _seasonNumber,
                                episode: epNum,
                                episodeTitle: epName,
                              ),
                              child: Container(
                                width: 200,
                                margin: EdgeInsets.only(right: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: SabuflixTheme.radiusMd,
                                      child: AspectRatio(
                                        aspectRatio: 16 / 9,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            CachedNetworkImage(
                                              imageUrl: fullStillPath,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) =>
                                                  Container(
                                                      color: SabuflixTheme.of(
                                                              context)
                                                          .surface),
                                              errorWidget: (context, url,
                                                      err) =>
                                                  Container(
                                                      color: SabuflixTheme.of(
                                                              context)
                                                          .surface),
                                            ),
                                            Center(
                                              child: Container(
                                                padding: EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.5),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                    Icons.play_arrow_rounded,
                                                    color: Colors.white,
                                                    size: 24),
                                              ),
                                            ),
                                            Positioned(
                                              right: 6,
                                              bottom: 6,
                                              child: _EpisodeDownloadBadge(
                                                mediaId: media.id,
                                                season: _seasonNumber,
                                                episode: epNum,
                                                onStart: () =>
                                                    _showStreamSelector(
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
                                    SizedBox(height: 8),
                                    Text(
                                      '$epNum. $epName',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: SabuflixTheme.of(context).body(
                                          color: SabuflixTheme.of(context)
                                              .textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    if (ep['runtime'] != null)
                                      Text(
                                        '${ep['runtime']} min',
                                        style: SabuflixTheme.of(context).body(
                                            color: SabuflixTheme.of(context)
                                                .textMuted,
                                            fontSize: 11),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    SizedBox(height: 32),
                  ],
                  Text('Sinopse',
                      style: SabuflixTheme.of(context).title(fontSize: 19)),
                  SizedBox(height: 10),
                  Text(
                    media.overview != null && media.overview!.isNotEmpty
                        ? media.overview!
                        : 'Nenhuma sinopse disponível em português.',
                    style: SabuflixTheme.of(context)
                        .body(fontSize: 15, height: 1.6),
                  ),
                  SizedBox(height: 32),
                  if (_cast.isNotEmpty) ...[
                    Text('Elenco Principal',
                        style: SabuflixTheme.of(context).title(fontSize: 19)),
                    SizedBox(height: 14),
                    SizedBox(
                      height: 145,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _cast.length,
                        itemBuilder: (context, index) {
                          final actor = _cast[index];
                          return Container(
                            width: 95,
                            margin: EdgeInsets.only(right: 16),
                            child: Column(
                              children: [
                                ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: actor.fullProfilePath,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, err) =>
                                        Container(
                                      color: SabuflixTheme.of(context).surface,
                                      child: Icon(Icons.person,
                                          color: SabuflixTheme.of(context)
                                              .textMuted),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  actor.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: SabuflixTheme.of(context).body(
                                      color:
                                          SabuflixTheme.of(context).textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  actor.character,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: SabuflixTheme.of(context).body(
                                      color:
                                          SabuflixTheme.of(context).textMuted,
                                      fontSize: 10),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 32),
                  ],
                  if (_similar.isNotEmpty) ...[
                    MediaRow(
                        title: 'Títulos Semelhantes', mediaItems: _similar),
                    SizedBox(height: 40),
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
              label = item.totalBytes > 0
                  ? '${(item.progress * 100).round()}%'
                  : 'Baixando';
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

        return OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon,
              color: isDone ? SabuflixTheme.of(context).success : null),
          label: Text(label),
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

        IconData icon = Icons.download_rounded;
        Color color = Colors.white;
        VoidCallback? onTap = onStart;

        if (item != null) {
          switch (item.status) {
            case DownloadStatus.completed:
              icon = Icons.check_rounded;
              color = SabuflixTheme.of(context).success;
              onTap = null;
              break;
            case DownloadStatus.downloading:
            case DownloadStatus.queued:
              icon = Icons.downloading_rounded;
              color = SabuflixTheme.of(context).accent;
              onTap = () => downloads.pause(item.id);
              break;
            case DownloadStatus.paused:
              icon = Icons.pause_rounded;
              color = SabuflixTheme.of(context).accent;
              onTap = () => downloads.resume(item.id);
              break;
            case DownloadStatus.failed:
              icon = Icons.refresh_rounded;
              color = Color(0xFFFF453A);
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
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22), width: 0.8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
        );
      },
    );
  }
}
