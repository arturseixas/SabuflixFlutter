import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../providers/settings_provider.dart';
import '../../theme/sabuflix_theme.dart';

/// Dark bottom sheet used by every player menu.
Future<T?> showPlayerSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF15171A),
    showDragHandle: true,
    builder: (_) => Theme(data: SabuflixTheme.themeData, child: child),
  );
}

String describeAudioTrack(AudioTrack track, int index) {
  final title = track.title?.trim();
  final language = _languageName(track.language);
  if (title != null && title.isNotEmpty) {
    return language != null &&
            !title.toLowerCase().contains(language.toLowerCase())
        ? '$title · $language'
        : title;
  }
  if (language != null) return language;
  return 'Faixa ${index + 1}';
}

String describeSubtitleTrack(SubtitleTrack track, int index) {
  if (track.id == 'no') return 'Desligadas';
  if (track.id == 'auto') return 'Automática';
  final title = track.title?.trim();
  final language = _languageName(track.language);
  if (title != null && title.isNotEmpty) return title;
  if (language != null) return language;
  return 'Legenda ${index + 1}';
}

String? _languageName(String? code) {
  if (code == null) return null;
  final normalized = code.toLowerCase().trim();
  const names = {
    'por': 'Português',
    'pob': 'Português (Brasil)',
    'pt': 'Português',
    'pt-br': 'Português (Brasil)',
    'pb': 'Português (Brasil)',
    'bra': 'Português (Brasil)',
    'eng': 'Inglês',
    'en': 'Inglês',
    'spa': 'Espanhol',
    'es': 'Espanhol',
    'fre': 'Francês',
    'fra': 'Francês',
    'fr': 'Francês',
    'ger': 'Alemão',
    'deu': 'Alemão',
    'de': 'Alemão',
    'ita': 'Italiano',
    'it': 'Italiano',
    'jpn': 'Japonês',
    'ja': 'Japonês',
    'kor': 'Coreano',
    'ko': 'Coreano',
    'chi': 'Chinês',
    'zho': 'Chinês',
    'zh': 'Chinês',
    'rus': 'Russo',
    'ru': 'Russo',
    'und': null,
  };
  if (names.containsKey(normalized)) return names[normalized];
  return normalized.toUpperCase();
}

/// Audio + subtitle picker, two columns on wide screens.
class TracksSheet extends StatelessWidget {
  final List<AudioTrack> audioTracks;
  final AudioTrack? selectedAudio;
  final List<SubtitleTrack> subtitleTracks;
  final SubtitleTrack? selectedSubtitle;
  final ValueChanged<AudioTrack> onAudio;
  final ValueChanged<SubtitleTrack> onSubtitle;
  final bool loadingSubtitles;

  const TracksSheet({
    super.key,
    required this.audioTracks,
    required this.selectedAudio,
    required this.subtitleTracks,
    required this.selectedSubtitle,
    required this.onAudio,
    required this.onSubtitle,
    this.loadingSubtitles = false,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final audio = _Section(
      title: 'Áudio',
      icon: Icons.audiotrack_rounded,
      children: audioTracks.isEmpty
          ? [const _Hint('Esta fonte tem uma única faixa de áudio.')]
          : [
              for (var i = 0; i < audioTracks.length; i++)
                _RadioRow(
                  label: describeAudioTrack(audioTracks[i], i),
                  selected: selectedAudio == audioTracks[i] ||
                      (selectedAudio?.id == audioTracks[i].id),
                  onTap: () => onAudio(audioTracks[i]),
                ),
            ],
    );
    final subtitles = _Section(
      title: 'Legendas',
      icon: Icons.subtitles_rounded,
      trailing: loadingSubtitles
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2))
          : null,
      children: [
        _RadioRow(
          label: 'Desligadas',
          selected: selectedSubtitle == null ||
              selectedSubtitle!.id == 'no' ||
              (selectedSubtitle!.id == 'auto' && subtitleTracks.isEmpty),
          onTap: () => onSubtitle(SubtitleTrack.no()),
        ),
        for (var i = 0; i < subtitleTracks.length; i++)
          _RadioRow(
            label: describeSubtitleTrack(subtitleTracks[i], i),
            detail: subtitleTracks[i].uri ? 'OpenSubtitles' : 'Embutida',
            selected: selectedSubtitle != null &&
                selectedSubtitle!.id == subtitleTracks[i].id,
            onTap: () => onSubtitle(subtitleTracks[i]),
          ),
        if (subtitleTracks.isEmpty && !loadingSubtitles)
          const _Hint('Nenhuma legenda encontrada para este título.'),
      ],
    );
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .7),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: audio),
                    const SizedBox(width: 24),
                    Expanded(child: subtitles),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [audio, const SizedBox(height: 20), subtitles],
                ),
        ),
      ),
    );
  }
}

