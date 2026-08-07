import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/media_item.dart';
import '../providers/watch_history_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../widgets/glass_container.dart';

class VideoPlayerScreen extends StatefulWidget {
  final MediaItem media;
  final String? videoUrl;

  /// Set for series, so progress is filed against the right episode.
  final int? season;
  final int? episode;

  /// Where to pick playback back up, from "Continuar assistindo".
  final Duration? resumeFrom;

  /// When set, finishing the episode offers to roll straight into this one.
  /// The screen pops with `true` to ask the caller to start it.
  final int? nextEpisode;

  const VideoPlayerScreen({
    Key? key,
    required this.media,
    this.videoUrl,
    this.season,
    this.episode,
    this.resumeFrom,
    this.nextEpisode,
  }) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _showControls = true;
  Timer? _hideTimer;
  Timer? _mockTimer;

  Player? _player;
  VideoController? _videoController;

  final List<StreamSubscription> _subscriptions = [];

  /// Set as soon as the screen starts going away, so playback that is still
  /// being set up asynchronously never gets (re)started behind our back.
  bool _isShuttingDown = false;

  bool _isPlaying = false;
  bool _isBuffering = false;
  double _currentPosition = 0;
  double _totalDuration = 0;
  
  bool _showAudioMenu = false;
  bool _showSubtitleMenu = false;
  bool _showSpeedMenu = false;

  bool _isCompleted = false;

  double _volume = 100;
  double _volumeBeforeMute = 100;
  double _speed = 1.0;

  static const List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  /// Subtitle scale, cycled by the "Aa" control.
  int _subtitleSizeIndex = 1;
  static const List<double> _subtitleSizes = [24, 32, 44];
  static const List<String> _subtitleSizeLabels = ['P', 'M', 'G'];

  /// Holds keyboard focus so the shortcuts work without a click first.
  final FocusNode _keyboardFocus = FocusNode();

  String? _errorMessage;

  /// A reported error only takes over the screen if nothing is actually
  /// playing — media_kit also reports recoverable hiccups mid-stream.
  bool get _hasFatalError => _errorMessage != null && !_isPlaying;

  /// Captured in `initState` so progress can still be filed from `dispose()`,
  /// where the context is already gone.
  WatchHistoryProvider? _history;
  int _lastRecordedSecond = 0;

  List<AudioTrack> _audioTracks = [];
  AudioTrack? _selectedAudioTrack;
  
