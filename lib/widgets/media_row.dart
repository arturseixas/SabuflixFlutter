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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            children: [
              Text(
                '✳ ',
                style: TextStyle(
                  color: SabuflixTheme.terracotta,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: SabuflixTheme.serifHeader(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: SabuflixTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 232,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
