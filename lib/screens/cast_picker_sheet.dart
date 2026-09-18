import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cast_provider.dart';
import '../services/cast/cast_device.dart';
import '../theme/sabuflix_theme.dart';

/// Lets the viewer pick a TV. Resolves with the connected device, or `null`
/// when dismissed or disconnected.
Future<CastDevice?> showCastPicker(BuildContext context) {
  final cast = context.read<CastProvider>();
  if (cast.isSupported && !cast.isDiscovering) cast.discover();
  return showModalBottomSheet<CastDevice?>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: SabuflixTheme.of(context).surface,
    showDragHandle: true,
    builder: (_) => const _CastPickerSheet(),
  );
}

class _CastPickerSheet extends StatefulWidget {
  const _CastPickerSheet();

  @override
  State<_CastPickerSheet> createState() => _CastPickerSheetState();
}

class _CastPickerSheetState extends State<_CastPickerSheet> {
  String? _connectingId;

  Future<void> _connect(CastDevice device) async {
    final cast = context.read<CastProvider>();
    setState(() => _connectingId = device.id);
    try {
      await cast.connect(device);
      if (!mounted) return;
      Navigator.pop(context, device);
    } on CastException catch (error) {
      if (!mounted) return;
      setState(() => _connectingId = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _addManual() async {
    final controller = TextEditingController();
    final host = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Adicionar TV pelo IP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Encontre o endereço IP nas configurações de rede da TV. Ela precisa estar na mesma rede Wi-Fi.',
              style: SabuflixTheme.of(dialogContext).body(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: '192.168.0.20'),
              onSubmitted: (value) => Navigator.pop(dialogContext, value),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Procurar')),
        ],
      ),
    );
    if (host == null || host.trim().isEmpty || !mounted) return;
    setState(() => _connectingId = 'manual');
    final device = await context.read<CastProvider>().addManual(host);
    if (!mounted) return;
    setState(() => _connectingId = null);
    if (device == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Nenhuma TV compatível respondeu nesse endereço. Confira o IP e se a TV está ligada.')));
      return;
    }
    await _connect(device);
  }

  @override
  Widget build(BuildContext context) {
    final colors = SabuflixTheme.of(context);
    final cast = context.watch<CastProvider>();
    final devices = cast.devices;
    final connected = cast.device;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Transmitir para a TV',
                    style: colors.title(fontSize: 20)),
              ),
              if (cast.isDiscovering)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (cast.isSupported)
                IconButton(
                  tooltip: 'Buscar novamente',
                  onPressed: cast.discover,
                  icon: const Icon(Icons.refresh_rounded),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            cast.isSupported
                ? 'Chromecast, Android TV, Google TV e Smart TVs com DLNA (Samsung, LG, Sony, Philips, TCL e outras) na mesma rede Wi-Fi.'
                : 'No navegador, use o botão de transmissão do próprio Chrome ou abra o aplicativo Sabuflix no celular, computador ou TV.',
            style: colors.body(fontSize: 13),
          ),
          const SizedBox(height: 18),
          if (connected != null) ...[
            _DeviceTile(
              device: connected,
              connected: true,
              busy: false,
              onTap: () => Navigator.pop(context, connected),
              trailing: TextButton(
                onPressed: () async {
                  await cast.disconnect();
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Desconectar'),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (cast.isSupported)
            Flexible(
              child: devices.where((d) => d.id != connected?.id).isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Column(
                        children: [
                          Icon(
                            cast.isDiscovering
                                ? Icons.wifi_tethering_rounded
                                : Icons.tv_off_rounded,
                            size: 40,
                            color: colors.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            cast.isDiscovering
                                ? 'Procurando TVs na sua rede…'
                                : 'Nenhuma TV encontrada. Confira se a TV está ligada e na mesma rede, ou adicione pelo IP.',
                            textAlign: TextAlign.center,
                            style: colors.body(fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount:
                          devices.where((d) => d.id != connected?.id).length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final device = devices
                            .where((d) => d.id != connected?.id)
                            .elementAt(index);
                        final saved = cast.savedDevices.contains(device);
                        return _DeviceTile(
                          device: device,
                          connected: false,
                          busy: _connectingId == device.id,
                          onTap: _connectingId == null
                              ? () => _connect(device)
                              : null,
                          onLongPress: saved ? () => cast.forget(device) : null,
                          trailing: saved && !cast.isDiscovering
                              ? Tooltip(
                                  message:
                                      'Salva · toque e segure para esquecer',
                                  child: Icon(Icons.bookmark_rounded,
                                      size: 16, color: colors.textMuted),
                                )
                              : null,
                        );
                      },
                    ),
            ),
          if (cast.isSupported) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _connectingId == null ? _addManual : null,
              icon: _connectingId == 'manual'
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_link_rounded),
              label: const Text('Adicionar TV pelo IP'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final CastDevice device;
  final bool connected;
  final bool busy;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  const _DeviceTile({
    required this.device,
    required this.connected,
    required this.busy,
    required this.onTap,
    this.onLongPress,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = SabuflixTheme.of(context);
    return Material(
      color: connected
          ? colors.accent.withValues(alpha: .12)
          : colors.secondaryFill,
      borderRadius: SabuflixTheme.radiusMd,
      child: InkWell(
        borderRadius: SabuflixTheme.radiusMd,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: .14),
                  borderRadius: SabuflixTheme.radiusSm,
                ),
                child: Icon(
                  device.isChromecast ? Icons.cast_rounded : Icons.tv_rounded,
                  color: colors.accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: colors.title(fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(
                      connected
                          ? 'Conectada · ${device.detailLabel}'
                          : device.detailLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: colors.caption(
                          fontSize: 12,
                          color:
                              connected ? colors.accent : colors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else if (trailing != null)
                trailing!
              else if (connected)
                Icon(Icons.check_circle_rounded, color: colors.accent)
              else
                Icon(Icons.chevron_right_rounded, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
