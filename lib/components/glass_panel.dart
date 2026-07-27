import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme/aniverse_theme.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? color;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.radius = AniVerseTheme.radiusLg,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color:
                color ?? AniVerseTheme.surfaceElevated.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: AniVerseTheme.softShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}
