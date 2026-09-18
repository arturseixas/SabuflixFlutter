import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/cast_member.dart';
import '../../models/media_details.dart';
import '../../theme/sabuflix_theme.dart';

/// Vertical icon + label action, the row under the play button.
class DetailAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final Color? activeColor;
  final Widget? child;

  const DetailAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = SabuflixTheme.of(context);
    final color = onTap == null
        ? colors.textMuted
        : active
            ? (activeColor ?? colors.accent)
            : colors.textPrimary;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: SabuflixTheme.radiusMd,
        child: SizedBox(
          width: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                child ?? Icon(icon, color: color, size: 26),
                const SizedBox(height: 6),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: colors.caption(fontSize: 11, color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small bordered chip used in the meta row (age rating, HD, status…).
class MetaChip extends StatelessWidget {
  final String text;
  final Color? color;
  final bool filled;
  const MetaChip(this.text, {super.key, this.color, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final colors = SabuflixTheme.of(context);
    final tint = color ?? colors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? tint : Colors.transparent,
        border: Border.all(color: filled ? tint : colors.borderStrong),
        borderRadius: SabuflixTheme.radiusSm,
      ),
      child: Text(text,
          style: colors.label(
              fontSize: 10.5,
              color: filled ? Colors.white : tint,
              letterSpacing: .3)),
    );
  }
}

/// Section title used throughout the details page.
class DetailSectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const DetailSectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
              child: Text(text,
                  style: SabuflixTheme.of(context).title(fontSize: 19))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Synopsis with "mais / menos" toggle.
class ExpandableOverview extends StatefulWidget {
  final String text;
  final int collapsedLines;
  const ExpandableOverview(
      {super.key, required this.text, this.collapsedLines = 4});

  @override
  State<ExpandableOverview> createState() => _ExpandableOverviewState();
}

class _ExpandableOverviewState extends State<ExpandableOverview> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = SabuflixTheme.of(context);
    final style = colors.body(fontSize: 15, height: 1.6);
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        maxLines: widget.collapsedLines,
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final overflows = painter.didExceedMaxLines;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            style: style,
            maxLines: _expanded ? null : widget.collapsedLines,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          if (overflows)
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text(_expanded ? 'Mostrar menos' : 'Ler mais'),
            ),
        ],
      );
    });
  }
}

/// `Direção  Nome, Nome` style key/value line.
class InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const InfoLine({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = SabuflixTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
              text: '$label  ',
              style: colors.caption(fontSize: 13, color: colors.textMuted)),
          TextSpan(
              text: value,
              style: colors.caption(fontSize: 13, color: colors.textSecondary)),
        ]),
      ),
    );
  }
}

/// Circular cast avatars.
class CastRow extends StatelessWidget {
  final List<CastMember> cast;
  const CastRow({super.key, required this.cast});

