import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/media_item.dart';

/// Holds the player/controller of a video that was minimized into the
/// in-app floating mini-player (used on iOS, Windows, macOS, Linux and web,
/// where there is no OS-level Picture-in-Picture available to this app).
class PipSession {
  final MediaItem media;
  final Player player;
  final VideoController videoController;

  PipSession({
    required this.media,
    required this.player,
    required this.videoController,
  });
}

class PipController extends ChangeNotifier {
  PipSession? _session;
  Offset _offset = const Offset(12, 80);

  PipSession? get session => _session;
  bool get isActive => _session != null;
  Offset get offset => _offset;

  void activate(PipSession session) {
    _session?.player.dispose();
    _session = session;
    notifyListeners();
  }

  void updateOffset(Offset offset) {
    _offset = offset;
    notifyListeners();
  }

  /// Removes the mini-player from the screen without disposing the player,
  /// used when the user taps it to go back to the full screen player.
  void clearWithoutDispose() {
    _session = null;
    notifyListeners();
  }

  /// Closes the mini-player and stops playback entirely.
  void close() {
    _session?.player.dispose();
    _session = null;
    notifyListeners();
  }
}
