import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/sabuflix_theme.dart';
import '../widgets/wordmark.dart';
import '../widgets/glass_container.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'categories_screen.dart';
import 'downloads_screen.dart';
import 'my_list_screen.dart';
import 'playlists_screen.dart';
import 'profile_selection_screen.dart';
import '../providers/downloads_provider.dart';
import '../providers/profile_provider.dart';
import 'package:provider/provider.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

/// Index of the Downloads tab inside [_MainNavigationScreenState._destinations].
const int _downloadsIndex = 3;

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  static const List<_NavDestination> _destinations = [
    _NavDestination(Icons.home, Icons.home_outlined, 'Início'),
    _NavDestination(Icons.search, Icons.search, 'Pesquisar', shortLabel: 'Buscar'),
    _NavDestination(Icons.category, Icons.category_outlined, 'Categorias', shortLabel: 'Gêneros'),
    _NavDestination(Icons.download_rounded, Icons.download_outlined, 'Downloads'),
    _NavDestination(Icons.bookmark, Icons.bookmark_border, 'Minha Lista', shortLabel: 'Lista'),
    _NavDestination(Icons.featured_play_list, Icons.featured_play_list_outlined, 'Playlists'),
  ];

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    CategoriesScreen(),
    DownloadsScreen(),
    MyListScreen(),
    PlaylistsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    // Only rebuilds the chrome when the number of pending downloads changes,
    // not on every progress tick.
    final activeDownloads = context.select<DownloadsProvider, int>((provider) => provider.activeCount);

    return Scaffold(
      backgroundColor: SabuflixTheme.background,
      body: isDesktop ? _buildDesktopLayout(activeDownloads) : _buildMobileLayout(context, activeDownloads),
    );
  }

  Widget _buildDesktopLayout(int activeDownloads) {
    return Row(
      children: [
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              width: 240,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: SabuflixTheme.surface.withValues(alpha: 0.6),
                border: const Border(right: BorderSide(color: SabuflixTheme.border, width: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    child: SabuflixWordmark(fontSize: 19),
                  ),
                  const SizedBox(height: 36),
                  for (int i = 0; i < _destinations.length; i++)
                    _buildNavItem(i, _destinations[i], activeDownloads),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Consumer<ProfileProvider>(
                      builder: (context, profileProvider, child) {
                        final profile = profileProvider.currentProfile;
                        if (profile == null) return const SizedBox.shrink();
                        return GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfileSelectionScreen()));
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Color(profile.colorValue),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person, size: 20, color: Colors.white),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(profile.name, style: SabuflixTheme.caption(fontSize: 13, fontWeight: FontWeight.w600, color: SabuflixTheme.textPrimary)),
                                    Text('Trocar Perfil', style: SabuflixTheme.caption(fontSize: 12, color: SabuflixTheme.accent)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, int activeDownloads) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: bottomSafeArea > 0 ? bottomSafeArea + 6 : 22,
          child: Center(
            child: ConstrainedBox(
              // Keeps the dock centred and finger-sized instead of stretching
              // edge to edge on wide phones and small tablets.
              constraints: const BoxConstraints(maxWidth: 460),
              child: GlassContainer(
                borderRadius: SabuflixTheme.radiusPill,
                blur: 32,
                fillOpacity: 0.4,
                hasGlow: true,
                glowColor: SabuflixTheme.accent.withValues(alpha: 0.25),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (int i = 0; i < _destinations.length; i++)
                      _buildMobileDockItem(i, _destinations[i], activeDownloads),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(int index, _NavDestination destination, int activeDownloads) {
    final isSelected = _currentIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _currentIndex = index),
          borderRadius: SabuflixTheme.radiusPill,
          child: AnimatedContainer(
            duration: SabuflixTheme.durationFast,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: isSelected ? SabuflixTheme.accent.withValues(alpha: 0.18) : Colors.transparent,
              borderRadius: SabuflixTheme.radiusPill,
              border: isSelected ? Border.all(color: SabuflixTheme.accent.withValues(alpha: 0.4), width: 1) : null,
            ),
            child: Row(
              children: [
                _DockIcon(
                  destination: destination,
                  isSelected: isSelected,
                  size: 19,
                  showBadge: index == _downloadsIndex && activeDownloads > 0,
                ),
                const SizedBox(width: 14),
                Text(
                  destination.label,
                  style: SabuflixTheme.body(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? SabuflixTheme.accent : SabuflixTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Dock item in the iOS idiom: only the active tab spells out its name, the
  /// rest stay as icons. Six destinations then fit a narrow phone without the
  /// 9pt labels that used to overflow, and the label never has to be truncated.
  Widget _buildMobileDockItem(int index, _NavDestination destination, int activeDownloads) {
    final isSelected = _currentIndex == index;

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: SabuflixTheme.radiusPill,
        child: AnimatedContainer(
          duration: SabuflixTheme.durationFast,
          curve: SabuflixTheme.curveStandard,
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: isSelected ? 13 : 9),
          decoration: BoxDecoration(
            color: isSelected ? SabuflixTheme.accent.withValues(alpha: 0.22) : Colors.transparent,
            borderRadius: SabuflixTheme.radiusPill,
            border: isSelected ? Border.all(color: SabuflixTheme.accent.withValues(alpha: 0.4), width: 1) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DockIcon(
                destination: destination,
                isSelected: isSelected,
                size: 21,
                showBadge: index == _downloadsIndex && activeDownloads > 0,
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    destination.dockLabel,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: SabuflixTheme.caption(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: SabuflixTheme.accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    // Only the expanded item competes for the leftover width.
    return isSelected ? Flexible(child: button) : button;
  }
}

/// Tab glyph with the little "something is downloading" dot.
class _DockIcon extends StatelessWidget {
  final _NavDestination destination;
  final bool isSelected;
  final double size;
  final bool showBadge;

  const _DockIcon({
    required this.destination,
    required this.isSelected,
    required this.size,
    required this.showBadge,
  });

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      isSelected ? destination.filledIcon : destination.outlineIcon,
      color: isSelected ? SabuflixTheme.accent : SabuflixTheme.textMuted,
      size: size,
    );

    if (!showBadge) return icon;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          top: -1,
          right: -2,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: SabuflixTheme.accent,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

class _NavDestination {
  final IconData filledIcon;
  final IconData outlineIcon;

  /// Full name, used in the desktop sidebar.
  final String label;

  /// Shorter name for the phone dock, where the active pill has to share the
  /// row with five other icons.
  final String? shortLabel;

  const _NavDestination(this.filledIcon, this.outlineIcon, this.label, {this.shortLabel});

  String get dockLabel => shortLabel ?? label;
}


