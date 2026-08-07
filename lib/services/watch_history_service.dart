import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/watch_progress.dart';

/// Per-profile storage for the "Continuar assistindo" row.
class WatchHistoryService {
  /// The row is a shortcut, not an archive — older entries fall off the end.
  static const int maxEntries = 20;

  String _prefsKey(String? profileId) => 'sabuflix_continue_watching_${profileId ?? "default"}';

  Future<List<WatchProgress>> load(String? profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey(profileId));
    if (stored == null || stored.isEmpty) return [];

    try {
      final List<dynamic> decoded = json.decode(stored);
      return decoded
          .map((entry) => WatchProgress.fromJson(Map<String, dynamic>.from(entry)))
          .toList();
    } catch (e) {
      debugPrint('Error decoding watch history: $e');
      return [];
    }
  }

  Future<void> save(List<WatchProgress> entries, String? profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = entries.take(maxEntries).toList();
    await prefs.setString(
      _prefsKey(profileId),
      json.encode(trimmed.map((entry) => entry.toJson()).toList()),
    );
  }
}
