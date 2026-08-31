import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/continue_watching_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/watched_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/wordmark.dart';
import 'profile_selection_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final profile = context.watch<ProfileProvider>().currentProfile;
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 800;

    return Scaffold(
      backgroundColor: SabuflixTheme.background,
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
                    style: SabuflixTheme.headline(
                        fontSize: width < 500 ? 28 : 34)),
                const SizedBox(height: 8),
                Text('Personalize a experiência neste dispositivo.',
                    style: SabuflixTheme.body(fontSize: 14)),
                const SizedBox(height: 28),
                if (profile != null)
                  _SettingsCard(
                    children: [
                      _ProfileRow(
                        name: profile.name,
                        color: Color(profile.colorValue),
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProfileSelectionScreen()),
                        ),
                      ),
                    ],
                  ),
                const _SectionLabel('CATÁLOGO'),
                _SettingsCard(
                  children: [
                    SwitchListTile.adaptive(
                      value: settings.hideUnreleased,
                      onChanged: settings.setHideUnreleased,
                      title: const Text('Ocultar lançamentos futuros'),
                      subtitle:
                          const Text('Mostra apenas títulos já lançados.'),
                      secondary: const Icon(Icons.event_available_outlined),
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      value: settings.compactPosters,
                      onChanged: settings.setCompactPosters,
                      title: const Text('Capas compactas'),
                      subtitle: const Text('Oculta os nomes abaixo das capas.'),
                      secondary: const Icon(Icons.view_compact_outlined),
                    ),
                  ],
                ),
                const _SectionLabel('CONTINUAR ASSISTINDO'),
                _SettingsCard(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.sort_rounded,
                                  color: SabuflixTheme.textSecondary),
                              const SizedBox(width: 14),
                              Expanded(
                                  child: Text('Ordenar por',
                                      style: SabuflixTheme.body(
                                          color: SabuflixTheme.textPrimary))),
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
                      title: 'Limpar títulos assistidos',
                      count: context.watch<WatchedProvider>().items.length,
                      onTap: () => _confirmClear(
                        context,
                        title: 'Limpar histórico?',
                        message:
                            'Os títulos marcados como assistidos neste perfil serão removidos.',
                        onConfirm: context.read<WatchedProvider>().clear,
                      ),
                    ),
                  ],
                ),
                const _SectionLabel('SOBRE'),
                _SettingsCard(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SabuflixWordmark(fontSize: 18),
                          Spacer(),
                          Text('1.1.0',
                              style: TextStyle(
                                  color: SabuflixTheme.textMuted,
                                  fontSize: 12)),
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
                  style: SabuflixTheme.caption(
                      fontSize: 11, color: SabuflixTheme.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
      applicationName: 'Sabuflix',
      applicationVersion: '1.1.1',
      applicationLegalese:
          '© 2026 Sabuflix\n\nEste produto usa a API do TMDB, mas não é endossado ou certificado pelo TMDB.',
      children: [
        const SizedBox(height: 14),
        Text(
          'Uma experiência oficial Sabuflix para descobrir, organizar e reproduzir sua mídia autorizada.',
          style: SabuflixTheme.body(fontSize: 13),
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 28, 6, 10),
      child: Text(text, style: SabuflixTheme.label(fontSize: 11)),
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
  final VoidCallback onTap;
  const _ProfileRow(
      {required this.name, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      leading: CircleAvatar(
          backgroundColor: color,
          child: const Icon(Icons.person_rounded, color: Colors.white)),
      title: Text(name, style: SabuflixTheme.title(fontSize: 15)),
      subtitle:
          Text('Perfil ativo', style: SabuflixTheme.caption(fontSize: 12)),
      trailing: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Trocar',
              style: TextStyle(
                  color: SabuflixTheme.accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
          SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: SabuflixTheme.textMuted),
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
              ? SabuflixTheme.textMuted
              : SabuflixTheme.textSecondary),
      title: Text(title,
          style: SabuflixTheme.body(
              color: count == 0
                  ? SabuflixTheme.textMuted
                  : SabuflixTheme.textPrimary)),
      trailing: Text('$count', style: SabuflixTheme.caption()),
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
      leading: Icon(icon, color: SabuflixTheme.textSecondary),
      title: Text(title,
          style: SabuflixTheme.body(color: SabuflixTheme.textPrimary)),
      trailing: const Icon(Icons.open_in_new_rounded,
          size: 17, color: SabuflixTheme.textMuted),
    );
  }
}
