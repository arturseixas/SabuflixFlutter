import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../models/cast_member.dart';
import '../theme/sabuflix_theme.dart';
import '../services/tmdb_service.dart';
import '../widgets/media_row.dart';
import '../widgets/glass_container.dart';
import '../widgets/stream_selector_sheet.dart';
import '../widgets/playlist_selector_sheet.dart';
import '../providers/profile_provider.dart';

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

  Future<void> _showStreamSelector({int? season, int? episode}) async {
    final media = _detailedMedia ?? widget.media;
    await showStreamSelectorSheet(context, media: media, season: season, episode: episode);
  }

  int _getAgeValue(String? rating) {
    if (rating == null || rating.isEmpty || rating == 'Livre' || rating == 'L') return 0;
    return int.tryParse(rating.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final media = _detailedMedia ?? widget.media;
    final profileProvider = Provider.of<ProfileProvider>(context);
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
                  media.fullLogoPath != null
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
                        GlassContainer(
                          borderRadius: SabuflixTheme.radiusPill,
                          blur: 28,
                          fillOpacity: 0.3,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: SabuflixTheme.radiusPill,
                              onTap: () => showPlaylistSelectorSheet(context, media),
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
