import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'theme/sabuflix_theme.dart';
import 'providers/catalog_provider.dart';
import 'providers/continue_watching_provider.dart';
import 'providers/downloads_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/search_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/watched_provider.dart';
import 'screens/profile_selection_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const SabuflixApp());
}

class SabuflixApp extends StatelessWidget {
  const SabuflixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => DownloadsProvider()),
        ChangeNotifierProvider(create: (_) => ContinueWatchingProvider()),
        ChangeNotifierProvider(create: (_) => WatchedProvider()),
      ],
      child: MaterialApp(
        title: 'Sabuflix',
        debugShowCheckedModeBanner: false,
        theme: SabuflixTheme.themeData,
        themeMode: ThemeMode.dark,
        scrollBehavior: const _SabuflixScrollBehavior(),
        home: const _AppLifecycleGate(child: ProfileSelectionScreen()),
      ),
    );
  }
}

class _SabuflixScrollBehavior extends MaterialScrollBehavior {
  const _SabuflixScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// Re-syncs the offline library whenever the app comes back to the foreground.
///
/// Downloads live on disk, and the system (or the user, through the OS storage
/// settings) can remove those files while Sabuflix is in the background. Without
/// this pass the library would keep advertising titles that are no longer
/// playable until the app was killed and started again.
class _AppLifecycleGate extends StatefulWidget {
  final Widget child;

  const _AppLifecycleGate({required this.child});

  @override
  State<_AppLifecycleGate> createState() => _AppLifecycleGateState();
}

class _AppLifecycleGateState extends State<_AppLifecycleGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    context.read<DownloadsProvider>().refreshFromDisk();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
