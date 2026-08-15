import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/sabuflix_theme.dart';
import '../providers/playlist_provider.dart';
import '../widgets/glass_container.dart';
import '../widgets/media_card.dart';
import '../models/playlist.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({Key? key}) : super(key: key);

  void _showCreatePlaylistDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          borderRadius: SabuflixTheme.radiusLg,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nova Playlist', style: SabuflixTheme.headline(fontSize: 22)),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nome da Playlist',
                  labelStyle: const TextStyle(color: SabuflixTheme.textSecondary),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: SabuflixTheme.radiusSm,
                    borderSide: const BorderSide(color: SabuflixTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: SabuflixTheme.radiusSm,
                    borderSide: const BorderSide(color: SabuflixTheme.accent),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar', style: TextStyle(color: SabuflixTheme.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        Provider.of<PlaylistProvider>(context, listen: false).createPlaylist(controller.text.trim());
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: SabuflixTheme.accent),
                    child: const Text('Criar', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SabuflixTheme.background,
      appBar: AppBar(
        title: Text('Minhas Playlists', style: SabuflixTheme.headline(fontSize: 20)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: SabuflixTheme.textPrimary),
            onPressed: () => _showCreatePlaylistDialog(context),
          ),
        ],
      ),
      body: Consumer<PlaylistProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: SabuflixTheme.accent));
          }
          
          if (provider.playlists.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.featured_play_list_outlined, size: 80, color: SabuflixTheme.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 24),
                  Text('Nenhuma playlist criada', style: SabuflixTheme.headline(fontSize: 20, color: SabuflixTheme.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showCreatePlaylistDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SabuflixTheme.accent,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Criar Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(context).size.width < 800 ? 118 : 24,
            ),
            itemCount: provider.playlists.length,
            itemBuilder: (context, index) {
              final playlist = provider.playlists[index];
              return _PlaylistCard(playlist: playlist);
            },
          );
        },
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  const _PlaylistCard({required this.playlist});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(playlist.name, style: SabuflixTheme.headline(fontSize: 20)),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                onPressed: () {
                  Provider.of<PlaylistProvider>(context, listen: false).deletePlaylist(playlist.id);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (playlist.items.isEmpty)
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: SabuflixTheme.surface,
                borderRadius: SabuflixTheme.radiusMd,
              ),
              alignment: Alignment.center,
              child: Text('Playlist vazia', style: SabuflixTheme.body(color: SabuflixTheme.textMuted)),
            )
          else
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: playlist.items.length,
                itemBuilder: (context, index) {
                  final media = playlist.items[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Stack(
                      children: [
                        SizedBox(
                          width: 120,
                          child: MediaCard(media: media),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              Provider.of<PlaylistProvider>(context, listen: false)
                                  .removeMediaFromPlaylist(playlist.id, media.id);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
