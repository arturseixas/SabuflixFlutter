import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../models/cast_member.dart';
import '../models/download_item.dart';
import '../theme/sabuflix_theme.dart';
import '../services/tmdb_service.dart';
import '../providers/favorites_provider.dart';
import '../utils/app_route.dart';
import '../widgets/media_row.dart';
import '../widgets/glass_container.dart';
import '../services/froststream_service.dart';
import '../providers/profile_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/downloads_provider.dart';
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
      if (widget.media.mediaType == 'tv' && details != null) {
         if (details.seasons != null && details.seasons!.isNotEmpty) {
           final validSeasons = details.seasons!.where((s) => s['season_number'] > 0).toList();
           if (validSeasons.isNotEmpty) sNum = validSeasons.first['season_number'];
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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _detailedMedia = widget.media);
    }
  }

  /// Shows the available sources for a title. In [forDownload] mode picking a
  /// source queues it for offline viewing instead of starting playback.
  Future<void> _showStreamSelector({int? season, int? episode, bool forDownload = false}) async {
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
                    forDownload ? 'Baixar — Selecione a Qualidade' : 'Selecione uma Fonte',
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
                              _enqueueDownload(media, s, season: season, episode: episode);
                            } else {
                              Navigator.push(context, glassRoute(VideoPlayerScreen(media: media, videoUrl: s['url'])));
                            }
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

  Future<void> _enqueueDownload(
    MediaItem media,
    Map<String, dynamic> stream, {
    int? season,
    int? episode,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final downloads = Provider.of<DownloadsProvider>(context, listen: false);

    final url = (stream['url'] ?? '').toString();
    if (url.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Esta fonte não fornece um link para download.')));
      return;
    }

    final added = await downloads.enqueue(
      media: media,
      url: url,
      sourceName: (stream['name'] ?? 'Fonte desconhecida').toString(),
      quality: (stream['title'] ?? '').toString(),
      season: season,
      episode: episode,
    );

    messenger.showSnackBar(SnackBar(
      content: Text(added
          ? 'Download iniciado — acompanhe na aba Downloads.'
          : 'Este título já está na sua lista de downloads.'),
    ));
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

  int _getAgeValue(String? rating) {
    if (rating == null || rating.isEmpty || rating == 'Livre' || rating == 'L') return 0;
    return int.tryParse(rating.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final media = _detailedMedia ?? widget.media;
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
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
                              if (media.mediaType == 'tv') {
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
                              media.mediaType == 'tv' ? 'Assistir S$_seasonNumber:E1' : 'Assistir Agora',
                              style: SabuflixTheme.body(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ),
                        Consumer<DownloadsProvider>(
                          builder: (context, downloads, child) {
                            final isTv = media.mediaType == 'tv';
                            final entry = downloads.itemFor(
                              media,
                              season: isTv ? _seasonNumber : null,
                              episode: isTv ? 1 : null,
                            );
                            final isDone = entry?.status == DownloadStatus.completed;
                            final inProgress = entry != null && entry.isActive;

                            return GlassContainer(
                              borderRadius: SabuflixTheme.radiusPill,
                              blur: 28,
                              fillOpacity: 0.3,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: SabuflixTheme.radiusPill,
                                  onTap: () {
                                    if (isDone) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Já disponível offline na aba Downloads.')),
                                      );
                                      return;
                                    }
                                    _showStreamSelector(
                                      season: isTv ? _seasonNumber : null,
                                      episode: isTv ? 1 : null,
                                      forDownload: true,
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Icon(
                                      isDone
                                          ? Icons.download_done_rounded
                                          : inProgress
                                              ? Icons.downloading_rounded
                                              : Icons.download_outlined,
                                      color: isDone || inProgress
                                          ? SabuflixTheme.accent
                                          : SabuflixTheme.textPrimary,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
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

                  if (!isBlocked && _episodes.isNotEmpty) ...[
                    Text('Episódios', style: SabuflixTheme.title(fontSize: 19)),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _episodes.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final ep = _episodes[index];
                          final stillPath = ep['still_path'];
                          final epNum = ep['episode_number'] ?? (index + 1);
                          final epName = ep['name'] ?? 'Episódio $epNum';
                          final fullStillPath = stillPath != null ? 'https://image.tmdb.org/t/p/w300$stillPath' : media.fullBackdropPath;

                          return GestureDetector(
                            onTap: () => _showStreamSelector(season: _seasonNumber, episode: epNum),
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
                                            top: 6,
                                            right: 6,
                                            child: Consumer<DownloadsProvider>(
                                              builder: (context, downloads, child) {
                                                final entry = downloads.itemFor(
                                                  media,
                                                  season: _seasonNumber,
                                                  episode: epNum,
                                                );
                                                final isDone = entry?.status == DownloadStatus.completed;
                                                final inProgress = entry != null && entry.isActive;

                                                return Material(
                                                  color: Colors.black.withValues(alpha: 0.55),
                                                  shape: const CircleBorder(),
                                                  child: InkWell(
                                                    customBorder: const CircleBorder(),
                                                    onTap: () {
                                                      if (isDone) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('Episódio já disponível offline.')),
                                                        );
                                                        return;
                                                      }
                                                      _showStreamSelector(
                                                        season: _seasonNumber,
                                                        episode: epNum,
                                                        forDownload: true,
                                                      );
                                                    },
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(6),
                                                      child: Icon(
                                                        isDone
                                                            ? Icons.download_done_rounded
                                                            : inProgress
                                                                ? Icons.downloading_rounded
                                                                : Icons.download_outlined,
                                                        size: 16,
                                                        color: isDone || inProgress ? SabuflixTheme.accent : Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
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
