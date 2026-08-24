import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile.dart';

class ProfileProvider extends ChangeNotifier {
  static const String _profilesKey = 'sabuflix_profiles';
  static const String _currentProfileIdKey = 'sabuflix_current_profile_id';

  List<Profile> _profiles = [];
  Profile? _currentProfile;

  List<Profile> get profiles => _profiles;
  Profile? get currentProfile => _currentProfile;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  ProfileProvider() {
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();

    // Load profiles
    final String? profilesJson = prefs.getString(_profilesKey);
    if (profilesJson != null) {
      final List<dynamic> decoded = json.decode(profilesJson);
      _profiles = decoded.map((p) => Profile.fromJson(p)).toList();
    } else {
      // Create default profile if none exists
      final defaultProfile = Profile(
        id: 'default',
        name: 'Principal',
        avatarUrl: 'https://i.pravatar.cc/150?u=principal',
        maxAgeRating: '18',
      );
      _profiles = [defaultProfile];
      await _saveProfiles(prefs);
    }

    // Load current profile
    final String? currentId = prefs.getString(_currentProfileIdKey);
    if (currentId != null) {
      _currentProfile = _profiles.firstWhere(
        (p) => p.id == currentId,
        orElse: () => _profiles.first,
      );
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveProfiles(SharedPreferences prefs) async {
    final encoded = json.encode(_profiles.map((p) => p.toJson()).toList());
    await prefs.setString(_profilesKey, encoded);
  }

  Future<void> addProfile(Profile profile) async {
    _profiles.add(profile);
    final prefs = await SharedPreferences.getInstance();
    await _saveProfiles(prefs);
    notifyListeners();
  }

  Future<void> updateProfile(Profile profile) async {
    final index = _profiles.indexWhere((p) => p.id == profile.id);
    if (index != -1) {
      _profiles[index] = profile;
      if (_currentProfile?.id == profile.id) {
        _currentProfile = profile;
      }
      final prefs = await SharedPreferences.getInstance();
      await _saveProfiles(prefs);
      notifyListeners();
    }
  }

  Future<void> deleteProfile(String id) async {
    _profiles.removeWhere((p) => p.id == id);
    if (_currentProfile?.id == id) {
      _currentProfile = _profiles.isNotEmpty ? _profiles.first : null;
      if (_currentProfile != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_currentProfileIdKey, _currentProfile!.id);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await _saveProfiles(prefs);
    notifyListeners();
  }

  Future<void> selectProfile(String id) async {
    final profile =
        _profiles.firstWhere((p) => p.id == id, orElse: () => _profiles.first);
    _currentProfile = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentProfileIdKey, profile.id);
    notifyListeners();
  }
}
