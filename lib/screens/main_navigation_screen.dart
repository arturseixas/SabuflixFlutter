import 'package:flutter/material.dart';
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
      backgroundColor: const Color(0xFF09090E),
      body: isDesktop
          ? Row(
              children: [
                // Desktop Navigation Sidebar
                Container(
                  width: 220,
                  color: const Color(0xFF0D0D14),
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      
                      // Sabuflix Brand Logo
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFE50914), size: 32),
                          const SizedBox(width: 8),
                          Text(
                            'SABUFLIX',
                            style: TextStyle(
                              color: const Color(0xFFE50914),
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              shadows: [
                                Shadow(
                                  color: const Color(0xFFE50914).withOpacity(0.5),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Navigation items
                      _buildNavItem(0, Icons.home_rounded, 'Início'),
                      _buildNavItem(1, Icons.search_rounded, 'Pesquisar'),
                      _buildNavItem(2, Icons.grid_view_rounded, 'Categorias'),
                      _buildNavItem(3, Icons.bookmark_rounded, 'Minha Lista'),
                      
                      const Spacer(),
                      
                      // User Profile Mock
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFFE50914),
                              child: const Text('S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Usuário Sabuflix',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                
                // Vertical divider line
                Container(width: 1, color: Colors.white10),

                // Main screen view
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _screens,
                  ),
                ),
              ],
            )
          : IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              backgroundColor: const Color(0xFF0D0D14),
              selectedItemColor: const Color(0xFFE50914),
              unselectedItemColor: Colors.white54,
              type: BottomNavigationBarType.fixed,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Início'),
                BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'Pesquisar'),
                BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Categorias'),
                BottomNavigationBarItem(icon: Icon(Icons.bookmark_rounded), label: 'Minha Lista'),
              ],
            ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: isSelected ? const Color(0xFFE50914) : Colors.transparent,
              width: 4,
            ),
          ),
          color: isSelected ? const Color(0xFFE50914).withOpacity(0.12) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFE50914) : Colors.white60,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
