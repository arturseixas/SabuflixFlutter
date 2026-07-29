import 'package:flutter/material.dart';
import '../theme/sabuflix_theme.dart';
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
      body: isDesktop
          ? Row(
              children: [
                // Claude / Anthropic Warm Dark Floating Sidebar
                Container(
                  width: 240,
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SabuflixTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: SabuflixTheme.border, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 28),

                      // Anthropic Brand Header: ✳ SABUFLIX
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            const Text(
                              '✳',
                              style: TextStyle(
                                color: SabuflixTheme.terracotta,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'SABUFLIX',
                              style: SabuflixTheme.serifHeader(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: SabuflixTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 36),

                      // Navigation menu items
                      _buildNavItem(0, Icons.home_rounded, 'Início'),
                      _buildNavItem(1, Icons.search_rounded, 'Pesquisar'),
                      _buildNavItem(2, Icons.grid_view_rounded, 'Categorias'),
                      _buildNavItem(3, Icons.bookmark_rounded, 'Minha Lista'),

                      const Spacer(),

                      // User Profile Container (Claude Style)
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: SabuflixTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: SabuflixTheme.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: SabuflixTheme.terracotta,
                              child: Text(
                                'S',
                                style: SabuflixTheme.sansBody(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Sabuflix Pro',
                                    style: SabuflixTheme.sansBody(
                                      color: SabuflixTheme.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Anthropic Edition',
                                    style: SabuflixTheme.sansBody(
                                      color: SabuflixTheme.textMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                // Main Content View
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: IndexedStack(
                      index: _currentIndex,
                      children: _screens,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            )
          : Stack(
              children: [
                IndexedStack(
                  index: _currentIndex,
                  children: _screens,
                ),

                // Mobile Floating Dock Navigation
                Positioned(
                  bottom: 20,
                  left: 24,
                  right: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: SabuflixTheme.surface.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(30), // Apple TV Dock
                      border: Border.all(color: SabuflixTheme.border, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMobileDockItem(0, Icons.home_rounded, 'Início'),
                        _buildMobileDockItem(1, Icons.search_rounded, 'Pesquisar'),
                        _buildMobileDockItem(2, Icons.grid_view_rounded, 'Categorias'),
                        _buildMobileDockItem(3, Icons.bookmark_rounded, 'Lista'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? SabuflixTheme.terracotta.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? SabuflixTheme.terracotta.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? SabuflixTheme.terracotta : SabuflixTheme.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: SabuflixTheme.sansBody(
                color: isSelected ? SabuflixTheme.textPrimary : SabuflixTheme.textSecondary,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileDockItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? SabuflixTheme.terracotta.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? SabuflixTheme.terracotta : SabuflixTheme.textSecondary,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: SabuflixTheme.sansBody(
                color: isSelected ? SabuflixTheme.textPrimary : SabuflixTheme.textMuted,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
