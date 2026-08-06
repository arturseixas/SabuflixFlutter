import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'theme/sabuflix_theme.dart';
import 'providers/catalog_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/search_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/watch_history_provider.dart';
import 'screens/profile_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  if (!kIsWeb && Platform.isWindows) {
    await windowManager.ensureInitialized();
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
        ChangeNotifierProvider(create: (_) => WatchHistoryProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
      ],
      child: MaterialApp(
        title: 'Sabuflix - Streaming Platform',
        debugShowCheckedModeBanner: false,
        theme: SabuflixTheme.themeData,
        home: const ProfileSelectionScreen(),
      ),
    );
  }
}
