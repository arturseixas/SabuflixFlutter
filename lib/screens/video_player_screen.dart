import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../providers/continue_watching_provider.dart';
import '../theme/sabuflix_theme.dart';
import '../tv/tv_focus.dart';
import '../tv/tv_metrics.dart';
import '../tv/tv_platform.dart';
import '../tv/tv_remote.dart';
import '../utils/formatters.dart';
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

  /// Captured up front: `dispose` runs after the element is unmounted, so the
  /// provider can no longer be looked up from the context by then.
  ContinueWatchingProvider? _continueWatching;
  Timer? _progressTimer;
  bool _seekedToStart = false;
  bool _resumeBannerVisible = false;

  /// Holds the keyboard focus whenever the controls are hidden, so the remote
  /// still reaches the player. Without it, key events would go nowhere once
  /// the last focusable button disappeared.
  final FocusNode _keyboardNode = FocusNode(debugLabel: 'player-keys');
  final FocusNode _playPauseNode = FocusNode(debugLabel: 'player-play');

  /// Feedback for a seek made with the remote, since the controls may be
  /// hidden when it happens.
  String? _seekFlash;
  Timer? _seekFlashTimer;

  @override
  void initState() {
    super.initState();
    _continueWatching = Provider.of<ContinueWatchingProvider>(context, listen: false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    // Nothing touches the remote for two hours during a film; without this the
    // panel's own screensaver would come up mid-scene.
    TvPlatform.setKeepScreenOn(true);
    _initPlayer();
    _startHideTimer();
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());
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
        debugPrint('Error initializing media_kit player: $e');
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
        // The buttons are gone, so the key handler takes the focus back.
        _keyboardNode.requestFocus();
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _revealControls();
    } else {
      _keyboardNode.requestFocus();
    }
  }

  /// Brings the controls up and parks the focus on play/pause, which is where
  /// a remote user expects to land.
  void _revealControls() {
    if (!_showControls) setState(() => _showControls = true);
    _startHideTimer();
    if (!TvPlatform.isTv) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showControls) _playPauseNode.requestFocus();
    });
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
      setState(() => _currentPosition = newPos);
    } else {
      setState(() {
        _currentPosition = (_currentPosition + seconds).clamp(0.0, _totalDuration);
      });
    }
    _flashSeek(seconds);
    _startHideTimer();
  }

  void _seekTo(double value) {
    if (_player != null) {
      _player!.seek(Duration(seconds: value.toInt()));
    } else {
      setState(() => _currentPosition = value);
    }
    _startHideTimer();
  }

  void _flashSeek(double seconds) {
    final label = '${seconds > 0 ? '+' : '−'}${seconds.abs().toInt()}s  ·  ${_formatDuration(_currentPosition)}';
    setState(() => _seekFlash = label);
    _seekFlashTimer?.cancel();
    _seekFlashTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _seekFlash = null);
    });
  }

  /// The remote, in one place.
  ///
  /// Two modes, because a TV player has to answer the same buttons in two
  /// situations: with the controls up, where the D-pad walks the buttons, and
  /// with them hidden, where left and right have to scrub directly — that is
  /// how every set-top player behaves, and pressing left to move an invisible
  /// highlight would feel broken.
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;

    // Dedicated media keys work the same whether the controls are up or not.
    if (RemoteKey.isPlayPause(event)) {
      _playPause();
      _revealControls();
      return KeyEventResult.handled;
    }
    if (RemoteKey.isFastForward(event)) {
      _seek(30);
      return KeyEventResult.handled;
    }
    if (RemoteKey.isRewind(event)) {
      _seek(-30);
      return KeyEventResult.handled;
    }
    if (RemoteKey.isStop(event)) {
      Navigator.maybePop(context);
      return KeyEventResult.handled;
    }

    // Back closes the player; it must never be treated as "show the controls".
    if (RemoteKey.isBack(event)) return KeyEventResult.ignored;

    if (_showControls) {
      // Let the arrows drive the focus between the buttons.
      _startHideTimer();
      return KeyEventResult.ignored;
    }

    if (RemoteKey.isLeft(event)) {
      _seek(-10);
      return KeyEventResult.handled;
    }
    if (RemoteKey.isRight(event)) {
      _seek(10);
      return KeyEventResult.handled;
    }

    // Anything else — OK, up, down, a colour button — brings the controls back.
    _revealControls();
    return KeyEventResult.handled;
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
    _seekFlashTimer?.cancel();
    _keyboardNode.dispose();
    _playPauseNode.dispose();
    _player?.dispose();
    TvPlatform.setKeepScreenOn(false);
    // A television has no portrait mode and no system bars to restore; forcing
    // either would leave the app rotated into a letterbox on the way out.
    if (!TvPlatform.isTv) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
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
    final metrics = TvMetrics.of(context);
    final overscan = metrics.overscan;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _keyboardNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: GestureDetector(
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

              if (_isBuffering && hasVideo)
                const Center(child: CircularProgressIndicator(color: SabuflixTheme.accent)),

              // Brief confirmation that playback jumped to where it stopped.
              Positioned(
                top: 24 + overscan.top,
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

              // Scrubbing with the controls hidden still has to say something.
              if (_seekFlash != null && !_showControls)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: SabuflixTheme.radiusPill,
                    ),
                    child: Text(
                      _seekFlash!,
                      style: SabuflixTheme.body(
                        fontSize: metrics.isTv ? 24 : 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              if (_showControls || !_isPlaying)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  color: Colors.black.withValues(alpha: _isPlaying ? 0.35 : 0.65),
                ),

              if (_showControls) _buildControls(context, metrics),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context, TvMetrics metrics) {
    final overscan = metrics.overscan;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _showControls ? 1.0 : 0.0,
      child: Stack(
        children: [
          Positioned(
            top: 16 + overscan.top,
            left: 16 + overscan.left,
            right: 220 + overscan.right,
            child: Row(
              children: [
                if (!metrics.isTv)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
                    onPressed: () => Navigator.pop(context),
                  ),
                if (!metrics.isTv) const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.media.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SabuflixTheme.title(fontSize: metrics.isTv ? 30 : 18, color: Colors.white),
                      ),
                      Text(
                        _headerSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SabuflixTheme.body(
                          color: SabuflixTheme.textSecondary,
                          fontSize: metrics.isTv ? 18 : 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            top: 16 + overscan.top,
            right: 12 + overscan.right,
            child: Row(
              children: [
                if (widget.media.trailerKey != null && widget.media.trailerKey!.isNotEmpty)
                  _PlayerButton(
                    icon: Icons.smart_display_outlined,
                    label: 'Trailer',
                    onPressed: _openOfficialTrailer,
                  ),
                if (_subtitleTracks.isNotEmpty)
                  _PlayerButton(
                    icon: Icons.subtitles_outlined,
                    label: metrics.isTv ? 'Legendas' : null,
                    onPressed: () {
                      setState(() {
                        _showSubtitleMenu = !_showSubtitleMenu;
                        _showAudioMenu = false;
                      });
                      _startHideTimer();
                    },
                  ),
                if (_audioTracks.length > 1)
                  _PlayerButton(
                    icon: Icons.audiotrack_rounded,
                    label: metrics.isTv ? 'Áudio' : null,
                    onPressed: () {
                      setState(() {
                        _showAudioMenu = !_showAudioMenu;
                        _showSubtitleMenu = false;
                      });
                      _startHideTimer();
                    },
                  ),
              ],
            ),
          ),

          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PlayerButton(
                  icon: Icons.replay_10_rounded,
                  iconSize: metrics.isTv ? 52 : 40,
                  onPressed: () => _seek(-10),
                ),
                SizedBox(width: metrics.isTv ? 44 : 28),
                _PlayerButton(
                  icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  iconSize: metrics.isTv ? 56 : 38,
                  filled: true,
                  focusNode: _playPauseNode,
                  autofocus: metrics.isTv,
                  onPressed: _playPause,
                ),
                SizedBox(width: metrics.isTv ? 44 : 28),
                _PlayerButton(
                  icon: Icons.forward_10_rounded,
                  iconSize: metrics.isTv ? 52 : 40,
                  onPressed: () => _seek(10),
                ),
              ],
            ),
          ),

          if (_showAudioMenu)
            Positioned(
              right: 56 + overscan.right,
              top: 80 + overscan.top,
              child: _TrackMenu<AudioTrack>(
                width: metrics.isTv ? 340 : 220,
                tracks: _audioTracks,
                selectedTrack: _selectedAudioTrack,
                titleBuilder: (t) => t.title ?? t.language ?? 'Áudio ${t.id}',
                onSelect: (track) {
                  _player?.setAudioTrack(track);
                  setState(() {
                    _selectedAudioTrack = track;
                    _showAudioMenu = false;
                  });
                  _revealControls();
                },
              ),
            ),

          if (_showSubtitleMenu)
            Positioned(
              right: (_audioTracks.length > 1 ? 96 : 56) + overscan.right,
              top: 80 + overscan.top,
              child: _TrackMenu<SubtitleTrack>(
                width: metrics.isTv ? 340 : 220,
                tracks: _subtitleTracks,
                selectedTrack: _selectedSubtitleTrack,
                titleBuilder: (t) => t.title ?? t.language ?? 'Legenda ${t.id}',
                onSelect: (track) {
                  _player?.setSubtitleTrack(track);
                  setState(() {
                    _selectedSubtitleTrack = track;
                    _showSubtitleMenu = false;
                  });
                  _revealControls();
                },
              ),
            ),

          Positioned(
            bottom: 20 + overscan.bottom,
            left: 20 + overscan.left,
            right: 20 + overscan.right,
            child: Column(
              children: [
                // A slider thumb cannot be dragged with a D-pad, so the TV gets
                // a read-out bar and scrubs with left/right instead.
                if (metrics.isTv)
                  ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(3)),
                    child: LinearProgressIndicator(
                      value: _totalDuration > 0 ? (_currentPosition / _totalDuration).clamp(0.0, 1.0) : 0.0,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      valueColor: const AlwaysStoppedAnimation<Color>(SabuflixTheme.accent),
                    ),
                  )
                else
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
                      onChanged: _seekTo,
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: metrics.isTv ? 10 : 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_currentPosition),
                        style: SabuflixTheme.body(
                          color: Colors.white70,
                          fontSize: metrics.isTv ? 18 : 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (metrics.isTv)
                        Text(
                          '← 10s   ·   OK pausa   ·   Voltar sai',
                          style: SabuflixTheme.caption(fontSize: 15, color: Colors.white54),
                        ),
                      Text(
                        _formatDuration(_totalDuration),
                        style: SabuflixTheme.body(
                          color: Colors.white70,
                          fontSize: metrics.isTv ? 18 : 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A control in the player chrome, focusable by remote.
class _PlayerButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final double iconSize;
  final bool filled;
  final bool autofocus;
  final FocusNode? focusNode;
  final VoidCallback onPressed;

  const _PlayerButton({
    required this.icon,
    required this.onPressed,
    this.label,
    this.iconSize = 24,
    this.filled = false,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = TvMetrics.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TvFocusable(
        focusNode: focusNode,
        autofocus: autofocus,
        onPressed: onPressed,
        showRing: false,
        scaleOnFocus: false,
        semanticLabel: label,
        builder: (context, focused, child) {
          final Color background = focused
              ? SabuflixTheme.textPrimary
              : filled
                  ? SabuflixTheme.accent
                  : Colors.white.withValues(alpha: 0.14);
          final Color foreground = focused ? SabuflixTheme.background : Colors.white;

          return AnimatedContainer(
            duration: SabuflixTheme.durationFast,
            curve: SabuflixTheme.curveStandard,
            padding: EdgeInsets.symmetric(
              horizontal: label == null ? (metrics.isTv ? 22 : 14) : (metrics.isTv ? 26 : 16),
              vertical: metrics.isTv ? 18 : 12,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: SabuflixTheme.radiusPill,
              border: Border.all(
                color: focused ? SabuflixTheme.textPrimary : Colors.white.withValues(alpha: 0.18),
                width: focused ? metrics.focusRingWidth : 1,
              ),
              boxShadow: focused
                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 22, offset: const Offset(0, 8))]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: iconSize, color: foreground),
                if (label != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    label!,
                    style: SabuflixTheme.body(
                      fontSize: metrics.isTv ? 18 : 12,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        child: const SizedBox.shrink(),
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
    final metrics = TvMetrics.of(context);

    return GlassContainer(
      borderRadius: SabuflixTheme.radiusMd,
      blur: 30,
      fillOpacity: 0.65,
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        width: width,
        height: tracks.length > 5 ? (metrics.isTv ? 420 : 250) : null,
        child: ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            final isSelected = selectedTrack == track;
            return TvFocusable(
              // The menu appears on demand, so the current track takes the
              // focus and the remote can move straight to a neighbour.
              autofocus: isSelected,
              onPressed: () => onSelect(track),
              showRing: false,
              scaleOnFocus: false,
              semanticLabel: titleBuilder(track),
              builder: (context, focused, child) => AnimatedContainer(
                duration: SabuflixTheme.durationFast,
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: metrics.isTv ? 14 : 10),
                decoration: BoxDecoration(
                  color: focused ? SabuflixTheme.textPrimary : Colors.transparent,
                  borderRadius: SabuflixTheme.radiusSm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        titleBuilder(track),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SabuflixTheme.body(
                          fontSize: metrics.isTv ? 18 : 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: focused
                              ? SabuflixTheme.background
                              : isSelected
                                  ? Colors.white
                                  : SabuflixTheme.textSecondary,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_rounded,
                        color: focused ? SabuflixTheme.background : SabuflixTheme.accent,
                        size: metrics.isTv ? 24 : 18,
                      ),
                  ],
                ),
              ),
              child: const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }
}
