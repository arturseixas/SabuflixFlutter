import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../theme/sabuflix_theme.dart';
import 'media_card.dart';

class MediaRow extends StatelessWidget {
  final String title;
  final List<MediaItem> mediaItems;

  const MediaRow({
    Key? key,
    required this.title,
    required this.mediaItems,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (mediaItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 15),
          child: Text(
            title,
            style: SabuflixTheme.headline(fontSize: 22),
          ),
        ),
        SizedBox(
          height: 274,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: mediaItems.length,
            itemBuilder: (context, index) {
              final item = mediaItems[index];
              final width = index == 0 ? 168.0 : 148.0;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: MediaCard(media: item, width: width),
              );
            },
          ),
        ),
      ],
    );
  }
}
