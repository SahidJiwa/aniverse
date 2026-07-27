// widgets/liquid_glass.dart — AniVerse shared Liquid Glass components
//
// Single source of truth for the iOS-26-style frosted glass treatment used
// across AniVerse screens. Ported from jadwal_screen.dart (the original
// source, per ANIVERSE_LIQUID_GLASS_SPEC.md) — do not re-derive or restyle
// per-screen; import LiquidGlassPill/GradientBoxBorder here instead so
// every screen stays visually consistent and bug fixes only need to
// happen in one place.
//
// See ANIVERSE_LIQUID_GLASS_SPEC.md for the full parameter table, visual
// recipe, and the anti-bug checklist (explicit height on multi-state
// widgets, etc) — read that before wiring this into a new screen.

import 'dart:ui';

import 'package:flutter/material.dart';

// ─── LIQUID GLASS PILL ──────────────────────────────────────────────────────
// Reusable iOS-26-style frosted glass pill. Background shows through faintly
// (low blur + low-alpha radial gradient) rather than being fully obscured —
// that's what reads as "glass" instead of a solid tinted box.
//
// NOTE: renamed from the private `_LiquidGlassPill` (jadwal_screen.dart) to
// the public `LiquidGlassPill` so it's importable across files. The content
// Padding is kept as a NON-positioned Stack child (not Positioned.fill) so
// the Stack can size itself from its own content when `height` is null —
// wrapping it in Positioned.fill previously caused
// "A Stack requires bounded constraints" crashes (rendering/stack.dart:666,
// size.isFinite) at every one of the ~17 call sites in home_screen.dart
// that don't pass an explicit height (most are plain Row/Column children,
// which hand down unbounded height). When height IS null, the whole pill
// is also wrapped in IntrinsicHeight as a second layer of protection.
class LiquidGlassPill extends StatelessWidget {
  const LiquidGlassPill({
    super.key,
    required this.child,
    this.borderRadius = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.height,
    this.alignment,
    this.compact = false,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double? height;
  final AlignmentGeometry? alignment;
  // Set true for small tag/pill-style badges — they get less blur (a large
  // blur radius on a tiny box washes out all detail instead of reading as
  // glass) and a slightly stronger fill/border for per-pixel contrast.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Blur/fill values are the app-wide baseline (see
    // ANIVERSE_LIQUID_GLASS_SPEC.md §3) — do not tune per-screen without
    // updating the spec, or screens drift out of sync again.
    final blurAmount = compact ? 5.0 : 8.0;
    final fillAlpha = compact ? 0.05 : 0.03;
    final radius = BorderRadius.circular(borderRadius);

    final Widget pill = Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: RadialGradient(
          center: const Alignment(-0.6, -0.8),
          radius: 1.4,
          colors: [
            Colors.white.withValues(alpha: fillAlpha + 0.05),
            Colors.white.withValues(alpha: fillAlpha),
          ],
        ),
        border: GradientBoxBorder(
          width: 1.0,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: compact ? 0.40 : 0.32),
              Colors.white.withValues(alpha: compact ? 0.08 : 0.05),
            ],
          ),
        ),
        boxShadow: compact
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // Top sheen: thin bright streak along the upper edge,
            // mimicking the specular highlight on curved glass.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: (height ?? 40) * 0.5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(borderRadius),
                    topRight: Radius.circular(borderRadius),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: compact ? 0.10 : 0.06),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Secondary inner refraction pass — soft offset highlight
            // so the surface reads as curved/thick glass.
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: const Alignment(0.7, 0.9),
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    heightFactor: 0.5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(
                              alpha: compact ? 0.05 : 0.035,
                            ),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Content is intentionally NOT wrapped in Positioned/
            // Positioned.fill: a Stack with only positioned children
            // has no way to size itself, and needs a bounded size from
            // its parent Container to satisfy Positioned.fill above.
            // When height is null (the common case — 17+ call sites in
            // home_screen.dart), the outer Container/Stack chain is
            // otherwise unbounded and crashes with "A Stack requires
            // bounded constraints" (rendering/stack.dart:666, size.isFinite).
            // Keeping this child non-positioned lets the Stack size
            // itself from its intrinsic content instead.
            Padding(
              padding: padding,
              child: Align(
                alignment: alignment ?? Alignment.centerLeft,
                widthFactor: 1.0,
                heightFactor: 1.0,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        // When no explicit height is given, IntrinsicHeight forces this
        // subtree to size from its content instead of relying on an
        // unbounded parent (e.g. a plain Row/Column child) to hand down a
        // finite height — which is what the crash above needs.
        child: height == null ? IntrinsicHeight(child: pill) : pill,
      ),
    );
  }
}

// ─── GRADIENT BOX BORDER ────────────────────────────────────────────────────
// BoxDecoration.border only accepts solid-color borders out of the box; this
// paints a gradient stroke around the same rounded-rect path so the liquid
// glass border can have the top-bright / bottom-dim falloff that sells the
// "refracting glass edge" look.
class GradientBoxBorder extends BoxBorder {
  const GradientBoxBorder({required this.gradient, this.width = 1.0});

  final Gradient gradient;
  final double width;

  @override
  BorderSide get top => BorderSide(width: width);
  @override
  BorderSide get bottom => BorderSide(width: width);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  BoxBorder scale(double t) =>
      GradientBoxBorder(gradient: gradient, width: width * t);

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    final rrect = (borderRadius ?? BorderRadius.zero).toRRect(rect);
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    canvas.drawRRect(rrect.deflate(width / 2), paint);
  }

  @override
  bool get isUniform => true;
}
