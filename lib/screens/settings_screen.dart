import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';
import '../providers/cast_provider.dart';
import '../providers/continue_watching_provider.dart';
import '../providers/downloads_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/watched_provider.dart';
import '../services/backup_service.dart';
import '../services/playback_resolver.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/formatters.dart';
import '../widgets/glass_container.dart';
import '../widgets/wordmark.dart';
import 'cast_picker_sheet.dart';
import '../utils/profile_icons.dart';
import 'profile_selection_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final profile = context.watch<ProfileProvider>().currentProfile;
    final cast = context.watch<CastProvider>();
    final downloads = context.watch<DownloadsProvider>();
    final colors = SabuflixTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 800;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(22, 28, 22, isMobile ? 126 : 42),
              children: [
                Text('Ajustes',
                    style: colors.headline(fontSize: width < 500 ? 28 : 34)),
                const SizedBox(height: 8),
                Text('Personalize a experiência neste dispositivo.',
                    style: colors.body(fontSize: 14)),
                const SizedBox(height: 28),
                if (profile != null)
                  _SettingsCard(
                    children: [
                      _ProfileRow(
                        name: profile.name,
                        color: Color(profile.colorValue),
                        icon: profileIcon(profile.avatar),
                        detail: [
                          'Perfil ativo',
                          if (profile.isKids) 'Infantil',
                          if (profile.hasPin) 'Protegido por PIN',
                          'Até ${profile.maxAgeRating == 'Livre' ? 'Livre' : '${profile.maxAgeRating} anos'}',
                        ].join(' · '),
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProfileSelectionScreen()),
                        ),
                      ),
                    ],
                  ),
                const _SectionLabel('APARÊNCIA'),
                _SettingsCard(children: [
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tema do aplicativo', style: colors.title()),
                          const SizedBox(height: 6),
                          Text('A aparência é salva neste dispositivo.',
                              style: colors.body(fontSize: 13)),
                          const SizedBox(height: 16),
                          Row(children: [
                            for (final mode in ThemeMode.values)
                              Expanded(
                                  child: Padding(
                                padding: EdgeInsets.only(
                                    right: mode == ThemeMode.dark ? 0 : 6),
                                child: Semantics(
                                    selected: settings.themeMode == mode,
                                    child: OutlinedButton(
                                      key: ValueKey('theme-${mode.name}'),
                                      onPressed: () =>
                                          settings.setThemeMode(mode),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 12),
                                        backgroundColor:
                                            settings.themeMode == mode
                                                ? SabuflixTheme.brandBlue
                                                : colors.secondaryFill,
                                        foregroundColor:
                                            settings.themeMode == mode
                                                ? Colors.white
                                                : colors.textPrimary,
                                        side: BorderSide(
                                            color: settings.themeMode == mode
                                                ? SabuflixTheme.brandBlue
                                                : colors.borderStrong),
                                      ),
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                                mode == ThemeMode.system
                                                    ? Icons
                                                        .brightness_auto_outlined
                                                    : mode == ThemeMode.light
                                                        ? Icons
                                                            .light_mode_outlined
                                                        : Icons
                                                            .dark_mode_outlined,
                                                size: 20),
                                            const SizedBox(height: 8),
                                            Text(
                                                mode == ThemeMode.system
                                                    ? 'Sistema'
                                                    : mode == ThemeMode.light
                                                        ? 'Claro'
                                                        : 'Escuro',
                                                style: const TextStyle(
                                                    fontSize: 12)),
                                          ]),
                                    )),
                              )),
                          ]),
                        ],
                      )),
                ]),
                const _SectionLabel('REPRODUÇÃO'),
                _SettingsCard(children: [
                  SwitchListTile.adaptive(
                    value: settings.autoplayNext,
                    onChanged: settings.setAutoplayNext,
                    title: const Text('Próximo episódio automático'),
                    subtitle: Text(
                        'Começa o próximo episódio após ${settings.autoplayCountdownSeconds}s de contagem.'),
                    secondary: width >= 500
                        ? const Icon(Icons.skip_next_rounded)
                        : null,
                  ),
                  if (settings.autoplayNext)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                      child: Row(
                        children: [
                          Text('Contagem', style: colors.caption(fontSize: 12)),
                          Expanded(
                            child: Slider(
                              value:
                                  settings.autoplayCountdownSeconds.toDouble(),
                              min: 3,
                              max: 30,
                              divisions: 9,
                              label: '${settings.autoplayCountdownSeconds}s',
                              onChanged: (value) => settings
                                  .setAutoplayCountdownSeconds(value.round()),
                            ),
                          ),
                          SizedBox(
                              width: 34,
                              child: Text(
                                  '${settings.autoplayCountdownSeconds}s',
                                  textAlign: TextAlign.end,
                                  style: colors.caption(fontSize: 12))),
                        ],
                      ),
                    ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    value: settings.quickPlay,
                    onChanged: settings.setQuickPlay,
                    title: const Text('Reprodução rápida'),
                    subtitle: const Text(
                        'Toca direto na melhor fonte segundo suas preferências, sem abrir a lista.'),
                    secondary:
                        width >= 500 ? const Icon(Icons.bolt_rounded) : null,
                  ),
                  const Divider(height: 1),
                  _ChoiceRow<PreferredQuality>(
                    icon: Icons.high_quality_outlined,
                    title: 'Qualidade preferida',
                    value: settings.preferredQuality,
                    options: PreferredQuality.values,
                    label: (value) => value.label,
                    onChanged: settings.setPreferredQuality,
                  ),
                  const Divider(height: 1),
                  _ChoiceRow<PreferredAudio>(
                    icon: Icons.record_voice_over_outlined,
                    title: 'Áudio preferido',
                    value: settings.preferredAudio,
                    options: PreferredAudio.values,
                    label: (value) => value.label,
                    onChanged: settings.setPreferredAudio,
                  ),
                  const Divider(height: 1),
                  _ChoiceRow<SubtitlePreference>(
                    icon: Icons.subtitles_outlined,
                    title: 'Legendas ao iniciar',
                    value: settings.subtitlePreference,
                    options: SubtitlePreference.values,
                    label: (value) => value.label,
                    onChanged: settings.setSubtitlePreference,
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                    child: Row(
                      children: [
                        Icon(Icons.format_size_rounded,
                            color: colors.textSecondary),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Text('Tamanho das legendas',
                                style: colors.body(color: colors.textPrimary))),
                        Text('${(settings.subtitleScale * 100).round()}%',
                            style: colors.caption(fontSize: 12)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                    child: Slider(
                      value: settings.subtitleScale,
                      min: 0.7,
                      max: 1.8,
                      divisions: 11,
                      onChanged: settings.setSubtitleScale,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: SabuflixTheme.radiusMd,
                      ),
                      child: Text(
                        'Exemplo de legenda no player',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 16 * settings.subtitleScale,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          backgroundColor: const Color(0xAA000000),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  _ChoiceRow<int>(
                    icon: Icons.replay_10_rounded,
                    title: 'Salto ao avançar e voltar',
                    value: settings.seekStepSeconds,
                    options: SettingsProvider.seekStepOptions,
                    label: (value) => '${value}s',
                    onChanged: settings.setSeekStepSeconds,
                  ),
                ]),
                const _SectionLabel('TRANSMITIR PARA A TV'),
                _SettingsCard(children: [
                  ListTile(
                    leading: Icon(
                        cast.isConnected
                            ? Icons.cast_connected_rounded
                            : Icons.cast_rounded,
                        color: cast.isConnected
                            ? colors.accent
                            : colors.textSecondary),
                    title: Text(cast.isConnected
                        ? 'Conectado a ${cast.device!.name}'
                        : 'Nenhuma TV conectada'),
                    subtitle: Text(cast.isSupported
                        ? 'Chromecast, Android TV, Google TV e Smart TVs com DLNA na mesma rede Wi-Fi.'
                        : 'No navegador, use o botão de transmissão do Chrome.'),
                    trailing: cast.isSupported
                        ? TextButton(
                            onPressed: () => showCastPicker(context),
                            child: Text(
                                cast.isConnected ? 'Gerenciar' : 'Procurar'))
                        : null,
                  ),
                  if (cast.savedDevices.isNotEmpty) ...[
                    const Divider(height: 1),
                    for (final device in cast.savedDevices)
                      ListTile(
                        dense: true,
                        leading: Icon(
                            device.isChromecast
                                ? Icons.cast_rounded
                                : Icons.tv_rounded,
                            size: 20,
                            color: colors.textMuted),
                        title: Text(device.name,
                            style: colors.body(color: colors.textPrimary)),
                        subtitle: Text('${device.detailLabel} · ${device.host}',
                            style: colors.caption(fontSize: 11.5)),
                        trailing: IconButton(
                          tooltip: 'Esquecer TV',
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 20),
                          onPressed: () => cast.forget(device),
                        ),
                      ),
                  ],
                ]),
                const _SectionLabel('CATÁLOGO'),
                _SettingsCard(
                  children: [
                    SwitchListTile.adaptive(
                      value: settings.hideUnreleased,
                      onChanged: settings.setHideUnreleased,
                      title: const Text('Ocultar lançamentos futuros'),
                      subtitle: const Text(
                          'Mostra apenas títulos já lançados (a prateleira "Em breve" continua).'),
                      secondary: width >= 500
                          ? const Icon(Icons.event_available_outlined)
                          : null,
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      value: settings.compactPosters,
                      onChanged: settings.setCompactPosters,
                      title: const Text('Capas compactas'),
                      subtitle: const Text('Oculta os nomes abaixo das capas.'),
                      secondary: width >= 500
                          ? const Icon(Icons.view_compact_outlined)
                          : null,
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.sort_rounded,
                                  color: colors.textSecondary),
                              const SizedBox(width: 14),
                              Expanded(
                                  child: Text(
                                      'Ordenar "Continuar assistindo" por',
                                      style: colors.body(
                                          color: colors.textPrimary))),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _SortChip(
                                  label: 'Mais recentes',
                                  value: ContinueWatchingSort.recent,
                                  settings: settings),
                              _SortChip(
                                  label: 'Mais avançados',
                                  value: ContinueWatchingSort.progress,
                                  settings: settings),
                              _SortChip(
                                  label: 'Menos tempo restante',
                                  value: ContinueWatchingSort.remaining,
                                  settings: settings),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (downloads.isSupported) ...[
                  const _SectionLabel('DOWNLOADS'),
                  _SettingsCard(children: [
                    ListTile(
                      leading: Icon(Icons.sd_storage_outlined,
                          color: colors.textSecondary),
                      title: const Text('Espaço usado'),
                      subtitle: Text(
                          '${downloads.completedCount} ${downloads.completedCount == 1 ? 'título' : 'títulos'} · ${formatBytes(downloads.bytesUsed)}'),
                      trailing: downloads.hasAnything
                          ? TextButton(
                              onPressed: () => _confirmClear(
                                context,
                                title: 'Apagar todos os downloads?',
                                message:
                                    'Todos os arquivos baixados neste perfil serão removidos do aparelho.',
                                onConfirm: downloads.removeAll,
                              ),
                              child: Text('Apagar tudo',
                                  style: TextStyle(color: colors.error)),
                            )
                          : null,
                    ),
                  ]),
                ],
                const _SectionLabel('DADOS DESTE PERFIL'),
                _SettingsCard(
                  children: [
                    _DataAction(
                      icon: Icons.play_circle_outline_rounded,
                      title: 'Limpar “Continuar assistindo”',
                      count: context
                          .watch<ContinueWatchingProvider>()
                          .entries
                          .length,
                      onTap: () => _confirmClear(
                        context,
                        title: 'Limpar progresso?',
                        message:
                            'As posições salvas de reprodução deste perfil serão removidas.',
                        onConfirm:
                            context.read<ContinueWatchingProvider>().clear,
                      ),
                    ),
                    const Divider(height: 1),
                    _DataAction(
                      icon: Icons.visibility_outlined,
                      title: 'Limpar títulos e episódios assistidos',
                      count: context.watch<WatchedProvider>().items.length,
                      onTap: () => _confirmClear(
                        context,
                        title: 'Limpar histórico?',
                        message:
                            'Os títulos e episódios marcados como assistidos neste perfil serão removidos.',
                        onConfirm: context.read<WatchedProvider>().clear,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      onTap: () => _exportBackup(context),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 4),
                      leading: Icon(Icons.upload_file_outlined,
                          color: colors.textSecondary),
                      title: Text('Exportar backup',
                          style: colors.body(color: colors.textPrimary)),
                      subtitle: Text(
                          'Copia lista, playlists, progresso, histórico e ajustes para a área de transferência.',
                          style: colors.caption(fontSize: 12)),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      onTap: () => _importBackup(context),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 4),
                      leading: Icon(Icons.download_for_offline_outlined,
                          color: colors.textSecondary),
                      title: Text('Restaurar backup',
                          style: colors.body(color: colors.textPrimary)),
                      subtitle: Text(
                          'Cole um backup exportado em outro aparelho.',
                          style: colors.caption(fontSize: 12)),
                    ),
                  ],
                ),
                const _SectionLabel('FONTES E LEGENDAS'),
                _SettingsCard(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.movie_outlined),
                      title: Text('Nebula, FrostStream e Wali'),
                      subtitle: Text(
                          'Filmes e séries · 4K, Full HD, HD e SD\nÁudio dublado e legendado. As fontes são consultadas em paralelo.'),
                    ),
                    const Divider(height: 1),
                    const ListTile(
                      leading: Icon(Icons.subtitles_outlined),
                      title: Text('OpenSubtitles'),
                      subtitle: Text(
                          'Legendas externas carregadas automaticamente no idioma preferido.'),
                    ),
                  ],
                ),
                const _SectionLabel('SOBRE'),
                _SettingsCard(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SabuflixWordmark(fontSize: 18),
                          const Spacer(),
                          Text(
                              '${AppInfo.version}${kIsWeb ? ' · web' : ' · ${defaultTargetPlatform.name}'}',
                              style: TextStyle(
                                  color: colors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    _LinkTile(
                      icon: Icons.info_outline_rounded,
                      title: 'Informações e atribuições',
                      onTap: _showAbout,
                    ),
                    const Divider(height: 1),
                    _LinkTile(
                      icon: Icons.movie_filter_outlined,
                      title: 'The Movie Database (TMDB)',
                      onTap: _openTmdb,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'O Sabuflix é um cliente de mídia. Não hospeda nem distribui conteúdo. Use somente fontes e mídias que você tem autorização para acessar.',
                  textAlign: TextAlign.center,
                  style: colors.caption(fontSize: 11, color: colors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _exportBackup(BuildContext context) async {
    final profileId = context.read<ProfileProvider>().currentProfile?.id;
    final backup = await BackupService.export(
      profileId: profileId,
      settings: context.read<SettingsProvider>(),
    );
    await Clipboard.setData(ClipboardData(text: backup));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Backup copiado. Cole em um arquivo ou no outro aparelho para restaurar.')));
  }

  static Future<void> _importBackup(BuildContext context) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restaurar backup'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration:
              const InputDecoration(hintText: 'Cole aqui o backup exportado'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Restaurar')),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty || !context.mounted) return;
    final profileId = context.read<ProfileProvider>().currentProfile?.id;
    try {
      await BackupService.import(text,
          profileId: profileId, settings: context.read<SettingsProvider>());
      if (!context.mounted) return;
      await Future.wait([
        context.read<FavoritesProvider>().loadFavorites(profileId),
        context
            .read<ContinueWatchingProvider>()
            .loadForProfile(profileId, force: true),
        context.read<WatchedProvider>().loadForProfile(profileId),
        if (profileId != null)
          context.read<PlaylistProvider>().loadForProfile(profileId),
      ]);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restaurado neste perfil.')));
    } on FormatException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível ler este backup.')));
    }
  }

  static Future<void> _confirmClear(
    BuildContext context, {
    required String title,
    required String message,
    required Future<void> Function() onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Limpar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) await onConfirm();
  }

  static void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: AppInfo.name,
      applicationVersion: AppInfo.version,
      applicationLegalese:
          '${AppInfo.copyright}\n\nEste produto usa a API do TMDB, mas não é endossado ou certificado pelo TMDB. Disponibilidade em serviços de streaming fornecida por JustWatch.',
      children: [
        const SizedBox(height: 14),
        Text(
          'Uma experiência oficial Sabuflix para descobrir, organizar e reproduzir sua mídia autorizada, no celular, no computador e na TV.',
          style: SabuflixTheme.of(context).body(fontSize: 13),
        ),
      ],
    );
  }

  static Future<void> _openTmdb(BuildContext context) async {
    final uri = Uri.parse('https://www.themoviedb.org/');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o link.')));
    }
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  final IconData icon;
  final String title;
  final T value;
  final List<T> options;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  const _ChoiceRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = SabuflixTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.textSecondary),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(title,
                      style: colors.body(color: colors.textPrimary))),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                ChoiceChip(
                  label: Text(label(option)),
                  selected: option == value,
                  showCheckmark: false,
                  onSelected: (_) => onChanged(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 28, 6, 10),
      child: Text(text, style: SabuflixTheme.of(context).label(fontSize: 11)),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: SabuflixTheme.radiusLg,
      fillOpacity: 0.22,
      padding: EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String name;
  final Color color;
  final IconData icon;
  final String detail;
  final VoidCallback onTap;
  const _ProfileRow(
      {required this.name,
      required this.color,
      required this.icon,
      required this.detail,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      leading: CircleAvatar(
          backgroundColor: color, child: Icon(icon, color: Colors.white)),
      title: Text(name, style: SabuflixTheme.of(context).title(fontSize: 15)),
      subtitle:
          Text(detail, style: SabuflixTheme.of(context).caption(fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Trocar',
              style: TextStyle(
                  color: SabuflixTheme.of(context).accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded,
              color: SabuflixTheme.of(context).textMuted),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final ContinueWatchingSort value;
  final SettingsProvider settings;
  const _SortChip(
      {required this.label, required this.value, required this.settings});

  @override
  Widget build(BuildContext context) {
    final selected = settings.continueWatchingSort == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => settings.setContinueWatchingSort(value),
    );
  }
}

class _DataAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final VoidCallback onTap;
  const _DataAction(
      {required this.icon,
      required this.title,
      required this.count,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: count == 0 ? null : onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      leading: Icon(icon,
          color: count == 0
              ? SabuflixTheme.of(context).textMuted
              : SabuflixTheme.of(context).textSecondary),
      title: Text(title,
          style: SabuflixTheme.of(context).body(
              color: count == 0
                  ? SabuflixTheme.of(context).textMuted
                  : SabuflixTheme.of(context).textPrimary)),
      trailing: Text('$count', style: SabuflixTheme.of(context).caption()),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final void Function(BuildContext) onTap;
  const _LinkTile(
      {required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => onTap(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      leading: Icon(icon, color: SabuflixTheme.of(context).textSecondary),
      title: Text(title,
          style: SabuflixTheme.of(context)
              .body(color: SabuflixTheme.of(context).textPrimary)),
      trailing: Icon(Icons.open_in_new_rounded,
          size: 17, color: SabuflixTheme.of(context).textMuted),
    );
  }
}
