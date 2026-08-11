import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/downloads_provider.dart';
import '../providers/profile_provider.dart';
import '../screens/categories_screen.dart';
import '../screens/downloads_screen.dart';
import '../screens/home_screen.dart';
import '../screens/my_list_screen.dart';
import '../screens/playlists_screen.dart';
import '../screens/profile_selection_screen.dart';
import '../screens/search_screen.dart';
import '../theme/sabuflix_theme.dart';
import '../widgets/wordmark.dart';
import 'tv_focus.dart';
import 'tv_metrics.dart';
import 'tv_platform.dart';
import 'tv_settings_screen.dart';

/// The living-room home screen: a focusable rail on the left, the current
/// section on the right.
///
/// A rail rather than the phone's floating dock, because a D-pad reaches a
/// vertical list in one press from anywhere in the content, and because the
/// bottom edge of a TV picture is the least reliable part of the panel.
class TvShell extends StatefulWidget {
  const TvShell({Key? key}) : super(key: key);

  @override
  State<TvShell> createState() => _TvShellState();
}

class _TvShellState extends State<TvShell> {
  int _currentIndex = 0;
  bool _railFocused = false;
  DateTime? _lastBackPress;

  final FocusNode _railGroupNode = FocusNode(debugLabel: 'tv-rail', skipTraversal: true);
  late final List<_TvDestination> _destinations = _buildDestinations();
  late final List<FocusNode> _railNodes =
      List.generate(_destinations.length, (i) => FocusNode(debugLabel: 'tv-rail-$i'));

  static List<_TvDestination> _buildDestinations() {
    return [
      const _TvDestination(Icons.home_rounded, Icons.home_outlined, 'Início', HomeScreen()),
      const _TvDestination(Icons.search_rounded, Icons.search_rounded, 'Pesquisar', SearchScreen()),
      const _TvDestination(Icons.grid_view_rounded, Icons.grid_view_outlined, 'Categorias', CategoriesScreen()),
      const _TvDestination(Icons.bookmark_rounded, Icons.bookmark_border_rounded, 'Minha Lista', MyListScreen()),
      const _TvDestination(
        Icons.featured_play_list_rounded,
        Icons.featured_play_list_outlined,
        'Playlists',
        PlaylistsScreen(),
      ),
      // The browser-based TVs have no filesystem to download into, so the tab
      // only exists where it can actually do something.
      if (TvPlatform.supportsDownloads)
        const _TvDestination(Icons.download_rounded, Icons.download_outlined, 'Downloads', DownloadsScreen()),
      const _TvDestination(Icons.settings_rounded, Icons.settings_outlined, 'Ajustes', TvSettingsScreen()),
    ];
  }

  @override
  void initState() {
    super.initState();
    // Directional traversal can only move a focus that already exists. The
    // shell opens with an empty content area (the catalogue is still loading),
    // so without this the very first press of the remote would go nowhere and
    // the app would look frozen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusRailIfIdle());
  }

  void _focusRailIfIdle() {
    if (!mounted) return;
    if (FocusScope.of(context).focusedChild != null) return;
    _railNodes[_currentIndex].requestFocus();
  }

