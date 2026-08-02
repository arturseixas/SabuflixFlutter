import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/media_item.dart';
import '../services/cast_service.dart';
import '../services/playback_service.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/haptics.dart';
import '../widgets/cast_picker.dart';
import '../widgets/glass_container.dart';

class VideoPlayerScreen extends StatefulWidget {
  final MediaItem media;
  final String? videoUrl;
  final int? season;
  final int? episode;
  final String? sourceLabel;

  /// Set when re-opening the page for something already playing (coming back
  /// from the mini player), so playback is not restarted from zero.
  final bool resumeExisting;

  const VideoPlayerScreen({
    super.key,
    required this.media,
    this.videoUrl,
    this.season,
    this.episode,
    this.sourceLabel,
    this.resumeExisting = false,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  final PlaybackService _playback = PlaybackService.instance;
  final CastService _cast = CastService.instance;

  bool _showControls = true;
  Timer? _hideTimer;
  bool _showAudioMenu = false;
  bool _showSubtitleMenu = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(
      [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
    );

    // Coming back from the mini player: playback is already running, just
    // re-attach the full screen chrome to it.
    _playback.exitPip();

    if (!widget.resumeExisting) {
      unawaited(_playback.open(
        media: widget.media,
        videoUrl: widget.videoUrl,
        sourceLabel: widget.sourceLabel,
        season: widget.season,
        episode: widget.episode,
      ));
    }

    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();

    // The fix for playback outliving the page: whatever the reason this route
    // went away — back button, window close, a pop from somewhere else — the
    // one player is stopped unless it was deliberately handed to PiP.
    // stop() bumps the service's generation synchronously, so even a source
    // still being opened in the background is cancelled.
    if (!_playback.isPipActive) {
      unawaited(_playback.stop());
    }

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || !_playback.isPlaying) return;
      setState(() {
        _showControls = false;
        _showAudioMenu = false;
        _showSubtitleMenu = false;
      });
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  void _playPause() {
    Haptics.medium();
    if (_cast.isCasting) {
      unawaited(_cast.togglePlayPause());
    } else {
      _playback.playOrPause();
    }
    _startHideTimer();
  }

  void _seek(Duration delta) {
    Haptics.light();
    if (_cast.isCasting) {
      unawaited(_cast.seek(_playback.position + delta));
    }
    _playback.seekBy(delta);
    _startHideTimer();
  }

  void _seekTo(double seconds) {
    _playback.seekTo(Duration(seconds: seconds.toInt()));
    _startHideTimer();
  }

  Future<void> _enterPip() async {
    Haptics.medium();
    final systemPip = await _playback.enterPip();
    // Android draws this very page inside its floating window, so there is
    // nothing to pop. Everywhere else the in-app mini player takes over.
    if (!systemPip && mounted) Navigator.pop(context);
  }

  Future<void> _openCastPicker() async {
    Haptics.selection();
    final url = _playback.videoUrl;
    if (url == null || url.isEmpty) {
      _notify('Nada para transmitir nesta tela.');
      return;
    }

    final started = await showCastPicker(
      context: context,
      media: widget.media,
      url: url,
      title: _playback.displayTitle,
      startAt: _playback.position,
    );

    if (started == true) {
      // The TV is playing it now — silence the local copy so the audio is
      // not duplicated across the room.
      _playback.pause();
      if (mounted) setState(() {});
    }
  }

  Future<void> _stopCasting() async {
    Haptics.selection();
    await _cast.stopCasting();
    if (mounted) setState(() {});
  }

  Future<void> _openOfficialTrailer() async {
    final key = widget.media.trailerKey;
    if (key == null || key.isEmpty) return;
    Haptics.selection();
    final url = Uri.parse('https://www.youtube.com/watch?v=$key');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _notify(String message) {
    Haptics.error();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDuration(Duration duration) {
    String two(int value) => value.toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      return '${two(duration.inHours)}:${two(duration.inMinutes.remainder(60))}'
          ':${two(duration.inSeconds.remainder(60))}';
    }
    return '${two(duration.inMinutes)}:${two(duration.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_playback, _cast]),
      builder: (context, _) {
        // Inside Android's PiP window there is no room for chrome — the OS
        // shows a thumbnail-sized surface, so render the picture alone.
        if (_playback.isSystemPip) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: _playback.hasVideo
                ? Video(
                    controller: _playback.videoController!,
                    controls: NoVideoControls,
                    fill: Colors.black,
                  )
                : const SizedBox.expand(),
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
                _buildSurface(),
                if (_playback.isBuffering && _playback.hasVideo && !_cast.isCasting)
                  const Center(
                    child: CircularProgressIndicator(color: SabuflixTheme.accent),
                  ),
                if (_cast.isCasting) _buildCastingStage(),
                if (_showControls || !_playback.isPlaying)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    color: Colors.black.withValues(
                      alpha: _playback.isPlaying ? 0.35 : 0.65,
                    ),
                  ),
                if (_showControls) _buildControls(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSurface() {
    if (_playback.hasVideo) {
      return Center(
        child: Video(
          controller: _playback.videoController!,
          controls: NoVideoControls,
          fill: Colors.black,
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: widget.media.fullBackdropPath,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      placeholder: (context, url) => Container(color: SabuflixTheme.background),
      errorWidget: (context, url, err) => Container(color: SabuflixTheme.background),
    );
  }

  /// Shown over the video while a TV is playing it, so the phone is clearly a
  /// remote control rather than a second screen.
  Widget _buildCastingStage() {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cast_connected_rounded, size: 56, color: SabuflixTheme.accent),
          const SizedBox(height: 16),
          Text(
            'Transmitindo para ${_cast.connectedDevice?.name ?? 'TV'}',
            style: SabuflixTheme.title(fontSize: 18, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            _playback.displayTitle,
            style: SabuflixTheme.body(fontSize: 13, color: SabuflixTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _stopCasting,
            icon: const Icon(Icons.stop_circle_outlined, size: 18),
            label: const Text('Parar transmissão'),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final position = _playback.position;
    final duration = _playback.duration;
    final maxSeconds = duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1.0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _showControls ? 1.0 : 0.0,
      child: Stack(
        children: [
          Positioned(
            top: 16,
            left: 16,
            right: 260,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
                  onPressed: () {
                    Haptics.selection();
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _playback.displayTitle.isEmpty
                            ? widget.media.title
                            : _playback.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SabuflixTheme.title(fontSize: 18, color: Colors.white),
                      ),
                      Text(
                        widget.media.formattedYear,
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
                TextButton.icon(
                  onPressed: _openOfficialTrailer,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusSm),
                  ),
                  icon: const Icon(Icons.smart_display_outlined, size: 18, color: Colors.white),
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
                IconButton(
                  tooltip: _cast.isCasting ? 'Parar transmissão' : 'Transmitir para TV',
                  icon: Icon(
                    _cast.isCasting ? Icons.cast_connected_rounded : Icons.cast_rounded,
                    color: _cast.isCasting ? SabuflixTheme.accent : Colors.white,
                  ),
                  onPressed: _cast.isCasting ? _stopCasting : _openCastPicker,
                ),
                IconButton(
                  tooltip: 'Picture in Picture',
                  icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white),
                  onPressed: _playback.hasMedia ? _enterPip : null,
                ),
                if (_playback.subtitleTracks.isNotEmpty)
                  IconButton(
                    tooltip: 'Legendas',
                    icon: const Icon(Icons.subtitles_outlined, color: Colors.white),
                    onPressed: () {
                      Haptics.selection();
                      setState(() {
                        _showSubtitleMenu = !_showSubtitleMenu;
                        _showAudioMenu = false;
                      });
                    },
                  ),
                if (_playback.audioTracks.length > 1)
                  IconButton(
                    tooltip: 'Áudio',
                    icon: const Icon(Icons.audiotrack_rounded, color: Colors.white),
                    onPressed: () {
                      Haptics.selection();
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
                  onPressed: () => _seek(const Duration(seconds: -10)),
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
                    icon: Icon(
                      (_cast.isCasting ? _cast.isPlaying : _playback.isPlaying)
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                    ),
                    onPressed: _playPause,
                  ),
                ),
                const SizedBox(width: 28),
                IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                  onPressed: () => _seek(const Duration(seconds: 10)),
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
                tracks: _playback.audioTracks,
                selectedTrack: _playback.selectedAudioTrack,
                titleBuilder: (t) => t.title ?? t.language ?? 'Áudio ${t.id}',
                onSelect: (track) {
                  Haptics.selection();
                  _playback.setAudioTrack(track);
                  setState(() => _showAudioMenu = false);
                },
              ),
            ),
          if (_showSubtitleMenu)
            Positioned(
              right: _playback.audioTracks.length > 1 ? 96 : 56,
              top: 64,
              child: _TrackMenu<SubtitleTrack>(
                width: 220,
                tracks: _playback.subtitleTracks,
                selectedTrack: _playback.selectedSubtitleTrack,
                titleBuilder: (t) => t.title ?? t.language ?? 'Legenda ${t.id}',
                onSelect: (track) {
                  Haptics.selection();
                  _playback.setSubtitleTrack(track);
                  setState(() => _showSubtitleMenu = false);
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
                    value: position.inSeconds.toDouble().clamp(0.0, maxSeconds),
                    min: 0,
                    max: maxSeconds,
                    onChanged: _seekTo,
                    onChangeEnd: (value) {
                      Haptics.light();
                      if (_cast.isCasting) {
                        unawaited(_cast.seek(Duration(seconds: value.toInt())));
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(position),
                        style: SabuflixTheme.body(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatDuration(duration),
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
              trailing: isSelected
                  ? const Icon(Icons.check_rounded, color: SabuflixTheme.accent, size: 18)
                  : null,
              onTap: () => onSelect(track),
            );
          },
        ),
      ),
    );
  }
}
