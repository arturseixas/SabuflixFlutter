import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cast_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../widgets/casting_panel.dart';

/// The remote control, reached from the cast bar after the player screen has
/// been left behind.
///
/// Leaving the player does not stop the television — that is the whole point of
/// casting — so there has to be a way back to the controls that does not
/// involve finding the title again.
class CastControlScreen extends StatelessWidget {
  const CastControlScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cast = context.watch<CastProvider>();

    // Whoever stopped the cast (this screen, or the TV itself) leaves nothing
    // to control here.
    if (!cast.isCasting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) Navigator.pop(context);
      });
    }

    return Scaffold(
      backgroundColor: SabuflixTheme.background,
      body: CastingPanel(
        title: cast.castingTitle ?? 'Sabuflix',
        subtitle: cast.castingSubtitle ?? '',
        onBack: () => Navigator.pop(context),
        onStop: () async {
          await cast.stopCasting();
          if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
        },
      ),
    );
  }
}