  List<SubtitleTrack> _subtitleTracks = [];
  SubtitleTrack? _selectedSubtitleTrack;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _history = Provider.of<WatchHistoryProvider>(context, listen: false);
    _initPlayer();
    _startHideTimer();
  }

  /// Files the current stopping point with "Continuar assistindo". Safe to
  /// call after the widget is gone — it touches no context.
  void _recordProgress() {
    final history = _history;
    if (history == null) return;
    if (widget.videoUrl == null || widget.videoUrl!.isEmpty) return;
    if (_totalDuration <= 0) return;

    _lastRecordedSecond = _currentPosition.toInt();
    unawaited(history.record(
      media: widget.media,
      position: Duration(seconds: _currentPosition.toInt()),
      duration: Duration(seconds: _totalDuration.toInt()),
      season: widget.season,
      episode: widget.episode,
      videoUrl: widget.videoUrl,
    ));
  }

  Future<void> _initPlayer() async {
    if (widget.videoUrl == null || widget.videoUrl!.isEmpty) {
      // Mock playback if no URL (e.g. trailer mode)
      _totalDuration = 6840;
      _isPlaying = true;
      _mockPlaybackTimer();
      return;
    }

    final player = Player();
    _player = player;
    _videoController = VideoController(player);

    _subscriptions.addAll([
      player.stream.position.listen((Duration position) {
        if (!mounted) return;
        setState(() => _currentPosition = position.inSeconds.toDouble());
        // Checkpoint every 15s, so progress survives the app being killed
        // rather than only being written on the way out.
        if ((position.inSeconds - _lastRecordedSecond).abs() >= 15) {
          _recordProgress();
        }
      }),
      player.stream.duration.listen((Duration duration) {
        if (!mounted) return;
        setState(() => _totalDuration = duration.inSeconds.toDouble());
      }),
      player.stream.playing.listen((bool playing) {
        if (!mounted) return;
        setState(() => _isPlaying = playing);
        if (!playing) _recordProgress();
      }),
      player.stream.buffering.listen((bool buffering) {
        if (!mounted) return;
        setState(() => _isBuffering = buffering);
      }),
      player.stream.tracks.listen((tracks) {
        if (!mounted) return;
        setState(() {
          _audioTracks = tracks.audio;
          _subtitleTracks = tracks.subtitle;
        });
      }),
      player.stream.track.listen((track) {
        if (!mounted) return;
        setState(() {
          _selectedAudioTrack = track.audio;
          _selectedSubtitleTrack = track.subtitle;
        });
      }),
      player.stream.error.listen((error) {
        if (!mounted) return;
        // Sources handed out by the provider expire, and a resumed one may no
        // longer be good — say so instead of sitting on a black screen.
        setState(() => _errorMessage = error);
      }),
      player.stream.completed.listen((completed) {
        if (!mounted) return;
        setState(() {
          _isCompleted = completed;
          // The end of an episode is the one moment the controls must stay up.
          if (completed) _showControls = true;
        });
      }),
      player.stream.volume.listen((volume) {
        if (!mounted) return;
        setState(() => _volume = volume);
      }),
      player.stream.rate.listen((rate) {
        if (!mounted) return;
        setState(() => _speed = rate);
      }),
    ]);

    try {
      await player.open(Media(widget.videoUrl!));
      // The screen may have been popped while the media was still opening —
      // `open()` starts playback on its own, so tear it down instead of playing.
      if (_isShuttingDown) {
        await _teardown(player, const []);
        return;
      }
      await _resumeIfNeeded(player);
      if (_isShuttingDown) {
        await _teardown(player, const []);
        return;
      }
      await player.play();
    } catch (e) {
      debugPrint('Error initializing media_kit player: $e');
      if (mounted) {
        setState(() => _errorMessage = 'Não foi possível carregar esta fonte.');
      }
    }

    if (_isShuttingDown) {
      await _teardown(player, const []);
    }
  }

  /// Seeks to the stored position once the media reports a duration — seeking
  /// before that lands nowhere.
  Future<void> _resumeIfNeeded(Player player) async {
    final resumeFrom = widget.resumeFrom;
    if (resumeFrom == null || resumeFrom <= Duration.zero) return;

    try {
      if (player.state.duration <= Duration.zero) {
        await player.stream.duration
            .firstWhere((duration) => duration > Duration.zero)
            .timeout(const Duration(seconds: 10));
      }
      if (_isShuttingDown) return;
      _lastRecordedSecond = resumeFrom.inSeconds;
      await player.seek(resumeFrom);
    } catch (e) {
      debugPrint('Could not resume playback at $resumeFrom: $e');
    }
  }

  void _mockPlaybackTimer() {
    _mockTimer?.cancel();
    _mockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_isPlaying) {
        setState(() {
          if (_currentPosition < _totalDuration) {
            _currentPosition += 1;
          }
        });
      }
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) {
        setState(() {
          _showControls = false;
          _showAudioMenu = false;
          _showSubtitleMenu = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideTimer();
    }
  }

  void _playPause() {
    if (_player != null) {
      _player!.playOrPause();
    } else {
      setState(() => _isPlaying = !_isPlaying);
    }
    _startHideTimer();
  }

  void _seek(double seconds) {
    if (_player != null) {
      final newPos = (_currentPosition + seconds).clamp(0.0, _totalDuration);
      _player!.seek(Duration(seconds: newPos.toInt()));
    } else {
      setState(() {
        _currentPosition = (_currentPosition + seconds).clamp(0.0, _totalDuration);
      });
    }
    _startHideTimer();
  }

  void _setVolume(double volume) {
    final clamped = volume.clamp(0.0, 100.0);
    _player?.setVolume(clamped);
    setState(() => _volume = clamped);
    _startHideTimer();
  }

  void _toggleMute() {
    if (_volume > 0) {
      _volumeBeforeMute = _volume;
      _setVolume(0);
    } else {
      _setVolume(_volumeBeforeMute > 0 ? _volumeBeforeMute : 100);
    }
  }

  void _setSpeed(double speed) {
    _player?.setRate(speed);
    setState(() {
      _speed = speed;
      _showSpeedMenu = false;
    });
    _startHideTimer();
  }

  void _cycleSubtitleSize() {
    setState(() => _subtitleSizeIndex = (_subtitleSizeIndex + 1) % _subtitleSizes.length);
    _startHideTimer();
  }

  /// Pops with `true`, which the details screen reads as "open the next one".
  void _playNextEpisode() {
    Navigator.pop(context, true);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;

    // Any key press means the viewer is present — bring the controls back.
    if (!_showControls) setState(() => _showControls = true);
    _startHideTimer();

    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
      case LogicalKeyboardKey.keyK:
        _playPause();
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.keyJ:
        _seek(-10);
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.keyL:
        _seek(10);
      case LogicalKeyboardKey.arrowUp:
        _setVolume(_volume + 10);
      case LogicalKeyboardKey.arrowDown:
        _setVolume(_volume - 10);
      case LogicalKeyboardKey.keyM:
        _toggleMute();
      case LogicalKeyboardKey.escape:
        Navigator.maybePop(context);
      case LogicalKeyboardKey.keyN:
        if (widget.nextEpisode != null) _playNextEpisode();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _seekTo(double value) {
    if (_player != null) {
      _player!.seek(Duration(seconds: value.toInt()));
    } else {
      setState(() => _currentPosition = value);
    }
    _startHideTimer();
  }

  String _formatDuration(double seconds) {
    if (seconds.isNaN || seconds.isInfinite) return '00:00';
    final duration = Duration(seconds: seconds.toInt());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _openOfficialTrailer() async {
    if (widget.media.trailerKey != null && widget.media.trailerKey!.isNotEmpty) {
      final Uri url = Uri.parse('https://www.youtube.com/watch?v=${widget.media.trailerKey}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }

  /// Silences playback the instant the route starts popping, instead of waiting
  /// for the exit transition to finish and `dispose()` to run.
  void _onPopped() {
    if (_isShuttingDown) return;
    _isShuttingDown = true;
    _recordProgress();
    final player = _player;
    if (player != null) unawaited(_pauseQuietly(player));
  }

  static Future<void> _pauseQuietly(Player player) async {
    try {
      await player.pause();
    } catch (_) {}
  }

  /// Fully unwinds the player. `stop()` before `dispose()` matters: disposing a
  /// player that still has media loaded can leave the audio output running.
  ///
  /// Static so it can safely outlive the `State` it was started from.
  static Future<void> _teardown(Player? player, List<StreamSubscription> subscriptions) async {
    for (final subscription in subscriptions) {
      try {
        await subscription.cancel();
      } catch (_) {}
    }
    if (player == null) return;
    try {
      await player.pause();
    } catch (_) {}
    try {
      await player.stop();
    } catch (_) {}
    try {
      await player.dispose();
    } catch (_) {}
  }

  @override
  void dispose() {
    _recordProgress();
    _isShuttingDown = true;
    _hideTimer?.cancel();
    _mockTimer?.cancel();
    _keyboardFocus.dispose();

    // Hand the player and its listeners off to an async teardown: `dispose()`
    // cannot await, and every one of these calls is asynchronous.
    final player = _player;
    final subscriptions = List<StreamSubscription>.of(_subscriptions);
    _player = null;
    _subscriptions.clear();
    unawaited(_teardown(player, subscriptions));

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = _videoController != null;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _onPopped();
      },
      child: Focus(
        focusNode: _keyboardFocus,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: _buildPlayer(hasVideo),
      ),
    );
  }

  Widget _buildPlayer(bool hasVideo) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasVideo)
              Center(
                child: Video(
                  controller: _videoController!,
                  controls: NoVideoControls,
                  fill: Colors.black,
                  subtitleViewConfiguration: SubtitleViewConfiguration(
                    style: TextStyle(
                      height: 1.4,
                      fontSize: _subtitleSizes[_subtitleSizeIndex],
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      backgroundColor: Colors.black.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              )
            else
              CachedNetworkImage(
                imageUrl: widget.media.fullBackdropPath,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                placeholder: (context, url) => Container(color: SabuflixTheme.background),
                errorWidget: (context, url, err) => Container(color: SabuflixTheme.background),
              ),

            if (_isBuffering && hasVideo && !_hasFatalError)
              const Center(child: CircularProgressIndicator(color: SabuflixTheme.accent)),

            if (_isCompleted && widget.nextEpisode != null && !_hasFatalError)
              Positioned(
                right: 28,
                bottom: 96,
                child: GlassContainer(
                  borderRadius: SabuflixTheme.radiusLg,
                  blur: 30,
                  fillOpacity: 0.5,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('A seguir', style: SabuflixTheme.label(color: SabuflixTheme.textSecondary)),
                      const SizedBox(height: 4),
                      Text(
                        'Episódio ${widget.nextEpisode}',
                        style: SabuflixTheme.title(fontSize: 17, color: Colors.white),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: _playNextEpisode,
                        icon: const Icon(Icons.skip_next_rounded, size: 20),
                        label: const Text('Assistir agora'),
                      ),
                    ],
                  ),
                ),
              ),

            if (_hasFatalError)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: GlassContainer(
                    borderRadius: SabuflixTheme.radiusLg,
                    blur: 30,
                    fillOpacity: 0.5,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 34),
                        const SizedBox(height: 14),
                        Text(
                          'Não foi possível reproduzir esta fonte.',
                          textAlign: TextAlign.center,
                          style: SabuflixTheme.title(fontSize: 16, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ela pode ter expirado. Volte e escolha outra fonte.',
                          textAlign: TextAlign.center,
                          style: SabuflixTheme.body(fontSize: 13, color: SabuflixTheme.textSecondary),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Voltar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (_showControls || !_isPlaying)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                color: Colors.black.withValues(alpha: _isPlaying ? 0.35 : 0.65),
              ),

            if (_showControls)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showControls ? 1.0 : 0.0,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                  child: Container(
                    color: Colors.transparent,
                    child: Stack(
                      children: [
                        Positioned(
                          top: 16,
                          left: 16,
                          right: 200,
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.media.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: SabuflixTheme.title(fontSize: 18, color: Colors.white),
                                    ),
                                    Text(
                                      widget.media.formattedYear,
                                      style: SabuflixTheme.body(color: SabuflixTheme.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        Positioned(
                          top: 16,
                          right: 12,
                          child: Row(
                            children: [
                              TextButton.icon(
                                onPressed: _openOfficialTrailer,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusSm),
                                ),
                                icon: const Icon(Icons.smart_display_outlined, size: 18, color: Colors.white),
                                label: Text('Trailer', style: SabuflixTheme.body(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: 'Velocidade',
                                icon: Text(
                                  '${_speed.toString().replaceAll(RegExp(r'\.0$'), '')}x',
                                  style: SabuflixTheme.body(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showSpeedMenu = !_showSpeedMenu;
                                    _showAudioMenu = false;
                                    _showSubtitleMenu = false;
                                  });
                                  _startHideTimer();
                                },
                              ),
                              if (_subtitleTracks.isNotEmpty) ...[
                                IconButton(
                                  tooltip: 'Legendas',
                                  icon: const Icon(Icons.subtitles_outlined, color: Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      _showSubtitleMenu = !_showSubtitleMenu;
                                      _showAudioMenu = false;
                                      _showSpeedMenu = false;
                                    });
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Tamanho da legenda',
                                  icon: Text(
                                    'Aa ${_subtitleSizeLabels[_subtitleSizeIndex]}',
                                    style: SabuflixTheme.body(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                  onPressed: _cycleSubtitleSize,
                                ),
                              ],
                              if (_audioTracks.length > 1)
                                IconButton(
                                  tooltip: 'Áudio',
                                  icon: const Icon(Icons.audiotrack_rounded, color: Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      _showAudioMenu = !_showAudioMenu;
                                      _showSubtitleMenu = false;
                                      _showSpeedMenu = false;
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),

                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                iconSize: 40,
                                icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                                onPressed: () => _seek(-10),
                              ),
                              const SizedBox(width: 28),
                              Container(
                                width: 70,
                                height: 70,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: SabuflixTheme.accent,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: SabuflixTheme.accent.withValues(alpha: 0.45),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  iconSize: 38,
                                  icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                                  onPressed: _playPause,
                                ),
                              ),
                              const SizedBox(width: 28),
                              IconButton(
                                iconSize: 40,
                                icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                                onPressed: () => _seek(10),
                              ),
                            ],
                          ),
                        ),



                        if (_showSpeedMenu)
                          Positioned(
                            right: 56,
                            top: 64,
                            child: _TrackMenu<double>(
                              width: 150,
                              tracks: _speeds,
                              selectedTrack: _speed,
                              titleBuilder: (s) => s == 1.0 ? 'Normal' : '${s.toString().replaceAll(RegExp(r'\.0$'), '')}x',
                              onSelect: _setSpeed,
                            ),
                          ),

                        if (_showAudioMenu)
                          Positioned(
                            right: 56,
                            top: 64,
                            child: _TrackMenu<AudioTrack>(
                              width: 220,
                              tracks: _audioTracks,
                              selectedTrack: _selectedAudioTrack,
                              titleBuilder: (t) => t.title ?? t.language ?? 'Áudio ${t.id}',
                              onSelect: (track) {
                                _player?.setAudioTrack(track);
                                setState(() {
                                  _selectedAudioTrack = track;
                                  _showAudioMenu = false;
                                });
                              },
                            ),
                          ),

                        if (_showSubtitleMenu)
                          Positioned(
                            right: _audioTracks.length > 1 ? 96 : 56,
                            top: 64,
                            child: _TrackMenu<SubtitleTrack>(
                              width: 220,
                              tracks: _subtitleTracks,
                              selectedTrack: _selectedSubtitleTrack,
                              titleBuilder: (t) => t.title ?? t.language ?? 'Legenda ${t.id}',
                              onSelect: (track) {
                                _player?.setSubtitleTrack(track);
                                setState(() {
                                  _selectedSubtitleTrack = track;
                                  _showSubtitleMenu = false;
                                });
                              },
                            ),
                          ),

                        Positioned(
                          bottom: 20,
                          left: 20,
                          right: 20,
                          child: Column(
                            children: [
                              SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 4.0,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                  activeTrackColor: SabuflixTheme.accent,
                                  inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
                                  thumbColor: SabuflixTheme.accent,
                                  overlayColor: SabuflixTheme.accent.withValues(alpha: 0.2),
                                ),
                                child: Slider(
                                  value: _currentPosition.clamp(0.0, _totalDuration > 0 ? _totalDuration : 1.0),
                                  min: 0,
                                  max: _totalDuration > 0 ? _totalDuration : 1.0,
                                  onChanged: (val) {
                                    _seekTo(val);
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Row(
                                  children: [
                                    Text(_formatDuration(_currentPosition), style: SabuflixTheme.body(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                                    const Spacer(),
                                    if (_player != null) ...[
                                      IconButton(
                                        tooltip: 'Mudo (M)',
                                        visualDensity: VisualDensity.compact,
                                        icon: Icon(
                                          _volume <= 0
                                              ? Icons.volume_off_rounded
                                              : _volume < 50
                                                  ? Icons.volume_down_rounded
                                                  : Icons.volume_up_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        onPressed: _toggleMute,
                                      ),
                                      SizedBox(
                                        width: 96,
                                        child: SliderTheme(
                                          data: SliderThemeData(
                                            trackHeight: 3,
                                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                            activeTrackColor: Colors.white,
                                            inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
                                            thumbColor: Colors.white,
                                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                          ),
                                          child: Slider(
                                            value: _volume.clamp(0.0, 100.0),
                                            max: 100,
                                            onChanged: _setVolume,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Text(_formatDuration(_totalDuration), style: SabuflixTheme.body(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrackMenu<T> extends StatelessWidget {
  final double width;
  final List<T> tracks;
  final T? selectedTrack;
  final String Function(T) titleBuilder;
  final ValueChanged<T> onSelect;

  const _TrackMenu({
    required this.width,
    required this.tracks,
    required this.selectedTrack,
    required this.titleBuilder,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: SabuflixTheme.radiusMd,
      blur: 30,
      fillOpacity: 0.65,
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        width: width,
        height: tracks.length > 5 ? 250 : null,
        child: ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            final isSelected = selectedTrack == track;
            return ListTile(
              dense: true,
              shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusSm),
              title: Text(
                titleBuilder(track),
                style: SabuflixTheme.body(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : SabuflixTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: isSelected ? const Icon(Icons.check_rounded, color: SabuflixTheme.accent, size: 18) : null,
              onTap: () => onSelect(track),
            );
          },
        ),
      ),
    );
  }
}
