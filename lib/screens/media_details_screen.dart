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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final details = await _tmdbService.fetchMediaDetails(widget.media.id, widget.media.mediaType);
      final castList = await _tmdbService.fetchCast(widget.media.id, widget.media.mediaType);
      final similarList = await _tmdbService.fetchSimilar(widget.media.id, widget.media.mediaType);

      setState(() {
        _detailedMedia = details ?? widget.media;
        _cast = castList;
        _similar = similarList;
      });
    } catch (e) {
      print('Error loading media details: $e');
      _detailedMedia = widget.media;
    } finally {
      setState(() => _isLoading = false);
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
          // App Bar with backdrop
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

                  // Play Button overlay
                  Center(
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor: SabuflixTheme.terracotta,
                      child: IconButton(
                        iconSize: 46,
                        icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VideoPlayerScreen(media: media),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Details content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Favorite button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          media.title,
                          style: SabuflixTheme.serifHeader(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: SabuflixTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          favoritesProvider.toggleFavorite(media);
                        },
                        icon: Icon(
                          isFav ? Icons.bookmark : Icons.bookmark_border,
                          color: isFav ? SabuflixTheme.terracotta : SabuflixTheme.textSecondary,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Badges & Metadata
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: SabuflixTheme.amber, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            media.formattedRating,
                            style: SabuflixTheme.sansBody(color: SabuflixTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      Text(media.formattedYear, style: SabuflixTheme.sansBody(color: SabuflixTheme.textSecondary, fontSize: 14)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: media.mediaType == 'tv' ? const Color(0xFF10B981) : SabuflixTheme.terracotta,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          media.mediaType == 'tv' ? 'SÉRIE' : 'FILME',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          border: Border.all(color: SabuflixTheme.border),
                          borderRadius: BorderRadius.circular(4),
                          color: SabuflixTheme.surface,
                        ),
                        child: Text(
                          'HDR 10+ / 4K',
                          style: SabuflixTheme.sansBody(color: SabuflixTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Play Main Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoPlayerScreen(media: media),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SabuflixTheme.terracotta,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30), // Apple TV Pill
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 30, color: Colors.white),
                      label: Text(
                        'Assistir Agora no Sabuflix',
                        style: SabuflixTheme.sansBody(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Genres tags
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
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: SabuflixTheme.border),
                              ),
                              child: Text(
                                g,
                                style: SabuflixTheme.sansBody(color: SabuflixTheme.textSecondary, fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Overview / Synopsis
                  Text(
                    'Sinopse',
                    style: SabuflixTheme.serifHeader(fontSize: 22, color: SabuflixTheme.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    media.overview != null && media.overview!.isNotEmpty
                        ? media.overview!
                        : 'Nenhuma sinopse disponível em português.',
                    style: SabuflixTheme.sansBody(
                      color: SabuflixTheme.textSecondary,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Cast Section
                  if (_cast.isNotEmpty) ...[
                    Text(
                      'Elenco Principal',
                      style: SabuflixTheme.serifHeader(fontSize: 22, color: SabuflixTheme.textPrimary),
                    ),
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
                                  style: SabuflixTheme.sansBody(color: SabuflixTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  actor.character,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: SabuflixTheme.sansBody(color: SabuflixTheme.textMuted, fontSize: 10),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Recommended / Similar Titles
                  if (_similar.isNotEmpty) ...[
                    MediaRow(
                      title: 'Títulos Semelhantes',
                      mediaItems: _similar,
                    ),
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
