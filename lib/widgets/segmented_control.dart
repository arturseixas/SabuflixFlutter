import 'package:flutter/material.dart';
import '../theme/sabuflix_theme.dart';

/// A UIKit-style segmented control: a recessed track with a single light
/// "thumb" that slides between segments.
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
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: SabuflixTheme.radiusPill,
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
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: SabuflixTheme.radiusPill,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.16), width: 0.8),
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
                              fontWeight: i == selectedIndex ? FontWeight.w800 : FontWeight.w600,
                              color: i == selectedIndex ? SabuflixTheme.textPrimary : SabuflixTheme.textSecondary,
                            ),
                            child: Text(segments[i], maxLines: 1, overflow: TextOverflow.ellipsis),
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
