import 'dart:ui';
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

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return GlassContainer(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          padding: const EdgeInsets.all(24),
          blur: 40,
          fillOpacity: 0.4,
          child: FutureBuilder<List<Map<String, dynamic>>>(
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
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    forDownload ? 'Baixar de qual fonte?' : 'Selecione uma Fonte',
                    style: SabuflixTheme.title(fontSize: 20),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount: streams.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final s = streams[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusMd),
                          tileColor: Colors.white.withValues(alpha: 0.08),
                          title: Text(s['name'] ?? 'Stream', style: SabuflixTheme.body(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 16)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              s['title'] ?? 'Qualidade desconhecida', 
                              style: SabuflixTheme.body(fontSize: 13, color: Colors.white70, height: 1.4),
                            ),
                          ),
                          trailing: Icon(
                            forDownload ? Icons.download_for_offline_rounded : Icons.play_circle_fill_rounded,
                            color: SabuflixTheme.accent,
                            size: 36,
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
      }
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

  void _showPlaylistsSelector(MediaItem media) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return GlassContainer(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          padding: const EdgeInsets.all(24),
          blur: 40,
          fillOpacity: 0.4,
          child: Consumer<PlaylistProvider>(
            builder: (context, provider, child) {
              if (provider.playlists.isEmpty) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Nenhuma Playlist', style: SabuflixTheme.title(fontSize: 20)),
                    const SizedBox(height: 16),
                    Text('Você ainda não tem playlists criadas.', style: SabuflixTheme.body(color: SabuflixTheme.textSecondary)),
                  ],
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Adicionar a qual Playlist?', style: SabuflixTheme.title(fontSize: 20)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount: provider.playlists.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final p = provider.playlists[i];
                        final isInPlaylist = p.items.any((item) => item.id == media.id);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusMd),
                          tileColor: Colors.white.withValues(alpha: 0.08),
                          title: Text(p.name, style: SabuflixTheme.body(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 16)),
                          trailing: Icon(isInPlaylist ? Icons.check_circle : Icons.add_circle_outline, color: SabuflixTheme.accent),
                          onTap: () {
                            if (!isInPlaylist) {
                              provider.addMediaToPlaylist(p.id, media);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Adicionado à ${p.name}')));
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
      }
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 600;

    final mediaAge = _getAgeValue(media.ageRating);
    final profileAge = _getAgeValue(profileProvider.currentProfile?.maxAgeRating);
    final isBlocked = mediaAge > profileAge;

    return Scaffold(
      backgroundColor: SabuflixTheme.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: SabuflixTheme.background,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
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
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
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
                                  constraints: const BoxConstraints(
                                    maxHeight: 75,
                                    maxWidth: 320,
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: media.fullLogoPath!,
                                    fit: BoxFit.contain,
                                    alignment: Alignment.centerLeft,
                                    errorWidget: (context, url, err) => Text(
                                      media.title,
                                      style: SabuflixTheme.headline(fontSize: 28),
                                    ),
                                  ),
                                ),
                              )
                            : Text(
                                media.title,
                                style: SabuflixTheme.headline(fontSize: 28),
                              ),
                      ),
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
                      const Icon(Icons.star_rounded, color: SabuflixTheme.gold, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        media.formattedRating,
                        style: SabuflixTheme.body(color: SabuflixTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(width: 10),
                      Text('·', style: SabuflixTheme.body(fontSize: 14, color: SabuflixTheme.textMuted)),
                      const SizedBox(width: 10),
                      Text(media.formattedYear, style: SabuflixTheme.body(fontSize: 14)),
                      if (media.ageRating != null) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.3),
                            borderRadius: SabuflixTheme.radiusSm,
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            media.ageRating!,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          width: isDesktop ? 220 : 180,
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: SabuflixTheme.radiusPill,
                            gradient: const LinearGradient(
                              colors: [SabuflixTheme.accent, SabuflixTheme.accentHover],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: SabuflixTheme.accent.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (savedProgress != null) {
                                resumeWatching(context, savedProgress);
                              } else if (media.mediaType == 'tv') {
                                _showStreamSelector(season: _seasonNumber, episode: 1);
                              } else {
                                _showStreamSelector();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: const StadiumBorder(),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 26, color: Colors.white),
                            label: Text(
                              savedProgress != null
                                  ? savedProgress.resumeLabel
                                  : (media.mediaType == 'tv' ? 'Assistir S$_seasonNumber:E1' : 'Assistir Agora'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SabuflixTheme.body(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ),
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
                        GlassContainer(
                          borderRadius: SabuflixTheme.radiusPill,
                          blur: 28,
                          fillOpacity: 0.3,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: SabuflixTheme.radiusPill,
                              onTap: () => _showPlaylistsSelector(media),
                              child: const Padding(
                                padding: EdgeInsets.all(14),
                                child: Icon(Icons.featured_play_list_outlined, color: SabuflixTheme.textPrimary, size: 22),
                              ),
                            ),
                          ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Episódios', style: SabuflixTheme.title(fontSize: 19)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: SabuflixTheme.radiusSm,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: DropdownButton<int>(
                            value: _seasonNumber,
                            dropdownColor: SabuflixTheme.surface,
                            style: SabuflixTheme.body(color: Colors.white, fontWeight: FontWeight.bold),
                            underline: const SizedBox(),
                            icon: const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Icon(Icons.arrow_drop_down, color: SabuflixTheme.accent),
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
                    const SizedBox(height: 14),
                    if (_episodes.isEmpty)
                      const SizedBox(
                        height: 150,
                        child: Center(child: CircularProgressIndicator(color: SabuflixTheme.accent)),
                      )
                    else
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _episodes.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final ep = _episodes[index];
                          final stillPath = ep['still_path'];
                          final int epNum = (ep['episode_number'] as num?)?.toInt() ?? (index + 1);
                          final String epName = (ep['name'] ?? 'Episódio $epNum').toString();
                          final fullStillPath = stillPath != null ? 'https://image.tmdb.org/t/p/w300$stillPath' : media.fullBackdropPath;

                          return GestureDetector(
                            onTap: () => _showStreamSelector(
                              season: _seasonNumber,
                              episode: epNum,
                              episodeTitle: epName,
                            ),
                            child: Container(
                              width: 200,
                              margin: const EdgeInsets.only(right: 16),
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
                                              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                                            ),
                                          ),
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
                                  const SizedBox(height: 8),
                                  Text(
                                    '$epNum. $epName',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: SabuflixTheme.body(color: SabuflixTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  if (ep['runtime'] != null)
                                    Text(
                                      '${ep['runtime']} min',
                                      style: SabuflixTheme.body(color: SabuflixTheme.textMuted, fontSize: 11),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  Text('Sinopse', style: SabuflixTheme.title(fontSize: 19)),
                  const SizedBox(height: 10),
                  Text(
                    media.overview != null && media.overview!.isNotEmpty
                        ? media.overview!
                        : 'Nenhuma sinopse disponível em português.',
                    style: SabuflixTheme.body(fontSize: 15, height: 1.6),
                  ),
                  const SizedBox(height: 32),

                  if (_cast.isNotEmpty) ...[
                    Text('Elenco Principal', style: SabuflixTheme.title(fontSize: 19)),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 145,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _cast.length,
                        itemBuilder: (context, index) {
                          final actor = _cast[index];
                          return Container(
                            width: 95,
                            margin: const EdgeInsets.only(right: 16),
                            child: Column(
                              children: [
                                ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: actor.fullProfilePath,
                                    width: 72,
                                    height: 72,
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
                                  style: SabuflixTheme.body(color: SabuflixTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  actor.character,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: SabuflixTheme.body(color: SabuflixTheme.textMuted, fontSize: 10),
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

        return GlassContainer(
          borderRadius: SabuflixTheme.radiusPill,
          blur: 28,
          fillOpacity: 0.3,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: SabuflixTheme.radiusPill,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 20, color: isDone ? SabuflixTheme.success : SabuflixTheme.textPrimary),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: SabuflixTheme.caption(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDone ? SabuflixTheme.success : SabuflixTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
