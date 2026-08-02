import 'package:flutter/material.dart';

import '../models/cast_device.dart';
import '../models/media_item.dart';
import '../services/cast_service.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/haptics.dart';
import 'glass_container.dart';

/// Opens the "transmitir para" sheet and starts a network scan.
///
/// Resolves to true once a device accepted the media, so the caller can mute
/// local playback.
Future<bool?> showCastPicker({
  required BuildContext context,
  required MediaItem media,
  required String url,
  required String title,
  String? imageUrl,
  Duration startAt = Duration.zero,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _CastPickerSheet(
      media: media,
      url: url,
      title: title,
      imageUrl: imageUrl ?? media.fullBackdropPath,
      startAt: startAt,
    ),
  );
}

class _CastPickerSheet extends StatefulWidget {
  final MediaItem media;
  final String url;
  final String title;
  final String? imageUrl;
  final Duration startAt;

  const _CastPickerSheet({
    required this.media,
    required this.url,
    required this.title,
    required this.imageUrl,
    required this.startAt,
  });

  @override
  State<_CastPickerSheet> createState() => _CastPickerSheetState();
}

class _CastPickerSheetState extends State<_CastPickerSheet> {
  final CastService _cast = CastService.instance;
  String? _connectingId;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    await _cast.discover();
  }

  Future<void> _connect(CastDevice device) async {
    Haptics.heavy();
    setState(() => _connectingId = device.id);

    final success = await _cast.castTo(
      device: device,
      url: widget.url,
      media: widget.media,
      title: widget.title,
      imageUrl: widget.imageUrl,
      startAt: widget.startAt,
    );

    if (!mounted) return;
    setState(() => _connectingId = null);

    if (success) {
      Navigator.pop(context, true);
    } else {
      Haptics.error();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cast.lastError ?? 'Falha ao conectar na TV.')),
      );
    }
  }

  IconData _iconFor(CastProtocol protocol) {
    switch (protocol) {
      case CastProtocol.googleCast:
        return Icons.cast_rounded;
      case CastProtocol.roku:
        return Icons.tv_rounded;
      case CastProtocol.dlna:
        return Icons.connected_tv_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.6;

    return ListenableBuilder(
      listenable: _cast,
      builder: (context, _) {
        final devices = _cast.devices;

        return GlassContainer(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          blur: 40,
          fillOpacity: 0.4,
          child: SizedBox(
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Transmitir para',
                        style: SabuflixTheme.title(fontSize: 20),
                      ),
                    ),
                    if (_cast.isDiscovering)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: SabuflixTheme.accent,
                        ),
                      )
                    else
                      IconButton(
                        tooltip: 'Procurar novamente',
                        icon: const Icon(Icons.refresh_rounded, color: SabuflixTheme.textSecondary),
                        onPressed: () {
                          Haptics.selection();
                          _scan();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Samsung, LG, Sony, Roku, Chromecast e Google TV na mesma rede.',
                  style: SabuflixTheme.body(fontSize: 12, color: SabuflixTheme.textMuted),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: devices.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          itemCount: devices.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final device = devices[index];
                            final isConnecting = _connectingId == device.id;
                            final isConnected = _cast.connectedDevice == device;

                            return ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusMd),
                              tileColor: Colors.white.withValues(alpha: 0.08),
                              leading: Icon(
                                _iconFor(device.protocol),
                                color: isConnected ? SabuflixTheme.accent : Colors.white,
                              ),
                              title: Text(
                                device.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SabuflixTheme.body(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(
                                device.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SabuflixTheme.body(
                                  fontSize: 12,
                                  color: SabuflixTheme.textMuted,
                                ),
                              ),
                              trailing: isConnecting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: SabuflixTheme.accent,
                                      ),
                                    )
                                  : Icon(
                                      isConnected
                                          ? Icons.check_circle_rounded
                                          : Icons.play_circle_fill_rounded,
                                      color: SabuflixTheme.accent,
                                      size: 30,
                                    ),
                              onTap: isConnecting ? null : () => _connect(device),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _cast.isDiscovering ? Icons.wifi_tethering_rounded : Icons.tv_off_rounded,
            size: 42,
            color: SabuflixTheme.textMuted,
          ),
          const SizedBox(height: 14),
          Text(
            _cast.isDiscovering
                ? 'Procurando dispositivos na rede…'
                : 'Nenhuma TV encontrada',
            style: SabuflixTheme.body(color: SabuflixTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (!_cast.isDiscovering) ...[
            const SizedBox(height: 6),
            Text(
              'Verifique se a TV está ligada e no mesmo Wi-Fi.',
              style: SabuflixTheme.body(fontSize: 12, color: SabuflixTheme.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
