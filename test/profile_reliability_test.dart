import 'package:flutter_test/flutter_test.dart';
import 'package:sabuflix/providers/profile_provider.dart';
import 'package:sabuflix/providers/playlist_provider.dart';
import 'package:sabuflix/providers/favorites_provider.dart';
import 'package:sabuflix/models/media_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> loaded(ProfileProvider p) async {
  while (p.isLoading) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('corrupt profiles recover with a backup and a usable default', () async {
    SharedPreferences.setMockInitialValues({'sabuflix_profiles': '{broken'});
    final p = ProfileProvider();
    await loaded(p);
    expect(p.profiles.single.name, 'Principal');
    expect(
        (await SharedPreferences.getInstance())
            .getString('sabuflix_profiles_recovery'),
        '{broken');
    await p.deleteProfile(p.profiles.single.id);
    expect(p.profiles, hasLength(1));
    p.dispose();
  });
  test('empty saved profiles do not crash selection on restart', () async {
    SharedPreferences.setMockInitialValues(
        {'sabuflix_profiles': '[]', 'sabuflix_current_profile_id': 'gone'});
    final p = ProfileProvider();
    await loaded(p);
    expect(p.currentProfile?.id, 'default');
    p.dispose();
  });
  test('overlapping playlist loads keep only the selected profile', () async {
    SharedPreferences.setMockInitialValues({
      'sabuflix_playlists_a': '[{"id":"1","name":"Private","items":[]}]',
      'sabuflix_playlists_b': '[]',
    });
    final p = PlaylistProvider();
    await Future.wait([p.loadForProfile('a'), p.loadForProfile('b')]);
    expect(p.playlists, isEmpty);
    expect(p.isLoading, isFalse);
    p.dispose();
  });
  test('rapid favorite mutations do not overwrite each other', () async {
    SharedPreferences.setMockInitialValues({});
    final p = FavoritesProvider();
    await p.loadFavorites('a');
    await Future.wait([
      p.toggleFavorite(MediaItem.fromJson({'id': 1, 'title': 'One'})),
      p.toggleFavorite(MediaItem.fromJson({'id': 2, 'title': 'Two'})),
    ]);
    expect(p.favorites, hasLength(2));
    await p.loadFavorites('a');
    expect(p.favorites, hasLength(2));
    p.dispose();
  });
}