  @override
  Widget build(BuildContext context) {
    final colors = SabuflixTheme.of(context);
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cast.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final actor = cast[index];
          return SizedBox(
            width: 92,
            child: Column(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.border),
                  ),
                  child: ClipOval(
                    child: actor.profilePath == null
                        ? ColoredBox(
                            color: colors.surfaceLight,
                            child: Icon(Icons.person,
                                color: colors.textMuted, size: 34))
                        : CachedNetworkImage(
                            imageUrl: actor.fullProfilePath,
                            fit: BoxFit.cover,
                            memCacheWidth: 200,
                            errorWidget: (_, __, ___) => ColoredBox(
                                color: colors.surfaceLight,
                                child: Icon(Icons.person,
                                    color: colors.textMuted)),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(actor.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: colors.caption(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary)),
                if (actor.character.isNotEmpty)
                  Text(actor.character,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: colors.caption(
                          fontSize: 10.5, color: colors.textMuted)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Streaming services that carry the title in Brazil.
class WatchProvidersRow extends StatelessWidget {
  final List<WatchProvider> providers;
  final VoidCallback? onOpen;
  const WatchProvidersRow({super.key, required this.providers, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final colors = SabuflixTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final provider in providers.take(10))
              Tooltip(
                message: '${provider.name} · ${provider.kindLabel}',
                child: InkWell(
                  onTap: onOpen,
                  borderRadius: SabuflixTheme.radiusMd,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: SabuflixTheme.radiusMd,
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: provider.fullLogoPath == null
                              ? ColoredBox(
                                  color: colors.surfaceLight,
                                  child: Icon(Icons.tv_rounded,
                                      color: colors.textMuted))
                              : CachedNetworkImage(
                                  imageUrl: provider.fullLogoPath!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      ColoredBox(color: colors.surfaceLight)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(provider.kindLabel,
                          style: colors.caption(
                              fontSize: 9.5, color: colors.textMuted)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Disponibilidade no Brasil · dados JustWatch via TMDB',
            style: colors.caption(fontSize: 10.5, color: colors.textMuted)),
      ],
    );
  }
}

/// One episode in the vertical season list.
class EpisodeTile extends StatelessWidget {
  final int number;
  final String name;
  final String? overview;
  final int? runtime;
  final String? airDate;
  final String imageUrl;
  final double progress;
  final bool watched;
  final bool current;
  final bool unreleased;
  final VoidCallback? onPlay;
  final VoidCallback? onToggleWatched;
  final Widget? downloadBadge;

  const EpisodeTile({
    super.key,
    required this.number,
    required this.name,
    required this.imageUrl,
    required this.onPlay,
    this.overview,
    this.runtime,
    this.airDate,
    this.progress = 0,
    this.watched = false,
    this.current = false,
    this.unreleased = false,
    this.onToggleWatched,
    this.downloadBadge,
  });

  @override
  Widget build(BuildContext context) {
    final colors = SabuflixTheme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 520;
    final meta = <String>[
      if (runtime != null && runtime! > 0) '$runtime min',
      if (airDate != null && airDate!.length >= 10) _formatDate(airDate!),
      if (unreleased) 'Em breve',
    ];
    return Material(
      color: current ? colors.accent.withValues(alpha: .1) : Colors.transparent,
      borderRadius: SabuflixTheme.radiusMd,
      child: InkWell(
        onTap: onPlay,
        borderRadius: SabuflixTheme.radiusMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: compact ? 128 : 168,
                child: ClipRRect(
                  borderRadius: SabuflixTheme.radiusMd,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 400,
                          placeholder: (_, __) =>
                              ColoredBox(color: colors.surface),
                          errorWidget: (_, __, ___) =>
                              ColoredBox(color: colors.surface),
                        ),
                        if (watched)
                          const DecoratedBox(
                              decoration: BoxDecoration(color: Colors.black38)),
                        Center(
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .55),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: .4)),
                            ),
                            child: Icon(
                                unreleased
                                    ? Icons.schedule_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 22),
                          ),
                        ),
                        if (progress > 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 3,
                              backgroundColor:
                                  Colors.white.withValues(alpha: .25),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(colors.accent),
                            ),
                          ),
                        if (downloadBadge != null)
                          Positioned(right: 6, top: 6, child: downloadBadge!),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '$number. $name',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: colors.title(
                                fontSize: 14,
                                color: watched
                                    ? colors.textSecondary
                                    : colors.textPrimary),
                          ),
                        ),
                        if (onToggleWatched != null)
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 20,
                              tooltip: watched
                                  ? 'Marcar como não assistido'
                                  : 'Marcar como assistido',
                              onPressed: onToggleWatched,
                              icon: Icon(
                                watched
                                    ? Icons.check_circle_rounded
                                    : Icons.check_circle_outline_rounded,
                                color:
                                    watched ? colors.success : colors.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(meta.join(' · '),
                          style: colors.caption(
                              fontSize: 11.5, color: colors.textMuted)),
                    ],
                    if (!compact &&
                        overview != null &&
                        overview!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(overview!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: colors.caption(
                              fontSize: 12.5, color: colors.textSecondary)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(String iso) {
    final parts = iso.split('-');
    if (parts.length < 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }
}
