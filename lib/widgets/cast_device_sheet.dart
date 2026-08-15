import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cast_target.dart';
import '../providers/casting_provider.dart';
import '../theme/sabuflix_theme.dart';
import 'glass_container.dart';

Future<bool?> showCastDeviceSheet(
  BuildContext context, {
  required CastMediaRequest media,
}) {
  final provider = context.read<CastingProvider>();
  provider.startDiscovery();

  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: 0.72,
      child: GlassContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        blur: 38,
        fillOpacity: 0.34,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Consumer<CastingProvider>(
          builder: (context, casting, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.28),
                      borderRadius: SabuflixTheme.radiusPill,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(
                      Icons.cast_rounded,
                      color: SabuflixTheme.textPrimary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Transmitir para TV',
                        style: SabuflixTheme.title(fontSize: 20),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Procurar novamente',
                      onPressed:
                          casting.isSupported ? casting.startDiscovery : null,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Google TV, Samsung, LG e Roku na mesma rede Wi-Fi.',
                  style: SabuflixTheme.body(fontSize: 13),
                ),
                const SizedBox(height: 18),
                if (!casting.isSupported)
                  const Expanded(child: _NativeAppRequired())
                else ...[
                  if (casting.activeTarget != null)
                    _ConnectedDevice(
                      target: casting.activeTarget!,
                      onDisconnect: casting.disconnect,
                    ),
                  if (casting.error != null) ...[
                    const SizedBox(height: 10),
                    _CastError(message: casting.error!),
                  ],
                  const SizedBox(height: 10),
                  Expanded(
                    child: casting.devices.isEmpty
                        ? _DiscoveryEmpty(
                            isDiscovering: casting.isDiscovering,
                          )
                        : ListView.separated(
                            itemCount: casting.devices.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final device = casting.devices[index];
                              final isConnecting =
                                  casting.connectingDeviceId == device.id;
                              final isConnected =
                                  casting.activeTarget?.id == device.id;
                              return Material(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: SabuflixTheme.radiusMd,
                                child: InkWell(
                                  borderRadius: SabuflixTheme.radiusMd,
                                  onTap: isConnecting || isConnected
                                      ? null
                                      : () async {
                                          final success = await casting.castTo(
                                            device,
                                            media,
                                          );
                                          if (success && sheetContext.mounted) {
                                            Navigator.of(sheetContext)
                                                .pop(true);
                                          }
                                        },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 13,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _iconFor(device.kind),
                                          color: isConnected
                                              ? SabuflixTheme.accent
                                              : SabuflixTheme.textPrimary,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                device.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: SabuflixTheme.body(
                                                  color:
                                                      SabuflixTheme.textPrimary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                device.kind.label,
                                                style: SabuflixTheme.caption(),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isConnecting)
                                          const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        else if (isConnected)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: SabuflixTheme.accent,
                                          )
                                        else
                                          const Icon(
                                            Icons.chevron_right_rounded,
                                            color: SabuflixTheme.textMuted,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    ),
  );
}

IconData _iconFor(CastTargetKind kind) {
  switch (kind) {
    case CastTargetKind.googleCast:
      return Icons.cast_rounded;
    case CastTargetKind.roku:
      return Icons.live_tv_rounded;
    case CastTargetKind.samsung:
    case CastTargetKind.lg:
    case CastTargetKind.dlna:
      return Icons.tv_rounded;
  }
}

class _DiscoveryEmpty extends StatelessWidget {
  final bool isDiscovering;

  const _DiscoveryEmpty({required this.isDiscovering});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDiscovering)
            const CircularProgressIndicator(strokeWidth: 2.4)
          else
            const Icon(
              Icons.tv_off_outlined,
              size: 42,
              color: SabuflixTheme.textMuted,
            ),
          const SizedBox(height: 14),
          Text(
            isDiscovering ? 'Procurando TVs...' : 'Nenhuma TV encontrada',
            style: SabuflixTheme.body(
              color: SabuflixTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectedDevice extends StatelessWidget {
  final CastTarget target;
  final Future<void> Function() onDisconnect;

  const _ConnectedDevice({
    required this.target,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: SabuflixTheme.radiusMd,
      blur: 20,
      fillOpacity: 0.2,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.cast_connected_rounded, color: SabuflixTheme.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Transmitindo para ${target.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SabuflixTheme.caption(
                color: SabuflixTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(onPressed: onDisconnect, child: const Text('Desconectar')),
        ],
      ),
    );
  }
}

class _CastError extends StatelessWidget {
  final String message;

  const _CastError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF453A).withValues(alpha: 0.12),
        borderRadius: SabuflixTheme.radiusMd,
        border: Border.all(
          color: const Color(0xFFFF453A).withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        message,
        style: SabuflixTheme.caption(color: const Color(0xFFFFB4AE)),
      ),
    );
  }
}

class _NativeAppRequired extends StatelessWidget {
  const _NativeAppRequired();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.phone_android_rounded,
              size: 44,
              color: SabuflixTheme.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              'Abra o Sabuflix no Android, iPhone ou Windows para procurar TVs na rede local.',
              textAlign: TextAlign.center,
              style: SabuflixTheme.body(),
            ),
          ],
        ),
      ),
    );
  }
}
