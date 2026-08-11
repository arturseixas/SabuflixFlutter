import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'screens/profile_selection_screen.dart';
import 'tv/tv_platform.dart';
import 'tv/tv_remote.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Has to settle before the first frame: it decides whether the app builds
  // the touch interface or the 10-foot one.
  await TvPlatform.initialize();

  if (TvPlatform.isTv && !kIsWeb) {
    // A television is landscape, always, and the system bars have no business
    // on top of a full-screen catalogue.
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  runApp(const SabuflixApp());
}

class SabuflixApp extends StatelessWidget {
  const SabuflixApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => DownloadsProvider()),
        ChangeNotifierProvider(create: (_) => ContinueWatchingProvider()),
      ],
      // Rebuilds the whole tree when TV mode is switched by hand in Ajustes,
      // so the interface changes without restarting the app.
      child: ValueListenableBuilder<bool>(
        valueListenable: TvPlatform.modeChanged,
        builder: (context, _, __) => MaterialApp(
          title: 'Sabuflix - Streaming Platform',
          debugShowCheckedModeBanner: false,
          theme: SabuflixTheme.themeData,
          navigatorKey: appNavigatorKey,
          shortcuts: TvPlatform.isTv ? tvShortcuts : null,
          builder: (context, child) {
            Widget app = TvBackKeyHandler(
              navigatorKey: appNavigatorKey,
              child: child ?? const SizedBox.shrink(),
            );
            if (TvPlatform.isTv) {
              // TVs carry their own font-scaling setting, which can double the
              // type and break every fixed-height shelf. The 10-foot sizes are
              // already large, so the scale is pinned.
              app = MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
                child: app,
              );
            }
            return app;
          },
          home: const _AppLifecycleGate(child: ProfileSelectionScreen()),
        ),
      ),
    );
  }
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

class _AppLifecycleGateState extends State<_AppLifecycleGate> with WidgetsBindingObserver {
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
