import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'home_screen.dart';
import 'main_navigation_screen.dart';

class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({super.key});
  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen> {
  bool _selecting = false;

  Future<bool> _unlock(Profile profile, {String? reason}) async {
    if (!profile.hasPin) return true;
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => _PinDialog(
        title: reason ?? 'Perfil de ${profile.name}',
        subtitle: 'Digite o PIN de 4 dígitos para continuar.',
        validate: profile.checkPin,
      ),
    );
    return pin != null;
  }

  void _selectProfile(BuildContext context, Profile profile) async {
    if (_selecting) return;
    if (!await _unlock(profile)) return;
    if (!context.mounted) return;
    setState(() => _selecting = true);
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
      if (context.mounted) {
        setState(() => _selecting = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Não foi possível abrir este perfil. Tente novamente.')));
      }
      return;
    }

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
      );
    }
  }

  Future<void> _showAddEditProfileDialog(BuildContext context,
      {Profile? profileToEdit}) async {
    if (profileToEdit != null &&
        !await _unlock(profileToEdit, reason: 'Editar ${profileToEdit.name}')) {
      return;
    }
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => _ProfileDialog(profileToEdit: profileToEdit),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SabuflixTheme.of(context).background,
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
                  return Center(
                    child: CircularProgressIndicator(
                        color: SabuflixTheme.of(context).accent),
                  );
                }

                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 100, 24, 90),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _selecting
                              ? 'Preparando seu perfil…'
                              : 'Quem está assistindo?',
                          textAlign: TextAlign.center,
                          style: SabuflixTheme.of(context).headline(
                              fontSize: 32, fontWeight: FontWeight.w600),
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
                                onEdit: () => _showAddEditProfileDialog(context,
                                    profileToEdit: p),
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
                'Seu próximo filme começa aqui.',
                textAlign: TextAlign.center,
                style: SabuflixTheme.of(context).label(fontSize: 9),
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
    return InkWell(
      borderRadius: SabuflixTheme.radiusLg,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
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
                child: Icon(profileIcon(profile.avatar),
                    size: 64, color: Colors.white),
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
              if (profile.hasPin)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_rounded,
                        color: Colors.white, size: 14),
                  ),
                ),
              if (profile.isKids || profile.maxAgeRating != '18')
                Positioned(
                  bottom: -6,
                  left: -6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: profile.isKids
                          ? const Color(0xFF34A853)
                          : SabuflixTheme.brandBlue,
                      borderRadius: SabuflixTheme.radiusSm,
                    ),
                    child: Text(
                      profile.isKids ? 'INFANTIL' : profile.maxAgeRating,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: .4),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            profile.name,
            style: SabuflixTheme.of(context).body(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: SabuflixTheme.of(context).textPrimary),
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
    return InkWell(
      borderRadius: SabuflixTheme.radiusLg,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: SabuflixTheme.of(context).surface,
              borderRadius: SabuflixTheme.radiusLg,
              border:
                  Border.all(color: SabuflixTheme.of(context).border, width: 2),
            ),
            child: Icon(Icons.add_rounded,
                size: 64, color: SabuflixTheme.of(context).textSecondary),
          ),
          const SizedBox(height: 12),
          Text(
            'Adicionar',
            style: SabuflixTheme.of(context).body(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: SabuflixTheme.of(context).textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Four-digit PIN prompt. Pops with the PIN when [validate] accepts it.
class _PinDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool Function(String pin) validate;
  const _PinDialog(
      {required this.title, required this.subtitle, required this.validate});

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _controller.text.trim();
    if (widget.validate(pin)) {
      Navigator.pop(context, pin);
    } else {
      setState(() => _error = 'PIN incorreto. Tente novamente.');
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = SabuflixTheme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.subtitle, style: colors.body(fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: colors.headline(fontSize: 28, letterSpacing: 8),
            decoration: InputDecoration(
                counterText: '', errorText: _error, hintText: '••••'),
            onChanged: (value) {
              if (value.length == 4) _submit();
            },
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Entrar')),
      ],
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
  late TextEditingController _pinController;
  late String _maxAgeRating;
  late int _colorValue;
  late String _avatar;
  late bool _isKids;
  late bool _usePin;
  bool _changePin = false;

  final List<String> _ageOptions = ['Livre', '10', '12', '14', '16', '18'];
  final List<int> _colorOptions = [
    0xFF4285F4, // Blue
    0xFFEA4335, // Red
    0xFFFBBC05, // Yellow
    0xFF34A853, // Green
    0xFF9C27B0, // Purple
    0xFFFF9800, // Orange
    0xFF00BCD4, // Cyan
    0xFFE91E63, // Pink
  ];

  @override
  void initState() {
    super.initState();
    final profile = widget.profileToEdit;
    _nameController = TextEditingController(text: profile?.name ?? '');
    _pinController = TextEditingController();
    _maxAgeRating = profile?.maxAgeRating ?? '18';
    _colorValue = profile?.colorValue ?? _colorOptions[0];
    _avatar = profile?.avatar ?? 'person';
    _isKids = profile?.isKids ?? false;
    _usePin = profile?.hasPin ?? false;
    _changePin = profile == null || !profile.hasPin;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) return;
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    final pin = _pinController.text.trim();
    if (_usePin && _changePin && pin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('O PIN precisa ter 4 dígitos.')));
      return;
    }
    final pinHash = !_usePin
        ? null
        : _changePin
            ? Profile.hashPin(pin)
            : widget.profileToEdit?.pinHash;
    final rating = _isKids && _ageOptions.indexOf(_maxAgeRating) > 2
        ? '12'
        : _maxAgeRating;

    if (widget.profileToEdit == null) {
      provider.addProfile(Profile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        avatarUrl: '',
        maxAgeRating: rating,
        colorValue: _colorValue,
        avatar: _avatar,
        pinHash: pinHash,
        isKids: _isKids,
      ));
    } else {
      provider.updateProfile(widget.profileToEdit!.copyWith(
        name: _nameController.text.trim(),
        maxAgeRating: rating,
        colorValue: _colorValue,
        avatar: _avatar,
        pinHash: pinHash,
        clearPin: !_usePin,
        isKids: _isKids,
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
    final colors = SabuflixTheme.of(context);
    final ageOptions = _isKids ? _ageOptions.take(3).toList() : _ageOptions;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: GlassContainer(
          borderRadius: SabuflixTheme.radiusLg,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    widget.profileToEdit == null
                        ? 'Novo perfil'
                        : 'Editar perfil',
                    style: colors.headline(fontSize: 22)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Color(_colorValue),
                        borderRadius: SabuflixTheme.radiusMd,
                      ),
                      child: Icon(profileIcon(_avatar),
                          size: 36, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        autofocus: widget.profileToEdit == null,
                        maxLength: 20,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: const InputDecoration(
                            labelText: 'Nome do perfil', counterText: ''),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Ícone', style: colors.label(fontSize: 11)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final key in profileAvatarKeys)
                      InkWell(
                        borderRadius: SabuflixTheme.radiusMd,
                        onTap: () => setState(() => _avatar = key),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _avatar == key
                                ? Color(_colorValue)
                                : colors.secondaryFill,
                            borderRadius: SabuflixTheme.radiusMd,
                            border: Border.all(
                                color: _avatar == key
                                    ? Colors.white
                                    : colors.border),
                          ),
                          child: Icon(profileIcon(key),
                              color: _avatar == key
                                  ? Colors.white
                                  : colors.textSecondary),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Cor', style: colors.label(fontSize: 11)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _colorOptions.map((c) {
                    final isSelected = _colorValue == c;
                    return GestureDetector(
                      onTap: () => setState(() => _colorValue = c),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: colors.textPrimary, width: 3)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _isKids,
                  onChanged: (value) => setState(() {
                    _isKids = value;
                    if (value && _ageOptions.indexOf(_maxAgeRating) > 2) {
                      _maxAgeRating = '12';
                    }
                  }),
                  title: const Text('Perfil infantil'),
                  subtitle: const Text(
                      'Início com animações e conteúdo para a família; classificação até 12 anos.'),
                ),
                const SizedBox(height: 8),
                Text('Classificação máxima', style: colors.label(fontSize: 11)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ageOptions.map((age) {
                    final isSelected = _maxAgeRating == age;
                    return ChoiceChip(
                      label: Text(age),
                      selected: isSelected,
                      showCheckmark: false,
                      onSelected: (selected) {
                        if (selected) setState(() => _maxAgeRating = age);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _usePin,
                  onChanged: (value) => setState(() {
                    _usePin = value;
                    if (value && !(widget.profileToEdit?.hasPin ?? false)) {
                      _changePin = true;
                    }
                  }),
                  title: const Text('Proteger com PIN'),
                  subtitle: const Text(
                      'Pede um PIN de 4 dígitos para entrar neste perfil.'),
                ),
                if (_usePin)
                  Row(
                    children: [
                      Expanded(
                        child: _changePin
                            ? TextField(
                                controller: _pinController,
                                obscureText: true,
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                style: TextStyle(
                                    color: colors.textPrimary,
                                    letterSpacing: 6),
                                decoration: const InputDecoration(
                                    labelText: 'Novo PIN',
                                    counterText: '',
                                    hintText: '••••'),
                              )
                            : Text('PIN definido.',
                                style: colors.body(fontSize: 13)),
                      ),
                      if (!_changePin)
                        TextButton(
                          onPressed: () => setState(() => _changePin = true),
                          child: const Text('Alterar PIN'),
                        ),
                    ],
                  ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    if (widget.profileToEdit != null &&
                        context.read<ProfileProvider>().profiles.length > 1)
                      TextButton(
                        onPressed: _delete,
                        child: Text('Excluir',
                            style: TextStyle(color: colors.error)),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancelar',
                          style: TextStyle(color: colors.textSecondary)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _save,
                      child: const Text('Salvar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
