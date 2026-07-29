import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/media_item.dart';

class VideoPlayerScreen extends StatefulWidget {
  final MediaItem media;

  const VideoPlayerScreen({Key? key, required this.media}) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  YoutubePlayerController? _youtubeController;
  bool _showControls = true;
  Timer? _hideTimer;
  bool _isPlaying = true;
  double _currentPosition = 120; // in seconds
  final double _totalDuration = 7200; // 2 hours sample
  String _selectedQuality = '4K Ultra HD';
  String _selectedSubtitle = 'Português (Brasil)';
  bool _showQualityMenu = false;
  bool _showSubtitleMenu = false;

  @override
  void initState() {
    super.initState();
    _startHideTimer();

    // Enable landscape immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (widget.media.trailerKey != null && widget.media.trailerKey!.isNotEmpty) {
      _youtubeController = YoutubePlayerController(
        initialVideoId: widget.media.trailerKey!,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          disableDragSeek: false,
          loop: false,
          isLive: false,
          forceHD: true,
        ),
      );
    }
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

  @override
  void dispose() {
    _hideTimer?.cancel();
    _youtubeController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasYoutube = _youtubeController != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video Engine (YouTube or Custom Preview)
            if (hasYoutube)
              Center(
                child: YoutubePlayer(
                  controller: _youtubeController!,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: const Color(0xFFE50914),
                  progressColors: const ProgressBarColors(
                    playedColor: Color(0xFFE50914),
                    handleColor: Color(0xFFE50914),
                  ),
                ),
              )
            else
              Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.media.fullBackdropPath,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    color: Colors.black.withOpacity(0.55),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.movie_creation_outlined, color: Color(0xFFE50914), size: 64),
                        const SizedBox(height: 16),
                        Text(
                          'Reproduzindo: ${widget.media.title}',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Transmissão Sabuflix High Quality [$_selectedQuality]',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

            // Controls Overlay
            if (_showControls)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showControls ? 1.0 : 0.0,
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Stack(
                    children: [
                      // Header bar
                      Positioned(
                        top: 20,
                        left: 20,
                        right: 20,
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.media.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${widget.media.formattedYear} • Sabuflix Stream',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),

                            // Subtitles button
                            IconButton(
                              icon: const Icon(Icons.subtitles, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _showSubtitleMenu = !_showSubtitleMenu;
                                  _showQualityMenu = false;
                                });
                              },
                            ),

                            // Quality Settings Button
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
                              iconSize: 42,
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
                              backgroundColor: const Color(0xFFE50914),
                              child: IconButton(
                                iconSize: 42,
                                icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                                onPressed: () {
                                  setState(() {
                                    _isPlaying = !_isPlaying;
                                    if (hasYoutube) {
                                      if (_isPlaying) {
                                        _youtubeController!.play();
                                      } else {
                                        _youtubeController!.pause();
                                      }
                                    }
                                  });
                                  _startHideTimer();
                                },
                              ),
                            ),
                            const SizedBox(width: 30),
                            IconButton(
                              iconSize: 42,
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
                              const SnackBar(
                                content: Text('Abertura pulada!'),
                                duration: Duration(seconds: 1),
                                backgroundColor: Color(0xFFE50914),
                              ),
                            );
                            _startHideTimer();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          icon: const Icon(Icons.fast_forward_rounded, size: 20),
                          label: const Text('Pular Abertura', style: TextStyle(fontWeight: FontWeight.bold)),
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
                              color: const Color(0xFF14141F),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAlignment: CrossAlignment.start,
                              children: ['4K Ultra HD', 'Full HD 1080p', 'HD 720p', 'Automático']
                                  .map(
                                    (q) => ListTile(
                                      dense: true,
                                      title: Text(
                                        q,
                                        style: TextStyle(
                                          color: _selectedQuality == q ? const Color(0xFFE50914) : Colors.white,
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
                              color: const Color(0xFF14141F),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAlignment: CrossAlignment.start,
                              children: ['Português (Brasil)', 'English', 'Español', 'Desativado']
                                  .map(
                                    (s) => ListTile(
                                      dense: true,
                                      title: Text(
                                        s,
                                        style: TextStyle(
                                          color: _selectedSubtitle == s ? const Color(0xFFE50914) : Colors.white,
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
                                activeTrackColor: const Color(0xFFE50914),
                                inactiveTrackColor: Colors.white24,
                                thumbColor: const Color(0xFFE50914),
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
                                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    _formatDuration(_totalDuration),
                                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
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
