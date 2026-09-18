import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/media_item.dart';
import '../providers/settings_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../widgets/media_card.dart';

/// Full grid for a shelf, opened from "Ver tudo".
class BrowseScreen extends StatelessWidget {
  final String title;
  final List<MediaItem> items;

  const BrowseScreen({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final colors = SabuflixTheme.of(context);
    final settings = context.watch<SettingsProvider>();
    final width = MediaQuery.sizeOf(context).width;
    final columns = (width / 170).floor().clamp(2, 8);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(title, style: colors.title(fontSize: 20)),
      ),
      body: GridView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: settings.compactPosters ? 0.72 : 0.62,
          crossAxisSpacing: 14,
          mainAxisSpacing: 16,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) => MediaCard(media: items[index]),
      ),
    );
  }
}
