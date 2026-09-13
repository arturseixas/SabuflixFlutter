import 'package:flutter/material.dart';
import '../theme/sabuflix_theme.dart';

/// Opaque dark surfaces keep controls legible over any film.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double blur;
  final double fillOpacity;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? boxShadow;
  final Border? border;
  final Gradient? gradient;
  final bool hasGlow;
  final Color? glowColor;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
    this.blur = 32,
    this.fillOpacity = 0.4,
    this.padding,
    this.boxShadow,
    this.border,
    this.gradient,
    this.hasGlow = false,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = SabuflixTheme.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? colors.surface : null,
        gradient: gradient,
        borderRadius: borderRadius,
        border: border ?? Border.all(color: colors.border),
        boxShadow: boxShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
