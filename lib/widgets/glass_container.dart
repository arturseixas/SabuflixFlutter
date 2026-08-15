import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/sabuflix_theme.dart';

/// A restrained smoked-glass surface for floating chrome and dialogs.
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
    Key? key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
    this.blur = 32,
    this.fillOpacity = 0.4,
    this.padding,
    this.boxShadow,
    this.border,
    this.gradient,
    this.hasGlow = false,
    this.glowColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveShadows = boxShadow ??
        [
          BoxShadow(
            color: const Color(0xFF070708).withValues(alpha: 0.42),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          if (hasGlow)
            BoxShadow(
              color:
                  (glowColor ?? SabuflixTheme.accent).withValues(alpha: 0.12),
              blurRadius: 16,
            ),
        ];

    final effectiveGradient = gradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SabuflixTheme.elevated
                .withValues(alpha: (fillOpacity + 0.2).clamp(0.0, 1.0)),
            SabuflixTheme.surface
                .withValues(alpha: (fillOpacity + 0.1).clamp(0.0, 1.0)),
          ],
        );

    final effectiveBorder = border ??
        Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.7,
        );

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: effectiveShadows,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: effectiveGradient,
              borderRadius: borderRadius,
              border: effectiveBorder,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
