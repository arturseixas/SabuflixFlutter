import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../models/cast_member.dart';
import '../theme/sabuflix_theme.dart';
import '../services/tmdb_service.dart';
import '../providers/favorites_provider.dart';
import '../widgets/media_row.dart';
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

      if (!mounted) return;
      setState(() {
        _detailedMedia = details ?? widget.media;
        _cast = castList;
        _similar = similarList;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _detailedMedia = widget.media);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = _detailedMedia ?? widget.media;
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final isFav = favoritesProvider.isFavorite(media.id);

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
              child: CircleAvatar(
                backgroundColor: SabuflixTheme.background.withValues(alpha: 0.7),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
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
                  Center(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => VideoPlayerScreen(media: media)),
                          );
                        },
                        child: Container(
                          width: 76,
                          height: 76,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 42),
                        ),
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
                        child: Text(
                          media.title,
                          style: SabuflixTheme.headline(fontSize: 28, fontWeight: FontWeight.w800),
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
                  const SizedBox(height: 12),

                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: SabuflixTheme.gold, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            media.formattedRating,
                            style: SabuflixTheme.body(color: SabuflixTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ],
                      ),
                      Text(media.formattedYear, style: SabuflixTheme.body(fontSize: 14)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: media.mediaType == 'tv' ? SabuflixTheme.tvBadge : SabuflixTheme.movieBadge,
                          borderRadius: SabuflixTheme.radiusSm,
                        ),
                        child: Text(
                          media.mediaType == 'tv' ? 'SÉRIE' : 'FILME',
                          style: SabuflixTheme.label(fontSize: 10, color: Colors.white),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: SabuflixTheme.tagDecoration(),
                        child: Text(
                          '4K HDR',
                          style: SabuflixTheme.label(fontSize: 10, color: SabuflixTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => VideoPlayerScreen(media: media)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SabuflixTheme.textPrimary,
                        foregroundColor: SabuflixTheme.background,
                        shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusSm),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 26, color: SabuflixTheme.background),
                      label: Text(
                        'Assistir Agora',
                        style: SabuflixTheme.body(fontSize: 16, fontWeight: FontWeight.w700, color: SabuflixTheme.background),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (media.genres != null && media.genres!.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: media.genres!
                          .map(
                            (g) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: SabuflixTheme.surface,
                                borderRadius: SabuflixTheme.radiusPill,
                                border: Border.all(color: SabuflixTheme.border),
                              ),
                              child: Text(g, style: SabuflixTheme.body(fontSize: 12)),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 24),
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
