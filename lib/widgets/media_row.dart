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
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
          child: Text(
            title,
            style: SabuflixTheme.title(fontSize: 19, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: 232,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: mediaItems.length,
            itemBuilder: (context, index) {
              final item = mediaItems[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: MediaCard(media: item),
              );
            },
          ),
        ),
      ],
    );
  }
}
