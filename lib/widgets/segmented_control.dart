import 'package:flutter/material.dart';
import '../theme/sabuflix_theme.dart';

/// Accessible rectangular filters using the same action language as the hero.
class SabuSegmentedControl extends StatelessWidget {
  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double height;

  const SabuSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
    this.height = 38,
  });

  @override
  Widget build(BuildContext context) {
    if (segments.length < 2) return SizedBox.shrink();

    final colors = SabuflixTheme.of(context);
    return Row(children: [
      for (var i = 0; i < segments.length; i++)
        Expanded(
            child: Padding(
          padding: EdgeInsets.only(right: i == segments.length - 1 ? 0 : 6),
          child: Semantics(
              selected: i == selectedIndex,
              child: OutlinedButton(
                onPressed: () => onChanged(i),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(48, height < 48 ? 48 : height),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                  backgroundColor: i == selectedIndex
                      ? SabuflixTheme.brandBlue
                      : colors.secondaryFill,
                  foregroundColor:
                      i == selectedIndex ? Colors.white : colors.textPrimary,
                  side: BorderSide(
                      color: i == selectedIndex
                          ? SabuflixTheme.brandBlue
                          : colors.borderStrong),
                ),
                child: Text(segments[i],
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              )),
        )),
    ]);
  }
}
