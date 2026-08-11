import 'package:flutter/material.dart';
import '../theme/sabuflix_theme.dart';

/// The Sabuflix brand mark — plain type, nothing else.
class SabuflixWordmark extends StatelessWidget {
  final double fontSize;

  /// Shortened form, for the collapsed TV rail where the full name has no room.
  final String text;

  const SabuflixWordmark({Key? key, this.fontSize = 20, this.text = 'Sabuflix'}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: SabuflixTheme.wordmark(fontSize: fontSize));
  }
}
