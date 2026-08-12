import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'theme/sabuflix_theme.dart';
import 'providers/catalog_provider.dart';
import 'providers/continue_watching_provider.dart';
import 'providers/downloads_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/search_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/playlist_provider.dart';
import 'screens/pip_player_window.dart';
import 'screens/profile_selection_screen.dart';
import 'services/pip/pip_window_args.dart';
import 'services/pip/pip_window_controller.dart';

/// `desktop_multi_window` runs the Picture-in-Picture floating window as a
/// second Flutter engine, re-entering this same `main()` with
/// `["multi_window", windowId, argsJson]` instead of the normal empty
/// argument list — that's the only signal telling this process which root
/// widget to boot. Every other platform/launch path falls through to the
/// regular app below untouched.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // `ensureInitialized` is the only thing that tells window_manager which
  // native window it controls — every later call (show, resize, always-on-top)
  // acts on an uninitialized handle without it, silently doing nothing. Each
  // Flutter engine gets its own plugin instance, so the Picture-in-Picture
  // window below has to do this for itself as much as the main window does.
  if (_isDesktop) {
    await windowManager.ensureInitialized();
  }

  if (args.isNotEmpty && args.first == 'multi_window') {
    final pipArgs = PipWindowArgs.fromArguments(args.length > 2 ? args[2] : '');
    runApp(PipPlayerWindow(args: pipArgs));
    return;
  }

  runApp(const SabuflixApp());
}

/// Uses `defaultTargetPlatform` rather than `dart:io`'s `Platform` so this
/// file stays compilable for the web target.
bool get _isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS);

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
      child: MaterialApp(
        navigatorKey: pipNavigatorKey,
        title: 'Sabuflix - Streaming Platform',
        debugShowCheckedModeBanner: false,
        theme: SabuflixTheme.themeData,
        home: const _AppLifecycleGate(child: ProfileSelectionScreen()),
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
