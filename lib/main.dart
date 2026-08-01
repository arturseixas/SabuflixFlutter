import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'theme/sabuflix_theme.dart';
import 'providers/catalog_provider.dart';
import 'providers/search_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/watch_history_provider.dart';
import 'providers/downloads_provider.dart';
import 'providers/cast_provider.dart';
import 'providers/pip_controller.dart';
import 'screens/profile_selection_screen.dart';
import 'widgets/pip_overlay.dart';

/// Global navigator key so the floating mini-player (which lives above the
/// Navigator in the widget tree) can push routes such as re-expanding the
/// full screen video player.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => WatchHistoryProvider()),
        ChangeNotifierProvider(create: (_) => DownloadsProvider()),
        ChangeNotifierProvider(create: (_) => CastProvider()),
        ChangeNotifierProvider(create: (_) => PipController()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Sabuflix - Streaming Platform',
        debugShowCheckedModeBanner: false,
        theme: SabuflixTheme.themeData,
        home: const ProfileSelectionScreen(),
        builder: (context, child) {
          return Stack(
            children: [
              if (child != null) child,
              const PipOverlay(),
            ],
          );
        },
      ),
    );
  }
}
