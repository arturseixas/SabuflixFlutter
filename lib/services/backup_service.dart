import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../providers/settings_provider.dart';

/// Moves a profile's local data between devices as one JSON document.
///
/// The document carries the raw SharedPreferences values under their keys,
/// so restoring is a matter of writing them back and reloading the providers.
class BackupService {
  BackupService._();

  static const int version = 1;

  static List<String> keysFor(String? profileId) {
    final id = profileId ?? 'default';
    return [
      'sabuflix_favorites_$id',
      'sabuflix_playlists_$id',
      'sabuflix_continue_$id',
      'sabuflix_watched_$id',
      'sabuflix_watched_eps_$id',
      'sabuflix_recent_searches',
    ];
  }

  static Future<String> export(
      {required String? profileId, required SettingsProvider settings}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    for (final key in keysFor(profileId)) {
      final value = prefs.get(key);
      if (value != null) data[key] = value;
    }
    return jsonEncode({
      'app': 'sabuflix',
      'version': version,
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': profileId ?? 'default',
      'settings': settings.toJson(),
      'data': data,
    });
  }

  /// Writes the backup into [profileId]'s keys. Throws [FormatException] with
  /// a user-facing message when the text is not a Sabuflix backup.
  static Future<void> import(String text,
      {required String? profileId, required SettingsProvider settings}) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(text.trim());
    } catch (_) {
      throw const FormatException('O texto colado não é um backup válido.');
    }
    if (decoded is! Map ||
        decoded['app'] != 'sabuflix' ||
        decoded['data'] is! Map) {
      throw const FormatException(
          'O texto colado não é um backup do Sabuflix.');
    }
    final sourceProfile = decoded['profile']?.toString() ?? 'default';
    final targetProfile = profileId ?? 'default';
    final prefs = await SharedPreferences.getInstance();
    final data = Map<String, dynamic>.from(decoded['data'] as Map);
    for (final entry in data.entries) {
      // Re-key from the source profile to the profile being restored into.
      final key = entry.key.replaceFirst('_$sourceProfile', '_$targetProfile');
      if (!keysFor(targetProfile).contains(key)) continue;
      final value = entry.value;
      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is List) {
        await prefs.setStringList(key, value.map((e) => e.toString()).toList());
      }
    }
    final settingsJson = decoded['settings'];
    if (settingsJson is Map) {
      await settings.applyJson(Map<String, dynamic>.from(settingsJson));
    }
  }
}
