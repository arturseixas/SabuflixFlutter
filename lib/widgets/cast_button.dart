import 'package:flutter/material.dart';

import '../models/cast_device.dart';
import '../services/cast_service.dart';
import '../theme/sabuflix_theme.dart';
import 'glass_container.dart';

/// The cast affordance — outline glyph when idle, filled accent glyph while
/// connected, a small spinner while a connection is in flight.
class CastIconButton extends StatelessWidget {
  final bool isCasting;
  final bool isConnecting;
  final VoidCallback onPressed;

  const CastIconButton({
    super.key,
    required this.isCasting,
    required this.isConnecting,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (isConnecting) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
        ),
      );
    }
    return IconButton(
      icon: Icon(
        isCasting ? Icons.cast_connected_rounded : Icons.cast_rounded,
        color: isCasting ? SabuflixTheme.accent : Colors.white,
      ),
      onPressed: onPressed,
    );
  }
}

/// Opens the device picker sheet and resolves with the [CastDevice] the
/// user tapped, or `null` if they dismissed it without choosing one.
Future<CastDevice?> showCastPicker(BuildContext context, CastService service) {
  return showModalBottomSheet<CastDevice>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _CastPickerSheet(service: service),
  );
}

class _CastPickerSheet extends StatefulWidget {
  final CastService service;
  const _CastPickerSheet({required this.service});

  @override
  State<_CastPickerSheet> createState() => _CastPickerSheetState();
}

class _CastPickerSheetState extends State<_CastPickerSheet> {
  @override
  void initState() {
    super.initState();
    widget.service.startDiscovery();
  }

  @override
  void dispose() {
    widget.service.stopDiscovery();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: GlassContainer(
          borderRadius: SabuflixTheme.radiusLg,
          blur: 34,
          fillOpacity: 0.6,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.cast_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text('Transmitir para TV', style: SabuflixTheme.title(fontSize: 17, color: Colors.white)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              StreamBuilder<List<CastDevice>>(
                stream: widget.service.devices,
                builder: (context, snapshot) {
                  final devices = snapshot.data ?? const [];
                  if (devices.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: SabuflixTheme.accent),
                            ),
                            const SizedBox(height: 14),
                            Text('Procurando TVs na sua rede…', style: SabuflixTheme.body(fontSize: 13)),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: devices.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.tv_rounded, color: Colors.white, size: 20),
                        ),
                        title: Text(
                          device.name,
                          style: SabuflixTheme.body(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        subtitle: Text(
                          device.protocol == CastProtocol.chromecast ? 'Chromecast' : 'DLNA · Smart TV',
                          style: SabuflixTheme.caption(fontSize: 12),
                        ),
                        onTap: () => Navigator.pop(context, device),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
