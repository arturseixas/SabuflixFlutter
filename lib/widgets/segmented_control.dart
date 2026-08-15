import 'package:flutter/material.dart';
import '../theme/sabuflix_theme.dart';

/// Matte segmented control used for compact library filters.
class SabuSegmentedControl extends StatelessWidget {
  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double height;

  const SabuSegmentedControl({
    Key? key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
    this.height = 38,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (segments.length < 2) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth = constraints.maxWidth / segments.length;
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: SabuflixTheme.surfaceLight,
            borderRadius: SabuflixTheme.radiusMd,
            border: Border.all(color: SabuflixTheme.border),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: SabuflixTheme.durationFast,
                curve: SabuflixTheme.curveStandard,
                left: segmentWidth * selectedIndex,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: SabuflixTheme.accentSoft,
                    borderRadius: SabuflixTheme.radiusSm,
                    border: Border.all(
                        color: SabuflixTheme.accent.withValues(alpha: 0.4)),
                  ),
                ),
              ),
              Row(
                children: [
                  for (int i = 0; i < segments.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(i),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: SabuflixTheme.durationFast,
                            style: SabuflixTheme.caption(
                              fontSize: 13,
                              fontWeight: i == selectedIndex
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: i == selectedIndex
                                  ? SabuflixTheme.accentHover
                                  : SabuflixTheme.textSecondary,
                            ),
                            child: Text(segments[i],
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
