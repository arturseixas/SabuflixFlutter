import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/sabuflix_theme.dart';
import '../providers/playlist_provider.dart';
import '../widgets/media_card.dart';
import '../models/playlist.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({Key? key}) : super(key: key);

  void _showCreatePlaylistDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: SabuflixTheme.elevated,
        shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nova playlist',
                  style: SabuflixTheme.headline(fontSize: 24)),
              const SizedBox(height: 24),
              Text('Nome da playlist',
                  style:
                      SabuflixTheme.label(color: SabuflixTheme.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                style: SabuflixTheme.body(color: SabuflixTheme.textPrimary),
                decoration:
                    const InputDecoration(hintText: 'Ex.: Noite de cinema'),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar',
                        style: TextStyle(color: SabuflixTheme.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        Provider.of<PlaylistProvider>(context, listen: false)
                            .createPlaylist(controller.text.trim());
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Criar'),
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
        title: Text('Playlists', style: SabuflixTheme.headline(fontSize: 24)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon:
                const Icon(Icons.add_rounded, color: SabuflixTheme.textPrimary),
            onPressed: () => _showCreatePlaylistDialog(context),
          ),
        ],
      ),
      body: Consumer<PlaylistProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
                child: CircularProgressIndicator(color: SabuflixTheme.accent));
          }

          if (provider.playlists.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: SabuflixTheme.surface,
                      borderRadius: SabuflixTheme.radiusLg,
                      border: Border.all(color: SabuflixTheme.border),
                    ),
                    child: const Icon(Icons.featured_play_list_outlined,
                        size: 32, color: SabuflixTheme.textMuted),
                  ),
                  const SizedBox(height: 24),
                  Text('Crie sua primeira playlist',
                      style: SabuflixTheme.headline(fontSize: 22)),
                  const SizedBox(height: 10),
                  Text('Organize filmes e séries para cada momento.',
                      style: SabuflixTheme.body(fontSize: 14)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _showCreatePlaylistDialog(context),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Criar playlist'),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(playlist.name,
                      style: SabuflixTheme.headline(fontSize: 22)),
                  const SizedBox(height: 3),
                  Text(
                    '${playlist.items.length} ${playlist.items.length == 1 ? 'título' : 'títulos'}',
                    style:
                        SabuflixTheme.caption(color: SabuflixTheme.textMuted),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: SabuflixTheme.textMuted, size: 20),
                onPressed: () {
                  Provider.of<PlaylistProvider>(context, listen: false)
                      .deletePlaylist(playlist.id);
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
                borderRadius: SabuflixTheme.radiusLg,
                border: Border.all(color: SabuflixTheme.border),
              ),
              alignment: Alignment.center,
              child: Text('Playlist vazia',
                  style: SabuflixTheme.body(color: SabuflixTheme.textMuted)),
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
                              Provider.of<PlaylistProvider>(context,
                                      listen: false)
                                  .removeMediaFromPlaylist(
                                      playlist.id, media.id);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 14),
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
