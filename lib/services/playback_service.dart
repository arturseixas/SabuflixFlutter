import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/media_item.dart';
import 'pip_service.dart';

/// Single owner of the application's video playback.
///
/// Before this existed every [VideoPlayerScreen] created its own [Player] and
/// relied on `State.dispose()` to tear it down. On desktop that leaked audio:
/// `dispose()` is not awaited, and a player created *after* the screen was
/// already gone (the `open()` call is asynchronous) was never torn down at
/// all — the movie kept playing over the rest of the UI until the process
/// exited. Centralising the player means there is exactly one thing to stop,
/// and [stop] is the single, awaited path that stops it.
class PlaybackService extends ChangeNotifier {
  PlaybackService._();

  static final PlaybackService instance = PlaybackService._();

  Player? _player;
  VideoController? _videoController;

  /// Incremented on every [open]/[stop]. Any asynchronous work started under
  /// an older generation is discarded — this is what makes "close the screen
  /// while the source is still loading" safe.
  int _generation = 0;

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  MediaItem? _media;
  String? _videoUrl;
  String? _sourceLabel;
  int? _season;
  int? _episode;

  bool _isPipActive = false;
  bool _isSystemPip = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  List<AudioTrack> _audioTracks = [];
  AudioTrack? _selectedAudioTrack;
  List<SubtitleTrack> _subtitleTracks = [];
  SubtitleTrack? _selectedSubtitleTrack;

  Player? get player => _player;
  VideoController? get videoController => _videoController;
  MediaItem? get media => _media;
  String? get videoUrl => _videoUrl;
  String? get sourceLabel => _sourceLabel;
  int? get season => _season;
  int? get episode => _episode;

  bool get hasMedia => _media != null;
  bool get hasVideo => _videoController != null;

  /// True while the mini player (or the system PiP window) is showing.
  bool get isPipActive => _isPipActive;

  /// True while Android is rendering the app inside the system PiP window.
  bool get isSystemPip => _isSystemPip;

  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  Duration get position => _position;
  Duration get duration => _duration;

  List<AudioTrack> get audioTracks => _audioTracks;
  AudioTrack? get selectedAudioTrack => _selectedAudioTrack;
  List<SubtitleTrack> get subtitleTracks => _subtitleTracks;
  SubtitleTrack? get selectedSubtitleTrack => _selectedSubtitleTrack;

  /// Human readable label for what is playing, e.g. `Severance · T1:E4`.
  String get displayTitle {
    final title = _media?.title ?? '';
    if (_season != null && _episode != null) {
      return '$title · T$_season:E$_episode';
    }
    return title;
  }

  /// Tears down whatever is playing and starts [videoUrl] for [media].
  ///
  /// Passing a null/empty [videoUrl] leaves the service in "no video" mode:
  /// the screen falls back to the backdrop still, no native player is created.
  Future<void> open({
    required MediaItem media,
    String? videoUrl,
    String? sourceLabel,
    int? season,
    int? episode,
  }) async {
    await _teardown();

    final generation = ++_generation;

    _media = media;
    _videoUrl = videoUrl;
    _sourceLabel = sourceLabel;
    _season = season;
    _episode = episode;
    _position = Duration.zero;
    _duration = Duration.zero;
    _isPlaying = false;
    _isBuffering = false;
    _audioTracks = [];
    _subtitleTracks = [];
    _selectedAudioTrack = null;
    _selectedSubtitleTrack = null;
    notifyListeners();

    if (videoUrl == null || videoUrl.isEmpty) return;

    unawaited(PipService.instance.setAutoPipEnabled(true));

    final player = Player();
    final controller = VideoController(player);

    // Another open()/stop() landed while the controller was being created.
    // Drop this player on the floor rather than leaving it running.
    if (generation != _generation) {
      await player.stop();
      await player.dispose();
      return;
    }

    _player = player;
    _videoController = controller;
    _listenTo(player);
    notifyListeners();

    try {
      await player.open(Media(videoUrl));
      if (generation != _generation) return;
      await player.play();
    } catch (e) {
      debugPrint('PlaybackService: failed to open $videoUrl — $e');
    }
  }

  void _listenTo(Player player) {
    _subscriptions.addAll([
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
  }

  void playOrPause() {
    _player?.playOrPause();
  }

  void play() {
    _player?.play();
  }

  void pause() {
    _player?.pause();
  }

  void seekTo(Duration position) {
    _player?.seek(position);
    _position = position;
    notifyListeners();
  }

  void seekBy(Duration delta) {
    final target = _position + delta;
    final max = _duration;
    if (target.isNegative) {
      seekTo(Duration.zero);
    } else if (max > Duration.zero && target > max) {
      seekTo(max);
    } else {
      seekTo(target);
    }
  }

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

  /// Detaches playback from the full screen page so it survives as a mini
  /// player (or, on Android, as the system PiP window).
  ///
  /// Returns true when the OS took over with a real PiP window — the caller
  /// then stays on the player page, because Android renders that same page
  /// inside the floating window. False means the in-app mini player should
  /// take over instead.
  Future<bool> enterPip() async {
    if (!hasMedia) return false;
    _isPipActive = true;
    notifyListeners();
    if (PipService.supportsSystemPip) {
      return PipService.instance.enterSystemPip();
    }
    return false;
  }

  void exitPip() {
    if (!_isPipActive) return;
    _isPipActive = false;
    notifyListeners();
  }

  /// Called by [PipService] when Android enters/leaves its PiP window.
  void setSystemPipMode(bool active) {
    if (_isSystemPip == active) return;
    _isSystemPip = active;
    // Leaving the system window means the user tapped back into the app and
    // the full screen page is in charge again — otherwise the mini player
    // would pop up on top of it.
    _isPipActive = active;
    notifyListeners();
  }

  /// Stops playback for good and releases the native player.
  ///
  /// Safe to call from `dispose()` and safe to call twice.
  Future<void> stop() async {
    _generation++;
    unawaited(PipService.instance.setAutoPipEnabled(false));
    await _teardown();
    _media = null;
    _videoUrl = null;
    _sourceLabel = null;
    _season = null;
    _episode = null;
    _isPipActive = false;
    _isSystemPip = false;
    notifyListeners();
  }

  Future<void> _teardown() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    final player = _player;
    _player = null;
    _videoController = null;
    _isPlaying = false;
    _isBuffering = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _audioTracks = [];
    _subtitleTracks = [];
    _selectedAudioTrack = null;
    _selectedSubtitleTrack = null;

    if (player != null) {
      try {
        // stop() before dispose(): on desktop dispose() alone has been seen
        // to return before libmpv actually releases the audio output.
        await player.stop();
      } catch (_) {
        // The player may already be gone; nothing left to stop.
      }
      try {
        await player.dispose();
      } catch (_) {
        // Ditto — disposing twice must never crash the app.
      }
    }
  }
}
