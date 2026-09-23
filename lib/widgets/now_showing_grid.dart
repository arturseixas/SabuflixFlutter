import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/media_item.dart';
import '../providers/settings_provider.dart';
import '../theme/sabuflix_theme.dart';
import 'media_card.dart';

/// "Em Cartaz": the short, hand-picked programme right under the daily film —
/// a single column of large stills on phones, a gallery grid on desktop.
class NowShowingGrid extends StatelessWidget {
  final List<MediaItem> items;

  const NowShowingGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final palette = SabuflixTheme.of(context);
    final compact =
        context.select<SettingsProvider, bool>((p) => p.compactPosters);
    return LayoutBuilder(builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 800;
      final inset = desktop ? 40.0 : 20.0;
      final gap = desktop ? 24.0 : 28.0;
      final columns = constraints.maxWidth >= 1100
          ? 3
          : constraints.maxWidth >= 600
              ? 2
              : 1;
      final cardWidth =
          (constraints.maxWidth - inset * 2 - gap * (columns - 1)) / columns;
      final caption =
          compact ? 0.0 : 16 + MediaQuery.textScalerOf(context).scale(34);
      return Padding(
        padding: EdgeInsets.fromLTRB(inset, desktop ? 48 : 36, inset, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EM CARTAZ',
                style: palette.title(
                    fontSize: desktop ? 20 : 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.2)),
            const SizedBox(height: 6),
            Text('Uma seleção feita a dedo. Novos títulos toda semana.',
                style: palette.body(fontSize: 14, color: palette.textMuted)),
            const SizedBox(height: 18),
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final item in items)
                  SizedBox(
                    width: cardWidth,
                    height: cardWidth * 9 / 16 + caption,
                    child: MediaCard(
                        media: item, width: cardWidth, landscape: true),
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
