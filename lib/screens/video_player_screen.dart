import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../models/media_item.dart';
import '../providers/cast_provider.dart';
import '../providers/continue_watching_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/watched_provider.dart';
import '../services/addon_service.dart';
import '../services/cast/cast_device.dart';
import '../services/native_pip_service.dart';
import '../services/playback_resolver.dart';
import '../services/tmdb_service.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_route.dart';
import '../utils/browser_playback.dart';
import '../utils/formatters.dart';
import '../widgets/glass_container.dart';
import '../widgets/player/player_sheets.dart';
import '../widgets/player/player_widgets.dart';
import 'cast_picker_sheet.dart';
import 'cast_remote_screen.dart';

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
  // --- Player -------------------------------------------------------------
  Player? _player;
  VideoController? _videoController;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  String? _playbackError;
  Timer? _startupTimer;

  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _completed = false;
  bool _waitingForBrowserPlay = kIsWeb;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffered = Duration.zero;
  Duration? _scrubbing;
  double _volume = 100;
  double _volumeBeforeMute = 100;
  double _speed = 1.0;
  BoxFit _fit = BoxFit.contain;

  // --- Tracks -------------------------------------------------------------
  List<AudioTrack> _audioTracks = [];
  AudioTrack? _selectedAudioTrack;
  List<SubtitleTrack> _subtitleTracks = [];
  List<SubtitleTrack> _externalSubtitles = [];
  SubtitleTrack? _selectedSubtitleTrack;
  bool _loadingSubtitles = false;
  bool _subtitleChosenByUser = false;
  bool _subtitleAutoApplied = false;

  // --- Chrome -------------------------------------------------------------
  bool _showControls = true;
  bool _locked = false;
  Timer? _hideTimer;
  bool _resumeBannerVisible = false;
  bool _seekedToStart = false;
  int? _seekFeedbackSeconds;
  Timer? _seekFeedbackTimer;
  bool _volumeFeedbackVisible = false;
  Timer? _volumeFeedbackTimer;
  double? _volumeDragStart;
  bool _pipSupported = false;
  bool _isInPip = false;
  bool _sheetOpen = false;

  // --- Sleep timer --------------------------------------------------------
  Timer? _sleepTimer;
  DateTime? _sleepAt;
  bool _sleepAtEnd = false;

  // --- Next episode -------------------------------------------------------
  final PlaybackResolver _resolver = PlaybackResolver();
  EpisodePointer? _next;
  bool _nextLookedUp = false;
  Future<Map<String, dynamic>?>? _nextStream;
  bool _nextCardDismissed = false;
  Timer? _countdownTimer;
  int? _countdown;
  bool _startingNext = false;

  // Episode sheet cache.
  int? _sheetSeason;
  List<dynamic> _sheetEpisodes = [];
  bool _sheetLoading = false;

  /// Captured up front: `dispose` runs after the element is unmounted, so the
  /// providers can no longer be looked up from the context by then.
  ContinueWatchingProvider? _continueWatching;
  WatchedProvider? _watched;
  SettingsProvider? _settings;
  bool _markedCompleted = false;
  Timer? _progressTimer;

  bool get _isEpisode => widget.season != null && widget.episode != null;
  bool get _isSeries => widget.media.mediaType == 'tv';
  bool get _hasVideo => _videoController != null;
  Duration get _remaining => _duration - _position;

  @override
  void initState() {
    super.initState();
    _continueWatching = context.read<ContinueWatchingProvider>();
    _watched = context.read<WatchedProvider>();
    _settings = context.read<SettingsProvider>();
    _speed = _settings?.playbackSpeed ?? 1.0;
    _volume = _settings?.volume ?? 100;
    if (!kIsWeb) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    _initPlayer();
    _initPip();
    _startHideTimer();
    _progressTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());
    if (_isSeries && _isEpisode) _lookupNextEpisode();
  }

  // --- Setup -------------------------------------------------------------

  Future<void> _initPlayer() async {
    final url = widget.videoUrl;
    if (url == null || url.isEmpty) {
      _playbackError = 'Nenhuma fonte de vídeo disponível.';
      return;
    }
    try {
      final player = Player();
      _player = player;
      _videoController = VideoController(player);

      _subscriptions.add(player.stream.error.listen((message) {
        if (kIsWeb && isRecoverableBrowserPlayError(message)) {
          _startupTimer?.cancel();
          if (!mounted) return;
          setState(() {
            _waitingForBrowserPlay = true;
            _isPlaying = false;
            _showControls = true;
            _isBuffering = false;
          });
        } else {
          debugPrint('Playback error: $message');
          _failPlayback();
        }
      }));
      if (!kIsWeb) {
        _startupTimer = Timer(const Duration(seconds: 30), _failPlayback);
      }
      _subscriptions.add(player.stream.position.listen((position) {
        if (!mounted) return;
        if (position > Duration.zero) _startupTimer?.cancel();
        setState(() => _position = position);
        _checkEndOfEpisode();
      }));
      _subscriptions.add(player.stream.duration.listen((duration) {
        if (!mounted) return;
        setState(() => _duration = duration);
        if (duration > Duration.zero) _seekToStartOnce();
      }));
      _subscriptions.add(player.stream.buffer.listen((buffer) {
        if (!mounted) return;
        setState(() => _buffered = buffer);
      }));
      _subscriptions.add(player.stream.playing.listen((playing) {
        if (!mounted) return;
        if (playing && kIsWeb) _startupTimer?.cancel();
        setState(() {
          _isPlaying = playing;
          if (playing) _waitingForBrowserPlay = false;
        });
        if (playing) _startHideTimer();
      }));
      _subscriptions.add(player.stream.buffering.listen((buffering) {
        if (!mounted) return;
        setState(() => _isBuffering = buffering);
      }));
      _subscriptions.add(player.stream.completed.listen((completed) {
        if (!mounted || !completed) return;
        setState(() {
          _completed = true;
          _showControls = true;
        });
        _saveProgress();
        _onCompleted();
      }));
      _subscriptions.add(player.stream.volume.listen((volume) {
        if (!mounted) return;
        setState(() => _volume = volume);
      }));
      _subscriptions.add(player.stream.rate.listen((rate) {
        if (!mounted) return;
        setState(() => _speed = rate);
      }));
      _subscriptions.add(player.stream.tracks.listen((tracks) {
        if (!mounted) return;
        setState(() {
          _audioTracks = tracks.audio
              .where((t) => t.id != 'auto' && t.id != 'no')
              .toList();
          _subtitleTracks = [
            ...tracks.subtitle.where((t) => t.id != 'auto' && t.id != 'no'),
            ..._externalSubtitles,
          ];
        });
        _applySubtitlePreference();
      }));
      _subscriptions.add(player.stream.track.listen((track) {
        if (!mounted) return;
        setState(() {
          _selectedAudioTrack = track.audio;
          if (_selectedSubtitleTrack == null ||
              !(_selectedSubtitleTrack!.uri || _selectedSubtitleTrack!.data)) {
            _selectedSubtitleTrack = track.subtitle;
          }
        });
      }));

      await player.setVolume(_volume);
      if ((_speed - 1.0).abs() > 0.01) await player.setRate(_speed);
      // Opening a route/awaiting a manifest can consume browser user activation.
      // Load paused, then start from the visible Play button's gesture.
      await player.open(Media(url), play: !kIsWeb);
      unawaited(_loadExternalSubtitles());
    } catch (error) {
      debugPrint('Player init failed: $error');
      _failPlayback();
    }
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

  /// media_kit reports a duration only once the container has been parsed, so
  /// the resume seek waits for the first real duration instead of firing
  /// straight after `open` (where it would be dropped).
  Future<void> _seekToStartOnce() async {
    if (_seekedToStart || _duration <= Duration.zero) return;
    _seekedToStart = true;
    final start = widget.startAt;
    if (start < const Duration(seconds: 10) ||
        start >= _duration - const Duration(seconds: 10)) {
      return;
    }
    await _player?.seek(start);
    if (!mounted) return;
    setState(() => _resumeBannerVisible = true);
    Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _resumeBannerVisible = false);
    });
  }

  Future<void> _loadExternalSubtitles() async {
    var imdbId = widget.media.imdbId;
    if (mounted) setState(() => _loadingSubtitles = true);
    if ((imdbId == null || imdbId.isEmpty) && widget.media.id > 0) {
      try {
        final details = await TMDBService()
            .fetchMediaDetails(widget.media.id, widget.media.mediaType);
        imdbId = details?.imdbId;
      } catch (_) {}
    }
    if (imdbId == null || imdbId.isEmpty) {
      if (mounted) setState(() => _loadingSubtitles = false);
      return;
    }
    final items = await const AddonService().subtitles(
      imdbId: imdbId,
      type: widget.media.mediaType,
      season: widget.season,
      episode: widget.episode,
    );
    if (!mounted || _player == null) return;
    final counts = <String, int>{};
    setState(() {
      _externalSubtitles = items.map((item) {
        final lang = item['lang']?.toString().toLowerCase().trim() ?? 'und';
        final index = (counts[lang] = (counts[lang] ?? 0) + 1);
        final label = describeSubtitleTrack(
            SubtitleTrack(item['url'].toString(), null, lang, uri: true), 0);
        return SubtitleTrack.uri(
          item['url'].toString(),
          title: index == 1 ? label : '$label $index',
          language: lang,
        );
      }).toList();
      _subtitleTracks = [
        ..._player!.state.tracks.subtitle
            .where((t) => t.id != 'auto' && t.id != 'no'),
        ..._externalSubtitles,
      ];
      _loadingSubtitles = false;
    });
    _applySubtitlePreference();
  }

  /// Turns on the first subtitle matching the preferred language, once, unless
  /// the viewer already picked something by hand.
  void _applySubtitlePreference() {
    if (_subtitleAutoApplied || _subtitleChosenByUser) return;
    final preference =
        _settings?.subtitlePreference ?? SubtitlePreference.portuguese;
    if (preference == SubtitlePreference.off) {
      _subtitleAutoApplied = true;
      return;
    }
    final codes = preference.languageCodes;
    SubtitleTrack? match;
    for (final track in _subtitleTracks) {
      final language = track.language?.toLowerCase().trim();
      final title = track.title?.toLowerCase() ?? '';
      if ((language != null && codes.contains(language)) ||
          (preference == SubtitlePreference.portuguese &&
              (title.contains('portugu') || title.contains('brasil')))) {
        match = track;
        break;
      }
    }
    if (match == null) return;
    _subtitleAutoApplied = true;
    // Prefer an embedded track when the source has one with the same language.
    unawaited(_selectSubtitle(match, byUser: false));
  }

  // --- Progress & completion ---------------------------------------------

  /// Persists the playback position so the title shows up on the
  /// "Continuar Assistindo" shelf with the right resume point.
  void _saveProgress() {
    if (_player == null) return;
    if (_duration <= Duration.zero || _position <= Duration.zero) return;
    _continueWatching?.record(
      media: widget.media,
      season: widget.season,
      episode: widget.episode,
      episodeTitle: widget.episodeTitle,
      positionSeconds: _position.inSeconds,
      durationSeconds: _duration.inSeconds,
      sourceUrl: widget.videoUrl,
    );
    final progress = _position.inMilliseconds / _duration.inMilliseconds;
    if (!_markedCompleted && progress >= 0.95) {
      _markedCompleted = true;
      if (_isEpisode) {
        _watched?.markEpisodeWatched(
            widget.media.id, widget.season!, widget.episode!);
      } else if (widget.media.mediaType == 'movie') {
        _watched?.markWatched(widget.media);
      }
    }
  }

  Future<void> _lookupNextEpisode() async {
    if (_nextLookedUp) return;
    _nextLookedUp = true;
    try {
      final next = await _resolver.nextEpisode(
        media: widget.media,
        season: widget.season!,
        episode: widget.episode!,
        seasons: widget.media.seasons,
      );
      if (mounted) setState(() => _next = next);
    } catch (error) {
      debugPrint('Next episode lookup failed: $error');
    }
  }

  void _checkEndOfEpisode() {
    if (_next == null || _nextCardDismissed || _duration <= Duration.zero) {
      return;
    }
    if (_remaining <= const Duration(seconds: 45)) {
      _nextStream ??= _resolver.resolveBest(
        media: widget.media,
        quality: _settings?.preferredQuality ?? PreferredQuality.auto,
        audio: _settings?.preferredAudio ?? PreferredAudio.any,
        season: _next!.season,
        episode: _next!.episode,
      );
      if (_remaining <= const Duration(seconds: 20) &&
          _countdownTimer == null &&
          (_settings?.autoplayNext ?? true) &&
          !_sleepAtEnd) {
        _startCountdown();
      }
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    final seconds = _settings?.autoplayCountdownSeconds ?? 10;
    setState(() {
      _countdown = seconds;
      _showControls = true;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final left = (_countdown ?? 1) - 1;
      if (left <= 0) {
        timer.cancel();
        _countdownTimer = null;
        _playNext();
      } else {
        setState(() => _countdown = left);
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    setState(() {
      _countdown = null;
      _nextCardDismissed = true;
    });
  }

  void _onCompleted() {
    if (_sleepAtEnd) {
      _sleepAtEnd = false;
      return;
    }
    if (_next != null &&
        !_nextCardDismissed &&
        (_settings?.autoplayNext ?? true)) {
      if (_countdownTimer == null) {
        _nextStream ??= _resolver.resolveBest(
          media: widget.media,
          quality: _settings?.preferredQuality ?? PreferredQuality.auto,
          audio: _settings?.preferredAudio ?? PreferredAudio.any,
          season: _next!.season,
          episode: _next!.episode,
        );
        _startCountdown();
      }
    }
  }

  Future<void> _playNext() async {
    final next = _next;
    if (next == null || _startingNext) return;
    setState(() => _startingNext = true);
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _nextStream ??= _resolver.resolveBest(
      media: widget.media,
      quality: _settings?.preferredQuality ?? PreferredQuality.auto,
      audio: _settings?.preferredAudio ?? PreferredAudio.any,
      season: next.season,
      episode: next.episode,
    );
    Map<String, dynamic>? stream;
    try {
      stream = await _nextStream!.timeout(const Duration(seconds: 25));
    } catch (error) {
      debugPrint('Could not resolve next episode: $error');
    }
    if (!mounted) return;
    final url = stream?['url']?.toString();
    if (url == null || url.isEmpty) {
      setState(() {
        _startingNext = false;
        _countdown = null;
        _nextCardDismissed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Nenhuma fonte encontrada para o próximo episódio. Escolha manualmente na tela da série.')));
      return;
    }
    _saveProgress();
    Navigator.pushReplacement(
      context,
      glassRoute(VideoPlayerScreen(
        media: widget.media,
        videoUrl: url,
        season: next.season,
        episode: next.episode,
        episodeTitle: next.title,
      )),
    );
  }

  // --- Controls ------------------------------------------------------------

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying && !_sheetOpen && _countdown == null) {
        setState(() => _showControls = false);
      }
    });
  }

  void _revealControls() {
    if (!_showControls) setState(() => _showControls = true);
    _startHideTimer();
  }

  void _toggleControls() {
    if (_isInPip && defaultTargetPlatform == TargetPlatform.android) return;
    if (_locked) {
      setState(() => _showControls = !_showControls);
      if (_showControls) _startHideTimer();
      return;
    }
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  void _playPause() {
    final player = _player;
    if (player == null) return;
    if (_isPlaying) {
      _startupTimer?.cancel();
      player.pause();
    } else {
      if (kIsWeb) {
        setState(() => _waitingForBrowserPlay = false);
        _startupTimer?.cancel();
        _startupTimer = Timer(const Duration(seconds: 30), _failPlayback);
      }
      if (_completed) {
        _completed = false;
        player.seek(Duration.zero);
      }
      player.play();
    }
    _startHideTimer();
  }

  void _seekBy(int seconds) {
    final target = _position + Duration(seconds: seconds);
    _seekTo(target);
    _seekFeedbackTimer?.cancel();
    setState(() => _seekFeedbackSeconds = seconds);
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _seekFeedbackSeconds = null);
    });
  }

  void _seekTo(Duration target) {
    var clamped = target < Duration.zero ? Duration.zero : target;
    if (_duration > Duration.zero && clamped > _duration) clamped = _duration;
    _player?.seek(clamped);
    setState(() => _position = clamped);
    _startHideTimer();
  }

  Future<void> _setVolume(double value, {bool persist = true}) async {
    final clamped = value.clamp(0.0, 100.0);
    setState(() => _volume = clamped);
    await _player?.setVolume(clamped);
    if (persist) unawaited(_settings?.setVolume(clamped));
  }

  void _toggleMute() {
    if (_volume > 0) {
      _volumeBeforeMute = _volume;
      _setVolume(0);
    } else {
      _setVolume(_volumeBeforeMute > 0 ? _volumeBeforeMute : 100);
    }
  }

  void _showVolumeFeedback() {
    _volumeFeedbackTimer?.cancel();
    setState(() => _volumeFeedbackVisible = true);
    _volumeFeedbackTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _volumeFeedbackVisible = false);
    });
  }

  Future<void> _setSpeed(double value) async {
    setState(() => _speed = value);
    await _player?.setRate(value);
    unawaited(_settings?.setPlaybackSpeed(value));
  }

  void _setSleep(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepAtEnd = false;
    if (duration == null) {
      setState(() => _sleepAt = null);
      return;
    }
    setState(() => _sleepAt = DateTime.now().add(duration));
    _sleepTimer = Timer(duration, () {
      if (!mounted) return;
      _player?.pause();
      setState(() => _sleepAt = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Timer para dormir: reprodução pausada.')));
    });
  }

  Future<void> _selectSubtitle(SubtitleTrack track,
      {bool byUser = true}) async {
    try {
      final selected = track.uri
          ? SubtitleTrack.data(await const AddonService().webSubtitle(track.id),
              title: track.title, language: track.language)
          : track;
      if (!mounted) return;
      await _player?.setSubtitleTrack(selected);
      if (!mounted) return;
      setState(() {
        _selectedSubtitleTrack = track;
        if (byUser) _subtitleChosenByUser = true;
      });
    } catch (_) {
      if (!mounted || !byUser) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Não foi possível carregar esta legenda. Tente outra.')));
    }
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

  Future<void> _castToTv() async {
    final url = widget.videoUrl;
    if (url == null || url.isEmpty) return;
    final wasPlaying = _isPlaying;
    _player?.pause();
    final device = await showCastPicker(context);
    if (!mounted) return;
    if (device == null) {
      if (wasPlaying) _player?.play();
      return;
    }
    final cast = context.read<CastProvider>();
    try {
      await cast.cast(
        media: widget.media,
        url: url,
        season: widget.season,
        episode: widget.episode,
        episodeTitle: widget.episodeTitle,
        startAt: _position,
      );
      if (!mounted) return;
      _saveProgress();
      Navigator.pushReplacement(context, glassRoute(const CastRemoteScreen()));
    } on CastException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
      if (wasPlaying) _player?.play();
    }
  }

  Future<void> _openSheet(Widget Function(BuildContext) builder) async {
    _sheetOpen = true;
    setState(() => _showControls = true);
    await showPlayerSheet<void>(
        context, StatefulBuilder(builder: (context, _) => builder(context)));
    _sheetOpen = false;
    if (mounted) _startHideTimer();
  }

  void _openTracks() {
    _openSheet((context) => TracksSheet(
          audioTracks: _audioTracks,
          selectedAudio: _selectedAudioTrack,
          subtitleTracks: _subtitleTracks,
          selectedSubtitle: _selectedSubtitleTrack,
          loadingSubtitles: _loadingSubtitles,
          onAudio: (track) {
            _player?.setAudioTrack(track);
            setState(() => _selectedAudioTrack = track);
            Navigator.pop(context);
          },
          onSubtitle: (track) {
            Navigator.pop(context);
            _selectSubtitle(track);
          },
        ));
  }

  void _openSettings() {
    _openSheet((context) => PlayerSettingsSheet(
          speed: _speed,
          onSpeed: (value) {
            _setSpeed(value);
            Navigator.pop(context);
          },
          fit: _fit,
          onFit: (value) {
            setState(() => _fit = value);
            Navigator.pop(context);
          },
          subtitleScale: _settings?.subtitleScale ?? 1.0,
          onSubtitleScale: (value) {
            _settings?.setSubtitleScale(value);
            setState(() {});
          },
          sleepRemaining: _sleepAt?.difference(DateTime.now()),
          sleepAtEnd: _sleepAtEnd,
          onSleep: (duration) {
            _setSleep(duration);
            Navigator.pop(context);
          },
          onSleepAtEnd: () {
            _sleepTimer?.cancel();
            setState(() {
              _sleepAt = null;
              _sleepAtEnd = true;
            });
            Navigator.pop(context);
          },
          autoplayNext: _settings?.autoplayNext ?? true,
          onAutoplayNext: (value) {
            _settings?.setAutoplayNext(value);
            setState(() {});
          },
          showAutoplay: _isSeries,
        ));
  }

  Future<void> _loadSheetSeason(int season, void Function() refresh) async {
    _sheetSeason = season;
    _sheetLoading = true;
    refresh();
    try {
      final episodes =
          await TMDBService().fetchSeasonEpisodes(widget.media.id, season);
      if (_sheetSeason != season) return;
      _sheetEpisodes = episodes;
    } catch (_) {
      _sheetEpisodes = [];
    } finally {
      _sheetLoading = false;
      refresh();
    }
  }

  void _openEpisodes() {
    final seasons = <int>[];
    for (final entry in widget.media.seasons ?? const []) {
      if (entry is Map) {
        final number = (entry['season_number'] as num?)?.toInt();
        if (number != null && number > 0) seasons.add(number);
      }
    }
    if (seasons.isEmpty && widget.media.numberOfSeasons != null) {
      for (var s = 1; s <= widget.media.numberOfSeasons!; s++) {
        seasons.add(s);
      }
    }
    if (seasons.isEmpty) seasons.add(widget.season ?? 1);
    final initial = widget.season ?? seasons.first;
    _sheetOpen = true;
    setState(() => _showControls = true);
    showPlayerSheet<void>(
      context,
      StatefulBuilder(builder: (context, setSheetState) {
        if (_sheetSeason != initial &&
            _sheetEpisodes.isEmpty &&
            !_sheetLoading) {
          _loadSheetSeason(initial, () {
            if (context.mounted) setSheetState(() {});
          });
        } else if (_sheetSeason == null) {
          _loadSheetSeason(initial, () {
            if (context.mounted) setSheetState(() {});
          });
        }
        return EpisodesSheet(
          season: _sheetSeason ?? initial,
          seasons: seasons,
          episodes: _sheetEpisodes,
          loading: _sheetLoading,
          currentEpisode: _sheetSeason == widget.season ? widget.episode : null,
          isWatched: (episode) =>
              _watched?.isEpisodeWatched(
                  widget.media.id, _sheetSeason ?? initial, episode) ??
              false,
          onSeason: (season) => _loadSheetSeason(season, () {
            if (context.mounted) setSheetState(() {});
          }),
          onEpisode: (episode, title) async {
            Navigator.pop(context);
            await _jumpToEpisode(_sheetSeason ?? initial, episode, title);
          },
          fallbackImage: widget.media.fullBackdropPath,
        );
      }),
    ).whenComplete(() {
      _sheetOpen = false;
      if (mounted) _startHideTimer();
    });
  }

  Future<void> _jumpToEpisode(int season, int episode, String? title) async {
    _player?.pause();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Procurando fontes para T$season E$episode…'),
        duration: const Duration(seconds: 20)));
    Map<String, dynamic>? stream;
    try {
      stream = await _resolver
          .resolveBest(
            media: widget.media,
            quality: _settings?.preferredQuality ?? PreferredQuality.auto,
            audio: _settings?.preferredAudio ?? PreferredAudio.any,
            season: season,
            episode: episode,
          )
          .timeout(const Duration(seconds: 25));
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final url = stream?['url']?.toString();
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nenhuma fonte encontrada para este episódio.')));
      _player?.play();
      return;
    }
    _saveProgress();
    Navigator.pushReplacement(
      context,
      glassRoute(VideoPlayerScreen(
        media: widget.media,
        videoUrl: url,
        season: season,
        episode: episode,
        episodeTitle: title,
      )),
    );
  }

  void _failPlayback() {
    if (!mounted) return;
    _startupTimer?.cancel();
    _hideTimer?.cancel();
    _player?.pause();
    setState(() {
      _isPlaying = false;
      _isBuffering = false;
      _playbackError = kIsWeb
          ? 'O navegador não conseguiu reproduzir esta fonte. Tente outra opção: o servidor precisa permitir acesso pelo navegador e usar um formato compatível.'
          : 'Não foi possível reproduzir esta fonte.';
    });
  }

  @override
  void dispose() {
    // Save before tearing the player down; leaving the screen is the moment
    // that matters most for resuming later.
    _saveProgress();
    _progressTimer?.cancel();
    _hideTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    _volumeFeedbackTimer?.cancel();
    _sleepTimer?.cancel();
    _countdownTimer?.cancel();
    _startupTimer?.cancel();
    NativePipService.instance.onPipChanged = null;
    NativePipService.instance.exit();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player?.dispose();
    if (!kIsWeb) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([]);
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

  // --- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) => Theme(
        data: SabuflixTheme.themeData,
        child: Builder(builder: _buildPlayer),
      );

  Map<ShortcutActivator, VoidCallback> _shortcuts() {
    final step = _settings?.seekStepSeconds ?? 10;
    final bindings = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.space): _playPause,
      const SingleActivator(LogicalKeyboardKey.keyK): _playPause,
      const SingleActivator(LogicalKeyboardKey.mediaPlayPause): _playPause,
      const SingleActivator(LogicalKeyboardKey.mediaPlay): _playPause,
      const SingleActivator(LogicalKeyboardKey.mediaPause): _playPause,
      const SingleActivator(LogicalKeyboardKey.mediaRewind): () =>
          _seekBy(-step),
      const SingleActivator(LogicalKeyboardKey.mediaFastForward): () =>
          _seekBy(step),
      const SingleActivator(LogicalKeyboardKey.keyJ): () => _seekBy(-step),
      const SingleActivator(LogicalKeyboardKey.keyL): () => _seekBy(step),
      const SingleActivator(LogicalKeyboardKey.keyM): _toggleMute,
      const SingleActivator(LogicalKeyboardKey.keyC): _openTracks,
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          Navigator.maybePop(context),
      const SingleActivator(LogicalKeyboardKey.mediaStop): () =>
          Navigator.maybePop(context),
      const SingleActivator(LogicalKeyboardKey.goBack): () =>
          Navigator.maybePop(context),
      if (_next != null)
        const SingleActivator(LogicalKeyboardKey.keyN): _playNext,
      if (_next != null)
        const SingleActivator(LogicalKeyboardKey.mediaTrackNext): _playNext,
    };
    if (!_showControls) {
      // With the chrome hidden the arrows seek and adjust volume; once it is
      // visible they move focus between the buttons for remote-control users.
      bindings.addAll({
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _seekBy(-step),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _seekBy(step),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () {
          _setVolume(_volume + 5);
          _showVolumeFeedback();
        },
        const SingleActivator(LogicalKeyboardKey.arrowDown): () {
          _setVolume(_volume - 5);
          _showVolumeFeedback();
        },
        const SingleActivator(LogicalKeyboardKey.select): _revealControls,
        const SingleActivator(LogicalKeyboardKey.enter): _revealControls,
      });
    }
    return bindings;
  }

  Widget _buildPlayer(BuildContext context) {
    if (_playbackError != null) return _errorView();
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 720;
    final settings = context.watch<SettingsProvider>();
    final subtitleStyle = TextStyle(
      height: 1.4,
      fontSize: (compact ? 22.0 : 32.0) * settings.subtitleScale,
      fontFamily: 'Manrope',
      fontWeight: FontWeight.w600,
      color: Colors.white,
      backgroundColor: const Color(0xAA000000),
    );

    return CallbackShortcuts(
      bindings: _shortcuts(),
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: MouseRegion(
            onHover: (_) {
              if (!_showControls && !_locked) _revealControls();
            },
            child: GestureDetector(
              onTap: _toggleControls,
              onDoubleTapDown: _locked
                  ? null
                  : (details) {
                      final step = settings.seekStepSeconds;
                      final third = size.width / 3;
                      if (details.localPosition.dx < third) {
                        _seekBy(-step);
                      } else if (details.localPosition.dx > third * 2) {
                        _seekBy(step);
                      } else {
                        _playPause();
                      }
                    },
              onDoubleTap: () {},
              onVerticalDragStart: _locked || compact == false
                  ? null
                  : (details) {
                      if (details.localPosition.dx < size.width / 2) return;
                      _volumeDragStart = _volume;
                    },
              onVerticalDragUpdate: _locked || compact == false
                  ? null
                  : (details) {
                      if (_volumeDragStart == null) return;
                      final delta = -details.primaryDelta! / size.height * 160;
                      _setVolume(_volume + delta, persist: false);
                      _showVolumeFeedback();
                    },
              onVerticalDragEnd: _locked || compact == false
                  ? null
                  : (_) {
                      if (_volumeDragStart != null) {
                        _settings?.setVolume(_volume);
                      }
                      _volumeDragStart = null;
                    },
              behavior: HitTestBehavior.opaque,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_hasVideo)
                    Video(
                      controller: _videoController!,
                      controls: NoVideoControls,
                      fit: _fit,
                      fill: Colors.black,
                      subtitleViewConfiguration: SubtitleViewConfiguration(
                        style: subtitleStyle,
                        padding: EdgeInsets.fromLTRB(
                            16, 0, 16, _showControls && !_locked ? 110 : 28),
                      ),
                    )
                  else
                    CachedNetworkImage(
                      imageUrl: widget.media.fullBackdropPath,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      placeholder: (context, url) =>
                          const ColoredBox(color: SabuflixTheme.background),
                      errorWidget: (context, url, err) =>
                          const ColoredBox(color: SabuflixTheme.background),
                    ),

                  if (_isBuffering &&
                      _hasVideo &&
                      !_waitingForBrowserPlay &&
                      !_showControls)
                    const Center(
                        child: CircularProgressIndicator(
                            color: SabuflixTheme.accent)),

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
                            fillOpacity: 0.5,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            child: Text(
                              'Retomando de ${formatPlayerTime(widget.startAt)}',
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

                  // Gesture feedback.
                  if (_seekFeedbackSeconds != null)
                    Align(
                      alignment: _seekFeedbackSeconds! < 0
                          ? const Alignment(-0.6, 0)
                          : const Alignment(0.6, 0),
                      child: SeekFeedback(
                          seconds: _seekFeedbackSeconds!, visible: true),
                    ),
                  Align(
                    alignment: const Alignment(0, -0.55),
                    child: VolumeFeedback(
                        volume: _volume, visible: _volumeFeedbackVisible),
                  ),

                  // Dim behind the chrome.
                  IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity:
                          (_showControls && !_locked) || !_isPlaying ? 1 : 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0, .25, .6, 1],
                            colors: [
                              Colors.black.withValues(alpha: .7),
                              Colors.black.withValues(alpha: .15),
                              Colors.black.withValues(alpha: .25),
                              Colors.black.withValues(alpha: .85),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (_locked)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _showControls ? 1 : 0,
                        child: IgnorePointer(
                          ignoring: !_showControls,
                          child: GlassContainer(
                            borderRadius: SabuflixTheme.radiusPill,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PlayerIconButton(
                                  icon: Icons.lock_open_rounded,
                                  tooltip: 'Desbloquear controles',
                                  onPressed: () => setState(() {
                                    _locked = false;
                                    _showControls = true;
                                  }),
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(right: 10),
                                  child: Text('Controles bloqueados',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _showControls ? 1 : 0,
                      child: IgnorePointer(
                        ignoring: !_showControls,
                        child: _chrome(context, compact, settings),
                      ),
                    ),

                  if (_next != null &&
                      (_countdown != null || _completed) &&
                      !_nextCardDismissed)
                    Positioned(
                      right: 20,
                      bottom: compact ? 92 : 112,
                      child: NextEpisodeCard(
                        title: _next!.title ?? 'Episódio ${_next!.episode}',
                        subtitle:
                            '${widget.media.title} · ${formatEpisodeTag(_next!.season, _next!.episode)}',
                        imageUrl: widget.media.fullBackdropPath,
                        secondsLeft: _countdown,
                        resolving: _startingNext,
                        onPlay: _playNext,
                        onCancel: _cancelCountdown,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chrome(
      BuildContext context, bool compact, SettingsProvider settings) {
    final step = settings.seekStepSeconds;
    final position = _scrubbing ?? _position;
    final cast = context.watch<CastProvider>();
    final hasSubtitleOptions = _subtitleTracks.isNotEmpty || _loadingSubtitles;
    final hasTrackOptions = hasSubtitleOptions || _audioTracks.length > 1;

    return SafeArea(
      child: Column(
        children: [
          // Top bar.
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Row(
              children: [
                PlayerIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Voltar',
                  size: 26,
                  onPressed: () => Navigator.maybePop(context),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.media.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SabuflixTheme.title(
                              fontSize: compact ? 15 : 18,
                              color: Colors.white)),
                      Text(_headerSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SabuflixTheme.body(
                              color: Colors.white70,
                              fontSize: compact ? 11 : 12)),
                    ],
                  ),
                ),
                if (_sleepAt != null || _sleepAtEnd)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.bedtime_rounded,
                        size: 18, color: Colors.white.withValues(alpha: .8)),
                  ),
                if (cast.isSupported)
                  PlayerIconButton(
                    icon: cast.isConnected
                        ? Icons.cast_connected_rounded
                        : Icons.cast_rounded,
                    tooltip: 'Transmitir para a TV',
                    active: cast.isConnected,
                    onPressed: _castToTv,
                  ),
                if (_pipSupported)
                  PlayerIconButton(
                    icon: _isInPip
                        ? Icons.picture_in_picture_alt_rounded
                        : Icons.picture_in_picture_rounded,
                    tooltip: _isInPip
                        ? 'Sair do Picture-in-Picture'
                        : 'Picture-in-Picture',
                    onPressed: _togglePip,
                  ),
                PlayerIconButton(
                  icon: Icons.lock_outline_rounded,
                  tooltip: 'Bloquear controles',
                  onPressed: () => setState(() {
                    _locked = true;
                    _showControls = false;
                  }),
                ),
              ],
            ),
          ),

          // Centre transport.
          Expanded(
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PlayerIconButton(
                    icon: step == 5
                        ? Icons.replay_5_rounded
                        : step == 30
                            ? Icons.replay_30_rounded
                            : Icons.replay_10_rounded,
                    tooltip: 'Voltar $step segundos',
                    size: compact ? 36 : 42,
                    onPressed: _hasVideo ? () => _seekBy(-step) : null,
                  ),
                  SizedBox(width: compact ? 22 : 36),
                  PlayerPrimaryButton(
                    playing: _isPlaying,
                    buffering: _isBuffering && !_waitingForBrowserPlay,
                    diameter: compact ? 64 : 76,
                    onPressed: _playPause,
                  ),
                  SizedBox(width: compact ? 22 : 36),
                  PlayerIconButton(
                    icon: step == 5
                        ? Icons.forward_5_rounded
                        : step == 30
                            ? Icons.forward_30_rounded
                            : Icons.forward_10_rounded,
                    tooltip: 'Avançar $step segundos',
                    size: compact ? 36 : 42,
                    onPressed: _hasVideo ? () => _seekBy(step) : null,
                  ),
                ],
              ),
            ),
          ),

          // Bottom bar.
          Padding(
            padding: EdgeInsets.fromLTRB(
                compact ? 8 : 20, 0, compact ? 8 : 20, compact ? 4 : 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PlayerSeekBar(
                  position: position,
                  duration: _duration,
                  buffered: _buffered,
                  onChangeStart: _hasVideo
                      ? (value) {
                          _hideTimer?.cancel();
                          setState(() => _scrubbing = value);
                        }
                      : null,
                  onChanged: _hasVideo
                      ? (value) => setState(() => _scrubbing = value)
                      : null,
                  onChangeEnd: _hasVideo
                      ? (value) {
                          setState(() => _scrubbing = null);
                          _seekTo(value);
                        }
                      : null,
                ),
                Row(
                  children: [
                    const SizedBox(width: 12),
                    Text(formatPlayerTime(position),
                        style: SabuflixTheme.body(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Text('/ ${formatPlayerTime(_duration)}',
                        style: SabuflixTheme.body(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    if (_speed != 1.0) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .14),
                          borderRadius: SabuflixTheme.radiusSm,
                        ),
                        child: Text('${_speed}x',
                            style: SabuflixTheme.caption(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ],
                    const Spacer(),
                    if (!compact) ...[
                      PlayerIconButton(
                        icon: _volume <= 0
                            ? Icons.volume_off_rounded
                            : _volume < 50
                                ? Icons.volume_down_rounded
                                : Icons.volume_up_rounded,
                        tooltip: _volume <= 0 ? 'Ativar som' : 'Silenciar',
                        onPressed: _toggleMute,
                      ),
                      SizedBox(
                        width: 110,
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 5),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12),
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: _volume.clamp(0, 100),
                            max: 100,
                            onChanged: (value) =>
                                _setVolume(value, persist: false),
                            onChangeEnd: (value) => _settings?.setVolume(value),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (_next != null)
                      PlayerIconButton(
                        icon: Icons.skip_next_rounded,
                        tooltip:
                            'Próximo episódio · ${formatEpisodeTag(_next!.season, _next!.episode)}',
                        size: 26,
                        onPressed: _startingNext ? null : _playNext,
                      ),
                    if (_isSeries)
                      PlayerIconButton(
                        icon: Icons.video_library_outlined,
                        tooltip: 'Episódios',
                        onPressed: _openEpisodes,
                      ),
                    PlayerIconButton(
                      icon: Icons.subtitles_outlined,
                      tooltip: 'Áudio e legendas',
                      active: _selectedSubtitleTrack != null &&
                          _selectedSubtitleTrack!.id != 'no' &&
                          _selectedSubtitleTrack!.id != 'auto',
                      onPressed:
                          hasTrackOptions || _hasVideo ? _openTracks : null,
                    ),
                    PlayerIconButton(
                      icon: Icons.tune_rounded,
                      tooltip: 'Velocidade, tela e timer',
                      active: _speed != 1.0 ||
                          _fit != BoxFit.contain ||
                          _sleepAt != null,
                      onPressed: _openSettings,
                    ),
                    if (!compact)
                      PlayerIconButton(
                        icon: _fit == BoxFit.contain
                            ? Icons.fullscreen_rounded
                            : Icons.fullscreen_exit_rounded,
                        tooltip: _fit == BoxFit.contain
                            ? 'Preencher tela'
                            : 'Tamanho original',
                        onPressed: () => setState(() => _fit =
                            _fit == BoxFit.contain
                                ? BoxFit.cover
                                : BoxFit.contain),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView() => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: Text(widget.media.title)),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_disabled_rounded, size: 48),
                const SizedBox(height: 20),
                Text(
                  _playbackError!,
                  textAlign: TextAlign.center,
                  style: SabuflixTheme.title(fontSize: 22),
                ),
                const SizedBox(height: 12),
                Text(
                  'Verifique sua conexão ou escolha outra fonte nos detalhes do título.',
                  textAlign: TextAlign.center,
                  style: SabuflixTheme.body(),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    if (widget.videoUrl?.isNotEmpty ?? false)
                      ElevatedButton(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => VideoPlayerScreen(
                              media: widget.media,
                              videoUrl: widget.videoUrl,
                              season: widget.season,
                              episode: widget.episode,
                              episodeTitle: widget.episodeTitle,
                              startAt: _position > Duration.zero
                                  ? _position
                                  : widget.startAt,
                            ),
                          ),
                        ),
                        child: const Text('Tentar novamente'),
                      ),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Voltar aos detalhes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
