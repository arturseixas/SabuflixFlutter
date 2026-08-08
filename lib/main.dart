import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'theme/sabuflix_theme.dart';
import 'providers/catalog_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/search_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/download_provider.dart';
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
        ChangeNotifierProvider(create: (_) => DownloadProvider()),
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
