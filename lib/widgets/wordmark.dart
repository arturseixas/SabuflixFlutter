import 'package:flutter/material.dart';
import '../theme/sabuflix_theme.dart';

/// The Sabuflix brand mark — plain type, nothing else.
class SabuflixWordmark extends StatelessWidget {
  final double fontSize;

  const SabuflixWordmark({super.key, this.fontSize = 20});

  @override
  Widget build(BuildContext context) {
    return Text('Sabuflix', style: SabuflixTheme.wordmark(fontSize: fontSize));
  }
}
