import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cast_provider.dart';
import '../screens/cast_picker_sheet.dart';
import '../screens/cast_remote_screen.dart';
import '../utils/app_route.dart';

/// The universal "send to TV" control. Grey when idle, accent when a TV is
/// connected; tapping while casting opens the remote instead of the picker.
class CastButton extends StatelessWidget {
  final Color? color;
  final double size;

  const CastButton({super.key, this.color, this.size = 24});

  @override
  Widget build(BuildContext context) {
    final cast = context.watch<CastProvider>();
    if (!cast.isSupported) return const SizedBox.shrink();
    final connected = cast.isConnected;
    final accent = Theme.of(context).colorScheme.secondary;
    return IconButton(
      tooltip: connected
          ? 'Transmitindo para ${cast.device!.name}'
          : 'Transmitir para a TV',
      onPressed: () {
        if (connected && cast.nowPlaying != null) {
          Navigator.push(context, glassRoute(const CastRemoteScreen()));
        } else {
          showCastPicker(context);
        }
      },
      icon: cast.isConnecting
          ? SizedBox(
              width: size - 4,
              height: size - 4,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Icon(
              connected ? Icons.cast_connected_rounded : Icons.cast_rounded,
              size: size,
              color: connected ? accent : color,
            ),
    );
  }
}
