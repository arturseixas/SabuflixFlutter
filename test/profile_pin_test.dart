import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sabuflix/models/profile.dart';
import 'package:sabuflix/providers/settings_provider.dart';
import 'package:sabuflix/services/backup_service.dart';
import 'package:sabuflix/services/playback_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PIN is stored hashed and verified, avatar falls back safely', () {
    final profile = Profile(
      id: 'a',
      name: 'Ana',
      avatarUrl: '',
      maxAgeRating: '16',
      pinHash: Profile.hashPin('1234'),
      avatar: 'rocket',
    );
    expect(profile.hasPin, isTrue);
    expect(profile.checkPin('1234'), isTrue);
    expect(profile.checkPin('0000'), isFalse);
    expect(profile.pinHash, isNot(contains('1234')));
    expect(profile.maxAge, 16);

    final restored = Profile.fromJson(jsonDecode(jsonEncode(profile.toJson())));
    expect(restored.checkPin('1234'), isTrue);
    expect(restored.avatar, 'rocket');
    expect(Profile.fromJson({'id': 'b', 'name': 'B', 'avatar': 'bogus'}).avatar,
        'person');
    expect(profile.copyWith(clearPin: true).hasPin, isFalse);
  });

  test('backup round-trips profile data and settings into another profile',
      () async {
    SharedPreferences.setMockInitialValues({
      'sabuflix_favorites_a': '[{"id":1,"title":"Filme"}]',
      'sabuflix_watched_eps_a': '{"7":["s1e1"]}',
      'sabuflix_recent_searches': ['batman'],
    });
    final settings = SettingsProvider();
    await Future<void>.delayed(Duration.zero);
    await settings.setPreferredQuality(PreferredQuality.fhd);
    final backup =
        await BackupService.export(profileId: 'a', settings: settings);
    final decoded = jsonDecode(backup) as Map;
    expect(decoded['app'], 'sabuflix');
    expect(decoded['data'], contains('sabuflix_favorites_a'));

    final target = SettingsProvider();
    await Future<void>.delayed(Duration.zero);
    await BackupService.import(backup, profileId: 'b', settings: target);
    final prefs = await SharedPreferences.getInstance();
    expect(
        prefs.getString('sabuflix_favorites_b'), '[{"id":1,"title":"Filme"}]');
    expect(prefs.getString('sabuflix_watched_eps_b'), '{"7":["s1e1"]}');
    expect(prefs.getStringList('sabuflix_recent_searches'), ['batman']);
    expect(target.preferredQuality, PreferredQuality.fhd);

    await expectLater(
        BackupService.import('nope', profileId: 'b', settings: target),
        throwsA(isA<FormatException>()));
    settings.dispose();
    target.dispose();
  });
}
