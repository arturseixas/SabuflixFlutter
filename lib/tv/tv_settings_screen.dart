import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/sabuflix_theme.dart';
import 'tv_focus.dart';
import 'tv_metrics.dart';
import 'tv_platform.dart';

/// The escape hatch for every TV we could not test on.
///
/// Detection covers Android TV, Tizen and webOS properly, and a long list of
/// other sets by user agent — but there will always be a box, a stick or a
/// browser that reports something new. This screen lets whoever is holding the
/// remote force the TV interface on (or off, on a tablet that was misread),
/// and the choice is remembered.
class TvSettingsScreen extends StatefulWidget {
  const TvSettingsScreen({Key? key}) : super(key: key);

  @override
  State<TvSettingsScreen> createState() => _TvSettingsScreenState();
}

class _TvSettingsScreenState extends State<TvSettingsScreen> {
  Future<void> _apply(TvModeSetting mode) async {
    await TvPlatform.setMode(mode);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final metrics = TvMetrics.of(context);

    return Scaffold(
      backgroundColor: SabuflixTheme.background,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(metrics.gutter, 40, metrics.gutter, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ajustes', style: SabuflixTheme.headline(fontSize: metrics.isTv ? 40 : 28)),
            const SizedBox(height: 10),
            Text(
              'Aparelho detectado: ${TvPlatform.systemLabel}'
              '${TvPlatform.detectedTv ? ' · modo TV detectado automaticamente' : ''}',
              style: SabuflixTheme.body(fontSize: metrics.bodySize),
            ),
            const SizedBox(height: 34),
            Text('Interface', style: SabuflixTheme.title(fontSize: metrics.titleSize)),
            const SizedBox(height: 8),
            Text(
              'Escolha "TV" para navegar com o controle remoto em qualquer aparelho, '
              'mesmo que ele não seja reconhecido automaticamente.',
              style: SabuflixTheme.body(fontSize: metrics.captionSize + 2),
            ),
            const SizedBox(height: 18),
            _ModeOption(
              label: 'Automático',
              description: 'Usa a interface de TV apenas em aparelhos reconhecidos como televisão.',
              selected: TvPlatform.setting == TvModeSetting.auto,
              autofocus: true,
              onPressed: () => _apply(TvModeSetting.auto),
            ),
            _ModeOption(
              label: 'Sempre TV',
              description: 'Força a interface de 10 pés com navegação por controle remoto.',
              selected: TvPlatform.setting == TvModeSetting.on,
              onPressed: () => _apply(TvModeSetting.on),
            ),
            _ModeOption(
              label: 'Sempre celular / desktop',
              description: 'Força a interface de toque, útil em tablets ligados a um monitor.',
              selected: TvPlatform.setting == TvModeSetting.off,
              onPressed: () => _apply(TvModeSetting.off),
            ),
            const SizedBox(height: 40),
            Text('Controle remoto', style: SabuflixTheme.title(fontSize: metrics.titleSize)),
            const SizedBox(height: 12),
            _ShortcutLine(text: 'Direcionais — navegar entre capas, prateleiras e o menu lateral'),
            _ShortcutLine(text: 'OK / Enter — abrir o título em foco ou pausar durante a reprodução'),
            _ShortcutLine(text: 'Voltar — sair da tela atual; na tela inicial, sair do aplicativo'),
            _ShortcutLine(text: 'Play/Pause, avançar e retroceder — controlam o player direto do controle'),
            _ShortcutLine(text: 'Durante o vídeo: ← e → avançam ou voltam 10 segundos'),
            if (!TvPlatform.supportsDownloads) ...[
              const SizedBox(height: 40),
              Text('Downloads', style: SabuflixTheme.title(fontSize: metrics.titleSize)),
              const SizedBox(height: 10),
              Text(
                'As TVs Samsung (Tizen) e LG (webOS) executam o aplicativo em modo web e não '
                'oferecem armazenamento local para vídeos, então os downloads ficam disponíveis '
                'apenas nas versões Android TV, Windows e celular.',
                style: SabuflixTheme.body(fontSize: metrics.captionSize + 2),
              ),
            ],
            const SizedBox(height: 40),
            Text(
              'Sabuflix · versão ${kIsWeb ? 'web' : defaultTargetPlatform.name}',
              style: SabuflixTheme.caption(fontSize: metrics.captionSize, color: SabuflixTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final String label;
  final String description;
  final bool selected;
  final bool autofocus;
  final VoidCallback onPressed;

  const _ModeOption({
    required this.label,
    required this.description,
    required this.selected,
    required this.onPressed,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = TvMetrics.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TvFocusable(
        autofocus: autofocus,
        showRing: false,
        scaleOnFocus: false,
        onPressed: onPressed,
        semanticLabel: label,
        builder: (context, focused, child) => AnimatedContainer(
          duration: SabuflixTheme.durationFast,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: tvFocusDecoration(
            focused: focused,
            borderRadius: SabuflixTheme.radiusMd,
            ringWidth: metrics.focusRingWidth,
            fill: focused ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.06),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                color: selected ? SabuflixTheme.accent : SabuflixTheme.textMuted,
                size: metrics.iconSize,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: SabuflixTheme.body(
                        fontSize: metrics.bodySize,
                        fontWeight: FontWeight.w700,
                        color: SabuflixTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(description, style: SabuflixTheme.caption(fontSize: metrics.captionSize)),
                  ],
                ),
              ),
            ],
          ),
        ),
        child: const SizedBox.shrink(),
      ),
    );
  }
}

class _ShortcutLine extends StatelessWidget {
  final String text;

  const _ShortcutLine({required this.text});

  @override
  Widget build(BuildContext context) {
    final metrics = TvMetrics.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 12),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(color: SabuflixTheme.accent, shape: BoxShape.circle),
            ),
          ),
          Expanded(child: Text(text, style: SabuflixTheme.body(fontSize: metrics.captionSize + 2))),
        ],
      ),
    );
  }
}
