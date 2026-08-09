import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/media_item.dart';
import '../providers/playback_controller.dart';
import '../services/desktop_pip.dart';
import '../services/native_pip.dart';
import '../theme/sabuflix_theme.dart';
import '../widgets/glass_container.dart';

class VideoPlayerScreen extends StatefulWidget {
  final MediaItem media;

  /// Remote stream URL, or an absolute file path when playing a download.
  final String? videoUrl;

  /// Playing from local storage. Hides everything that needs the network.
  final bool isOffline;

  /// Reopening the page for a session that is already running, such as when
  /// the floating window is expanded back to fullscreen. Playback continues
  /// from where it is instead of restarting.
  final bool resumeSession;

  const VideoPlayerScreen({
    Key? key,
    required this.media,
    this.videoUrl,
    this.isOffline = false,
    this.resumeSession = false,
  }) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _showControls = true;
  Timer? _hideTimer;

  bool _showAudioMenu = false;
  bool _showSubtitleMenu = false;

  /// Captured once so it is still reachable from dispose, after this widget
  /// has left the tree.
  PlaybackController? _playback;

  /// True while Android is showing this activity as a system PiP thumbnail.
  /// At that size every control is noise, so the video is shown bare.
  bool _inSystemPip = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(
      [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
    );

    // Starting playback notifies listeners, which cannot happen while the
    // first frame is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final url = widget.videoUrl;
      if (!widget.resumeSession && url != null && url.isNotEmpty) {
        _playback?.open(
          media: widget.media,
          url: url,
          isOffline: widget.isOffline,
        );
      } else {
        _playback?.exitPip();
      }
    });

    NativePip.listenModeChanges((inPip) {
      if (!mounted) return;
      setState(() {
        _inSystemPip = inPip;
        if (inPip) _showControls = false;
      });
    });

    _startHideTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _playback = context.read<PlaybackController>();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    NativePip.stopListening();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // Leaving the page normally ends playback; leaving it because the video
    // was sent to the floating window must not.
    final playback = _playback;
    if (playback != null && !playback.isPip) {
      playback.stop();
    }
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      final playing = _playback?.isPlaying ?? false;
      if (playing) {
        setState(() {
          _showControls = false;
          _showAudioMenu = false;
          _showSubtitleMenu = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  /// Sends the video to a floating window.
  ///
  /// System picture-in-picture is tried first, because that floats the video
  /// over every other app the way Firefox does. Where the platform has none —
  /// Windows, or Android before API 26 — the in-app window takes over, which
  /// floats over the rest of Sabuflix instead.
  Future<void> _enterPip(PlaybackController playback) async {
    if (await NativePip.enter()) return;
    if (!mounted) return;
    await playback.enterPip(useDesktopWindow: DesktopPip.isSupported);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _openOfficialTrailer() async {
    final key = widget.media.trailerKey;
    if (key == null || key.isEmpty) return;
    final url = Uri.parse('https://www.youtube.com/watch?v=$key');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<PlaybackController>();
    final hasVideo = playback.hasVideo;
    final totalSeconds = playback.duration.inSeconds.toDouble();
    final currentSeconds = playback.position.inSeconds.toDouble();

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
                  controller: playback.videoController!,
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

            if (playback.isBuffering && hasVideo)
              const Center(child: CircularProgressIndicator(color: SabuflixTheme.accent)),

            if (!_inSystemPip && (_showControls || !playback.isPlaying))
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                color: Colors.black.withValues(alpha: playback.isPlaying ? 0.35 : 0.65),
              ),

            if (_showControls && !_inSystemPip)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showControls ? 1.0 : 0.0,
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
                          if (hasVideo)
                            IconButton(
                              tooltip: 'Picture-in-picture',
                              icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white),
                              onPressed: () => _enterPip(playback),
                            ),
                          // The trailer opens YouTube, so it is pointless
                          // when the user is watching a download offline.
                          if (!widget.isOffline)
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
                          if (widget.isOffline)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: SabuflixTheme.radiusSm,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.download_done_rounded, size: 16, color: SabuflixTheme.success),
                                  const SizedBox(width: 6),
                                  Text('Offline', style: SabuflixTheme.body(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                                ],
                              ),
                            ),
                          const SizedBox(width: 4),
                          if (playback.subtitleTracks.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.subtitles_outlined, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _showSubtitleMenu = !_showSubtitleMenu;
                                  _showAudioMenu = false;
                                });
                              },
                            ),
                          if (playback.audioTracks.length > 1)
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
                            onPressed: () {
                              playback.seekBy(const Duration(seconds: -10));
                              _startHideTimer();
                            },
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
                                playback.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                playback.playOrPause();
                                _startHideTimer();
                              },
                            ),
                          ),
                          const SizedBox(width: 28),
                          IconButton(
                            iconSize: 40,
                            icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                            onPressed: () {
                              playback.seekBy(const Duration(seconds: 10));
                              _startHideTimer();
                            },
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
                          tracks: playback.audioTracks,
                          selectedTrack: playback.selectedAudioTrack,
                          titleBuilder: (t) => t.title ?? t.language ?? 'Áudio ${t.id}',
                          onSelect: (track) {
                            playback.setAudioTrack(track);
                            setState(() => _showAudioMenu = false);
                          },
                        ),
                      ),

                    if (_showSubtitleMenu)
                      Positioned(
                        right: playback.audioTracks.length > 1 ? 96 : 56,
                        top: 64,
                        child: _TrackMenu<SubtitleTrack>(
                          width: 220,
                          tracks: playback.subtitleTracks,
                          selectedTrack: playback.selectedSubtitleTrack,
                          titleBuilder: (t) => t.title ?? t.language ?? 'Legenda ${t.id}',
                          onSelect: (track) {
                            playback.setSubtitleTrack(track);
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
                              value: currentSeconds.clamp(0.0, totalSeconds > 0 ? totalSeconds : 1.0),
                              min: 0,
                              max: totalSeconds > 0 ? totalSeconds : 1.0,
                              onChanged: (val) {
                                playback.seekTo(Duration(seconds: val.toInt()));
                                _startHideTimer();
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formatPlaybackTime(playback.position),
                                  style: SabuflixTheme.body(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  formatPlaybackTime(playback.duration),
                                  style: SabuflixTheme.body(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
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
