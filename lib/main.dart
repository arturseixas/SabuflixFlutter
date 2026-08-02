import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'providers/catalog_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/search_provider.dart';
import 'screens/profile_selection_screen.dart';
import 'services/download_service.dart';
import 'services/pip_service.dart';
import 'services/playback_service.dart';
import 'theme/sabuflix_theme.dart';
import 'utils/app_navigator.dart';
import 'widgets/mini_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  PipService.instance.init();
  unawaited(DownloadService.instance.load());
  runApp(const SabuflixApp());
}

class SabuflixApp extends StatefulWidget {
  const SabuflixApp({super.key});

  @override
  State<SabuflixApp> createState() => _SabuflixAppState();
}

class _SabuflixAppState extends State<SabuflixApp> with WidgetsBindingObserver {
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
    // Closing the window (or the OS killing the app) must not leave libmpv
    // holding on to the audio device.
    if (state == AppLifecycleState.detached) {
      unawaited(PlaybackService.instance.stop());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider.value(value: DownloadService.instance),
      ],
      child: MaterialApp(
        title: 'Sabuflix - Streaming Platform',
        debugShowCheckedModeBanner: false,
        theme: SabuflixTheme.themeData,
        navigatorKey: appNavigatorKey,
        // The mini player is mounted above the navigator so Picture in
        // Picture survives every route change.
        builder: (context, child) => Stack(
          children: [
            if (child != null) child,
            const Positioned.fill(child: MiniPlayer()),
          ],
        ),
        home: const ProfileSelectionScreen(),
      ),
    );
  }
}
