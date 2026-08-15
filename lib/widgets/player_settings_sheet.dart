import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../theme/sabuflix_theme.dart';
import 'glass_container.dart';

Future<void> showPlayerSettingsSheet(
  BuildContext context, {
  required double rate,
  required BoxFit videoFit,
  required double subtitleSize,
  required bool subtitleBackground,
  required List<AudioTrack> audioTracks,
  required AudioTrack? selectedAudioTrack,
  required List<SubtitleTrack> subtitleTracks,
  required SubtitleTrack? selectedSubtitleTrack,
  required ValueChanged<double> onRateChanged,
  required ValueChanged<BoxFit> onVideoFitChanged,
  required void Function(double size, bool background) onSubtitleStyleChanged,
  required ValueChanged<AudioTrack> onAudioTrackChanged,
  required ValueChanged<SubtitleTrack> onSubtitleTrackChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PlayerSettingsSheet(
      rate: rate,
      videoFit: videoFit,
      subtitleSize: subtitleSize,
      subtitleBackground: subtitleBackground,
      audioTracks: audioTracks,
      selectedAudioTrack: selectedAudioTrack,
      subtitleTracks: subtitleTracks,
      selectedSubtitleTrack: selectedSubtitleTrack,
      onRateChanged: onRateChanged,
      onVideoFitChanged: onVideoFitChanged,
      onSubtitleStyleChanged: onSubtitleStyleChanged,
      onAudioTrackChanged: onAudioTrackChanged,
      onSubtitleTrackChanged: onSubtitleTrackChanged,
    ),
  );
}

class _PlayerSettingsSheet extends StatefulWidget {
  final double rate;
  final BoxFit videoFit;
  final double subtitleSize;
  final bool subtitleBackground;
  final List<AudioTrack> audioTracks;
  final AudioTrack? selectedAudioTrack;
  final List<SubtitleTrack> subtitleTracks;
  final SubtitleTrack? selectedSubtitleTrack;
  final ValueChanged<double> onRateChanged;
  final ValueChanged<BoxFit> onVideoFitChanged;
  final void Function(double size, bool background) onSubtitleStyleChanged;
  final ValueChanged<AudioTrack> onAudioTrackChanged;
  final ValueChanged<SubtitleTrack> onSubtitleTrackChanged;

  const _PlayerSettingsSheet({
    required this.rate,
    required this.videoFit,
    required this.subtitleSize,
    required this.subtitleBackground,
    required this.audioTracks,
    required this.selectedAudioTrack,
    required this.subtitleTracks,
    required this.selectedSubtitleTrack,
    required this.onRateChanged,
    required this.onVideoFitChanged,
    required this.onSubtitleStyleChanged,
    required this.onAudioTrackChanged,
    required this.onSubtitleTrackChanged,
  });

  @override
  State<_PlayerSettingsSheet> createState() => _PlayerSettingsSheetState();
}

class _PlayerSettingsSheetState extends State<_PlayerSettingsSheet> {
  late double _rate = widget.rate;
  late BoxFit _videoFit = widget.videoFit;
  late double _subtitleSize = widget.subtitleSize;
  late bool _subtitleBackground = widget.subtitleBackground;
  late AudioTrack? _selectedAudio = widget.selectedAudioTrack;
  late SubtitleTrack? _selectedSubtitle = widget.selectedSubtitleTrack;

