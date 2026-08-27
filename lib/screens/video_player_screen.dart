import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../providers/continue_watching_provider.dart';
import '../providers/watched_provider.dart';
import '../services/native_pip_service.dart';
import '../theme/sabuflix_theme.dart';
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
    super.key,
    required this.media,
    this.videoUrl,
    this.season,
    this.episode,
    this.episodeTitle,
    this.startAt = Duration.zero,
  });

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
  WatchedProvider? _watched;
  bool _markedCompleted = false;
  Timer? _progressTimer;
  bool _seekedToStart = false;
  bool _resumeBannerVisible = false;
  bool _pipSupported = false;
  bool _isInPip = false;

  @override
  void initState() {
    super.initState();
    _continueWatching =
        Provider.of<ContinueWatchingProvider>(context, listen: false);
    _watched = Provider.of<WatchedProvider>(context, listen: false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _initPlayer();
    _initPip();
    _startHideTimer();
    _progressTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());
  }

  Future<void> _initPip() async {
    final pip = NativePipService.instance;
    pip.onPipChanged = (active) {
      if (!mounted) return;
      setState(() {
        _isInPip = active;
        if (active) _showControls = false;
      });
    };
    final supported = await pip.isSupported();
    if (mounted) setState(() => _pipSupported = supported);
  }

  Future<void> _togglePip() async {
    final pip = NativePipService.instance;
    if (pip.isActive) {
      await pip.exit();
    } else {
      setState(() => _showControls = false);
      await pip.enter();
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
    final progress = _currentPosition / _totalDuration;
    if (!_markedCompleted &&
        widget.media.mediaType == 'movie' &&
        progress >= 0.95) {
      _markedCompleted = true;
      _watched?.markWatched(widget.media);
    }
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
      }
    });
  }

  void _toggleControls() {
    if (_isInPip && defaultTargetPlatform == TargetPlatform.android) return;
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
        _currentPosition =
            (_currentPosition + seconds).clamp(0.0, _totalDuration);
      });
    }
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
    if (widget.media.trailerKey != null &&
        widget.media.trailerKey!.isNotEmpty) {
      final Uri url = Uri.parse(
          'https://www.youtube.com/watch?v=${widget.media.trailerKey}');
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
    NativePipService.instance.onPipChanged = null;
    NativePipService.instance.exit();
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
                ),
              )
            else
              CachedNetworkImage(
                imageUrl: widget.media.fullBackdropPath,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                placeholder: (context, url) =>
                    Container(color: SabuflixTheme.background),
                errorWidget: (context, url, err) =>
                    Container(color: SabuflixTheme.background),
              ),

            if (_isBuffering && hasVideo)
              const Center(
                  child:
                      CircularProgressIndicator(color: SabuflixTheme.accent)),

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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      child: Text(
                        'Retomando de ${_formatDuration(widget.startAt.inSeconds.toDouble())}',
                        style: SabuflixTheme.caption(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
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
                                icon: const Icon(Icons.arrow_back_rounded,
                                    color: Colors.white, size: 26),
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
                                      style: SabuflixTheme.title(
                                          fontSize: 18, color: Colors.white),
                                    ),
                                    Text(
                                      _headerSubtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: SabuflixTheme.body(
                                          color: SabuflixTheme.textSecondary,
                                          fontSize: 12),
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
                              if (_pipSupported)
                                IconButton(
                                  tooltip: _isInPip
                                      ? 'Sair do Picture-in-Picture'
                                      : 'Picture-in-Picture',
                                  icon: Icon(
                                    _isInPip
                                        ? Icons.picture_in_picture_alt_rounded
                                        : Icons.picture_in_picture_rounded,
                                    color: Colors.white,
                                  ),
                                  onPressed: _togglePip,
                                ),
                              TextButton.icon(
                                onPressed: _openOfficialTrailer,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.12),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: SabuflixTheme.radiusSm),
                                ),
                                icon: const Icon(Icons.smart_display_outlined,
                                    size: 18, color: Colors.white),
                                label: Text('Trailer',
                                    style: SabuflixTheme.body(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white)),
                              ),
                              const SizedBox(width: 4),
                              if (_subtitleTracks.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.subtitles_outlined,
                                      color: Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      _showSubtitleMenu = !_showSubtitleMenu;
                                      _showAudioMenu = false;
                                    });
                                  },
                                ),
                              if (_audioTracks.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.audiotrack_rounded,
                                      color: Colors.white),
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
                                icon: const Icon(Icons.replay_10_rounded,
                                    color: Colors.white),
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
                                      color: SabuflixTheme.accent
                                          .withValues(alpha: 0.45),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  iconSize: 38,
                                  icon: Icon(
                                      _isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.white),
                                  onPressed: _playPause,
                                ),
                              ),
                              const SizedBox(width: 28),
                              IconButton(
                                iconSize: 40,
                                icon: const Icon(Icons.forward_10_rounded,
                                    color: Colors.white),
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
                              titleBuilder: (t) =>
                                  t.title ?? t.language ?? 'Áudio ${t.id}',
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
                              titleBuilder: (t) =>
                                  t.title ?? t.language ?? 'Legenda ${t.id}',
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
                                  thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 7),
                                  activeTrackColor: SabuflixTheme.accent,
                                  inactiveTrackColor:
                                      Colors.white.withValues(alpha: 0.25),
                                  thumbColor: SabuflixTheme.accent,
                                  overlayColor: SabuflixTheme.accent
                                      .withValues(alpha: 0.2),
                                ),
                                child: Slider(
                                  value: _currentPosition.clamp(
                                      0.0,
                                      _totalDuration > 0
                                          ? _totalDuration
                                          : 1.0),
                                  min: 0,
                                  max:
                                      _totalDuration > 0 ? _totalDuration : 1.0,
                                  onChanged: (val) {
                                    _seekTo(val);
                                  },
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_formatDuration(_currentPosition),
                                        style: SabuflixTheme.body(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                    Text(_formatDuration(_totalDuration),
                                        style: SabuflixTheme.body(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
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
              shape:
                  RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusSm),
              title: Text(
                titleBuilder(track),
                style: SabuflixTheme.body(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color:
                      isSelected ? Colors.white : SabuflixTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_rounded,
                      color: SabuflixTheme.accent, size: 18)
                  : null,
              onTap: () => onSelect(track),
            );
          },
        ),
      ),
    );
  }
}
