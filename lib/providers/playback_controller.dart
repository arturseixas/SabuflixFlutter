import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/media_item.dart';
import '../services/desktop_pip.dart';

/// Owns the video player for the whole app.
///
/// The player used to live inside the fullscreen page, which meant leaving
/// that page destroyed it. Picture-in-picture needs playback to outlive the
/// screen that started it, so the player sits here instead and the screens
/// are just different views onto the same session.
class PlaybackController extends ChangeNotifier {
  Player? _player;
  VideoController? _videoController;

  VideoController? get videoController => _videoController;
  bool get hasVideo => _videoController != null;

  MediaItem? _media;
  MediaItem? get media => _media;

  String? _url;
  String? get url => _url;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  /// True while playback is showing in the floating window instead of the
  /// fullscreen page.
  bool _isPip = false;
  bool get isPip => _isPip;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  bool _isBuffering = false;
  bool get isBuffering => _isBuffering;

  Duration _position = Duration.zero;
  Duration get position => _position;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  List<AudioTrack> _audioTracks = const [];
  List<AudioTrack> get audioTracks => _audioTracks;

  AudioTrack? _selectedAudioTrack;
  AudioTrack? get selectedAudioTrack => _selectedAudioTrack;

  List<SubtitleTrack> _subtitleTracks = const [];
  List<SubtitleTrack> get subtitleTracks => _subtitleTracks;

  SubtitleTrack? _selectedSubtitleTrack;
  SubtitleTrack? get selectedSubtitleTrack => _selectedSubtitleTrack;

  final List<StreamSubscription> _subs = [];

  /// Starts a new playback session, replacing whatever was playing.
  Future<void> open({
    required MediaItem media,
    required String url,
    bool isOffline = false,
  }) async {
    // Same media already loaded: keep the session and its position rather
    // than restarting from the beginning.
    if (_player != null && _url == url) {
      _media = media;
      _isPip = false;
      notifyListeners();
      return;
    }

    await _teardown();

    _media = media;
    _url = url;
    _isOffline = isOffline;
    _isPip = false;

    final player = Player();
    _player = player;
    _videoController = VideoController(player);

    _subs.addAll([
      player.stream.position.listen((value) {
        _position = value;
        notifyListeners();
      }),
      player.stream.duration.listen((value) {
        _duration = value;
        notifyListeners();
      }),
      player.stream.playing.listen((value) {
        _isPlaying = value;
        notifyListeners();
      }),
      player.stream.buffering.listen((value) {
        _isBuffering = value;
        notifyListeners();
      }),
      player.stream.tracks.listen((tracks) {
        _audioTracks = tracks.audio;
        _subtitleTracks = tracks.subtitle;
        notifyListeners();
      }),
      player.stream.track.listen((track) {
        _selectedAudioTrack = track.audio;
        _selectedSubtitleTrack = track.subtitle;
        notifyListeners();
      }),
    ]);

    notifyListeners();

    try {
      await player.open(Media(url));
      await player.play();
    } catch (e) {
      debugPrint('Sabuflix: falha ao abrir o vídeo: $e');
    }
  }

  void playOrPause() {
    _player?.playOrPause();
  }

  void seekTo(Duration target) {
    if (_player == null) return;
    final max = _duration;
    var clamped = target;
    if (clamped < Duration.zero) clamped = Duration.zero;
    if (max > Duration.zero && clamped > max) clamped = max;
    _player!.seek(clamped);
  }

  void seekBy(Duration delta) => seekTo(_position + delta);

  void setAudioTrack(AudioTrack track) {
    _player?.setAudioTrack(track);
    _selectedAudioTrack = track;
    notifyListeners();
  }

  void setSubtitleTrack(SubtitleTrack track) {
    _player?.setSubtitleTrack(track);
    _selectedSubtitleTrack = track;
    notifyListeners();
  }

  /// True when picture-in-picture is the app's own OS window, shrunk and
  /// pinned above other programs, rather than a box drawn inside the app.
  bool _isWindowPip = false;
  bool get isWindowPip => _isWindowPip;

  /// Moves playback into the floating window.
  ///
  /// With [useDesktopWindow] the app's window itself becomes the floating
  /// frame; if the platform refuses, the in-app box is used instead so the
  /// button always does something.
  Future<void> enterPip({bool useDesktopWindow = false}) async {
    if (!hasVideo || _isPip) return;
    _isPip = true;
    notifyListeners();

    if (useDesktopWindow) {
      _isWindowPip = await DesktopPip.enter();
      notifyListeners();
    }
  }

  /// Brings playback back to the fullscreen page.
  Future<void> exitPip() async {
    if (!_isPip) return;
    _isPip = false;
    if (_isWindowPip) {
      await DesktopPip.exit();
      _isWindowPip = false;
    }
    notifyListeners();
  }

  /// Ends the session entirely and releases the player.
  Future<void> stop() async {
    // The window has to come back to normal size even when playback is being
    // closed outright, or the app would be stranded as a small pinned frame.
    if (_isWindowPip) {
      await DesktopPip.exit();
      _isWindowPip = false;
    }
    await _teardown();
    _media = null;
    _url = null;
    _isOffline = false;
    _isPip = false;
    _isPlaying = false;
    _isBuffering = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _audioTracks = const [];
    _subtitleTracks = const [];
    _selectedAudioTrack = null;
    _selectedSubtitleTrack = null;
    notifyListeners();
  }

  Future<void> _teardown() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();

    final player = _player;
    _player = null;
    _videoController = null;
    if (player != null) {
      try {
        await player.dispose();
      } catch (e) {
        debugPrint('Sabuflix: falha ao liberar o player: $e');
      }
    }
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }
}

/// Formats a duration as mm:ss, or hh:mm:ss once it passes an hour.
String formatPlaybackTime(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  final seconds = value.inSeconds.remainder(60);
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) return '${hours.toString().padLeft(2, '0')}:$mm:$ss';
  return '$mm:$ss';
}
