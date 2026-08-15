import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/sabuflix_theme.dart';

/// A frosted "Liquid Glass" panel: real backdrop blur, multi-stop translucent fill,
/// specular edge highlights, and dynamic ambient reflections.
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
    final effectiveShadows = boxShadow ?? [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.45),
        blurRadius: 28,
        offset: const Offset(0, 10),
      ),
      if (hasGlow)
        BoxShadow(
          color: (glowColor ?? SabuflixTheme.accent).withValues(alpha: 0.35),
          blurRadius: 22,
          spreadRadius: 1,
        ),
    ];

    final effectiveGradient = gradient ?? LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: (fillOpacity + 0.14).clamp(0.0, 1.0)),
        SabuflixTheme.surface.withValues(alpha: fillOpacity),
        Colors.white.withValues(alpha: (fillOpacity * 0.35).clamp(0.0, 1.0)),
      ],
      stops: const [0.0, 0.45, 1.0],
    );

    final effectiveBorder = border ?? Border.all(
      color: Colors.white.withValues(alpha: 0.22),
      width: 0.8,
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
