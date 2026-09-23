import 'package:flutter/material.dart';
import '../theme/sabuflix_theme.dart';

/// The Sabuflix brand mark: a small dot grid beside heavy uppercase type.
class SabuflixWordmark extends StatelessWidget {
  final double fontSize;
  final Color? color;

  const SabuflixWordmark({super.key, this.fontSize = 20, this.color});

  @override
  Widget build(BuildContext context) {
    final palette = SabuflixTheme.of(context);
    final ink = color ?? palette.textPrimary;
    final dot = fontSize * .26;
    return Semantics(
      label: 'Sabuflix',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: dot * 5,
              height: dot * 3,
              child: CustomPaint(painter: _DotsPainter(ink)),
            ),
            SizedBox(width: fontSize * .4),
            Text('SABUFLIX',
                style: palette.wordmark(fontSize: fontSize, color: ink)),
          ],
        ),
      ),
    );
  }
}

/// Two staggered rows of dots, drawn rather than shipped as an asset so the
/// mark stays crisp at any size and follows the theme colour.
class _DotsPainter extends CustomPainter {
  final Color color;
  const _DotsPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final r = size.height / 6;
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(r + i * 4 * r, r), r, paint);
    }
    for (var i = 0; i < 2; i++) {
      canvas.drawCircle(Offset(3 * r + i * 4 * r, 5 * r), r, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}
