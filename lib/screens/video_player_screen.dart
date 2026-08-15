import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../models/cast_target.dart';
import '../providers/casting_provider.dart';
import '../providers/continue_watching_provider.dart';
import '../services/froststream_service.dart';
import '../services/picture_in_picture/picture_in_picture_controller.dart';
import '../services/tmdb_service.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/formatters.dart';
import '../widgets/glass_container.dart';
import '../widgets/cast_device_sheet.dart';
import '../widgets/player_settings_sheet.dart';

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
  static const double _nextEpisodeWindowSeconds = 45;

  bool _showControls = true;
  Timer? _hideTimer;

  Player? _player;
  VideoController? _videoController;

  bool _isPlaying = false;
  bool _isBuffering = false;
  double _currentPosition = 0;
  double _totalDuration = 0;

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
  final TMDBService _tmdbService = TMDBService();
  _NextEpisode? _nextEpisode;
  bool _isSwitchingEpisode = false;
  bool _isReplacingWithNextEpisode = false;
  final PictureInPictureController _pictureInPicture =
      PictureInPictureController();
  StreamSubscription<bool>? _pictureInPictureSubscription;
  bool _pictureInPictureSupported = false;
  bool _pictureInPictureActive = false;
  bool _allowRoutePop = false;
  bool _isClosingPlayer = false;
  late String? _activeVideoUrl;
  double _playbackRate = 1.0;
  double _volume = 100;
  double _volumeBeforeMute = 100;
  BoxFit _videoFit = BoxFit.contain;
  double _subtitleSize = 32;
  bool _subtitleBackground = true;
  String? _playerError;
  bool _isScrubbing = false;
  double _scrubPosition = 0;
  String? _seekFeedback;
  bool _seekFeedbackOnLeft = false;
  Timer? _seekFeedbackTimer;
  final FocusNode _keyboardFocusNode = FocusNode(debugLabel: 'player');

  @override
  void initState() {
    super.initState();
    _activeVideoUrl = widget.videoUrl;
    _continueWatching =
        Provider.of<ContinueWatchingProvider>(context, listen: false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _initPlayer();
    unawaited(_loadNextEpisode());
    _startHideTimer();
    _progressTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());
  }

  bool get _hasEpisodeContext =>
      widget.media.mediaType == 'tv' &&
      widget.season != null &&
      widget.episode != null;

  bool get _showNextEpisodeButton {
    if (_nextEpisode == null || _totalDuration <= 0) return false;
    final remaining = _totalDuration - _currentPosition;
    final finalWindow =
        _totalDuration < 450 ? _totalDuration * 0.1 : _nextEpisodeWindowSeconds;
    return _currentPosition > 0 && remaining <= finalWindow;
  }

  Future<void> _loadNextEpisode() async {
    if (!_hasEpisodeContext) return;

    final currentSeason = widget.season!;
    final currentEpisode = widget.episode!;
    final currentSeasonEpisodes = await _tmdbService.fetchSeasonEpisodes(
      widget.media.id,
      currentSeason,
    );

    final nextInSeason = _firstEpisodeAfter(
      currentSeasonEpisodes,
      season: currentSeason,
      episode: currentEpisode,
    );
    if (nextInSeason != null) {
      if (mounted) setState(() => _nextEpisode = nextInSeason);
      return;
    }

    final laterSeasons = <int>{};
    for (final season in widget.media.seasons ?? const <dynamic>[]) {
      if (season is! Map) continue;
      final seasonNumber = (season['season_number'] as num?)?.toInt();
      if (seasonNumber != null && seasonNumber > currentSeason) {
        laterSeasons.add(seasonNumber);
      }
    }

    final lastKnownSeason = widget.media.numberOfSeasons;
    if (lastKnownSeason != null) {
      for (var season = currentSeason + 1;
          season <= lastKnownSeason;
          season++) {
        laterSeasons.add(season);
      }
    } else if (laterSeasons.isEmpty) {
      // Stored items may not carry the season list. Trying the immediately
      // following season still lets a resumed episode advance correctly.
      laterSeasons.add(currentSeason + 1);
    }

    final orderedSeasons = laterSeasons.toList()..sort();
    for (final season in orderedSeasons) {
      final episodes =
          await _tmdbService.fetchSeasonEpisodes(widget.media.id, season);
      final firstEpisode =
          _firstEpisodeAfter(episodes, season: season, episode: 0);
      if (firstEpisode != null) {
        if (mounted) setState(() => _nextEpisode = firstEpisode);
        return;
      }
    }
  }

  _NextEpisode? _firstEpisodeAfter(
    List<dynamic> episodes, {
    required int season,
    required int episode,
  }) {
    final candidates = episodes.whereType<Map>().where((item) {
      final number = (item['episode_number'] as num?)?.toInt();
      return number != null && number > episode;
    }).toList()
      ..sort((a, b) {
        final aNumber = (a['episode_number'] as num).toInt();
        final bNumber = (b['episode_number'] as num).toInt();
        return aNumber.compareTo(bNumber);
      });

    if (candidates.isEmpty) return null;
    final payload = candidates.first;
    return _NextEpisode(
      season: season,
      episode: (payload['episode_number'] as num).toInt(),
      title: payload['name']?.toString(),
    );
  }

  Future<void> _playNextEpisode() async {
    final nextEpisode = _nextEpisode;
    if (nextEpisode == null || _isSwitchingEpisode) return;

    final imdbId = widget.media.imdbId;
    if (imdbId == null || imdbId.isEmpty) {
      _showPlayerMessage('Não foi possível localizar o próximo episódio.');
      return;
    }

    setState(() => _isSwitchingEpisode = true);
    try {
      final streams = await FrostStreamService.fetchStreams(
        imdbId: imdbId,
        type: 'tv',
        season: nextEpisode.season,
        episode: nextEpisode.episode,
      );
      final stream = streams.cast<Map<String, dynamic>?>().firstWhere(
            (item) => (item?['url'] ?? '').toString().isNotEmpty,
            orElse: () => null,
          );

      if (!mounted) return;
      if (stream == null) {
        _showPlayerMessage('Nenhuma fonte encontrada para o próximo episódio.');
        return;
      }

      // Keep dispose from restoring the almost-finished episode to the shelf.
      _currentPosition = _totalDuration;
      await _continueWatching?.record(
        media: widget.media,
        season: widget.season,
        episode: widget.episode,
        episodeTitle: widget.episodeTitle,
        positionSeconds: _totalDuration.toInt(),
        durationSeconds: _totalDuration.toInt(),
        sourceUrl: _activeVideoUrl,
      );
      await _player?.pause();
      await _pictureInPicture.exit();
      if (!mounted) return;

      _isReplacingWithNextEpisode = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(
            media: widget.media,
            videoUrl: stream['url'].toString(),
            season: nextEpisode.season,
            episode: nextEpisode.episode,
            episodeTitle: nextEpisode.title,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        _showPlayerMessage('Não foi possível abrir o próximo episódio.');
      }
    } finally {
      if (mounted && !_isReplacingWithNextEpisode) {
        setState(() => _isSwitchingEpisode = false);
      }
    }
  }

  void _showPlayerMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
      sourceUrl: _activeVideoUrl,
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
    if (_activeVideoUrl != null && _activeVideoUrl!.isNotEmpty) {
      _player = Player();
      _videoController = VideoController(_player!);
      await _attachPictureInPicture(_player!);

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

      _player!.stream.rate.listen((double rate) {
        if (mounted) setState(() => _playbackRate = rate);
      });

      _player!.stream.volume.listen((double volume) {
        if (mounted) setState(() => _volume = volume);
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
        await _player!.open(Media(_activeVideoUrl!));
        await _player!.play();
      } catch (e) {
        if (mounted) {
          setState(
              () => _playerError = 'Não foi possível reproduzir esta fonte.');
        }
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

  Future<void> _attachPictureInPicture(Player player) async {
    try {
      await _pictureInPicture.attach(player);
      if (!mounted) return;
      setState(() {
        _pictureInPictureSupported = _pictureInPicture.isSupported;
        _pictureInPictureActive = _pictureInPicture.isActive;
      });
      _pictureInPictureSubscription =
          _pictureInPicture.states.listen(_onPictureInPictureStateChanged);
    } catch (_) {
      // PiP is optional. Playback must remain usable in unsupported browsers.
      if (mounted) setState(() => _pictureInPictureSupported = false);
    }
  }

  void _onPictureInPictureStateChanged(bool active) {
    if (!mounted) return;
    _hideTimer?.cancel();
    setState(() {
      _pictureInPictureActive = active;
      _showControls = !active;
    });
    if (!active) _startHideTimer();
  }

  Future<void> _togglePictureInPicture() async {
    try {
      await _pictureInPicture.toggle();
    } catch (_) {
      if (mounted) {
        _showPlayerMessage('NÃ£o foi possÃ­vel abrir o modo PiP.');
      }
    }
  }

  Future<void> _closePlayer() async {
    if (_isClosingPlayer) return;
    _isClosingPlayer = true;
    try {
      // Chromium must return the video element to Flutter before media_kit is
      // disposed. Otherwise closing PiP can leave a black/broken platform view.
      await _pictureInPicture.exit();
      if (!mounted) return;
      setState(() => _allowRoutePop = true);
      Navigator.of(context).pop();
    } catch (_) {
      _isClosingPlayer = false;
      if (mounted) {
        _showPlayerMessage('Feche o PiP para sair do player.');
      }
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) {
        setState(() {
          _showControls = false;
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

  void _showSeekFeedback(double seconds, {required bool onLeft}) {
    _seekFeedbackTimer?.cancel();
    setState(() {
      _seekFeedback = seconds < 0 ? '-10 segundos' : '+10 segundos';
      _seekFeedbackOnLeft = onLeft;
    });
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 850), () {
      if (mounted) setState(() => _seekFeedback = null);
    });
  }

  void _handleDoubleTap(TapDownDetails details) {
    final left =
        details.localPosition.dx < MediaQuery.sizeOf(context).width / 2;
    final seconds = left ? -10.0 : 10.0;
    _seek(seconds);
    _showSeekFeedback(seconds, onLeft: left);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
      _playPause();
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _seek(-10);
      _showSeekFeedback(-10, onLeft: true);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _seek(10);
      _showSeekFeedback(10, onLeft: false);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _setVolume(_volume + 5);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _setVolume(_volume - 5);
    } else if (key == LogicalKeyboardKey.keyM) {
      _toggleMute();
    } else if (key == LogicalKeyboardKey.escape) {
      unawaited(_closePlayer());
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _setVolume(double value) {
    final normalized = value.clamp(0.0, 100.0);
    if (normalized > 0) _volumeBeforeMute = normalized;
    _player?.setVolume(normalized);
    if (_player == null) setState(() => _volume = normalized);
    _startHideTimer();
  }

  void _toggleMute() {
    if (_volume > 0) {
      _volumeBeforeMute = _volume;
      _setVolume(0);
    } else {
      _setVolume(_volumeBeforeMute <= 0 ? 100 : _volumeBeforeMute);
    }
  }

  Future<void> _openPlayerSettings() async {
    _hideTimer?.cancel();
    await showPlayerSettingsSheet(
      context,
      rate: _playbackRate,
      videoFit: _videoFit,
      subtitleSize: _subtitleSize,
      subtitleBackground: _subtitleBackground,
      audioTracks: _audioTracks,
      selectedAudioTrack: _selectedAudioTrack,
      subtitleTracks: _subtitleTracks,
      selectedSubtitleTrack: _selectedSubtitleTrack,
      onRateChanged: (rate) {
        _player?.setRate(rate);
        if (_player == null) setState(() => _playbackRate = rate);
      },
      onVideoFitChanged: (fit) => setState(() => _videoFit = fit),
      onSubtitleStyleChanged: (size, background) => setState(() {
        _subtitleSize = size;
        _subtitleBackground = background;
      }),
      onAudioTrackChanged: (track) {
        _player?.setAudioTrack(track);
        setState(() => _selectedAudioTrack = track);
      },
      onSubtitleTrackChanged: (track) {
        _player?.setSubtitleTrack(track);
        setState(() {
          _selectedSubtitleTrack = track;
        });
      },
    );
    if (mounted) _startHideTimer();
  }

  Future<void> _retryPlayback() async {
    final player = _player;
    final videoUrl = _activeVideoUrl;
    if (player == null || videoUrl == null) return;
    final resumeAt = Duration(seconds: _currentPosition.toInt());
    setState(() {
      _playerError = null;
      _isBuffering = true;
    });
    try {
      await player.open(Media(videoUrl), play: true);
      if (resumeAt > Duration.zero) await player.seek(resumeAt);
    } catch (_) {
      if (mounted) {
        setState(() => _playerError = 'A fonte continua indisponível.');
      }
    }
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

  Future<void> _openCastDevices() async {
    final videoUrl = _activeVideoUrl;
    if (videoUrl == null || videoUrl.isEmpty) {
      _showPlayerMessage('Esta fonte não está disponível para transmitir.');
      return;
    }

    final didStartCasting = await showCastDeviceSheet(
      context,
      media: CastMediaRequest(
        url: videoUrl,
        title: widget.episodeTitle?.trim().isNotEmpty == true
            ? '${widget.media.title} · ${widget.episodeTitle!.trim()}'
            : widget.media.title,
        imageUrl: widget.media.fullBackdropPath,
        startPosition: Duration(seconds: _currentPosition.toInt()),
      ),
    );
    if (didStartCasting != true || !mounted) return;

    if (_player != null) {
      await _player!.pause();
    } else {
      setState(() => _isPlaying = false);
    }
    if (!mounted) return;
    final target = context.read<CastingProvider>().activeTarget;
    _showPlayerMessage(
      target == null
          ? 'Transmissão iniciada.'
          : 'Transmitindo para ${target.name}.',
    );
  }

  @override
  void dispose() {
    // Save before tearing the player down; leaving the screen is the moment
    // that matters most for resuming later.
    _saveProgress();
    _progressTimer?.cancel();
    _hideTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    _keyboardFocusNode.dispose();
    _pictureInPictureSubscription?.cancel();
    unawaited(_pictureInPicture.dispose());
    _player?.dispose();
    if (!_isReplacingWithNextEpisode) {
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
    final displayedPosition = _isScrubbing ? _scrubPosition : _currentPosition;

    return PopScope(
      canPop: _allowRoutePop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_closePlayer());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          autofocus: true,
          focusNode: _keyboardFocusNode,
          onKeyEvent: _handleKeyEvent,
          child: GestureDetector(
            onTap: _toggleControls,
            onDoubleTapDown: _handleDoubleTap,
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
                      fit: _videoFit,
                      subtitleViewConfiguration: SubtitleViewConfiguration(
                        style: TextStyle(
                          height: 1.35,
                          fontSize: _subtitleSize,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          backgroundColor: _subtitleBackground
                              ? Colors.black.withValues(alpha: 0.72)
                              : Colors.transparent,
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 34),
                      ),
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

                if (_isBuffering && hasVideo && _playerError == null)
                  const Center(
                      child: CircularProgressIndicator(
                          color: SabuflixTheme.accent)),

                if (_playerError != null)
                  Center(
                    child: GlassContainer(
                      borderRadius: SabuflixTheme.radiusLg,
                      blur: 34,
                      fillOpacity: 0.58,
                      padding: const EdgeInsets.all(22),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 340),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_disabled_rounded,
                                size: 38, color: Colors.white70),
                            const SizedBox(height: 12),
                            Text(
                              _playerError!,
                              textAlign: TextAlign.center,
                              style: SabuflixTheme.body(color: Colors.white),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _retryPlayback,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                if (_seekFeedback != null)
                  Positioned(
                    top: MediaQuery.sizeOf(context).height * 0.42,
                    left: _seekFeedbackOnLeft
                        ? MediaQuery.sizeOf(context).width * 0.2
                        : null,
                    right: !_seekFeedbackOnLeft
                        ? MediaQuery.sizeOf(context).width * 0.2
                        : null,
                    child: GlassContainer(
                      borderRadius: SabuflixTheme.radiusPill,
                      blur: 26,
                      fillOpacity: 0.38,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 9),
                      child: Text(
                        _seekFeedback!,
                        style: SabuflixTheme.caption(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

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
                    color: Colors.black
                        .withValues(alpha: _isPlaying ? 0.35 : 0.65),
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
                              right: MediaQuery.sizeOf(context).width > 900
                                  ? 390
                                  : 270,
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back_rounded,
                                        color: Colors.white, size: 26),
                                    onPressed: _closePlayer,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          widget.media.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: SabuflixTheme.title(
                                              fontSize: 18,
                                              color: Colors.white),
                                        ),
                                        Text(
                                          _headerSubtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: SabuflixTheme.body(
                                              color:
                                                  SabuflixTheme.textSecondary,
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
                              child: Consumer<CastingProvider>(
                                builder: (context, casting, _) => Row(
                                  children: [
                                    IconButton(
                                      tooltip: casting.isConnected
                                          ? 'Transmitindo para ${casting.activeTarget!.name}'
                                          : 'Transmitir para TV',
                                      onPressed: _openCastDevices,
                                      icon: Icon(
                                        casting.isConnected
                                            ? Icons.cast_connected_rounded
                                            : Icons.cast_rounded,
                                        color: casting.isConnected
                                            ? SabuflixTheme.accent
                                            : Colors.white,
                                      ),
                                    ),
                                    if (_pictureInPictureSupported)
                                      IconButton(
                                        tooltip: _pictureInPictureActive
                                            ? 'Sair do Picture-in-Picture'
                                            : 'Picture-in-Picture',
                                        onPressed: _togglePictureInPicture,
                                        icon: Icon(
                                          _pictureInPictureActive
                                              ? Icons.picture_in_picture_rounded
                                              : Icons
                                                  .picture_in_picture_alt_rounded,
                                          color: _pictureInPictureActive
                                              ? SabuflixTheme.accent
                                              : Colors.white,
                                        ),
                                      ),
                                    TextButton.icon(
                                      onPressed: _openOfficialTrailer,
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.12),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                SabuflixTheme.radiusSm),
                                      ),
                                      icon: const Icon(
                                          Icons.smart_display_outlined,
                                          size: 18,
                                          color: Colors.white),
                                      label: Text('Trailer',
                                          style: SabuflixTheme.body(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white)),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      tooltip: 'Opções de reprodução',
                                      icon: const Icon(Icons.tune_rounded,
                                          color: Colors.white),
                                      onPressed: _openPlayerSettings,
                                    ),
                                  ],
                                ),
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
                                      value: displayedPosition.clamp(
                                          0.0,
                                          _totalDuration > 0
                                              ? _totalDuration
                                              : 1.0),
                                      min: 0,
                                      max: _totalDuration > 0
                                          ? _totalDuration
                                          : 1.0,
                                      onChangeStart: (value) {
                                        setState(() {
                                          _isScrubbing = true;
                                          _scrubPosition = value;
                                        });
                                      },
                                      onChanged: (value) {
                                        setState(() => _scrubPosition = value);
                                      },
                                      onChangeEnd: (value) {
                                        _seekTo(value);
                                        setState(() => _isScrubbing = false);
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_formatDuration(displayedPosition),
                                            style: SabuflixTheme.body(
                                                color: Colors.white70,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600)),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: _volume > 0
                                                  ? 'Silenciar'
                                                  : 'Ativar som',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: _toggleMute,
                                              icon: Icon(
                                                _volume <= 0
                                                    ? Icons.volume_off_rounded
                                                    : _volume < 50
                                                        ? Icons
                                                            .volume_down_rounded
                                                        : Icons
                                                            .volume_up_rounded,
                                                color: Colors.white70,
                                                size: 19,
                                              ),
                                            ),
                                            if (MediaQuery.sizeOf(context)
                                                    .width >
                                                720)
                                              SizedBox(
                                                width: 100,
                                                child: Slider(
                                                  min: 0,
                                                  max: 100,
                                                  value: _volume.clamp(0, 100),
                                                  onChanged: _setVolume,
                                                ),
                                              ),
                                            const SizedBox(width: 10),
                                            Text(
                                                _formatDuration(_totalDuration),
                                                style: SabuflixTheme.body(
                                                    color: Colors.white70,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          ],
                                        ),
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

                if (_showNextEpisodeButton)
                  AnimatedPositioned(
                    duration: SabuflixTheme.durationMed,
                    curve: Curves.easeOutCubic,
                    right: 24,
                    bottom: _showControls ? 92 : 24,
                    child: GlassContainer(
                      borderRadius: SabuflixTheme.radiusPill,
                      blur: 28,
                      fillOpacity: 0.3,
                      hasGlow: true,
                      glowColor: SabuflixTheme.accent,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: SabuflixTheme.radiusPill,
                          onTap: _isSwitchingEpisode ? null : _playNextEpisode,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isSwitchingEpisode)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: SabuflixTheme.accent,
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.skip_next_rounded,
                                    size: 22,
                                    color: SabuflixTheme.textPrimary,
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  _isSwitchingEpisode
                                      ? 'Carregando...'
                                      : 'Próximo episódio',
                                  style: SabuflixTheme.caption(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: SabuflixTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NextEpisode {
  final int season;
  final int episode;
  final String? title;

  const _NextEpisode({
    required this.season,
    required this.episode,
    this.title,
  });
}
