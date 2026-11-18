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
import '../services/addon_service.dart';
import '../services/stream_scanner.dart';
import '../services/tmdb_service.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/formatters.dart';
import '../utils/browser_playback.dart';
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

  /// Finds and switches sources by itself: scans every add-on when there is
  /// no [videoUrl], and fails over to the next working link whenever the
  /// current one (including a saved [videoUrl]) stops playing.
  final bool autoSource;

  /// Injectable for tests.
  final StreamScanner? scanner;

  const VideoPlayerScreen({
    super.key,
    required this.media,
    this.videoUrl,
    this.season,
    this.episode,
    this.episodeTitle,
    this.startAt = Duration.zero,
    this.autoSource = false,
    this.scanner,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _showControls = true;
  Timer? _hideTimer;

  String? _playbackError;
  StreamSubscription<String>? _errorSubscription;
  Timer? _startupTimer;
  Player? _player;
  VideoController? _videoController;

  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _waitingForBrowserPlay = kIsWeb;
  double _currentPosition = 0;
  double _totalDuration = 0;

  bool _showAudioMenu = false;
  bool _showSubtitleMenu = false;
  bool _showSourceMenu = false;

  // Source selection. [_currentUrl] is what the player has open; [_current]
  // is its scan entry when it came from the scanner.
  late final StreamScanner _scanner = widget.scanner ?? StreamScanner();
  StreamSubscription<List<StreamCandidate>>? _scanSubscription;
  List<StreamCandidate> _sources = [];
  StreamCandidate? _current;
  String? _currentUrl;
  final _failedUrls = <String>{};
  bool _scanning = false;
  bool _scannedOnce = false;
  bool _awaitingSource = false;
  bool _startedCurrent = false;
  bool _userPaused = false;
  DateTime _openedAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastProgressAt = DateTime.now();
  Timer? _stallWatchdog;
  late Duration _resumeFrom = widget.startAt;
  Future<String?>? _imdbId;

  /// Browsers only start media from a user gesture; after the first Play,
  /// later source switches may start on their own.
  bool _userActivated = !kIsWeb;
  String? _notice;
  Timer? _noticeTimer;

  List<AudioTrack> _audioTracks = [];
  AudioTrack? _selectedAudioTrack;

  List<SubtitleTrack> _subtitleTracks = [];
  List<SubtitleTrack> _externalSubtitles = [];
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
    _continueWatching = Provider.of<ContinueWatchingProvider>(
      context,
      listen: false,
    );
    _watched = Provider.of<WatchedProvider>(context, listen: false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initPlayer();
    _initPip();
    _startHideTimer();
    _progressTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _saveProgress(),
    );
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
      sourceUrl: _currentUrl,
    );
    final progress = _currentPosition / _totalDuration;
    if (!_markedCompleted &&
        widget.media.mediaType == 'movie' &&
        progress >= 0.95) {
      _markedCompleted = true;
      _watched?.markWatched(widget.media);
    }
  }

  /// The resume point travels inside [Media.start]; this only confirms it
  /// once the container is parsed, and restarts titles saved at the very end.
  void _confirmResumeOnce() {
    if (_seekedToStart || _totalDuration <= 0) return;
    _seekedToStart = true;
    final start = widget.startAt.inSeconds;
    if (start < 10) return;
    if (start >= _totalDuration - 10) {
      _player?.seek(Duration.zero);
      return;
    }
    setState(() => _resumeBannerVisible = true);
    Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _resumeBannerVisible = false);
    });
  }

  Future<void> _initPlayer() async {
    final url = widget.videoUrl;
    if ((url == null || url.isEmpty) && !widget.autoSource) {
      _playbackError = 'Nenhuma fonte de vídeo disponível.';
      return;
    }
    try {
      _player = Player();
      _errorSubscription = _player!.stream.error.listen((message) {
        if (kIsWeb && isRecoverableBrowserPlayError(message)) {
          _startupTimer?.cancel();
          if (!mounted) return;
          setState(() {
            _waitingForBrowserPlay = true;
            _isPlaying = false;
            _showControls = true;
            _isBuffering = false;
          });
        } else if (kIsWeb || _isFatalError(message)) {
          // Stale errors from the media being replaced arrive right after
          // `open`; the startup timer still covers the new link.
          if (DateTime.now().difference(_openedAt) >
              const Duration(milliseconds: 400)) {
            _onSourceFailed(_currentUrl);
          }
        }
        // Anything else is mpv logging a recoverable hiccup (a corrupt
        // frame, a TCP reconnect): the startup timer and the stall watchdog
        // decide whether the link is really gone.
      });
      _videoController = VideoController(_player!);

      _player!.stream.position.listen((Duration position) {
        if (!mounted) return;
        if (position > Duration.zero && _currentUrl != null) {
          _startupTimer?.cancel();
          _startedCurrent = true;
          if (position != _resumeFrom) _lastProgressAt = DateTime.now();
          _resumeFrom = position;
        }
        setState(() => _currentPosition = position.inSeconds.toDouble());
      });

      _player!.stream.duration.listen((Duration duration) {
        if (!mounted) return;
        setState(() => _totalDuration = duration.inSeconds.toDouble());
        if (_totalDuration > 0) _confirmResumeOnce();
      });

      _player!.stream.playing.listen((bool playing) {
        if (!mounted) return;
        if (playing && kIsWeb) _startupTimer?.cancel();
        setState(() {
          _isPlaying = playing;
          if (playing) _waitingForBrowserPlay = false;
        });
      });

      _player!.stream.buffering.listen((bool buffering) {
        if (!mounted) return;
        setState(() => _isBuffering = buffering);
      });

      _player!.stream.tracks.listen((tracks) {
        if (!mounted) return;
        setState(() {
          _audioTracks = tracks.audio;
          _subtitleTracks = [...tracks.subtitle, ..._externalSubtitles];
        });
      });

      _player!.stream.track.listen((track) {
        if (!mounted) return;
        setState(() {
          _selectedAudioTrack = track.audio;
          if (_selectedSubtitleTrack == null || !_selectedSubtitleTrack!.uri) {
            _selectedSubtitleTrack = track.subtitle;
          }
        });
      });
    } catch (_) {
      _failPlayback();
      return;
    }

    if (url != null && url.isNotEmpty) {
      await _open(url, const {});
    } else {
      unawaited(_startScan());
    }
    unawaited(_loadExternalSubtitles());
  }

  /// Opens [url] at the current resume point.
  Future<void> _open(String url, Map<String, String> headers) async {
    _startupTimer?.cancel();
    _currentUrl = url;
    _startedCurrent = false;
    _openedAt = DateTime.now();
    _lastProgressAt = _openedAt;
    _stallWatchdog ??= Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkStall(),
    );
    if (mounted) setState(() => _isBuffering = true);
    // Opening a route/awaiting a manifest can consume browser user activation.
    // Until the first Play, load paused and start from the button's gesture.
    if (_userActivated) _armStartupTimer();
    try {
      await _player!.open(
        Media(
          url,
          httpHeaders: headers.isEmpty ? null : headers,
          start: _resumeFrom > Duration.zero ? _resumeFrom : null,
        ),
        play: _userActivated,
      );
    } catch (_) {
      _onSourceFailed(url);
    }
  }

  /// mpv reports these when the link itself is unusable.
  static bool _isFatalError(String message) {
    final text = message.toLowerCase();
    return text.contains('failed to open') ||
        text.contains('failed to recognize file format') ||
        text.contains('http error') ||
        text.contains('server returned') ||
        text.contains('connection refused') ||
        text.contains('no such file');
  }

  /// A link that played and then froze (expired token, dropped CDN node)
  /// is swapped for the next one at the same position.
  void _checkStall() {
    if (!mounted || _currentUrl == null || !_startedCurrent) return;
    // Paused by any means (the user, PiP controls, a browser policy).
    if (_userPaused ||
        _waitingForBrowserPlay ||
        (!_isPlaying && !_isBuffering)) {
      _lastProgressAt = DateTime.now();
      return;
    }
    if (DateTime.now().difference(_lastProgressAt) >
        const Duration(seconds: 20)) {
      _onSourceFailed(_currentUrl);
    }
  }

  /// A link that hasn't produced a frame by now is treated as dead; with
  /// alternatives at hand there is no reason to wait as long.
  void _armStartupTimer() {
    _startupTimer?.cancel();
    final patience = widget.autoSource || _sources.length > 1
        ? const Duration(seconds: 15)
        : const Duration(seconds: 30);
    final url = _currentUrl;
    _startupTimer = Timer(patience, () => _onSourceFailed(url));
  }

  /// Marks the open link as failed and moves to the next one, keeping the
  /// position; only when nothing is left does the error screen appear.
  void _onSourceFailed([String? failedUrl]) {
    if (!mounted || _player == null || _playbackError != null) return;
    final url = failedUrl ?? _currentUrl;
    // Late reports about a link that was already replaced, or repeated
    // reports while the next one is being found.
    if (url != _currentUrl) return;
    if (url != null && _failedUrls.contains(url) && _awaitingSource) return;
    _startupTimer?.cancel();
    if (url != null) {
      _failedUrls.add(url);
      for (final candidate in _sources) {
        if (candidate.url == url) candidate.health = StreamHealth.dead;
      }
    }
    final next = _nextCandidate();
    if (next != null) {
      _switchTo(next,
          notice: 'Fonte indisponível · trocando para ${next.label}');
    } else if (widget.autoSource && !_scannedOnce) {
      _awaitingSource = true;
      _showNotice('Fonte indisponível · procurando outra');
      unawaited(_startScan());
    } else if (_scanning) {
      setState(() {
        _awaitingSource = true;
        _isBuffering = true;
      });
      _showNotice('Procurando outra fonte');
    } else {
      _failPlayback();
    }
  }

  StreamCandidate? _nextCandidate() {
    for (final candidate in StreamScanner.rank(_sources)) {
      if (_failedUrls.contains(candidate.url)) continue;
      if (candidate.health == StreamHealth.dead) continue;
      return candidate;
    }
    return null;
  }

  bool get _needsSource =>
      _awaitingSource ||
      _currentUrl == null ||
      _failedUrls.contains(_currentUrl);

  Future<void> _switchTo(StreamCandidate candidate, {String? notice}) async {
    if (!mounted) return;
    setState(() {
      _current = candidate;
      _awaitingSource = false;
      _showSourceMenu = false;
    });
    if (notice != null) _showNotice(notice);
    await _open(candidate.url, candidate.headers);
  }

  void _pickSource(StreamCandidate candidate) {
    _failedUrls.remove(candidate.url);
    if (candidate.url == _currentUrl) {
      setState(() => _showSourceMenu = false);
      return;
    }
    _switchTo(candidate, notice: 'Trocando para ${candidate.label}');
  }

  Future<String?> _resolveImdbId() => _imdbId ??= () async {
        final known = widget.media.imdbId;
        if (known != null && known.isNotEmpty) return known;
        if (widget.media.id <= 0) return null;
        try {
          final details = await TMDBService().fetchMediaDetails(
            widget.media.id,
            widget.media.mediaType,
          );
          return details?.imdbId;
        } catch (_) {
          return null;
        }
      }();

  /// Scans the add-ons and starts the first link confirmed to answer,
  /// without waiting for the slower ones.
  Future<void> _startScan({bool fresh = false}) async {
    _scannedOnce = true;
    await _scanSubscription?.cancel();
    if (mounted) setState(() => _scanning = true);
    final imdbId = await _resolveImdbId();
    if (!mounted) return;
    if (imdbId == null || imdbId.isEmpty) {
      setState(() => _scanning = false);
      if (_needsSource) {
        _failPlayback(message: 'Este título ainda não tem fontes disponíveis.');
      }
      return;
    }
    _scanSubscription = _scanner.scan(
      (
        imdbId: imdbId,
        type: widget.media.mediaType == 'tv' ? 'series' : 'movie',
        season: widget.season,
        episode: widget.episode,
      ),
      fresh: fresh,
    ).listen(
      (list) {
        if (!mounted) return;
        setState(() => _sources = list);
        if (!_needsSource) return;
        final best = _nextCandidate();
        if (best != null && best.health == StreamHealth.ok) {
          _switchTo(best,
              notice:
                  _currentUrl == null ? null : 'Trocando para ${best.label}');
        }
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _scanning = false);
        if (!_needsSource) return;
        final best = _nextCandidate();
        if (best != null) {
          _switchTo(best);
        } else {
          _failPlayback();
        }
      },
    );
  }

  void _showNotice(String text) {
    _noticeTimer?.cancel();
    setState(() => _notice = text);
    _noticeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  Future<void> _retry() async {
    setState(() {
      _playbackError = null;
      _failedUrls.clear();
      _awaitingSource = false;
      _current = null;
    });
    if (widget.autoSource) {
      _currentUrl = null;
      _sources = [];
      await _startScan(fresh: true);
    } else if (widget.videoUrl?.isNotEmpty ?? false) {
      await _open(widget.videoUrl!, const {});
    }
  }

  Future<void> _loadExternalSubtitles() async {
    final imdbId = await _resolveImdbId();
    if (imdbId == null || imdbId.isEmpty) return;

    final items = await const AddonService().subtitles(
      imdbId: imdbId,
      type: widget.media.mediaType,
      season: widget.season,
      episode: widget.episode,
    );
    if (!mounted || _player == null) return;
    setState(() {
      _externalSubtitles = items.asMap().entries.map((entry) {
        final item = entry.value;
        final lang = item['lang']?.toString().toLowerCase().trim() ?? 'und';
        final label = ['por', 'pob', 'pt', 'pt-br', 'pb', 'bra'].contains(lang)
            ? 'Português'
            : lang.toUpperCase();
        return SubtitleTrack.uri(
          item['url'].toString(),
          title: '$label · OpenSubtitles ${entry.key + 1}',
          language: lang,
        );
      }).toList();
      _subtitleTracks = [
        ..._player!.state.tracks.subtitle,
        ..._externalSubtitles,
      ];
    });
  }

  Future<void> _selectSubtitle(SubtitleTrack track) async {
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
        _showSubtitleMenu = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Não foi possível carregar esta legenda. Tente outra.')));
    }
  }

  void _failPlayback({String? message}) {
    if (!mounted) return;
    _startupTimer?.cancel();
    _hideTimer?.cancel();
    _player?.pause();
    // Links the probe already found down count as tested too.
    final tried = {
      ..._failedUrls,
      for (final c in _sources)
        if (c.health == StreamHealth.dead) c.url,
    }.length;
    setState(() {
      _isPlaying = false;
      _isBuffering = false;
      _scanning = false;
      _playbackError = message ??
          (widget.autoSource
              ? switch (tried) {
                  0 => 'Nenhuma fonte encontrada para este título.',
                  1 => 'A única fonte encontrada não funcionou.',
                  _ => 'Nenhuma das $tried fontes funcionou agora.',
                }
              : kIsWeb
                  ? 'O navegador não conseguiu reproduzir esta fonte.'
                  : 'Não foi possível reproduzir esta fonte.');
    });
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
                  widget.autoSource
                      ? 'As fontes mudam com frequência. Tente de novo em instantes.'
                      : kIsWeb
                          ? 'O servidor precisa permitir acesso pelo navegador e usar um formato compatível.'
                          : 'Verifique sua conexão ou tente novamente.',
                  textAlign: TextAlign.center,
                  style: SabuflixTheme.body(),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    if (_player != null &&
                        (widget.autoSource ||
                            (widget.videoUrl?.isNotEmpty ?? false)))
                      ElevatedButton(
                        onPressed: _retry,
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

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) {
        setState(() {
          _showControls = false;
          _showAudioMenu = false;
          _showSubtitleMenu = false;
          _showSourceMenu = false;
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
      if (_isPlaying) {
        _startupTimer?.cancel();
        _userPaused = true;
        _player!.pause();
      } else {
        _userPaused = false;
        if (kIsWeb) {
          setState(() => _waitingForBrowserPlay = false);
          if (!_startedCurrent && _currentUrl != null) _armStartupTimer();
          _userActivated = true;
        }
        _player!.play();
      }
    }
    _startHideTimer();
  }

  void _seek(double seconds) {
    if (_player != null) {
      final newPos = (_currentPosition + seconds).clamp(0.0, _totalDuration);
      _player!.seek(Duration(seconds: newPos.toInt()));
    } else {
      setState(() {
        _currentPosition = (_currentPosition + seconds).clamp(
          0.0,
          _totalDuration,
        );
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
        'https://www.youtube.com/watch?v=${widget.media.trailerKey}',
      );
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
    _errorSubscription?.cancel();
    _scanSubscription?.cancel();
    _noticeTimer?.cancel();
    _stallWatchdog?.cancel();
    _startupTimer?.cancel();
    _player?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([]);
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
  Widget build(BuildContext context) => Theme(
        data: SabuflixTheme.themeData,
        child: Builder(builder: _buildPlayer),
      );

  Widget _buildPlayer(BuildContext context) {
    if (_playbackError != null) return _errorView();
    final hasVideo = _videoController != null && _currentUrl != null;
    final searching = _currentUrl == null;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _playPause,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _seek(-10),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _seek(10),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.maybePop(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
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

                if (_isBuffering && hasVideo && !_waitingForBrowserPlay)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),

                if (searching) _SearchingSources(found: _sources.length),

                // Brief confirmation that playback jumped to where it stopped.
                Positioned(
                  top: 24,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: SabuflixTheme.durationMed,
                      opacity:
                          _resumeBannerVisible || _notice != null ? 1.0 : 0.0,
                      child: Center(
                        child: GlassContainer(
                          borderRadius: SabuflixTheme.radiusPill,
                          blur: 30,
                          fillOpacity: 0.5,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          child: Text(
                            _notice ??
                                'Retomando de ${_formatDuration(widget.startAt.inSeconds.toDouble())}',
                            style: SabuflixTheme.caption(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                if (_showControls || !_isPlaying)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    color: Colors.black.withValues(
                      alpha: _isPlaying ? 0.35 : 0.65,
                    ),
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
                                    icon: const Icon(
                                      Icons.arrow_back_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                    onPressed: () => Navigator.pop(context),
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
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          _headerSubtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: SabuflixTheme.body(
                                            color: SabuflixTheme.textSecondary,
                                            fontSize: 12,
                                          ),
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
                                  if (widget.autoSource || _sources.isNotEmpty)
                                    _SourceButton(
                                      label: _current?.label ??
                                          (searching
                                              ? 'Fontes'
                                              : 'Fonte atual'),
                                      scanning: _scanning,
                                      onPressed: () {
                                        if (!_scannedOnce &&
                                            widget.autoSource) {
                                          unawaited(_startScan());
                                        }
                                        setState(() {
                                          _showSourceMenu = !_showSourceMenu;
                                          _showAudioMenu = false;
                                          _showSubtitleMenu = false;
                                        });
                                        _startHideTimer();
                                      },
                                    ),
                                  const SizedBox(width: 4),
                                  if (_pipSupported)
                                    IconButton(
                                      tooltip: _isInPip
                                          ? 'Sair do Picture-in-Picture'
                                          : 'Picture-in-Picture',
                                      icon: Icon(
                                        _isInPip
                                            ? Icons
                                                .picture_in_picture_alt_rounded
                                            : Icons.picture_in_picture_rounded,
                                        color: Colors.white,
                                      ),
                                      onPressed: _togglePip,
                                    ),
                                  TextButton.icon(
                                    onPressed: _openOfficialTrailer,
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: SabuflixTheme.radiusSm,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.smart_display_outlined,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      'Trailer',
                                      style: SabuflixTheme.body(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  if (_subtitleTracks.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.subtitles_outlined,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _showSubtitleMenu =
                                              !_showSubtitleMenu;
                                          _showAudioMenu = false;
                                          _showSourceMenu = false;
                                        });
                                      },
                                    ),
                                  if (_audioTracks.length > 1)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.audiotrack_rounded,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _showAudioMenu = !_showAudioMenu;
                                          _showSubtitleMenu = false;
                                          _showSourceMenu = false;
                                        });
                                      },
                                    ),
                                ],
                              ),
                            ),
                            if (!searching)
                              Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      iconSize: 40,
                                      icon: const Icon(
                                        Icons.replay_10_rounded,
                                        color: Colors.white,
                                      ),
                                      onPressed: () => _seek(-10),
                                    ),
                                    const SizedBox(width: 28),
                                    Container(
                                      width: 70,
                                      height: 70,
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        tooltip: _isPlaying
                                            ? 'Pausar'
                                            : 'Reproduzir',
                                        iconSize: 38,
                                        icon: Icon(
                                          _isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          color: Colors.black,
                                        ),
                                        onPressed: _playPause,
                                      ),
                                    ),
                                    const SizedBox(width: 28),
                                    IconButton(
                                      iconSize: 40,
                                      icon: const Icon(
                                        Icons.forward_10_rounded,
                                        color: Colors.white,
                                      ),
                                      onPressed: () => _seek(10),
                                    ),
                                  ],
                                ),
                              ),
                            if (_showSourceMenu)
                              Positioned(
                                right: 12,
                                top: 64,
                                child: _SourceMenu(
                                  sources: _sources,
                                  current: _currentUrl,
                                  failed: _failedUrls,
                                  scanning: _scanning,
                                  onSelect: _pickSource,
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
                                      t.title ??
                                      t.language ??
                                      'Legenda ${t.id}',
                                  onSelect: _selectSubtitle,
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
                                        enabledThumbRadius: 7,
                                      ),
                                      activeTrackColor: Colors.white,
                                      inactiveTrackColor:
                                          Colors.white.withValues(alpha: 0.25),
                                      thumbColor: Colors.white,
                                      overlayColor:
                                          Colors.white.withValues(alpha: 0.2),
                                    ),
                                    child: Slider(
                                      value: _currentPosition.clamp(
                                        0.0,
                                        _totalDuration > 0
                                            ? _totalDuration
                                            : 1.0,
                                      ),
                                      min: 0,
                                      max: _totalDuration > 0
                                          ? _totalDuration
                                          : 1.0,
                                      onChanged: (val) {
                                        _seekTo(val);
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatDuration(_currentPosition),
                                          style: SabuflixTheme.body(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          _formatDuration(_totalDuration),
                                          style: SabuflixTheme.body(
                                            color: Colors.white70,
                                            fontSize: 12,
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
              shape: RoundedRectangleBorder(
                borderRadius: SabuflixTheme.radiusSm,
              ),
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
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 18,
                    )
                  : null,
              onTap: () => onSelect(track),
            );
          },
        ),
      ),
    );
  }
}

