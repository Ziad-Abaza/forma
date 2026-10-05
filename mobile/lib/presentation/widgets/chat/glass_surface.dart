import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class GlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final Color? fillColor;
  final Color? borderColor;

  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.blur = FormaTheme.glassBlur,
    this.fillColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final reduceTransparency = mediaQuery.accessibleNavigation || mediaQuery.highContrast;

    final br = borderRadius ?? BorderRadius.circular(FormaTheme.radiusCard);

    if (reduceTransparency) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: FormaTheme.glassFallback,
          borderRadius: br,
          border: Border.all(color: borderColor ?? FormaTheme.glassBorder),
        ),
        child: child,
      );
    }

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: fillColor ?? FormaTheme.glassFill,
              borderRadius: br,
              border: Border.all(color: borderColor ?? FormaTheme.glassBorder),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
