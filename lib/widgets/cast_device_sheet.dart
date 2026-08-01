import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cast_device.dart';
import '../providers/cast_provider.dart';
import '../theme/sabuflix_theme.dart';
import 'glass_container.dart';

/// Opens the device picker, scans the network for DLNA/Chromecast TVs and,
/// once the user taps one, starts casting [mediaUrl] to it.
void showCastDeviceSheet(
  BuildContext context, {
  required String mediaUrl,
  required String title,
  String? posterUrl,
  Duration startAt = Duration.zero,
}) {
  final provider = context.read<CastProvider>();
  provider.discover();

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return GlassContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        padding: const EdgeInsets.all(24),
        blur: 40,
        fillOpacity: 0.4,
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.55,
          child: Consumer<CastProvider>(
            builder: (context, cast, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Transmitir para a TV', style: SabuflixTheme.title(fontSize: 20)),
                      IconButton(
                        tooltip: 'Procurar novamente',
                        icon: cast.isDiscovering
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: SabuflixTheme.accent),
                              )
                            : const Icon(Icons.refresh_rounded, color: SabuflixTheme.textSecondary),
                        onPressed: cast.isDiscovering ? null : () => cast.discover(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Procurando TVs com Chromecast ou DLNA na mesma rede Wi-Fi.',
                    style: SabuflixTheme.caption(fontSize: 12, color: SabuflixTheme.textMuted),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: cast.devices.isEmpty
                        ? Center(
                            child: cast.isDiscovering
                                ? const CircularProgressIndicator(color: SabuflixTheme.accent)
                                : Text('Nenhuma TV encontrada', style: SabuflixTheme.body(color: Colors.white)),
                          )
                        : ListView.separated(
                            itemCount: cast.devices.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final device = cast.devices[i];
                              final isConnected = cast.connectedDevice?.id == device.id;
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusMd),
                                tileColor: Colors.white.withValues(alpha: 0.08),
                                leading: Icon(
                                  device.protocol == CastProtocol.chromecast ? Icons.cast_rounded : Icons.tv_rounded,
                                  color: isConnected ? SabuflixTheme.accent : Colors.white,
                                ),
                                title: Text(device.name, style: SabuflixTheme.body(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15)),
                                subtitle: Text(device.subtitle, style: SabuflixTheme.caption(fontSize: 12, color: SabuflixTheme.textMuted)),
                                trailing: isConnected
                                    ? const Icon(Icons.check_circle, color: SabuflixTheme.accent)
                                    : (cast.isConnecting ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: SabuflixTheme.accent),
                                      ) : null),
                                onTap: cast.isConnecting
                                    ? null
                                    : () async {
                                        Navigator.pop(ctx);
                                        if (isConnected) {
                                          await cast.disconnect();
                                          return;
                                        }
                                        try {
                                          await cast.castTo(
                                            device,
                                            mediaUrl: mediaUrl,
                                            title: title,
                                            posterUrl: posterUrl,
                                            startAt: startAt,
                                          );
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Transmitindo para ${device.name}')),
                                            );
                                          }
                                        } catch (_) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Não foi possível transmitir para ${device.name}.')),
                                            );
                                          }
                                        }
                                      },
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}
