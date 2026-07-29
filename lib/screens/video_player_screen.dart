import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/media_item.dart';
import '../theme/sabuflix_theme.dart';

class VideoPlayerScreen extends StatefulWidget {
  final MediaItem media;

  const VideoPlayerScreen({Key? key, required this.media}) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _showControls = true;
  Timer? _hideTimer;
  Timer? _playbackTimer;
  bool _isPlaying = true;
  double _currentPosition = 145; // in seconds
  final double _totalDuration = 6840; // 1h 54m
  String _selectedQuality = '4K Ultra HD';
  String _selectedSubtitle = 'Português (Brasil)';
  bool _showQualityMenu = false;
  bool _showSubtitleMenu = false;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    _startPlaybackTimer();

    // Enable landscape immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPlaying && mounted) {
        setState(() {
          if (_currentPosition < _totalDuration) {
            _currentPosition += 1;
          } else {
            _isPlaying = false;
          }
        });
      }
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showControls = false;
          _showQualityMenu = false;
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

  String _formatDuration(double seconds) {
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
    } else {
      final Uri searchUrl = Uri.parse('https://www.youtube.com/results?search_query=${Uri.encodeComponent('${widget.media.title} trailer oficial')}');
      if (await canLaunchUrl(searchUrl)) {
        await launchUrl(searchUrl, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _playbackTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video Backdrop stream preview
            CachedNetworkImage(
              imageUrl: widget.media.fullBackdropPath,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              placeholder: (context, url) => Container(color: SabuflixTheme.background),
              errorWidget: (context, url, err) => Container(color: SabuflixTheme.background),
            ),

            // Vignette darken overlay
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              color: Colors.black.withValues(alpha: _isPlaying ? 0.5 : 0.8),
            ),

            // Live status badge overlay
            Positioned(
              top: 25,
              right: 25,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: SabuflixTheme.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: SabuflixTheme.terracotta, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: SabuflixTheme.terracotta,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'SABUFLIX STREAM [$_selectedQuality]',
                      style: SabuflixTheme.sansBody(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Controls Overlay
            if (_showControls)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showControls ? 1.0 : 0.0,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  child: Stack(
                    children: [
                      // Header bar
                      Positioned(
                        top: 20,
                        left: 20,
                        right: 220,
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.media.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: SabuflixTheme.serifHeader(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${widget.media.formattedYear} • Reprodução Sabuflix HD',
                                    style: SabuflixTheme.sansBody(color: SabuflixTheme.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Header action icons
                      Positioned(
                        top: 20,
                        right: 80,
                        child: Row(
                          children: [
                            // Watch official trailer action
                            TextButton.icon(
                              onPressed: _openOfficialTrailer,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: SabuflixTheme.terracotta,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              icon: const Icon(Icons.movie_rounded, size: 18, color: Colors.white),
                              label: Text(
                                'Trailer Oficial',
                                style: SabuflixTheme.sansBody(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Subtitles menu toggle
                            IconButton(
                              icon: const Icon(Icons.subtitles, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _showSubtitleMenu = !_showSubtitleMenu;
                                  _showQualityMenu = false;
                                });
                              },
                            ),

                            // Quality menu toggle
                            IconButton(
                              icon: const Icon(Icons.settings, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _showQualityMenu = !_showQualityMenu;
                                  _showSubtitleMenu = false;
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      // Center Controls (10s back, play/pause, 10s forward)
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              iconSize: 44,
                              icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _currentPosition = (_currentPosition - 10).clamp(0, _totalDuration);
                                });
                                _startHideTimer();
                              },
                            ),
                            const SizedBox(width: 30),
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: SabuflixTheme.terracotta,
                              child: IconButton(
                                iconSize: 42,
                                icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                                onPressed: () {
                                  setState(() {
                                    _isPlaying = !_isPlaying;
                                  });
                                  _startHideTimer();
                                },
                              ),
                            ),
                            const SizedBox(width: 30),
                            IconButton(
                              iconSize: 44,
                              icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _currentPosition = (_currentPosition + 10).clamp(0, _totalDuration);
                                });
                                _startHideTimer();
                              },
                            ),
                          ],
                        ),
                      ),

                      // Skip Intro Button
                      Positioned(
                        right: 30,
                        bottom: 90,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _currentPosition += 85;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Abertura pulada (+85s)', style: SabuflixTheme.sansBody(color: Colors.white)),
                                duration: const Duration(seconds: 1),
                                backgroundColor: SabuflixTheme.terracotta,
                              ),
                            );
                            _startHideTimer();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SabuflixTheme.surface.withValues(alpha: 0.8),
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: SabuflixTheme.border),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: const Icon(Icons.fast_forward_rounded, size: 20),
                          label: Text('Pular Abertura', style: SabuflixTheme.sansBody(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),

                      // Quality Selection Popup Menu
                      if (_showQualityMenu)
                        Positioned(
                          right: 60,
                          top: 70,
                          child: Container(
                            width: 180,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: SabuflixTheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: SabuflixTheme.border),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: ['4K Ultra HD', 'Full HD 1080p', 'HD 720p', 'Automático']
                                  .map(
                                    (q) => ListTile(
                                      dense: true,
                                      title: Text(
                                        q,
                                        style: TextStyle(
                                          color: _selectedQuality == q ? SabuflixTheme.terracotta : Colors.white,
                                          fontWeight: _selectedQuality == q ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      onTap: () {
                                        setState(() {
                                          _selectedQuality = q;
                                          _showQualityMenu = false;
                                        });
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),

                      // Subtitles Popup Menu
                      if (_showSubtitleMenu)
                        Positioned(
                          right: 100,
                          top: 70,
                          child: Container(
                            width: 200,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: SabuflixTheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: SabuflixTheme.border),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: ['Português (Brasil)', 'English', 'Español', 'Desativado']
                                  .map(
                                    (s) => ListTile(
                                      dense: true,
                                      title: Text(
                                        s,
                                        style: TextStyle(
                                          color: _selectedSubtitle == s ? SabuflixTheme.terracotta : Colors.white,
                                          fontWeight: _selectedSubtitle == s ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      onTap: () {
                                        setState(() {
                                          _selectedSubtitle = s;
                                          _showSubtitleMenu = false;
                                        });
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),

                      // Bottom Timeline Bar & Controls
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Column(
                          children: [
                            SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                activeTrackColor: SabuflixTheme.terracotta,
                                inactiveTrackColor: SabuflixTheme.border,
                                thumbColor: SabuflixTheme.terracotta,
                              ),
                              child: Slider(
                                value: _currentPosition.clamp(0, _totalDuration),
                                min: 0,
                                max: _totalDuration,
                                onChanged: (val) {
                                  setState(() => _currentPosition = val);
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
                                    _formatDuration(_currentPosition),
                                    style: SabuflixTheme.sansBody(color: SabuflixTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    _formatDuration(_totalDuration),
                                    style: SabuflixTheme.sansBody(color: SabuflixTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
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
          ],
        ),
      ),
    );
  }
}
