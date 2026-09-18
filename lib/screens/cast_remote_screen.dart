import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cast_provider.dart';
import '../services/cast/cast_device.dart';
import '../theme/sabuflix_theme.dart';
import '../utils/app_route.dart';
import '../widgets/glass_container.dart';
import 'cast_picker_sheet.dart';
import 'video_player_screen.dart';

/// Remote control for whatever the TV is playing: transport, seek and volume,
/// plus a way to pull playback back onto this device.
class CastRemoteScreen extends StatefulWidget {
  const CastRemoteScreen({super.key});

  @override
  State<CastRemoteScreen> createState() => _CastRemoteScreenState();
}

class _CastRemoteScreenState extends State<CastRemoteScreen> {
  double? _dragging;
  Timer? _volumeDebounce;
  double? _pendingVolume;

  @override
  void dispose() {
    _volumeDebounce?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on CastException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _setVolume(double value) {
    setState(() => _pendingVolume = value);
    _volumeDebounce?.cancel();
    _volumeDebounce = Timer(const Duration(milliseconds: 250), () {
      _run(() => context.read<CastProvider>().setVolume(value)).then((_) {
        if (mounted) setState(() => _pendingVolume = null);
      });
    });
  }

  String _time(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  Future<void> _playHere(CastProvider cast) async {
    final playing = cast.nowPlaying;
    if (playing == null) return;
    final position = cast.status.position;
    await cast.stop();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      glassRoute(VideoPlayerScreen(
        media: playing.media,
        videoUrl: playing.url,
        season: playing.season,
        episode: playing.episode,
        episodeTitle: playing.episodeTitle,
        startAt: position,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: SabuflixTheme.themeData,
      child: Builder(builder: _build),
    );
  }

  Widget _build(BuildContext context) {
    final colors = SabuflixTheme.of(context);
    final cast = context.watch<CastProvider>();
    final device = cast.device;
    final playing = cast.nowPlaying;
    final status = cast.status;
    final duration = status.duration;
    final position = _dragging != null
        ? Duration(milliseconds: _dragging!.round())
        : status.position;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 700;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (playing?.media.fullBackdropPath.isNotEmpty ?? false)
            Opacity(
              opacity: .35,
              child: CachedNetworkImage(
                imageUrl: playing!.media.fullBackdropPath,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.background.withValues(alpha: .55),
                  colors.background.withValues(alpha: .92),
                  colors.background,
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Fechar',
                            onPressed: () => Navigator.maybePop(context),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                size: 30),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text('TRANSMITINDO PARA',
                                    style: colors.label(
                                        fontSize: 10, letterSpacing: 1.6)),
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.cast_connected_rounded,
                                        size: 16, color: colors.accent),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        device?.name ?? 'TV',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: colors.title(fontSize: 15),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Mais opções',
                            onSelected: (value) async {
                              switch (value) {
                                case 'switch':
                                  final chosen = await showCastPicker(context);
                                  if (chosen != null &&
                                      playing != null &&
                                      context.mounted) {
                                    await _run(() => cast.cast(
                                          media: playing.media,
                                          url: playing.url,
                                          season: playing.season,
                                          episode: playing.episode,
                                          episodeTitle: playing.episodeTitle,
                                          startAt: status.position,
                                        ));
                                  }
                                  break;
                                case 'disconnect':
                                  await cast.disconnect();
                                  if (context.mounted)
                                    Navigator.maybePop(context);
                                  break;
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                  value: 'switch', child: Text('Trocar de TV')),
                              PopupMenuItem(
                                  value: 'disconnect',
                                  child: Text('Desconectar')),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: playing == null
                          ? _Idle(colors: colors, device: device)
                          : SingleChildScrollView(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 16, 24, 24),
                              child: Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: SabuflixTheme.radiusLg,
                                    child: AspectRatio(
                                      aspectRatio: 16 / 9,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          CachedNetworkImage(
                                            imageUrl:
                                                playing.media.fullBackdropPath,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => ColoredBox(
                                                color: colors.surface),
                                            errorWidget: (_, __, ___) =>
                                                ColoredBox(
                                                    color: colors.surface),
                                          ),
                                          if (status.state ==
                                              CastPlayerState.buffering)
                                            const Center(
                                                child:
                                                    CircularProgressIndicator()),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  Text(playing.media.title,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: colors.headline(
                                          fontSize: wide ? 28 : 24)),
                                  const SizedBox(height: 6),
                                  Text(playing.subtitle,
                                      textAlign: TextAlign.center,
                                      style: colors.body(fontSize: 14)),
                                  if (cast.lastError != null) ...[
                                    const SizedBox(height: 16),
                                    GlassContainer(
                                      borderRadius: SabuflixTheme.radiusMd,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      child: Row(
                                        children: [
                                          Icon(Icons.error_outline_rounded,
                                              color: colors.error, size: 18),
                                          const SizedBox(width: 10),
                                          Expanded(
                                              child: Text(cast.lastError!,
                                                  style: colors.caption(
                                                      fontSize: 12))),
                                          IconButton(
                                            iconSize: 18,
                                            onPressed: cast.clearError,
                                            icon:
                                                const Icon(Icons.close_rounded),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 26),
                                  SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: 4,
                                      thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 7),
                                      activeTrackColor: colors.accent,
                                      inactiveTrackColor:
                                          Colors.white.withValues(alpha: .2),
                                      thumbColor: colors.accent,
                                    ),
                                    child: Slider(
                                      value: duration.inMilliseconds > 0
                                          ? position.inMilliseconds
                                              .clamp(0, duration.inMilliseconds)
                                              .toDouble()
                                          : 0,
                                      max: duration.inMilliseconds > 0
                                          ? duration.inMilliseconds.toDouble()
                                          : 1,
                                      onChanged: duration.inMilliseconds > 0
                                          ? (value) =>
                                              setState(() => _dragging = value)
                                          : null,
                                      onChangeEnd: (value) {
                                        setState(() => _dragging = null);
                                        _run(() => cast.seek(Duration(
                                            milliseconds: value.round())));
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_time(position),
                                            style:
                                                colors.caption(fontSize: 12)),
                                        Text(
                                            duration > Duration.zero
                                                ? '-${_time(duration - position)}'
                                                : '--:--',
                                            style:
                                                colors.caption(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        iconSize: 36,
                                        tooltip: 'Voltar 10 segundos',
                                        onPressed: () => _run(() => cast.seekBy(
                                            const Duration(seconds: -10))),
                                        icon:
                                            const Icon(Icons.replay_10_rounded),
                                      ),
                                      const SizedBox(width: 22),
                                      Container(
                                        width: 74,
                                        height: 74,
                                        decoration: BoxDecoration(
                                          color: colors.accent,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: colors.accent
                                                  .withValues(alpha: .4),
                                              blurRadius: 22,
                                            ),
                                          ],
                                        ),
                                        child: IconButton(
                                          iconSize: 40,
                                          color: Colors.white,
                                          tooltip: status.isPlaying
                                              ? 'Pausar'
                                              : 'Reproduzir',
                                          onPressed: () =>
                                              _run(cast.togglePlayPause),
                                          icon: Icon(status.isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded),
                                        ),
                                      ),
                                      const SizedBox(width: 22),
                                      IconButton(
                                        iconSize: 36,
                                        tooltip: 'Avançar 10 segundos',
                                        onPressed: () => _run(() => cast.seekBy(
                                            const Duration(seconds: 10))),
                                        icon: const Icon(
                                            Icons.forward_10_rounded),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 26),
                                  Row(
                                    children: [
                                      IconButton(
                                        tooltip: status.muted
                                            ? 'Ativar som'
                                            : 'Silenciar',
                                        onPressed: () => _run(
                                            () => cast.setMuted(!status.muted)),
                                        icon: Icon(status.muted
                                            ? Icons.volume_off_rounded
                                            : status.volume < .01
                                                ? Icons.volume_mute_rounded
                                                : status.volume < .5
                                                    ? Icons.volume_down_rounded
                                                    : Icons.volume_up_rounded),
                                      ),
                                      Expanded(
                                        child: Slider(
                                          value:
                                              (_pendingVolume ?? status.volume)
                                                  .clamp(0.0, 1.0),
                                          onChanged: _setVolume,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 40,
                                        child: Text(
                                          '${((_pendingVolume ?? status.volume) * 100).round()}',
                                          textAlign: TextAlign.end,
                                          style: colors.caption(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 22),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => _playHere(cast),
                                        icon: const Icon(
                                            Icons.phonelink_rounded,
                                            size: 20),
                                        label: const Text('Assistir aqui'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          await _run(cast.stop);
                                          if (context.mounted)
                                            Navigator.maybePop(context);
                                        },
                                        icon: const Icon(Icons.stop_rounded,
                                            size: 20),
                                        label: const Text('Parar na TV'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Idle extends StatelessWidget {
  final SabuPalette colors;
  final CastDevice? device;
  const _Idle({required this.colors, required this.device});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tv_rounded, size: 56, color: colors.textMuted),
            const SizedBox(height: 18),
            Text(
              device == null
                  ? 'Nenhuma TV conectada'
                  : 'Pronto para transmitir',
              style: colors.title(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              device == null
                  ? 'Escolha uma TV para começar.'
                  : 'Abra um filme ou episódio e toque em Assistir: ele será reproduzido em ${device!.name}.',
              textAlign: TextAlign.center,
              style: colors.body(fontSize: 14),
            ),
            const SizedBox(height: 20),
            if (device == null)
              FilledButton.icon(
                onPressed: () => showCastPicker(context),
                icon: const Icon(Icons.cast_rounded),
                label: const Text('Escolher TV'),
              )
            else
              OutlinedButton(
                onPressed: () => Navigator.maybePop(context),
                child: const Text('Voltar ao catálogo'),
              ),
          ],
        ),
      ),
    );
  }
}
