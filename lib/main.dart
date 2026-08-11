import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'theme/sabuflix_theme.dart';
import 'providers/cast_provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/continue_watching_provider.dart';
import 'providers/downloads_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/search_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/playlist_provider.dart';
import 'screens/profile_selection_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
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
        ChangeNotifierProvider(create: (_) => CastProvider()),
      ],
      child: MaterialApp(
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
