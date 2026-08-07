import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../providers/watch_history_provider.dart';
import '../services/tmdb_service.dart';
import 'media_row.dart';

/// "Porque você assistiu X" — built from the most recent thing watched,
/// matched on its first genre. Silent until there is something to build on.
class BecauseYouWatchedRow extends StatefulWidget {
  const BecauseYouWatchedRow({Key? key}) : super(key: key);

  @override
  State<BecauseYouWatchedRow> createState() => _BecauseYouWatchedRowState();
}

class _BecauseYouWatchedRowState extends State<BecauseYouWatchedRow> {
  final TMDBService _tmdbService = TMDBService();

  MediaItem? _seed;
  List<MediaItem> _suggestions = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final history = Provider.of<WatchHistoryProvider>(context);
    final latest = history.entries.isEmpty ? null : history.entries.first.media;

    // Only refetch when the title driving the row actually changes, not on
    // every progress checkpoint the provider notifies about. A rebuild is
    // already scheduled by the dependency change, so no setState here.
    if (latest?.id == _seed?.id) return;
    _seed = latest;
    _suggestions = [];
    if (latest != null) _loadFor(latest);
  }

  @override
  Widget build(BuildContext context) {
    if (_seed == null || _suggestions.isEmpty) return const SizedBox.shrink();

    return MediaRow(
      title: 'Porque você assistiu ${_seed!.title}',
      mediaItems: _suggestions,
    );
  }

  Future<void> _loadFor(MediaItem seed) async {
    if (seed.genreIds.isEmpty) return;

    final results = await _tmdbService.fetchByGenre(
      seed.genreIds.first,
      mediaType: seed.mediaType == 'tv' ? 'tv' : 'movie',
    );
    if (!mounted || seed.id != _seed?.id) return;

    setState(() {
      _suggestions = results.where((item) => item.id != seed.id).take(20).toList();
    });
  }
}