/// Shown over the backdrop while the first link is being found.
class _SearchingSources extends StatelessWidget {
  final int found;
  const _SearchingSources({required this.found});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2.5),
          ),
          const SizedBox(height: 18),
          Text('Procurando a melhor fonte',
              style: SabuflixTheme.title(fontSize: 16, color: Colors.white)),
          const SizedBox(height: 6),
          Text(
            found == 0
                ? 'Consultando os servidores'
                : found == 1
                    ? '1 fonte encontrada · testando'
                    : '$found fontes encontradas · testando',
            style: SabuflixTheme.caption(
                fontSize: 13, color: SabuflixTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Compact pill naming the source in use; opens [_SourceMenu].
class _SourceButton extends StatelessWidget {
  final String label;
  final bool scanning;
  final VoidCallback onPressed;

  const _SourceButton({
    required this.label,
    required this.scanning,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Trocar fonte',
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.white.withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (scanning)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 1.6),
              )
            else
              const Icon(Icons.layers_outlined, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SabuflixTheme.body(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ranked list of links with a one-word health note each.
class _SourceMenu extends StatelessWidget {
  final List<StreamCandidate> sources;
  final String? current;
  final Set<String> failed;
  final bool scanning;
  final ValueChanged<StreamCandidate> onSelect;

  const _SourceMenu({
    required this.sources,
    required this.current,
    required this.failed,
    required this.scanning,
    required this.onSelect,
  });

  String _status(StreamCandidate source) {
    if (failed.contains(source.url)) return 'falhou';
    return switch (source.health) {
      StreamHealth.ok =>
        source.latency == null ? 'ok' : '${source.latency!.inMilliseconds} ms',
      StreamHealth.pending => 'testando',
      StreamHealth.unknown => 'não testada',
      StreamHealth.dead => 'fora do ar',
    };
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: SabuflixTheme.radiusMd,
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        width: 280,
        height: sources.length > 5 ? 280 : null,
        child: sources.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  scanning
                      ? 'Procurando fontes…'
                      : 'Nenhuma outra fonte encontrada.',
                  style: SabuflixTheme.body(
                      fontSize: 13, color: SabuflixTheme.textSecondary),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: sources.length,
                itemBuilder: (context, index) {
                  final source = sources[index];
                  final selected = source.url == current;
                  final usable = !failed.contains(source.url) &&
                      source.health != StreamHealth.dead;
                  return ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                        borderRadius: SabuflixTheme.radiusSm),
                    title: Text(
                      source.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SabuflixTheme.body(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected || usable
                            ? Colors.white
                            : SabuflixTheme.textMuted,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 18)
                        : Text(
                            _status(source),
                            style: SabuflixTheme.caption(
                                fontSize: 11, color: SabuflixTheme.textMuted),
                          ),
                    onTap: () => onSelect(source),
                  );
                },
              ),
      ),
    );
  }
}
