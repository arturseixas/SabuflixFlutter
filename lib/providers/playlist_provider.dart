import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist.dart';
import '../models/media_item.dart';

class PlaylistProvider extends ChangeNotifier {
  List<Playlist> _playlists = [];
  bool _isLoading = false;
  String? _currentProfileId;

  List<Playlist> get playlists => _playlists;
  bool get isLoading => _isLoading;

  String _getPrefsKey() => 'sabuflix_playlists_${_currentProfileId ?? "default"}';

  Future<void> loadForProfile(String profileId) async {
    _currentProfileId = profileId;
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_getPrefsKey());

    if (jsonStr != null) {
      final List<dynamic> decoded = json.decode(jsonStr);
      _playlists = decoded.map((p) => Playlist.fromJson(p)).toList();
    } else {
      _playlists = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(_playlists.map((p) => p.toJson()).toList());
    await prefs.setString(_getPrefsKey(), encoded);
  }

  Future<void> createPlaylist(String name) async {
    final newPlaylist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      items: [],
    );
    _playlists.add(newPlaylist);
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> addMediaToPlaylist(String playlistId, MediaItem media) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final playlist = _playlists[index];
      if (!playlist.items.any((item) => item.id == media.id)) {
        final updatedItems = List<MediaItem>.from(playlist.items)..add(media);
        _playlists[index] = playlist.copyWith(items: updatedItems);
        await _savePlaylists();
        notifyListeners();
      }
    }
  }

  Future<void> removeMediaFromPlaylist(String playlistId, int mediaId) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final playlist = _playlists[index];
      final updatedItems = playlist.items.where((item) => item.id != mediaId).toList();
      _playlists[index] = playlist.copyWith(items: updatedItems);
      await _savePlaylists();
      notifyListeners();
    }
  }
}
