import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../providers/settings_provider.dart';
import '../theme/sabuflix_theme.dart';
import 'media_card.dart';

class MediaRow extends StatefulWidget {
  final String title;
  final List<MediaItem> mediaItems;
  const MediaRow({super.key, required this.title, required this.mediaItems});
  @override
  State<MediaRow> createState() => _MediaRowState();
}

class _MediaRowState extends State<MediaRow> {
  final _scroll = ScrollController();
  void _move(int direction) {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    _scroll.animateTo(
      (p.pixels + direction * p.viewportDimension * .8).clamp(
        0,
        p.maxScrollExtent,
      ),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : SabuflixTheme.durationMed,
      curve: SabuflixTheme.curveStandard,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaItems.isEmpty) return SizedBox.shrink();
    final compact = context.select<SettingsProvider, bool>(
      (p) => p.compactPosters,
    );
    final desktop = MediaQuery.sizeOf(context).width >= 800;
    final inset = desktop ? 40.0 : 20.0;
    final width = desktop ? 360.0 : 280.0;
    final caption =
        compact ? 0.0 : 16 + MediaQuery.textScalerOf(context).scale(34);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, 36, inset, 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title.toUpperCase(),
                  style: SabuflixTheme.of(context).title(
                    fontSize: desktop ? 20 : 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.2,
                  ),
                ),
              ),
              if (desktop) ...[
                IconButton(
                  tooltip: 'Voltar em ${widget.title}',
                  onPressed: () => _move(-1),
                  icon: Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: 'Avançar em ${widget.title}',
                  onPressed: () => _move(1),
                  icon: Icon(Icons.chevron_right),
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          height: width * 9 / 16 + caption + 8,
          child: ListView.separated(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: inset, vertical: 4),
            itemCount: widget.mediaItems.length,
            separatorBuilder: (_, index) => SizedBox(width: desktop ? 16 : 10),
            itemBuilder: (_, index) => MediaCard(
              media: widget.mediaItems[index],
              width: width,
              landscape: true,
            ),
          ),
        ),
      ],
    );
  }
}
