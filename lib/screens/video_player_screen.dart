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
            CachedNetworkImage(
              imageUrl: widget.media.fullBackdropPath,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              placeholder: (context, url) => Container(color: SabuflixTheme.background),
              errorWidget: (context, url, err) => Container(color: SabuflixTheme.background),
            ),

            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              color: Colors.black.withValues(alpha: _isPlaying ? 0.45 : 0.75),
            ),

            Positioned(
              top: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: SabuflixTheme.radiusPill,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(color: SabuflixTheme.accent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedQuality,
                      style: SabuflixTheme.label(fontSize: 10, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

            if (_showControls)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showControls ? 1.0 : 0.0,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
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
                            IconButton(
                              icon: const Icon(Icons.subtitles_outlined, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _showSubtitleMenu = !_showSubtitleMenu;
                                  _showQualityMenu = false;
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.settings_outlined, color: Colors.white),
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

                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              iconSize: 40,
                              icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _currentPosition = (_currentPosition - 10).clamp(0, _totalDuration);
                                });
                                _startHideTimer();
                              },
                            ),
                            const SizedBox(width: 28),
                            Container(
                              width: 68,
                              height: 68,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: IconButton(
                                iconSize: 36,
                                icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: SabuflixTheme.background),
                                onPressed: () {
                                  setState(() {
                                    _isPlaying = !_isPlaying;
                                  });
                                  _startHideTimer();
                                },
                              ),
                            ),
                            const SizedBox(width: 28),
                            IconButton(
                              iconSize: 40,
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

                      Positioned(
                        right: 24,
                        bottom: 96,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _currentPosition += 85;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Abertura pulada')),
                            );
                            _startHideTimer();
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.black.withValues(alpha: 0.4),
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusPill),
                          ),
                          icon: const Icon(Icons.fast_forward_rounded, size: 18),
                          label: const Text('Pular Abertura'),
                        ),
                      ),

                      if (_showQualityMenu)
                        Positioned(
                          right: 56,
                          top: 64,
                          child: _PopupMenu(
                            width: 180,
                            options: const ['4K Ultra HD', 'Full HD 1080p', 'HD 720p', 'Automático'],
                            selected: _selectedQuality,
                            onSelect: (q) => setState(() {
                              _selectedQuality = q;
                              _showQualityMenu = false;
                            }),
                          ),
                        ),

                      if (_showSubtitleMenu)
                        Positioned(
                          right: 96,
                          top: 64,
                          child: _PopupMenu(
                            width: 200,
                            options: const ['Português (Brasil)', 'English', 'Español', 'Desativado'],
                            selected: _selectedSubtitle,
                            onSelect: (s) => setState(() {
                              _selectedSubtitle = s;
                              _showSubtitleMenu = false;
                            }),
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
                                trackHeight: 3.5,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
                                thumbColor: Colors.white,
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
          ],
        ),
      ),
    );
  }
}

class _PopupMenu extends StatelessWidget {
  final double width;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _PopupMenu({
    required this.width,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: SabuflixTheme.elevated,
        borderRadius: SabuflixTheme.radiusMd,
        border: Border.all(color: SabuflixTheme.border),
        boxShadow: SabuflixTheme.shadowMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: options.map((o) {
          final isSelected = selected == o;
          return ListTile(
            dense: true,
            shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusSm),
            title: Text(
              o,
              style: SabuflixTheme.body(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : SabuflixTheme.textSecondary,
              ),
            ),
            trailing: isSelected ? const Icon(Icons.check_rounded, color: SabuflixTheme.accent, size: 18) : null,
            onTap: () => onSelect(o),
          );
        }).toList(),
      ),
    );
  }
}
