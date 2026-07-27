// animated_hitaku.dart
// Runtime character extraction with premium depth filters (rim lighting, soft shadow, glow).

import 'package:flutter/material.dart';
import 'app_theme.dart';

class AnimatedHitaku extends StatefulWidget {
  /// Width of the character slot. Height is unconstrained (BoxFit.contain).
  final double size;

  const AnimatedHitaku({super.key, this.size = 190});

  @override
  State<AnimatedHitaku> createState() => _AnimatedHitakuState();
}

class _AnimatedHitakuState extends State<AnimatedHitaku>
    with TickerProviderStateMixin {
  late final AnimationController _floatCtrl;
  late final AnimationController _fadeCtrl;
  late final AnimationController _glowCtrl;

  late final Animation<double> _floatAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();

    // Smooth vertical float — 4s period, easeInOut
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    // One-shot fade-in on first appear
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    // Slow glow pulse
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _fadeCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.size;
    const assetPath = 'asset/Hitaku Hero Character.png';

    return FadeTransition(
      opacity: _fadeAnim,
      child: AnimatedBuilder(
        animation: Listenable.merge([_floatAnim, _glowAnim]),
        builder: (_, child) {
          final glow = _glowAnim.value;
          return Transform.translate(
            offset: Offset(0, _floatAnim.value),
            child: Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                // ── Glow aura — two layered radial blooms ──────────────────
                Positioned(
                  bottom: -20,
                  child: Container(
                    width: w * 1.05,
                    height: w * 0.40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFC084FC)
                              .withValues(alpha: 0.65 + glow * 0.25),
                          blurRadius: 80 + glow * 25,
                          spreadRadius: 20 + glow * 8,
                        ),
                        BoxShadow(
                          color: AppTheme.terracotta.withValues(alpha: 0.9)
                              .withValues(alpha: 0.30 + glow * 0.15),
                          blurRadius: 50 + glow * 14,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Soft drop shadow behind the character ──
                // Lightweight version of the old ImageFiltered+ColorFiltered
                // shadow — avoids BlendMode.srcIn combos that can silently
                // fail to render on Flutter Web.
                Positioned(
                  bottom: -6,
                  child: Opacity(
                    opacity: 0.35,
                    child: Transform.scale(
                      scale: 0.97,
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Colors.black,
                          BlendMode.srcATop,
                        ),
                        child: Image.asset(
                          assetPath,
                          width: w,
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Character artwork ───────────────────────────────────────
                Image.asset(
                  assetPath,
                  width: w,
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  // Fade frame in once decoded — avoids pop-in flash.
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                    if (wasSynchronouslyLoaded) return child;
                    return AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      child: child,
                    );
                  },
                  // If the asset is missing / fails to decode, show a
                  // themed silhouette placeholder instead of nothing —
                  // keeps layout intact and makes the issue visible.
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('[AnimatedHitaku] failed to load "$assetPath": $error');
                    return Container(
                      width: w,
                      height: w * 1.25,
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: w * 0.55,
                        height: w * 0.95,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(w * 0.06),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF6B21A8), Color(0xFF1E0A3C)],
                          ),
                        ),
                        child: Center(
                          child: Icon(Icons.person_rounded,
                              color: AppTheme.surfaceRaised.withValues(alpha: 0.24), size: 64),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A pure-Flutter moon glow orb that can be composed behind AnimatedHitaku.
class HeroMoonGlow extends StatelessWidget {
  final double size;
  final double pulse; // 0.0–1.0 from external animation
  HeroMoonGlow({super.key, this.size = 180, this.pulse = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppTheme.surfaceRaised.withValues(alpha: 1.0), // brilliant bright core
            Color(0xFFD8B4FE).withValues(alpha: 0.85 + pulse * 0.10),
            AppTheme.sage.withValues(alpha: 0.50 + pulse * 0.10),
            Color(0xFF6B21C8).withValues(alpha: 0.20),
            Colors.transparent,
          ],
          stops: const [0.0, 0.20, 0.50, 0.75, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFC084FC).withValues(alpha: 0.55 + pulse * 0.20),
            blurRadius: size * 0.55,
            spreadRadius: size * 0.15,
          ),
        ],
      ),
    );
  }
}
