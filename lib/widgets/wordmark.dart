import 'package:flutter/material.dart';
import '../theme/sabuflix_theme.dart';

/// The Sabuflix brand mark — a terracotta asterisk mark followed by a
/// serif wordmark, in the spirit of the Claude brand mark.
class SabuflixWordmark extends StatelessWidget {
  final double fontSize;

  const SabuflixWordmark({Key? key, this.fontSize = 22}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('✳', style: SabuflixTheme.wordmarkGlyph(fontSize: fontSize * 0.82)),
        SizedBox(width: fontSize * 0.28),
        Text('Sabuflix', style: SabuflixTheme.wordmark(fontSize: fontSize)),
      ],
    );
  }
}
