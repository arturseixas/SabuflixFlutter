import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../services/playback_resolver.dart';
import '../../theme/sabuflix_theme.dart';

/// Lets the viewer choose a source. Sources are ranked by their quality and
/// audio preferences, with the recommended one on top.
///
/// Resolves with the chosen stream map, or `null` when dismissed.
Future<Map<String, dynamic>?> showStreamSelector(
  BuildContext context, {
  required Future<List<Map<String, dynamic>>> sources,
  required String title,
  String? subtitle,
  bool forDownload = false,
  String? castTargetName,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: SabuflixTheme.of(context).surface,
    showDragHandle: true,
    builder: (_) => _StreamSelectorSheet(
      sources: sources,
      title: title,
      subtitle: subtitle,
      forDownload: forDownload,
      castTargetName: castTargetName,
    ),
  );
}

class _StreamSelectorSheet extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> sources;
  final String title;
  final String? subtitle;
  final bool forDownload;
  final String? castTargetName;

  const _StreamSelectorSheet({
    required this.sources,
    required this.title,
    required this.subtitle,
    required this.forDownload,
    required this.castTargetName,
  });

  @override
  Widget build(BuildContext context) {
    final colors = SabuflixTheme.of(context);
    final settings = context.watch<SettingsProvider>();
    final heading = forDownload
        ? 'Escolha a qualidade do download'
        : castTargetName != null
            ? 'Assistir em $castTargetName'
            : 'Escolha como assistir';

    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .78),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: sources,
            builder: (context, snapshot) {
              final streams = snapshot.data == null
                  ? const <Map<String, dynamic>>[]
                  : PlaybackResolver.sort(snapshot.data!,
                      quality: settings.preferredQuality,
                      audio: settings.preferredAudio);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (castTargetName != null) ...[
                        Icon(Icons.cast_connected_rounded,
                            color: colors.accent, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                          child:
                              Text(heading, style: colors.title(fontSize: 20))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      title,
                      if (subtitle != null && subtitle!.isNotEmpty) subtitle!
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: colors.caption(fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: colors.accent),
                          const SizedBox(height: 16),
                          Text('Procurando fontes em todos os servidores…',
                              style: colors.body(fontSize: 13)),
                        ],
                      ),
                    )
                  else if (snapshot.hasError || streams.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Column(
                        children: [
                          Icon(Icons.cloud_off_rounded,
                              size: 40, color: colors.textMuted),
                          const SizedBox(height: 12),
                          Text('Nenhuma fonte encontrada',
                              style: colors.title(fontSize: 16)),
                          const SizedBox(height: 6),
                          Text(
                            'Os servidores ainda não têm este título. Tente novamente mais tarde.',
                            textAlign: TextAlign.center,
                            style: colors.body(fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: streams.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final stream = streams[index];
                          final recommended = index == 0;
                          final quality =
                              stream['displayQuality']?.toString() ??
                                  'Qualidade automática';
                          final dubbed = PlaybackResolver.isDubbed(stream);
                          final subtitled =
                              PlaybackResolver.isSubtitled(stream);
                          return Material(
                            color: recommended
                                ? colors.accent.withValues(alpha: .12)
                                : colors.secondaryFill,
                            borderRadius: SabuflixTheme.radiusMd,
                            child: InkWell(
                              borderRadius: SabuflixTheme.radiusMd,
                              onTap: () => Navigator.pop(context, stream),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: colors.accent
                                            .withValues(alpha: .16),
                                        borderRadius: SabuflixTheme.radiusSm,
                                      ),
                                      child: Text(
                                        _shortQuality(quality),
                                        style: colors.label(
                                            fontSize: 12,
                                            color: colors.accent,
                                            letterSpacing: 0),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  stream['displayName']
                                                          ?.toString() ??
                                                      'Sabuflix',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: colors.title(
                                                      fontSize: 15),
                                                ),
                                              ),
                                              if (recommended) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: colors.accent,
                                                    borderRadius:
                                                        SabuflixTheme.radiusSm,
                                                  ),
                                                  child: Text('RECOMENDADA',
                                                      style: colors.label(
                                                          fontSize: 9,
                                                          color: Colors.white,
                                                          letterSpacing: .8)),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              _Tag(quality),
                                              if (dubbed) const _Tag('Dublado'),
                                              if (subtitled)
                                                const _Tag('Legendado'),
                                              if (!dubbed && !subtitled)
                                                _Tag(
                                                    stream['displayDescription']
                                                            ?.toString()
                                                            .split('•')
                                                            .last
                                                            .trim() ??
                                                        ''),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      forDownload
                                          ? Icons.download_rounded
                                          : castTargetName != null
                                              ? Icons.cast_rounded
                                              : Icons.play_arrow_rounded,
                                      color: colors.textSecondary,
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
              );
            },
          ),
        ),
      ),
    );
  }

  static String _shortQuality(String quality) {
    final upper = quality.toUpperCase();
    if (upper.contains('4K') || upper.contains('2160')) return '4K';
    if (upper.contains('1080')) return 'FHD';
    if (upper.contains('720')) return 'HD';
    if (upper.contains('480') || upper.contains('SD')) return 'SD';
    if (upper.contains('CAM')) return 'CAM';
    return 'AUTO';
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    final colors = SabuflixTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: SabuflixTheme.radiusSm,
      ),
      child: Text(text, style: colors.caption(fontSize: 11)),
    );
  }
}
