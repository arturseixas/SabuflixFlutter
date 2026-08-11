import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/profile.dart';
import '../providers/profile_provider.dart';
import '../providers/continue_watching_provider.dart';
import '../providers/downloads_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/playlist_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../tv/tv_focus.dart';
import '../tv/tv_metrics.dart';
import '../tv/tv_platform.dart';
import '../tv/tv_shell.dart';
import '../widgets/glass_container.dart';
import 'main_navigation_screen.dart';

class ProfileSelectionScreen extends StatelessWidget {
  const ProfileSelectionScreen({Key? key}) : super(key: key);

  void _selectProfile(BuildContext context, Profile profile) async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final favProvider = Provider.of<FavoritesProvider>(context, listen: false);
    final playlistProvider = Provider.of<PlaylistProvider>(context, listen: false);
    final downloadsProvider = Provider.of<DownloadsProvider>(context, listen: false);
    final continueWatchingProvider = Provider.of<ContinueWatchingProvider>(context, listen: false);

    try {
      await profileProvider.selectProfile(profile.id);
      await favProvider.loadFavorites(profile.id);
      await playlistProvider.loadForProfile(profile.id);
      await downloadsProvider.loadForProfile(profile.id);
      await continueWatchingProvider.loadForProfile(profile.id);
    } catch (e) {
      // ignore
    }

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          // Two different homes for two different distances: the rail-based
          // shell for a remote, the dock-based one for a finger.
          builder: (context) => TvPlatform.isTv ? const TvShell() : const MainNavigationScreen(),
        ),
      );
    }
  }

  void _showAddEditProfileDialog(BuildContext context, {Profile? profileToEdit}) {
    showDialog(
      context: context,
      builder: (context) => _ProfileDialog(profileToEdit: profileToEdit),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SabuflixTheme.background,
      body: Consumer<ProfileProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: SabuflixTheme.accent));
          }
          
          final metrics = TvMetrics.of(context);
          final profiles = provider.profiles;

          return Center(
            child: SingleChildScrollView(
              padding: metrics.overscan,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Quem está assistindo?',
                    style: SabuflixTheme.headline(
                      fontSize: metrics.isTv ? 46 : 32,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: metrics.isTv ? 60 : 48),
                  Wrap(
                    spacing: metrics.isTv ? 34 : 24,
                    runSpacing: metrics.isTv ? 34 : 24,
                    alignment: WrapAlignment.center,
                    children: [
                      for (int i = 0; i < profiles.length; i++)
                        _ProfileAvatar(
                          profile: profiles[i],
                          // Something has to hold the focus when the app opens
                          // on a TV, or the first press of the remote goes
                          // nowhere.
                          autofocus: i == 0,
                          onTap: () => _selectProfile(context, profiles[i]),
                          onEdit: () => _showAddEditProfileDialog(context, profileToEdit: profiles[i]),
                        ),
                      if (profiles.length < 5)
                        _AddProfileButton(
                          autofocus: profiles.isEmpty,
                          onTap: () => _showAddEditProfileDialog(context),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final Profile profile;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final bool autofocus;

  const _ProfileAvatar({
    required this.profile,
    required this.onTap,
    required this.onEdit,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = TvMetrics.of(context);
    final tileSize = metrics.isTv ? 176.0 : 120.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TvFocusable(
          autofocus: autofocus,
          onPressed: onTap,
          borderRadius: SabuflixTheme.radiusLg,
          semanticLabel: profile.name,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: tileSize,
                    height: tileSize,
                    decoration: BoxDecoration(
                      color: Color(profile.colorValue),
                      borderRadius: SabuflixTheme.radiusLg,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(Icons.person, size: tileSize * 0.53, color: Colors.white),
                  ),
                  // On a TV the badge is unreachable with a D-pad, so editing
                  // moves to its own focusable button below the name.
                  if (!metrics.isTv)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: onEdit,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  if (profile.maxAgeRating != '18')
                    Positioned(
                      bottom: -4,
                      left: -4,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: metrics.isTv ? 10 : 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: SabuflixTheme.accent,
                          borderRadius: SabuflixTheme.radiusSm,
                        ),
                        child: Text(
                          profile.maxAgeRating,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: metrics.isTv ? 14 : 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                profile.name,
                style: SabuflixTheme.body(
                  fontSize: metrics.isTv ? 20 : 16,
                  fontWeight: FontWeight.w500,
                  color: SabuflixTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (metrics.isTv) ...[
          const SizedBox(height: 8),
          TvFocusable(
            onPressed: onEdit,
            showRing: false,
            scaleOnFocus: false,
            semanticLabel: 'Editar ${profile.name}',
            builder: (context, focused, child) => AnimatedContainer(
              duration: SabuflixTheme.durationFast,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: focused ? SabuflixTheme.textPrimary : Colors.white.withValues(alpha: 0.08),
                borderRadius: SabuflixTheme.radiusPill,
              ),
              child: Text(
                'Editar',
                style: SabuflixTheme.caption(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: focused ? SabuflixTheme.background : SabuflixTheme.textSecondary,
                ),
              ),
            ),
            child: const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
}

class _AddProfileButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool autofocus;

  const _AddProfileButton({required this.onTap, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    final metrics = TvMetrics.of(context);
    final tileSize = metrics.isTv ? 176.0 : 120.0;

    return TvFocusable(
      autofocus: autofocus,
      onPressed: onTap,
      borderRadius: SabuflixTheme.radiusLg,
      semanticLabel: 'Adicionar perfil',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: tileSize,
            height: tileSize,
            decoration: BoxDecoration(
              color: SabuflixTheme.surface,
              borderRadius: SabuflixTheme.radiusLg,
              border: Border.all(color: SabuflixTheme.border, width: 2),
            ),
            child: Icon(Icons.add_rounded, size: tileSize * 0.53, color: SabuflixTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          Text(
            'Adicionar',
            style: SabuflixTheme.body(fontSize: 16, fontWeight: FontWeight.w500, color: SabuflixTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ProfileDialog extends StatefulWidget {
  final Profile? profileToEdit;
  const _ProfileDialog({this.profileToEdit});

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late TextEditingController _nameController;
  late String _maxAgeRating;
  late int _colorValue;

  final List<String> _ageOptions = ['Livre', '10', '12', '14', '16', '18'];
  final List<int> _colorOptions = [
    0xFF4285F4, // Blue
    0xFFEA4335, // Red
    0xFFFBBC05, // Yellow
    0xFF34A853, // Green
    0xFF9C27B0, // Purple
    0xFFFF9800, // Orange
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profileToEdit?.name ?? '');
    _maxAgeRating = widget.profileToEdit?.maxAgeRating ?? '18';
    _colorValue = widget.profileToEdit?.colorValue ?? _colorOptions[0];
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) return;

    final provider = Provider.of<ProfileProvider>(context, listen: false);
    
    if (widget.profileToEdit == null) {
      provider.addProfile(Profile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        avatarUrl: 'https://i.pravatar.cc/150?u=${DateTime.now().millisecondsSinceEpoch}',
        maxAgeRating: _maxAgeRating,
        colorValue: _colorValue,
      ));
    } else {
      provider.updateProfile(widget.profileToEdit!.copyWith(
        name: _nameController.text.trim(),
        maxAgeRating: _maxAgeRating,
        colorValue: _colorValue,
      ));
    }
    
    Navigator.pop(context);
  }

  void _delete() {
    if (widget.profileToEdit != null) {
      Provider.of<ProfileProvider>(context, listen: false).deleteProfile(widget.profileToEdit!.id);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassContainer(
        borderRadius: SabuflixTheme.radiusLg,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.profileToEdit == null ? 'Novo Perfil' : 'Editar Perfil', style: SabuflixTheme.headline(fontSize: 22)),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nome do Perfil',
                labelStyle: const TextStyle(color: SabuflixTheme.textSecondary),
                enabledBorder: OutlineInputBorder(
                  borderRadius: SabuflixTheme.radiusSm,
                  borderSide: const BorderSide(color: SabuflixTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: SabuflixTheme.radiusSm,
                  borderSide: const BorderSide(color: SabuflixTheme.accent),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Classificação Máxima Permitida:', style: SabuflixTheme.body(color: SabuflixTheme.textSecondary)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _ageOptions.map((age) {
                final isSelected = _maxAgeRating == age;
                return ChoiceChip(
                  label: Text(age, style: TextStyle(color: isSelected ? Colors.white : SabuflixTheme.textSecondary)),
                  selected: isSelected,
                  selectedColor: SabuflixTheme.accent,
                  backgroundColor: SabuflixTheme.surface,
                  onSelected: (selected) {
                    if (selected) setState(() => _maxAgeRating = age);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text('Cor do Ícone:', style: SabuflixTheme.body(color: SabuflixTheme.textSecondary)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _colorOptions.map((c) {
                final isSelected = _colorValue == c;
                return GestureDetector(
                  onTap: () => setState(() => _colorValue = c),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.profileToEdit != null)
                  TextButton(
                    onPressed: _delete,
                    child: const Text('Excluir', style: TextStyle(color: Colors.redAccent)),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: SabuflixTheme.textSecondary)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(backgroundColor: SabuflixTheme.accent),
                  child: const Text('Salvar', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
