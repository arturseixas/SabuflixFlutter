import 'package:flutter/material.dart';
import '../theme/sabuflix_theme.dart';
import '../widgets/wordmark.dart';
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
    _NavDestination(Icons.home_rounded, 'Início'),
    _NavDestination(Icons.search_rounded, 'Pesquisar'),
    _NavDestination(Icons.grid_view_rounded, 'Categorias'),
    _NavDestination(Icons.bookmark_rounded, 'Minha Lista'),
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
        Container(
          width: 248,
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: const BoxDecoration(
            color: SabuflixTheme.surface,
            border: Border(right: BorderSide(color: SabuflixTheme.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: SabuflixWordmark(fontSize: 21),
              ),
              const SizedBox(height: 40),
              for (int i = 0; i < _destinations.length; i++)
                _buildNavItem(i, _destinations[i]),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SabuflixTheme.surfaceLight,
                    borderRadius: SabuflixTheme.radiusMd,
                    border: Border.all(color: SabuflixTheme.border),
                  ),
                  child: Row(
                    children: [
                      const _ProfileAvatar(),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Minha Conta', style: SabuflixTheme.body(fontSize: 13, fontWeight: FontWeight.w600, color: SabuflixTheme.textPrimary)),
                            Text('Plano Premium', style: SabuflixTheme.body(fontSize: 11, color: SabuflixTheme.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
          bottom: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: SabuflixTheme.surface.withValues(alpha: 0.96),
              borderRadius: SabuflixTheme.radiusXl,
              border: Border.all(color: SabuflixTheme.border),
              boxShadow: SabuflixTheme.shadowMd,
            ),
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
          borderRadius: SabuflixTheme.radiusMd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? SabuflixTheme.surfaceLight : Colors.transparent,
              borderRadius: SabuflixTheme.radiusMd,
            ),
            child: Row(
              children: [
                Icon(
                  destination.icon,
                  color: isSelected ? SabuflixTheme.textPrimary : SabuflixTheme.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 14),
                Text(
                  destination.label,
                  style: SabuflixTheme.body(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? SabuflixTheme.textPrimary : SabuflixTheme.textMuted,
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
        borderRadius: SabuflixTheme.radiusLg,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? SabuflixTheme.surfaceLight : Colors.transparent,
            borderRadius: SabuflixTheme.radiusLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                destination.icon,
                color: isSelected ? SabuflixTheme.accent : SabuflixTheme.textMuted,
                size: 22,
              ),
              const SizedBox(height: 3),
              Text(
                destination.label,
                style: SabuflixTheme.caption(
                  fontSize: 10,
                  letterSpacing: 0,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? SabuflixTheme.textPrimary : SabuflixTheme.textMuted,
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
  final IconData icon;
  final String label;
  const _NavDestination(this.icon, this.label);
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SabuflixTheme.elevated,
        shape: BoxShape.circle,
        border: Border.all(color: SabuflixTheme.borderStrong),
      ),
      child: Text(
        'S',
        style: SabuflixTheme.body(
          color: SabuflixTheme.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}
