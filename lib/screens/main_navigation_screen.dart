import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/downloads_provider.dart';
import '../providers/profile_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../widgets/wordmark.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'categories_screen.dart';
import 'library_screen.dart';
import 'profile_selection_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _index = 0;
  final _visited = <int>{0};
  static const _labels = [
    'Início',
    'Pesquisar',
    'Explorar',
    'Biblioteca',
    'Ajustes',
  ];
  static const _icons = [
    Icons.home_outlined,
    Icons.search,
    Icons.grid_view_outlined,
    Icons.video_library_outlined,
    Icons.settings_outlined,
  ];
  static const _selectedIcons = [
    Icons.home_rounded,
    Icons.search_rounded,
    Icons.grid_view_rounded,
    Icons.video_library_rounded,
    Icons.settings_rounded,
  ];
  static const _pages = [
    HomeScreen(),
    SearchScreen(),
    CategoriesScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];
  void _select(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _index = index;
      _visited.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 800 &&
        MediaQuery.textScalerOf(context).scale(14) <= 20;
    final count = context.select<DownloadsProvider, int>((p) => p.activeCount);
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        appBar: desktop
            ? AppBar(
                backgroundColor: SabuflixTheme.of(context).background,
                toolbarHeight: 72,
                titleSpacing: 40,
                shape: Border(
                  bottom: BorderSide(
                      color: SabuflixTheme.of(context).border, width: .5),
                ),
                title: Row(
                  children: [
                    SabuflixWordmark(fontSize: 20),
                    SizedBox(width: 36),
                    for (var i = 0; i < _labels.length; i++)
                      Flexible(
                        child: Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: TextButton(
                            onPressed: () => _select(i),
                            style: TextButton.styleFrom(
                              foregroundColor: _index == i
                                  ? SabuflixTheme.of(context).textPrimary
                                  : SabuflixTheme.of(context).textMuted,
                              backgroundColor: Colors.transparent,
                              overlayColor: Colors.transparent,
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 18,
                              ),
                              textStyle: SabuflixTheme.of(context).label(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.2,
                              ),
                            ),
                            child: Semantics(
                              selected: _index == i,
                              child: Container(
                                padding: EdgeInsets.only(bottom: 4),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _index == i
                                          ? SabuflixTheme.of(context)
                                              .textPrimary
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  _labels[i],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                actions: [
                  Consumer<ProfileProvider>(
                    builder: (context, profiles, _) => IconButton(
                      tooltip:
                          'Trocar perfil: ${profiles.currentProfile?.name ?? ''}',
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ProfileSelectionScreen(),
                        ),
                      ),
                      icon: CircleAvatar(
                        radius: 15,
                        backgroundColor: Color(
                          profiles.currentProfile?.colorValue ?? 0xFF4285F4,
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          size: 21,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 32),
                ],
              )
            : null,
        body: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < _pages.length; i++)
              TickerMode(
                enabled: _index == i,
                child: _visited.contains(i) ? _pages[i] : SizedBox.shrink(),
              ),
          ],
        ),
        bottomNavigationBar: desktop
            ? null
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: SabuflixTheme.of(context).background,
                  border: Border(
                    top: BorderSide(
                        color: SabuflixTheme.of(context).border, width: .5),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 64,
                    child: Row(
                      children: [
                        for (var i = 0; i < _labels.length; i++)
                          Expanded(
                            child: _MobileNavItem(
                              label: _labels[i],
                              icon: _icons[i],
                              selectedIcon: _selectedIcons[i],
                              selected: _index == i,
                              badgeCount: i == 3 ? count : 0,
                              onTap: () => _select(i),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  const _MobileNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? SabuflixTheme.of(context).textPrimary
        : SabuflixTheme.of(context).textMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 30,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badgeCount > 0,
              backgroundColor: Colors.white,
              textColor: Colors.black,
              smallSize: 6,
              largeSize: 16,
              label: Text('$badgeCount'),
              child: AnimatedSwitcher(
                duration: SabuflixTheme.durationFast,
                child: Icon(
                  selected ? selectedIcon : icon,
                  key: ValueKey(selected),
                  color: color,
                  size: 23,
                ),
              ),
            ),
            SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: SabuflixTheme.durationFast,
              style: SabuflixTheme.of(context).caption(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: .1,
                color: color,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.fade),
            ),
          ],
        ),
      ),
    );
  }
}
