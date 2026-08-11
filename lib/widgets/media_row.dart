import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../theme/sabuflix_theme.dart';
import '../tv/tv_metrics.dart';
import 'media_card.dart';

class MediaRow extends StatelessWidget {
  final String title;
  final List<MediaItem> mediaItems;

  /// Gives the first card of the first shelf the initial focus on a TV, so the
  /// remote has somewhere to start.
  final bool autofocusFirst;

  const MediaRow({
    Key? key,
    required this.title,
    required this.mediaItems,
    this.autofocusFirst = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (mediaItems.isEmpty) return const SizedBox.shrink();

    final metrics = TvMetrics.of(context);
    final spacing = metrics.isTv ? 12.0 : 8.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            metrics.gutter + spacing,
            metrics.isTv ? 30 : 20,
            metrics.gutter,
            metrics.isTv ? 18 : 14,
          ),
          child: Text(
            title,
            style: SabuflixTheme.title(fontSize: metrics.sectionTitleSize, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: metrics.posterRowHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            // A TV drives the shelf with the D-pad, not a flick, and the
            // rubber-band overscroll only fights the focus animation there.
            physics: metrics.isTv ? const ClampingScrollPhysics() : const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: metrics.gutter),
            itemCount: mediaItems.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing),
                child: MediaCard(
                  media: mediaItems[index],
                  autofocus: autofocusFirst && index == 0,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
