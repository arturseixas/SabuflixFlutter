import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../models/cast_device.dart';
import '../models/media_item.dart';
import '../providers/continue_watching_provider.dart';
import '../services/cast_service.dart';
import '../services/pip/android_pip_controller.dart';
import '../services/pip/pip_window_controller.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/formatters.dart';
import '../widgets/cast_button.dart';
import '../widgets/glass_container.dart';

class VideoPlayerScreen extends StatefulWidget {
  final MediaItem media;
  final String? videoUrl;

  /// Season/episode context, so "Continuar Assistindo" can show and resume the
  /// exact episode instead of just the show.
  final int? season;
  final int? episode;
  final String? episodeTitle;

  /// Where playback should pick up from.
  final Duration startAt;

  const VideoPlayerScreen({
    Key? key,
    required this.media,
    this.videoUrl,
    this.season,
    this.episode,
    this.episodeTitle,
    this.startAt = Duration.zero,
  }) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _showControls = true;
  Timer? _hideTimer;
  
  Player? _player;
  VideoController? _videoController;
  
  bool _isPlaying = false;
  bool _isBuffering = false;
  double _currentPosition = 0;
  double _totalDuration = 0;
  
  bool _showAudioMenu = false;
  bool _showSubtitleMenu = false;

  List<AudioTrack> _audioTracks = [];
  AudioTrack? _selectedAudioTrack;
  
  List<SubtitleTrack> _subtitleTracks = [];
  SubtitleTrack? _selectedSubtitleTrack;

  /// Casting to a TV takes over playback entirely: the local media_kit
  /// player is paused and `_currentPosition`/`_totalDuration`/`_isPlaying`
  /// start mirroring the receiver's own status instead, so the existing
  /// scrubber, time labels, and "Continuar assistindo" tracking all keep
  /// working unchanged regardless of where the video is actually playing.
  final CastService _castService = CastService();
  CastDevice? _castDevice;
  bool _castConnecting = false;
  StreamSubscription<CastPlaybackStatus>? _castStatusSub;

  /// Android: real system Picture-in-Picture — floats over the home screen
  /// and every other app, not just within Sabuflix. Windows: a separate
  /// always-on-top floating window (see PipWindowController) that survives
  /// this very screen closing, since triggering it pops this route.
  StreamSubscription<bool>? _pipModeSub;
  StreamSubscription<void>? _pipToggleSub;
  bool _isInAndroidPip = false;

  /// Captured up front: `dispose` runs after the element is unmounted, so the
  /// provider can no longer be looked up from the context by then.
  ContinueWatchingProvider? _continueWatching;
  Timer? _progressTimer;
  bool _seekedToStart = false;
  bool _resumeBannerVisible = false;

  @override
  void initState() {
    super.initState();
    _continueWatching = Provider.of<ContinueWatchingProvider>(context, listen: false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _initPlayer();
    _startHideTimer();
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());
    _castStatusSub = _castService.status.listen(_onCastStatus);
    if (Platform.isAndroid) {
      _pipModeSub = AndroidPipController.onModeChanged.listen(_onAndroidPipModeChanged);
      _pipToggleSub = AndroidPipController.onTogglePlayPauseRequested.listen((_) => _playPause());
    }
  }

  void _onAndroidPipModeChanged(bool inPip) {
    if (!mounted) return;
    setState(() {
      _isInAndroidPip = inPip;
      if (inPip) {
        _showControls = false;
        _showAudioMenu = false;
        _showSubtitleMenu = false;
      }
    });
  }

  /// Keeps the native side's "should Home/app-switch auto-enter PiP" flag
  /// and its play/pause action icon in sync with actual playback state —
  /// there's nothing worth floating in a PiP window while paused or while
  /// the video is actually playing on a cast receiver instead.
  void _syncAndroidPipEligibility() {
    if (!Platform.isAndroid) return;
    AndroidPipController.setPlaying(_isPlaying);
    AndroidPipController.setEligible(_isPlaying && _castDevice == null);
  }

