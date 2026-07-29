import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/sabuflix_theme.dart';
import '../widgets/wordmark.dart';
import '../widgets/glass_container.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'categories_screen.dart';
import 'my_list_screen.dart';
import 'playlists_screen.dart';
import 'profile_selection_screen.dart';
import '../providers/profile_provider.dart';
import 'package:provider/provider.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  static const List<_NavDestination> _destinations = [
    _NavDestination(Icons.home, Icons.home_outlined, 'Início'),
    _NavDestination(Icons.search, Icons.search, 'Pesquisar'),
    _NavDestination(Icons.category, Icons.category_outlined, 'Categorias'),
    _NavDestination(Icons.bookmark, Icons.bookmark_border, 'Minha Lista'),
    _NavDestination(Icons.featured_play_list, Icons.featured_play_list_outlined, 'Playlists'),
  ];

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    CategoriesScreen(),
    MyListScreen(),
    PlaylistsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return Scaffold(
      backgroundColor: SabuflixTheme.background,
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
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
                    _buildNavItem(i, _destinations[i]),
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

  Widget _buildMobileLayout() {
    return Stack(
      children: [
        IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 24,
          child: GlassContainer(
            borderRadius: SabuflixTheme.radiusPill,
            blur: 32,
            fillOpacity: 0.4,
            hasGlow: true,
            glowColor: SabuflixTheme.accent.withValues(alpha: 0.25),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (int i = 0; i < _destinations.length; i++)
                  Expanded(child: _buildMobileDockItem(i, _destinations[i])),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(int index, _NavDestination destination) {
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
                Icon(
                  isSelected ? destination.filledIcon : destination.outlineIcon,
                  color: isSelected ? SabuflixTheme.accent : SabuflixTheme.textMuted,
                  size: 19,
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

  Widget _buildMobileDockItem(int index, _NavDestination destination) {
    final isSelected = _currentIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: SabuflixTheme.radiusPill,
        child: AnimatedContainer(
          duration: SabuflixTheme.durationFast,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? SabuflixTheme.accent.withValues(alpha: 0.22) : Colors.transparent,
            borderRadius: SabuflixTheme.radiusPill,
            border: isSelected ? Border.all(color: SabuflixTheme.accent.withValues(alpha: 0.4), width: 1) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? destination.filledIcon : destination.outlineIcon,
                color: isSelected ? SabuflixTheme.accent : SabuflixTheme.textMuted,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SabuflixTheme.caption(
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? SabuflixTheme.accent : SabuflixTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavDestination {
  final IconData filledIcon;
  final IconData outlineIcon;
  final String label;
  const _NavDestination(this.filledIcon, this.outlineIcon, this.label);
}


