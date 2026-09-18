import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../providers/settings_provider.dart';
import '../theme/sabuflix_theme.dart';
import 'media_card.dart';

class MediaRow extends StatefulWidget {
  final String title;
  final List<MediaItem> mediaItems;

  /// Horizontal padding; `null` picks the standard page inset.
  final double? inset;

  /// Draws big ranking numbers next to each card (Top 10 shelves).
  final bool ranked;

  /// Optional "Ver tudo" action.
  final VoidCallback? onSeeAll;

  const MediaRow({
    super.key,
    required this.title,
    required this.mediaItems,
    this.inset,
    this.ranked = false,
    this.onSeeAll,
  });
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
    final inset = widget.inset ?? (desktop ? 40.0 : 20.0);
    final width = desktop ? 340.0 : 270.0;
    final caption =
        compact ? 0.0 : 15 + MediaQuery.textScalerOf(context).scale(32);
    final rankWidth = widget.ranked ? (desktop ? 64.0 : 48.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
              inset, widget.inset == null ? 40 : 8, inset, 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title.toUpperCase(),
                  style: SabuflixTheme.of(context).label(
                    fontSize: desktop ? 15 : 13,
                    color: SabuflixTheme.of(context).textPrimary,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              if (widget.onSeeAll != null)
                TextButton(
                  onPressed: widget.onSeeAll,
                  style: TextButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 10)),
                  child: const Text('Ver tudo'),
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
            separatorBuilder: (_, index) =>
                SizedBox(width: widget.ranked ? 6 : 14),
            itemBuilder: (_, index) {
              final card = MediaCard(
                media: widget.mediaItems[index],
                width: width,
                landscape: true,
              );
              if (!widget.ranked) return card;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: rankWidth,
                    height: width * 9 / 16,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: desktop ? 84 : 64,
                          height: 0.85,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -6,
                          color: SabuflixTheme.of(context).background,
                          shadows: [
                            for (final offset in const [
                              Offset(1.5, 0),
                              Offset(-1.5, 0),
                              Offset(0, 1.5),
                              Offset(0, -1.5),
                            ])
                              Shadow(
                                  offset: offset,
                                  color:
                                      SabuflixTheme.of(context).textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ),
                  card,
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
