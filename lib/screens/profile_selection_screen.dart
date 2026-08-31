import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/profile.dart';
import '../providers/profile_provider.dart';
import '../providers/continue_watching_provider.dart';
import '../providers/downloads_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/watched_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/wordmark.dart';
import 'main_navigation_screen.dart';

class ProfileSelectionScreen extends StatelessWidget {
  const ProfileSelectionScreen({super.key});

  void _selectProfile(BuildContext context, Profile profile) async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final favProvider = Provider.of<FavoritesProvider>(context, listen: false);
    final playlistProvider =
        Provider.of<PlaylistProvider>(context, listen: false);
    final downloadsProvider =
        Provider.of<DownloadsProvider>(context, listen: false);
    final continueWatchingProvider =
        Provider.of<ContinueWatchingProvider>(context, listen: false);
    final watchedProvider =
        Provider.of<WatchedProvider>(context, listen: false);

    try {
      await profileProvider.selectProfile(profile.id);
      await favProvider.loadFavorites(profile.id);
      await playlistProvider.loadForProfile(profile.id);
      await downloadsProvider.loadForProfile(profile.id);
      await continueWatchingProvider.loadForProfile(profile.id);
      await watchedProvider.loadForProfile(profile.id);
    } catch (e) {
      // ignore
    }

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
      );
    }
  }

  void _showAddEditProfileDialog(BuildContext context,
      {Profile? profileToEdit}) {
    showDialog(
      context: context,
      builder: (context) => _ProfileDialog(profileToEdit: profileToEdit),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SabuflixTheme.background,
      body: Stack(
        children: [
          const Positioned(
            top: 30,
            left: 30,
            child: SafeArea(child: SabuflixWordmark(fontSize: 20)),
          ),
          Positioned.fill(
            child: Consumer<ProfileProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: SabuflixTheme.accent,
                    ),
                  );
                }

                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 100, 24, 90),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Quem está assistindo?',
                          style: SabuflixTheme.headline(
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Wrap(
                          spacing: 24,
                          runSpacing: 24,
                          alignment: WrapAlignment.center,
                          children: [
                            ...provider.profiles.map(
                              (p) => _ProfileAvatar(
                                profile: p,
                                onTap: () => _selectProfile(context, p),
                                onEdit: () => _showAddEditProfileDialog(
                                  context,
                                  profileToEdit: p,
                                ),
                              ),
                            ),
                            if (provider.profiles.length < 5)
                              _AddProfileButton(
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
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: Text(
                'SUA CENTRAL DE MÍDIA  •  VERSÃO 1.1.1',
                textAlign: TextAlign.center,
                style: SabuflixTheme.label(fontSize: 9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final Profile profile;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _ProfileAvatar(
      {required this.profile, required this.onTap, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
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
                child: const Icon(Icons.person, size: 64, color: Colors.white),
              ),
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
                    child: const Icon(Icons.edit_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
              if (profile.maxAgeRating != '18')
                Positioned(
                  bottom: -4,
                  left: -4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: SabuflixTheme.accent,
                      borderRadius: SabuflixTheme.radiusSm,
                    ),
                    child: Text(
                      profile.maxAgeRating,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            profile.name,
            style: SabuflixTheme.body(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: SabuflixTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _AddProfileButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddProfileButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: SabuflixTheme.surface,
              borderRadius: SabuflixTheme.radiusLg,
              border: Border.all(color: SabuflixTheme.border, width: 2),
            ),
            child: const Icon(Icons.add_rounded,
                size: 64, color: SabuflixTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          Text(
            'Adicionar',
            style: SabuflixTheme.body(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: SabuflixTheme.textSecondary),
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
    _nameController =
        TextEditingController(text: widget.profileToEdit?.name ?? '');
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
        avatarUrl:
            'https://i.pravatar.cc/150?u=${DateTime.now().millisecondsSinceEpoch}',
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
      Provider.of<ProfileProvider>(context, listen: false)
          .deleteProfile(widget.profileToEdit!.id);
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
            Text(widget.profileToEdit == null ? 'Novo Perfil' : 'Editar Perfil',
                style: SabuflixTheme.headline(fontSize: 22)),
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
            Text('Classificação Máxima Permitida:',
                style: SabuflixTheme.body(color: SabuflixTheme.textSecondary)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _ageOptions.map((age) {
                final isSelected = _maxAgeRating == age;
                return ChoiceChip(
                  label: Text(age,
                      style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : SabuflixTheme.textSecondary)),
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
            Text('Cor do Ícone:',
                style: SabuflixTheme.body(color: SabuflixTheme.textSecondary)),
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
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
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
                    child: const Text('Excluir',
                        style: TextStyle(color: Colors.redAccent)),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar',
                      style: TextStyle(color: SabuflixTheme.textSecondary)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: SabuflixTheme.accent),
                  child: const Text('Salvar',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