  @override
  void dispose() {
    _railGroupNode.dispose();
    for (final node in _railNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _select(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  /// Back walks the interface the way a remote user expects: out of the
  /// content into the rail, from a section back to Início, and only then out
  /// of the app — with a confirmation, so a stray press never kills playback
  /// setup or a half-typed search.
  Future<void> _handleBack() async {
    if (!_railFocused) {
      _railNodes[_currentIndex].requestFocus();
      return;
    }

    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      _railNodes[0].requestFocus();
      return;
    }

    final now = DateTime.now();
    final recent = _lastBackPress != null && now.difference(_lastBackPress!) < const Duration(seconds: 3);
    if (recent) {
      await SystemNavigator.pop();
      return;
    }
    _lastBackPress = now;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pressione Voltar novamente para sair'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metrics = TvMetrics.of(context);
    final overscan = metrics.overscan;
    final activeDownloads = TvPlatform.supportsDownloads
        ? context.select<DownloadsProvider, int>((provider) => provider.activeCount)
        : 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: SabuflixTheme.background,
        body: Row(
          children: [
            Focus(
              focusNode: _railGroupNode,
              canRequestFocus: false,
              onFocusChange: (focused) => setState(() => _railFocused = focused),
              child: _TvNavRail(
                destinations: _destinations,
                nodes: _railNodes,
                currentIndex: _currentIndex,
                expanded: _railFocused,
                activeDownloads: activeDownloads,
                leftInset: overscan.left,
                onSelected: _select,
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  top: overscan.top * 0.5,
                  right: overscan.right,
                  bottom: overscan.bottom * 0.5,
                ),
                child: FocusTraversalGroup(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      // Every section stays alive so its scroll position and
                      // loaded data survive a trip through the rail — but the
                      // hidden ones must not answer the remote, or focus would
                      // vanish into a screen nobody can see.
                      for (int i = 0; i < _destinations.length; i++)
                        ExcludeFocus(
                          excluding: i != _currentIndex,
                          child: _destinations[i].screen,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TvNavRail extends StatelessWidget {
  final List<_TvDestination> destinations;
  final List<FocusNode> nodes;
  final int currentIndex;
  final bool expanded;
  final int activeDownloads;
  final double leftInset;
  final ValueChanged<int> onSelected;

  const _TvNavRail({
    required this.destinations,
    required this.nodes,
    required this.currentIndex,
    required this.expanded,
    required this.activeDownloads,
    required this.leftInset,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = TvMetrics.of(context);

    return AnimatedContainer(
      duration: SabuflixTheme.durationMed,
      curve: SabuflixTheme.curveStandard,
      width: (expanded ? metrics.railExpandedWidth : metrics.railWidth) + leftInset,
      padding: EdgeInsets.only(left: leftInset, top: metrics.overscan.top, bottom: metrics.overscan.bottom),
      decoration: BoxDecoration(
        // A solid gradient rather than a blur: BackdropFilter is the single
        // most expensive thing a TV GPU can be asked to do every frame, and
        // the cheap sets simply drop it.
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            SabuflixTheme.background,
            SabuflixTheme.background.withValues(alpha: expanded ? 0.94 : 0.75),
            SabuflixTheme.background.withValues(alpha: expanded ? 0.7 : 0.0),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 72,
            child: expanded
                ? const Padding(
                    padding: EdgeInsets.only(left: 26),
                    child: Align(alignment: Alignment.centerLeft, child: SabuflixWordmark(fontSize: 28)),
                  )
                : const Center(child: SabuflixWordmark(fontSize: 22, text: 'S')),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: FocusTraversalGroup(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: destinations.length,
                itemBuilder: (context, index) => _TvRailItem(
                  destination: destinations[index],
                  node: nodes[index],
                  selected: index == currentIndex,
                  expanded: expanded,
                  showBadge: destinations[index].label == 'Downloads' && activeDownloads > 0,
                  onPressed: () => onSelected(index),
                ),
              ),
            ),
          ),
          _TvProfileButton(expanded: expanded),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _TvRailItem extends StatelessWidget {
  final _TvDestination destination;
  final FocusNode node;
  final bool selected;
  final bool expanded;
  final bool showBadge;
  final VoidCallback onPressed;

  const _TvRailItem({
    required this.destination,
    required this.node,
    required this.selected,
    required this.expanded,
    required this.showBadge,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = TvMetrics.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: TvFocusable(
        focusNode: node,
        showRing: false,
        scaleOnFocus: false,
        scrollAlignment: 0.5,
        semanticLabel: destination.label,
        // Moving the highlight down the rail switches the section straight
        // away, the way every TV launcher behaves — OK is then only needed to
        // step into the content.
        onFocused: onPressed,
        onPressed: onPressed,
        builder: (context, focused, child) {
          final Color foreground = focused
              ? SabuflixTheme.background
              : selected
                  ? SabuflixTheme.textPrimary
                  : SabuflixTheme.textMuted;

          return AnimatedContainer(
            duration: SabuflixTheme.durationFast,
            curve: SabuflixTheme.curveStandard,
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: focused
                  ? SabuflixTheme.textPrimary
                  : selected
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.transparent,
              borderRadius: SabuflixTheme.radiusPill,
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      selected || focused ? destination.filledIcon : destination.outlineIcon,
                      size: metrics.iconSize,
                      color: foreground,
                    ),
                    if (showBadge)
                      Positioned(
                        top: -2,
                        right: -3,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(color: SabuflixTheme.accent, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
                if (expanded) ...[
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SabuflixTheme.body(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        child: const SizedBox.shrink(),
      ),
    );
  }
}

class _TvProfileButton extends StatelessWidget {
  final bool expanded;

  const _TvProfileButton({required this.expanded});

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, provider, child) {
        final profile = provider.currentProfile;
        if (profile == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TvFocusable(
            showRing: false,
            scaleOnFocus: false,
            semanticLabel: 'Trocar de perfil',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ProfileSelectionScreen()),
              );
            },
            builder: (context, focused, child) => AnimatedContainer(
              duration: SabuflixTheme.durationFast,
              height: 62,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: focused ? SabuflixTheme.textPrimary : Colors.transparent,
                borderRadius: SabuflixTheme.radiusPill,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: Color(profile.colorValue), shape: BoxShape.circle),
                    child: const Icon(Icons.person, size: 24, color: Colors.white),
                  ),
                  if (expanded) ...[
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            profile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SabuflixTheme.body(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: focused ? SabuflixTheme.background : SabuflixTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Trocar perfil',
                            maxLines: 1,
                            style: SabuflixTheme.caption(
                              fontSize: 14,
                              color: focused ? SabuflixTheme.background : SabuflixTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            child: const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

class _TvDestination {
  final IconData filledIcon;
  final IconData outlineIcon;
  final String label;
  final Widget screen;

  const _TvDestination(this.filledIcon, this.outlineIcon, this.label, this.screen);
}
