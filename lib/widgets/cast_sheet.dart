import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cast_device.dart';
import '../providers/cast_provider.dart';
import '../services/screen_mirror.dart';
import '../theme/sabuflix_theme.dart';
import 'glass_container.dart';

/// The "Transmitir para a TV" picker.
///
/// Opens a sweep of the network as soon as it appears — a user who tapped the
/// cast button has already decided; making them press "procurar" first is a
/// wasted step.
///
/// Returns the chosen [CastDevice], or null if the sheet was dismissed.
Future<CastDevice?> showCastSheet(BuildContext context) {
  context.read<CastProvider>().startDiscovery();

  return showModalBottomSheet<CastDevice>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _CastSheet(),
  );
}

class _CastSheet extends StatelessWidget {
  const _CastSheet();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CastProvider>();
    final devices = provider.devices;

    return SafeArea(
      top: false,
      child: GlassContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        blur: 40,
        fillOpacity: 0.4,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Transmitir para a TV', style: SabuflixTheme.title(fontSize: 20)),
                  ),
                  IconButton(
                    tooltip: 'Procurar de novo',
                    onPressed: provider.isScanning ? null : provider.startDiscovery,
                    icon: provider.isScanning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: SabuflixTheme.accent),
                          )
                        : const Icon(Icons.refresh_rounded, color: SabuflixTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'A TV precisa estar na mesma rede Wi-Fi. O vídeo vai direto para ela — '
                'o aparelho pode ser bloqueado sem parar a reprodução.',
                style: SabuflixTheme.caption(fontSize: 13, color: SabuflixTheme.textSecondary),
              ),
              const SizedBox(height: 18),

              Flexible(
                child: devices.isEmpty
                    ? _EmptyState(isScanning: provider.isScanning)
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: devices.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _DeviceTile(
                          device: devices[index],
                          onTap: () => Navigator.pop(context, devices[index]),
                        ),
                      ),
              ),

              if (ScreenMirror.isSupported) ...[
                const SizedBox(height: 16),
                const Divider(color: SabuflixTheme.border, height: 1),
                const SizedBox(height: 12),
                _MirrorTile(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isScanning;

  const _EmptyState({required this.isScanning});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Column(
        children: [
          Icon(
            isScanning ? Icons.wifi_tethering_rounded : Icons.tv_off_rounded,
            size: 40,
            color: SabuflixTheme.textMuted,
          ),
          const SizedBox(height: 14),
          Text(
            isScanning ? 'Procurando TVs na rede…' : 'Nenhuma TV encontrada',
            style: SabuflixTheme.body(fontSize: 15, color: SabuflixTheme.textPrimary),
          ),
          if (!isScanning) ...[
            const SizedBox(height: 8),
            Text(
              'Verifique se a TV está ligada e no mesmo Wi-Fi (redes de visitante '
              'e o 5 GHz separado do 2,4 GHz costumam bloquear a busca).',
              textAlign: TextAlign.center,
              style: SabuflixTheme.caption(fontSize: 13, color: SabuflixTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final CastDevice device;
  final VoidCallback onTap;

  const _DeviceTile({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: SabuflixTheme.radiusMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: SabuflixTheme.radiusMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                device.protocol == CastProtocol.googleCast ? Icons.cast_rounded : Icons.tv_rounded,
                color: SabuflixTheme.accent,
                size: 26,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      device.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SabuflixTheme.body(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: SabuflixTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.model == null || device.model!.isEmpty
                          ? device.protocolLabel
                          : '${device.model} · ${device.protocolLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SabuflixTheme.caption(fontSize: 12, color: SabuflixTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: SabuflixTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen mirroring, which only the operating system can start.
class _MirrorTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: SabuflixTheme.radiusMd,
        onTap: () async {
          final messenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          final opened = await ScreenMirror.openSystemMirroring();
          navigator.pop();
          if (!opened) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Abra o espelhamento pelas configurações do aparelho.'),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.screen_share_outlined, color: SabuflixTheme.textSecondary, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Espelhar a tela inteira',
                      style: SabuflixTheme.body(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: SabuflixTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Abre o espelhamento do sistema (Smart View, Screen Share, Cast)',
                      style: SabuflixTheme.caption(fontSize: 12, color: SabuflixTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new_rounded, color: SabuflixTheme.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
