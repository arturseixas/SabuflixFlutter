import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/watch_history_entry.dart';
import '../providers/favorites_provider.dart';
import '../providers/watch_history_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_route.dart';
import '../widgets/media_card.dart';
import 'media_details_screen.dart';

class MyListScreen extends StatefulWidget {
  const MyListScreen({Key? key}) : super(key: key);

  @override
  State<MyListScreen> createState() => _MyListScreenState();
}

class _MyListScreenState extends State<MyListScreen> {
  int _tabIndex = 0;

  Future<void> _confirmClearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SabuflixTheme.surface,
        title: Text('Limpar histórico?', style: SabuflixTheme.title(fontSize: 18)),
        content: Text(
          'Isso vai apagar todo o seu histórico de reprodução deste perfil.',
          style: SabuflixTheme.body(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: SabuflixTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      Provider.of<WatchHistoryProvider>(context, listen: false).clearHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final historyProvider = Provider.of<WatchHistoryProvider>(context);

    return Scaffold(
      backgroundColor: SabuflixTheme.background,
      appBar: AppBar(
        backgroundColor: SabuflixTheme.background,
        title: Text('Minha Lista', style: SabuflixTheme.title(fontSize: 20, fontWeight: FontWeight.w700)),
        actions: [
          if (_tabIndex == 1 && historyProvider.history.isNotEmpty)
            IconButton(
              tooltip: 'Limpar histórico',
              icon: const Icon(Icons.delete_outline_rounded, color: SabuflixTheme.textSecondary),
              onPressed: () => _confirmClearHistory(context),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _SegmentedToggle(
              index: _tabIndex,
              labels: const ['Favoritos', 'Histórico'],
              onChanged: (i) => setState(() => _tabIndex = i),
            ),
          ),
        ),
      ),
      body: _tabIndex == 0 ? _buildFavorites(favoritesProvider) : _buildHistory(historyProvider),
    );
  }

  Widget _buildFavorites(FavoritesProvider favoritesProvider) {
    final favorites = favoritesProvider.favorites;
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = (screenWidth / 160).floor().clamp(2, 6);

    if (favoritesProvider.isLoading) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(color: SabuflixTheme.textPrimary, strokeWidth: 2.5),
        ),
      );
    }

    if (favorites.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bookmark_border_rounded, size: 52, color: SabuflixTheme.textMuted),
              const SizedBox(height: 18),
              Text('Sua lista está vazia', style: SabuflixTheme.title(fontSize: 17)),
              const SizedBox(height: 8),
              Text(
                'Adicione filmes e séries para assistir mais tarde.',
                textAlign: TextAlign.center,
                style: SabuflixTheme.body(fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final item = favorites[index];
        return MediaCard(media: item);
      },
    );
  }

  Widget _buildHistory(WatchHistoryProvider historyProvider) {
    if (historyProvider.isLoading) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(color: SabuflixTheme.textPrimary, strokeWidth: 2.5),
        ),
      );
    }

    final history = historyProvider.history;

    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.history_rounded, size: 52, color: SabuflixTheme.textMuted),
              const SizedBox(height: 18),
              Text('Nenhum histórico ainda', style: SabuflixTheme.title(fontSize: 17)),
              const SizedBox(height: 8),
              Text(
                'O que você assistir vai aparecer aqui.',
                textAlign: TextAlign.center,
                style: SabuflixTheme.body(fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _HistoryTile(entry: history[index]),
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const _SegmentedToggle({required this.index, required this.labels, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SabuflixTheme.surface,
        borderRadius: SabuflixTheme.radiusPill,
      ),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: SabuflixTheme.durationFast,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: index == i ? SabuflixTheme.accent.withValues(alpha: 0.18) : Colors.transparent,
                    borderRadius: SabuflixTheme.radiusPill,
                    border: index == i ? Border.all(color: SabuflixTheme.accent.withValues(alpha: 0.4)) : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: SabuflixTheme.body(
                      fontSize: 13,
                      fontWeight: index == i ? FontWeight.w700 : FontWeight.w500,
                      color: index == i ? SabuflixTheme.accent : SabuflixTheme.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final WatchHistoryEntry entry;

  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, glassRoute(MediaDetailsScreen(media: entry.media)));
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: SabuflixTheme.radiusSm,
            child: SizedBox(
              width: 120,
              height: 68,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: entry.media.fullBackdropPath,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: SabuflixTheme.surface),
                    errorWidget: (context, url, error) => Container(color: SabuflixTheme.surface),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      value: entry.progress,
                      minHeight: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      valueColor: const AlwaysStoppedAnimation<Color>(SabuflixTheme.accent),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.media.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SabuflixTheme.body(fontSize: 14, fontWeight: FontWeight.w600, color: SabuflixTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (entry.episodeLabel != null) entry.episodeLabel!,
                    entry.isFinished ? 'Concluído' : '${(entry.progress * 100).round()}% assistido',
                  ].join(' • '),
                  style: SabuflixTheme.caption(fontSize: 12, color: SabuflixTheme.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: SabuflixTheme.textMuted, size: 20),
            onPressed: () {
              Provider.of<WatchHistoryProvider>(context, listen: false).removeEntry(entry.media.id);
            },
          ),
        ],
      ),
    );
  }
}
