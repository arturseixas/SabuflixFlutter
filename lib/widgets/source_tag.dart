import 'package:flutter/material.dart';
import '../models/playback_source.dart';
import '../theme/sabuflix_theme.dart';

/// The "de onde está tocando" pill — Streaming vs Download.
class SourceTag extends StatelessWidget {
  final PlaybackSource source;
  final bool compact;

  const SourceTag({Key? key, required this.source, this.compact = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = source.color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: SabuflixTheme.radiusPill,
        border: Border.all(color: color.withValues(alpha: 0.55), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(source.icon, size: compact ? 11 : 13, color: color),
          SizedBox(width: compact ? 4 : 6),
          Text(
            source.label.toUpperCase(),
            style: SabuflixTheme.label(
              fontSize: compact ? 9 : 10.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