  Future<void> _enterPip() async {
    if (Platform.isAndroid) {
      await AndroidPipController.enter();
      return;
    }
    final url = widget.videoUrl;
    if (!PipWindowController.isSupported || url == null || url.isEmpty) return;

    // Paused up front so the two players never overlap while the floating
    // window spins up its own engine and starts buffering.
    _player?.pause();

    final opened = await PipWindowController.instance.open(
      media: widget.media,
      season: widget.season,
      episode: widget.episode,
      episodeTitle: widget.episodeTitle,
      videoUrl: url,
      title: widget.media.title,
      imageUrl: widget.media.fullBackdropPath,
      startAt: Duration(seconds: _currentPosition.toInt()),
    );
    if (!mounted) return;

    if (!opened) {
      // Never strand the user on a blank screen: keep playing here instead.
      _player?.play();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir a janela flutuante.')),
      );
      return;
    }

    // Playback now lives entirely in the floating window — back out to
    // wherever the user was browsing, same as clicking Firefox's PiP
    // button hands the tab's video off and returns you to the page.
    Navigator.pop(context);
  }

  void _onCastStatus(CastPlaybackStatus status) {
    if (!mounted || _castDevice == null) return;
    if (!status.connected) {
      // The receiver dropped the session on its own (app closed on the TV,
      // Wi-Fi hiccup) — fall back to local playback instead of leaving the
      // UI stuck showing a "casting" screen with a dead connection.
      _resumeLocalPlayback();
      return;
    }
    setState(() {
      _isPlaying = status.playing;
      _isBuffering = status.buffering;
      _currentPosition = status.position.inSeconds.toDouble();
      if (status.duration > Duration.zero) {
        _totalDuration = status.duration.inSeconds.toDouble();
      }
    });
    _syncAndroidPipEligibility();
  }

  Future<void> _openCastPicker() async {
    final device = await showCastPicker(context, _castService);
    if (device == null || !mounted) return;
    await _startCasting(device);
  }

  Future<void> _startCasting(CastDevice device) async {
    setState(() => _castConnecting = true);
    _player?.pause();
    try {
      await _castService.connect(device);
      await _castService.loadMedia(
        contentUrl: widget.videoUrl!,
        title: widget.media.title,
        imageUrl: widget.media.fullBackdropPath,
        startAt: Duration(seconds: _currentPosition.toInt()),
      );
      if (!mounted) return;
      setState(() {
        _castDevice = device;
        _castConnecting = false;
        _showAudioMenu = false;
        _showSubtitleMenu = false;
      });
      _syncAndroidPipEligibility();
    } catch (e) {
      await _castService.disconnect();
      if (!mounted) return;
      setState(() => _castConnecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível conectar a essa TV. Tente novamente.')),
      );
    }
  }

  /// Tears the cast session down and hands playback back to the local
  /// player, picking up from wherever the TV left off.
  ///
  /// `_castDevice` is cleared *before* awaiting `disconnect()` — that call
  /// emits its own "disconnected" status event on the way out, which would
  /// otherwise loop straight back into this method while the first call is
  /// still in flight (`_onCastStatus` only stops forwarding once the device
  /// is nulled out).
  Future<void> _resumeLocalPlayback() async {
    if (_castDevice == null) return;
    final resumeAt = Duration(seconds: _currentPosition.toInt());
    setState(() => _castDevice = null);
    _syncAndroidPipEligibility();
    await _castService.disconnect();
    if (!mounted) return;
    if (_player != null) {
      await _player!.seek(resumeAt);
      await _player!.play();
    }
  }

  /// Persists the playback position so the title shows up on the
  /// "Continuar Assistindo" shelf with the right resume point.
  void _saveProgress() {
    if (_player == null) return;
    if (_totalDuration <= 0 || _currentPosition <= 0) return;
    _continueWatching?.record(
      media: widget.media,
      season: widget.season,
      episode: widget.episode,
      episodeTitle: widget.episodeTitle,
      positionSeconds: _currentPosition.toInt(),
      durationSeconds: _totalDuration.toInt(),
      sourceUrl: widget.videoUrl,
    );
  }

  /// media_kit reports a duration only once the container has been parsed, so
  /// the resume seek waits for the first real duration instead of firing
  /// straight after `open` (where it would be dropped).
  Future<void> _seekToStartOnce() async {
    if (_seekedToStart) return;
    if (_totalDuration <= 0) return;
    _seekedToStart = true;

    final start = widget.startAt.inSeconds;
    if (start < 10 || start >= _totalDuration - 10) return;

    await _player?.seek(widget.startAt);
    if (!mounted) return;
    setState(() => _resumeBannerVisible = true);
    Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _resumeBannerVisible = false);
    });
  }

  Future<void> _initPlayer() async {
    if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
      _player = Player();
      _videoController = VideoController(_player!);
      
      _player!.stream.position.listen((Duration position) {
        if (!mounted) return;
        setState(() => _currentPosition = position.inSeconds.toDouble());
      });
      
      _player!.stream.duration.listen((Duration duration) {
        if (!mounted) return;
        setState(() => _totalDuration = duration.inSeconds.toDouble());
        if (_totalDuration > 0) _seekToStartOnce();
      });
      
      _player!.stream.playing.listen((bool playing) {
        if (!mounted) return;
        setState(() => _isPlaying = playing);
        _syncAndroidPipEligibility();
      });
      
      _player!.stream.buffering.listen((bool buffering) {
        if (!mounted) return;
        setState(() => _isBuffering = buffering);
      });

      _player!.stream.tracks.listen((tracks) {
        if (!mounted) return;
        setState(() {
          _audioTracks = tracks.audio;
          _subtitleTracks = tracks.subtitle;
        });
      });

      _player!.stream.track.listen((track) {
        if (!mounted) return;
        setState(() {
          _selectedAudioTrack = track.audio;
          _selectedSubtitleTrack = track.subtitle;
        });
      });

      try {
        await _player!.open(Media(widget.videoUrl!));
        await _player!.play();
      } catch (e) {
        print('Error initializing media_kit player: $e');
      }
    } else {
      // Mock playback if no URL (e.g. trailer mode)
      _totalDuration = 6840;
      _isPlaying = true;
      _mockPlaybackTimer();
    }
  }

  void _mockPlaybackTimer() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
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
    if (_castDevice != null) {
      if (_isPlaying) {
        _castService.pause();
      } else {
        _castService.play();
      }
      setState(() => _isPlaying = !_isPlaying); // optimistic; the status stream corrects it
      _syncAndroidPipEligibility();
    } else if (_player != null) {
      _player!.playOrPause(); // _isPlaying/eligibility follow via the player's own stream
    } else {
      setState(() => _isPlaying = !_isPlaying);
      _syncAndroidPipEligibility();
    }
    _startHideTimer();
  }

  void _seek(double seconds) {
    final newPos = (_currentPosition + seconds).clamp(0.0, _totalDuration);
    if (_castDevice != null) {
      _castService.seek(Duration(seconds: newPos.toInt()));
      setState(() => _currentPosition = newPos);
    } else if (_player != null) {
      _player!.seek(Duration(seconds: newPos.toInt()));
    } else {
      setState(() => _currentPosition = newPos);
    }
    _startHideTimer();
  }

  void _seekTo(double value) {
    if (_castDevice != null) {
      _castService.seek(Duration(seconds: value.toInt()));
      setState(() => _currentPosition = value);
    } else if (_player != null) {
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

  @override
  void dispose() {
    // Save before tearing the player down; leaving the screen is the moment
    // that matters most for resuming later.
    _saveProgress();
    _progressTimer?.cancel();
    _hideTimer?.cancel();
    _castStatusSub?.cancel();
    _castService.dispose();
    _pipModeSub?.cancel();
    _pipToggleSub?.cancel();
    if (Platform.isAndroid) AndroidPipController.setEligible(false);
    _player?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  /// `T1 E4 · Nome do episódio` for series, release year for films.
  String get _headerSubtitle {
    final tag = formatEpisodeTag(widget.season, widget.episode);
    if (tag.isEmpty) return widget.media.formattedYear;
    final name = widget.episodeTitle;
    if (name == null || name.trim().isEmpty) return tag;
    return '$tag · ${name.trim()}';
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = _videoController != null;
    final isCasting = _castDevice != null;

    if (_isInAndroidPip) {
      // Android draws its own PiP chrome (drag affordance, close, our
      // play/pause action) on top of this — everything else would just be
      // illegible at that size, so show nothing but the bare video.
      return Scaffold(
        backgroundColor: Colors.black,
        body: hasVideo
            ? Video(controller: _videoController!, controls: NoVideoControls, fill: Colors.black)
            : const SizedBox.shrink(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isCasting)
              _CastingSurface(media: widget.media, deviceName: _castDevice!.name)
            else if (hasVideo)
              Center(
                child: Video(
                  controller: _videoController!,
                  controls: NoVideoControls,
                  fill: Colors.black,
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

            if (_isBuffering && (hasVideo || isCasting))
              const Center(child: CircularProgressIndicator(color: SabuflixTheme.accent)),

            // Brief confirmation that playback jumped to where it stopped.
            Positioned(
              top: 24,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: SabuflixTheme.durationMed,
                  opacity: _resumeBannerVisible ? 1.0 : 0.0,
                  child: Center(
                    child: GlassContainer(
                      borderRadius: SabuflixTheme.radiusPill,
                      blur: 30,
                      fillOpacity: 0.5,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      child: Text(
                        'Retomando de ${_formatDuration(widget.startAt.inSeconds.toDouble())}',
                        style: SabuflixTheme.caption(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
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
                                      _headerSubtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                              if (widget.videoUrl != null &&
                                  widget.videoUrl!.isNotEmpty &&
                                  !isCasting &&
                                  (Platform.isAndroid || Platform.isWindows))
                                IconButton(
                                  icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white),
                                  tooltip: 'Picture-in-Picture',
                                  onPressed: _enterPip,
                                ),
                              if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty)
                                CastIconButton(
                                  isCasting: isCasting,
                                  isConnecting: _castConnecting,
                                  onPressed: isCasting ? _resumeLocalPlayback : _openCastPicker,
                                ),
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
                              // Track selection only applies to the local media_kit
                              // player, so it's hidden once a TV owns playback.
                              if (!isCasting && _subtitleTracks.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.subtitles_outlined, color: Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      _showSubtitleMenu = !_showSubtitleMenu;
                                      _showAudioMenu = false;
                                    });
                                  },
                                ),
                              if (!isCasting && _audioTracks.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.audiotrack_rounded, color: Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      _showAudioMenu = !_showAudioMenu;
                                      _showSubtitleMenu = false;
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_formatDuration(_currentPosition), style: SabuflixTheme.body(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
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

/// Replaces the video surface while a TV owns playback: the backdrop stays
/// visible (blurred, dimmed) so the screen doesn't just go dark, with a
/// simple "now casting" readout on top. Playback controls underneath keep
/// working as normal — they just drive the receiver instead of media_kit.
class _CastingSurface extends StatelessWidget {
  final MediaItem media;
  final String deviceName;

  const _CastingSurface({required this.media, required this.deviceName});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: media.fullBackdropPath,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          placeholder: (context, url) => Container(color: SabuflixTheme.background),
          errorWidget: (context, url, err) => Container(color: SabuflixTheme.background),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(color: Colors.black.withValues(alpha: 0.6)),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: SabuflixTheme.accent.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cast_connected_rounded, color: SabuflixTheme.accent, size: 36),
              ),
              const SizedBox(height: 18),
              Text('Transmitindo para', style: SabuflixTheme.body(fontSize: 13, color: Colors.white70)),
              const SizedBox(height: 4),
              Text(
                deviceName,
                style: SabuflixTheme.title(fontSize: 22, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                media.title,
                style: SabuflixTheme.caption(fontSize: 13, color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
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
