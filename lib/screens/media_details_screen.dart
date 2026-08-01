import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../models/cast_member.dart';
import '../models/download_item.dart';
import '../models/playback_source.dart';
import '../theme/sabuflix_theme.dart';
import '../services/tmdb_service.dart';
import '../services/download_service.dart';
import '../providers/favorites_provider.dart';
import '../utils/app_route.dart';
import '../widgets/media_row.dart';
import '../widgets/glass_container.dart';
import '../widgets/source_tag.dart';
import '../services/froststream_service.dart';
import '../providers/profile_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/download_provider.dart';
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

  /// Plays the local copy when the title is already downloaded, otherwise
  /// falls back to picking an online source.
  Future<void> _play({int? season, int? episode}) async {
    final media = _detailedMedia ?? widget.media;
    final downloads = context.read<DownloadProvider>();
    final localPath = await downloads.localPathFor(media.id, season: season, episode: episode);

    if (!mounted) return;
    if (localPath != null) {
      Navigator.push(
        context,
        glassRoute(VideoPlayerScreen(
          media: media,
          videoUrl: localPath,
          source: PlaybackSource.download,
        )),
      );
      return;
    }
    await _showStreamSelector(season: season, episode: episode);
  }

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
                    forDownload ? 'Baixar — Selecione uma Fonte' : 'Selecione uma Fonte',
                    style: SabuflixTheme.title(fontSize: 20),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    forDownload
                        ? 'O arquivo fica salvo no dispositivo e pode ser assistido sem internet.'
                        : 'Toque para assistir online ou use o ícone de download para salvar.',
                    style: SabuflixTheme.body(fontSize: 12, color: SabuflixTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount: streams.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final s = streams[i];
                        final url = s['url'] as String?;
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Baixar',
                                icon: const Icon(Icons.download_rounded, color: SabuflixTheme.textPrimary, size: 26),
                                onPressed: url == null || url.isEmpty
                                    ? null
                                    : () {
                                        Navigator.pop(ctx);
                                        _startDownload(
                                          media: media,
                                          url: url,
                                          sourceName: s['name']?.toString() ?? 'Fonte',
                                          quality: s['title']?.toString() ?? '',
                                          season: season,
                                          episode: episode,
                                        );
                                      },
                              ),
                              const SizedBox(width: 2),
                              IconButton(
                                tooltip: 'Assistir agora',
                                icon: const Icon(Icons.play_circle_fill_rounded, color: SabuflixTheme.accent, size: 32),
                                onPressed: url == null || url.isEmpty
                                    ? null
                                    : () {
                                        Navigator.pop(ctx);
                                        Navigator.push(
                                          context,
                                          glassRoute(VideoPlayerScreen(
                                            media: media,
                                            videoUrl: url,
                                            source: PlaybackSource.stream,
                                          )),
                                        );
                                      },
                              ),
                            ],
                          ),
                          onTap: url == null || url.isEmpty
                              ? null
                              : () {
                                  Navigator.pop(ctx);
                                  if (forDownload) {
                                    _startDownload(
                                      media: media,
                                      url: url,
                                      sourceName: s['name']?.toString() ?? 'Fonte',
                                      quality: s['title']?.toString() ?? '',
                                      season: season,
                                      episode: episode,
                                    );
                                  } else {
                                    Navigator.push(
                                      context,
                                      glassRoute(VideoPlayerScreen(
                                        media: media,
                                        videoUrl: url,
                                        source: PlaybackSource.stream,
                                      )),
                                    );
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

  Future<void> _startDownload({
    required MediaItem media,
    required String url,
    required String sourceName,
    required String quality,
    int? season,
    int? episode,
  }) async {
    final downloads = context.read<DownloadProvider>();
    final added = await downloads.addDownload(
      media: media,
      url: url,
      sourceName: sourceName,
      quality: quality,
      season: season,
      episode: episode,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(added
            ? 'Download iniciado — acompanhe em Downloads.'
            : 'Este título já está na sua lista de downloads.'),
      ),
    );
  }

  /// Offline copy actions for the currently selected movie/episode.
  Future<void> _showDownloadOptions(DownloadItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        padding: const EdgeInsets.all(24),
        blur: 40,
        fillOpacity: 0.4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SourceTag(source: PlaybackSource.download),
                const SizedBox(width: 10),
                Text(item.sizeLabel, style: SabuflixTheme.caption(fontSize: 12, color: SabuflixTheme.textMuted)),
              ],
            ),
            const SizedBox(height: 18),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_circle_fill_rounded, color: SabuflixTheme.success, size: 28),
              title: Text('Assistir offline', style: SabuflixTheme.body(color: Colors.white, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, 'play'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cloud_outlined, color: SabuflixTheme.accent, size: 26),
              title: Text('Assistir online', style: SabuflixTheme.body(color: Colors.white, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, 'stream'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF453A), size: 26),
              title: Text('Remover download', style: SabuflixTheme.body(color: Colors.white, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case 'play':
        final path = await DownloadService.filePath(item.fileName);
        if (!mounted) return;
        Navigator.push(
          context,
          glassRoute(VideoPlayerScreen(
            media: item.media,
            videoUrl: path,
            source: PlaybackSource.download,
          )),
        );
        break;
      case 'stream':
        await _showStreamSelector(season: item.season, episode: item.episode);
        break;
      case 'remove':
        await context.read<DownloadProvider>().remove(item.id);
        break;
    }
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

  /// The download affordance next to "Assistir": starts a download, or
  /// opens the offline options when there already is a local copy.
  Widget _buildDownloadAction(MediaItem media, DownloadItem? download, bool isSeries) {
    final IconData icon;
    final Color color;
    if (download == null) {
      icon = Icons.download_rounded;
      color = SabuflixTheme.textPrimary;
    } else if (download.isCompleted) {
      icon = Icons.download_done_rounded;
      color = SabuflixTheme.success;
    } else if (download.status == DownloadStatus.failed) {
      icon = Icons.error_outline_rounded;
      color = const Color(0xFFFF453A);
    } else {
      icon = Icons.downloading_rounded;
      color = SabuflixTheme.accent;
    }

    return GlassContainer(
      borderRadius: SabuflixTheme.radiusPill,
      blur: 28,
      fillOpacity: 0.3,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: SabuflixTheme.radiusPill,
          onTap: () {
            if (download != null && download.isCompleted) {
              _showDownloadOptions(download);
            } else if (download != null) {
              // Already queued — the Downloads tab owns its lifecycle.
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${download.statusLabel} · veja em Downloads')),
              );
            } else if (isSeries) {
              _showStreamSelector(season: _seasonNumber, episode: 1, forDownload: true);
            } else {
              _showStreamSelector(forDownload: true);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
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
    final downloadProvider = Provider.of<DownloadProvider>(context);
    final isSeries = media.mediaType == 'tv';
    final primaryDownload = downloadProvider.findFor(
      media.id,
      season: isSeries ? _seasonNumber : null,
      episode: isSeries ? 1 : null,
    );
    final playsOffline = primaryDownload?.isCompleted ?? false;
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
                              if (isSeries) {
                                _play(season: _seasonNumber, episode: 1);
                              } else {
                                _play();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: const StadiumBorder(),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 26, color: Colors.white),
                            label: Text(
                              isSeries ? 'Assistir S$_seasonNumber:E1' : 'Assistir Agora',
                              style: SabuflixTheme.body(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ),
                        _buildDownloadAction(media, primaryDownload, isSeries),
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
                  if (!isBlocked && primaryDownload != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        SourceTag(
                          source: playsOffline ? PlaybackSource.download : PlaybackSource.stream,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            playsOffline
                                ? 'Disponível offline · ${primaryDownload.sizeLabel}'
                                : '${primaryDownload.statusLabel} · ${primaryDownload.sizeLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SabuflixTheme.caption(fontSize: 12, color: SabuflixTheme.textMuted),
                          ),
                        ),
                      ],
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
                          final epDownload = downloadProvider.findFor(media.id, season: _seasonNumber, episode: epNum);

                          return GestureDetector(
                            onTap: () => _play(season: _seasonNumber, episode: epNum),
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
                                            child: _EpisodeDownloadButton(
                                              download: epDownload,
                                              onTap: () => epDownload != null && epDownload.isCompleted
                                                  ? _showDownloadOptions(epDownload)
                                                  : _showStreamSelector(
                                                      season: _seasonNumber,
                                                      episode: epNum,
                                                      forDownload: true,
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
                                  Row(
                                    children: [
                                      if (ep['runtime'] != null)
                                        Text(
                                          '${ep['runtime']} min',
                                          style: SabuflixTheme.body(color: SabuflixTheme.textMuted, fontSize: 11),
                                        ),
                                      if (epDownload != null && epDownload.isCompleted) ...[
                                        if (ep['runtime'] != null)
                                          Text(' · ', style: SabuflixTheme.body(color: SabuflixTheme.textMuted, fontSize: 11)),
                                        Text(
                                          'Offline',
                                          style: SabuflixTheme.body(color: SabuflixTheme.success, fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ],
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

/// Corner affordance on an episode card reflecting its download state.
class _EpisodeDownloadButton extends StatelessWidget {
  final DownloadItem? download;
  final VoidCallback onTap;

  const _EpisodeDownloadButton({required this.download, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final item = download;
    IconData icon = Icons.download_rounded;
    Color color = Colors.white;

    if (item != null) {
      if (item.isCompleted) {
        icon = Icons.download_done_rounded;
        color = SabuflixTheme.success;
      } else if (item.status == DownloadStatus.failed) {
        icon = Icons.error_outline_rounded;
        color = const Color(0xFFFF453A);
      } else {
        icon = Icons.downloading_rounded;
        color = SabuflixTheme.accent;
      }
    }

    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