/// Speed, fit, subtitle size, sleep timer and autoplay.
class PlayerSettingsSheet extends StatelessWidget {
  final double speed;
  final ValueChanged<double> onSpeed;
  final BoxFit fit;
  final ValueChanged<BoxFit> onFit;
  final double subtitleScale;
  final ValueChanged<double> onSubtitleScale;
  final Duration? sleepRemaining;
  final bool sleepAtEnd;
  final ValueChanged<Duration?> onSleep;
  final VoidCallback onSleepAtEnd;
  final bool autoplayNext;
  final ValueChanged<bool> onAutoplayNext;
  final bool showAutoplay;

  const PlayerSettingsSheet({
    super.key,
    required this.speed,
    required this.onSpeed,
    required this.fit,
    required this.onFit,
    required this.subtitleScale,
    required this.onSubtitleScale,
    required this.sleepRemaining,
    required this.sleepAtEnd,
    required this.onSleep,
    required this.onSleepAtEnd,
    required this.autoplayNext,
    required this.onAutoplayNext,
    required this.showAutoplay,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .75),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Section(
                title: 'Velocidade',
                icon: Icons.speed_rounded,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in SettingsProvider.speedOptions)
                        ChoiceChip(
                          label: Text(option == 1.0 ? 'Normal' : '${option}x'),
                          selected: (speed - option).abs() < 0.01,
                          showCheckmark: false,
                          onSelected: (_) => onSpeed(option),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _Section(
                title: 'Ajuste de tela',
                icon: Icons.aspect_ratio_rounded,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in const [
                        (BoxFit.contain, 'Original', Icons.fit_screen_rounded),
                        (BoxFit.cover, 'Preencher', Icons.crop_free_rounded),
                        (BoxFit.fill, 'Esticar', Icons.open_in_full_rounded),
                      ])
                        ChoiceChip(
                          avatar: Icon(option.$3,
                              size: 16,
                              color: fit == option.$1 ? Colors.white : null),
                          label: Text(option.$2),
                          selected: fit == option.$1,
                          showCheckmark: false,
                          onSelected: (_) => onFit(option.$1),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _Section(
                title: 'Tamanho das legendas',
                icon: Icons.format_size_rounded,
                trailing: Text('${(subtitleScale * 100).round()}%',
                    style: SabuflixTheme.caption(fontSize: 12)),
                children: [
                  Slider(
                    value: subtitleScale,
                    min: 0.7,
                    max: 1.8,
                    divisions: 11,
                    onChanged: onSubtitleScale,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _Section(
                title: 'Timer para dormir',
                icon: Icons.bedtime_rounded,
                trailing: sleepRemaining != null
                    ? Text('${sleepRemaining!.inMinutes + 1} min restantes',
                        style: SabuflixTheme.caption(
                            fontSize: 12, color: SabuflixTheme.accent))
                    : sleepAtEnd
                        ? Text('No fim do episódio',
                            style: SabuflixTheme.caption(
                                fontSize: 12, color: SabuflixTheme.accent))
                        : null,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Desligado'),
                        selected: sleepRemaining == null && !sleepAtEnd,
                        showCheckmark: false,
                        onSelected: (_) => onSleep(null),
                      ),
                      for (final minutes in const [15, 30, 45, 60, 90])
                        ChoiceChip(
                          label: Text('$minutes min'),
                          selected: false,
                          showCheckmark: false,
                          onSelected: (_) =>
                              onSleep(Duration(minutes: minutes)),
                        ),
                      if (showAutoplay)
                        ChoiceChip(
                          label: const Text('Fim do episódio'),
                          selected: sleepAtEnd,
                          showCheckmark: false,
                          onSelected: (_) => onSleepAtEnd(),
                        ),
                    ],
                  ),
                ],
              ),
              if (showAutoplay) ...[
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: autoplayNext,
                  onChanged: onAutoplayNext,
                  title: const Text(
                      'Reproduzir o próximo episódio automaticamente'),
                  subtitle:
                      const Text('Um aviso aparece antes do próximo começar.'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Episode picker inside the player.
class EpisodesSheet extends StatelessWidget {
  final int season;
  final List<int> seasons;
  final List<dynamic> episodes;
  final bool loading;
  final int? currentEpisode;
  final bool Function(int episode) isWatched;
  final ValueChanged<int> onSeason;
  final void Function(int episode, String? title) onEpisode;
  final String fallbackImage;

  const EpisodesSheet({
    super.key,
    required this.season,
    required this.seasons,
    required this.episodes,
    required this.loading,
    required this.currentEpisode,
    required this.isWatched,
    required this.onSeason,
    required this.onEpisode,
    required this.fallbackImage,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                      child: Text('Episódios',
                          style: SabuflixTheme.title(fontSize: 18))),
                  if (seasons.length > 1)
                    DropdownButton<int>(
                      value: seasons.contains(season) ? season : seasons.first,
                      underline: const SizedBox(),
                      dropdownColor: SabuflixTheme.elevated,
                      items: [
                        for (final s in seasons)
                          DropdownMenuItem(
                              value: s, child: Text('Temporada $s')),
                      ],
                      onChanged: (value) {
                        if (value != null) onSeason(value);
                      },
                    ),
                ],
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : episodes.isEmpty
                      ? const Center(
                          child: _Hint('Nenhum episódio nesta temporada.'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                          itemCount: episodes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final ep = episodes[index] as Map;
                            final number =
                                (ep['episode_number'] as num?)?.toInt() ??
                                    index + 1;
                            final name =
                                ep['name']?.toString() ?? 'Episódio $number';
                            final still = ep['still_path'];
                            final image = still != null
                                ? 'https://image.tmdb.org/t/p/w300$still'
                                : fallbackImage;
                            final current = number == currentEpisode;
                            final watched = isWatched(number);
                            return Material(
                              color: current
                                  ? SabuflixTheme.accent.withValues(alpha: .14)
                                  : const Color(0xFF222529),
                              borderRadius: SabuflixTheme.radiusMd,
                              child: InkWell(
                                borderRadius: SabuflixTheme.radiusMd,
                                onTap: current
                                    ? null
                                    : () => onEpisode(number, name),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: SabuflixTheme.radiusSm,
                                        child: SizedBox(
                                          width: 112,
                                          height: 63,
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              CachedNetworkImage(
                                                imageUrl: image,
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) =>
                                                    const ColoredBox(
                                                        color: SabuflixTheme
                                                            .surface),
                                              ),
                                              if (current)
                                                const Center(
                                                    child: Icon(
                                                        Icons.equalizer_rounded,
                                                        color: Colors.white)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('$number. $name',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: SabuflixTheme.title(
                                                    fontSize: 14,
                                                    color: current
                                                        ? SabuflixTheme
                                                            .accentHover
                                                        : SabuflixTheme
                                                            .textPrimary)),
                                            if (ep['runtime'] != null) ...[
                                              const SizedBox(height: 3),
                                              Text('${ep['runtime']} min',
                                                  style: SabuflixTheme.caption(
                                                      fontSize: 11)),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (watched)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 8),
                                          child: Icon(
                                              Icons.check_circle_rounded,
                                              size: 18,
                                              color: SabuflixTheme.success),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;
  const _Section(
      {required this.title,
      required this.icon,
      required this.children,
      this.trailing});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: SabuflixTheme.textSecondary),
            const SizedBox(width: 8),
            Expanded(
                child: Text(title, style: SabuflixTheme.title(fontSize: 16))),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }
}

class _RadioRow extends StatelessWidget {
  final String label;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;
  const _RadioRow(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.detail});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: SabuflixTheme.radiusSm),
      leading: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_off_rounded,
        color: selected ? SabuflixTheme.accent : SabuflixTheme.textMuted,
        size: 20,
      ),
      title: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: SabuflixTheme.body(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? SabuflixTheme.textPrimary
                  : SabuflixTheme.textSecondary)),
      trailing: detail == null
          ? null
          : Text(detail!, style: SabuflixTheme.caption(fontSize: 11)),
      onTap: onTap,
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(text, style: SabuflixTheme.body(fontSize: 13)),
      );
}
