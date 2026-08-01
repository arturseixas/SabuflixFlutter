import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../providers/playlist_provider.dart';
import '../theme/sabuflix_theme.dart';
import 'glass_container.dart';

/// Lets the user add [media] to one of their playlists. Shared between the
/// details screen and the hero banner so both open the exact same picker.
void showPlaylistSelectorSheet(BuildContext context, MediaItem media) {
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
    },
  );
}
