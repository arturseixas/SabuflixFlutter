import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/sabuflix_theme.dart';
import '../widgets/wordmark.dart';
import '../widgets/glass_container.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'categories_screen.dart';
import 'my_list_screen.dart';

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
  ];

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    CategoriesScreen(),
    MyListScreen(),
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
                    child: Row(
                      children: [
                        const _ProfileAvatar(),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Minha Conta', style: SabuflixTheme.caption(fontSize: 13, fontWeight: FontWeight.w600, color: SabuflixTheme.textPrimary)),
                              Text('Premium', style: SabuflixTheme.caption(fontSize: 12, color: SabuflixTheme.textMuted)),
                            ],
                          ),
                        ),
                      ],
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
                  _buildMobileDockItem(i, _destinations[i]),
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                size: 21,
              ),
              const SizedBox(height: 3),
              Text(
                destination.label,
                style: SabuflixTheme.caption(
                  fontSize: 10,
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: SabuflixTheme.elevated,
        shape: BoxShape.circle,
      ),
      child: Text(
        'S',
        style: SabuflixTheme.body(
          color: SabuflixTheme.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