  List<AudioTrack> get _availableAudioTracks =>
      widget.audioTracks.where((track) => track.id != 'no').toList();

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: GlassContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        blur: 42,
        fillOpacity: 0.76,
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.28),
                borderRadius: SabuflixTheme.radiusPill,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('Opções de reprodução',
                      style: SabuflixTheme.title(fontSize: 20)),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  const _SettingsHeader(
                    icon: Icons.speed_rounded,
                    title: 'Velocidade',
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                        .map((value) => _ChoicePill(
                              label: value == 1 ? 'Normal' : '${value}x',
                              selected: _rate == value,
                              onTap: () {
                                setState(() => _rate = value);
                                widget.onRateChanged(value);
                              },
                            ))
                        .toList(),
                  ),
                  const _SectionGap(),
                  const _SettingsHeader(
                    icon: Icons.aspect_ratio_rounded,
                    title: 'Enquadramento',
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _ChoiceTile(
                          icon: Icons.fit_screen_rounded,
                          title: 'Original',
                          subtitle: 'Sem cortes',
                          selected: _videoFit == BoxFit.contain,
                          onTap: () => _selectFit(BoxFit.contain),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ChoiceTile(
                          icon: Icons.crop_free_rounded,
                          title: 'Preencher',
                          subtitle: 'Ocupa a tela',
                          selected: _videoFit == BoxFit.cover,
                          onTap: () => _selectFit(BoxFit.cover),
                        ),
                      ),
                    ],
                  ),
                  if (_availableAudioTracks.length > 1) ...[
                    const _SectionGap(),
                    const _SettingsHeader(
                      icon: Icons.graphic_eq_rounded,
                      title: 'Áudio',
                    ),
                    const SizedBox(height: 10),
                    ..._availableAudioTracks.map((track) => _TrackChoice(
                          title: _trackTitle(track, 'Áudio'),
                          selected: track == _selectedAudio,
                          onTap: () {
                            setState(() => _selectedAudio = track);
                            widget.onAudioTrackChanged(track);
                          },
                        )),
                  ],
                  const _SectionGap(),
                  const _SettingsHeader(
                    icon: Icons.subtitles_rounded,
                    title: 'Legendas',
                  ),
                  const SizedBox(height: 8),
                  _TrackChoice(
                    title: 'Desativadas',
                    selected: _selectedSubtitle?.id == 'no',
                    onTap: () {
                      final track = SubtitleTrack.no();
                      setState(() {
                        _selectedSubtitle = track;
                      });
                      widget.onSubtitleTrackChanged(track);
                    },
                  ),
                  ...widget.subtitleTracks
                      .where((track) => !['no', 'auto'].contains(track.id))
                      .map((track) => _TrackChoice(
                            title: _trackTitle(track, 'Legenda'),
                            selected: track == _selectedSubtitle,
                            onTap: () {
                              setState(() {
                                _selectedSubtitle = track;
                              });
                              widget.onSubtitleTrackChanged(track);
                            },
                          )),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text('Tamanho', style: SabuflixTheme.body(fontSize: 13)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Slider(
                          min: 22,
                          max: 42,
                          divisions: 4,
                          value: _subtitleSize,
                          label: '${_subtitleSize.round()}',
                          onChanged: (value) {
                            setState(() => _subtitleSize = value);
                            widget.onSubtitleStyleChanged(
                              value,
                              _subtitleBackground,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Fundo da legenda',
                        style: SabuflixTheme.body(
                            color: Colors.white, fontSize: 14)),
                    subtitle: Text('Melhora o contraste em cenas claras',
                        style: SabuflixTheme.caption()),
                    value: _subtitleBackground,
                    activeThumbColor: SabuflixTheme.accent,
                    onChanged: (value) {
                      setState(() => _subtitleBackground = value);
                      widget.onSubtitleStyleChanged(_subtitleSize, value);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectFit(BoxFit fit) {
    setState(() => _videoFit = fit);
    widget.onVideoFitChanged(fit);
  }

  String _trackTitle(dynamic track, String fallback) {
    return track.title?.toString().trim().isNotEmpty == true
        ? track.title.toString()
        : track.language?.toString().trim().isNotEmpty == true
            ? track.language.toString().toUpperCase()
            : '$fallback ${track.id}';
  }
}

class _SettingsHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SettingsHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: SabuflixTheme.textSecondary),
        const SizedBox(width: 9),
        Text(title,
            style: SabuflixTheme.body(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            )),
      ],
    );
  }
}

class _ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? SabuflixTheme.textPrimary
          : Colors.white.withValues(alpha: 0.075),
      borderRadius: SabuflixTheme.radiusPill,
      child: InkWell(
        borderRadius: SabuflixTheme.radiusPill,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Text(
            label,
            style: SabuflixTheme.caption(
              color: selected ? SabuflixTheme.background : Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Colors.white.withValues(alpha: 0.15)
          : Colors.white.withValues(alpha: 0.06),
      borderRadius: SabuflixTheme.radiusMd,
      child: InkWell(
        borderRadius: SabuflixTheme.radiusMd,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Icon(icon,
                  color: selected ? SabuflixTheme.accent : Colors.white70),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: SabuflixTheme.body(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        )),
                    Text(subtitle, style: SabuflixTheme.caption(fontSize: 10)),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded,
                    color: SabuflixTheme.accent, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackChoice extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _TrackChoice({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusSm),
      tileColor: selected ? Colors.white.withValues(alpha: 0.1) : null,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: SabuflixTheme.body(
          color: Colors.white,
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_rounded,
              color: SabuflixTheme.accent, size: 18)
          : null,
      onTap: onTap,
    );
  }
}

class _SectionGap extends StatelessWidget {
  const _SectionGap();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 24);
  }
}
