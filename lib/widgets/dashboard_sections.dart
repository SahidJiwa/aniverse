import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../premium_pass_screen.dart';

void _openPremiumPass(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const PremiumPassScreen()),
  );
}

// ─── ANIME FIELD HELPERS ──────────────────────────────────────────────────────
// Defensive accessors for AnimeModel. Field names can vary slightly across
// API integrations (Jikan/AniList/mock data), so these try several common
// names before falling back, keeping screens resilient to schema drift
// instead of crashing on a missing getter.
String titleOfAnime(dynamic a) {
  try {
    final t = a.title;
    if (t is String && t.isNotEmpty) return t;
  } catch (_) {}
  try {
    final t = a.name;
    if (t is String && t.isNotEmpty) return t;
  } catch (_) {}
  return a.toString();
}

double ratingOfAnime(dynamic a) {
  try {
    final r = a.rating;
    if (r is num) return r.toDouble();
  } catch (_) {}
  return 0;
}

String? coverOfAnime(dynamic a) {
  try {
    final v = a.coverUrl;
    if (v is String && v.isNotEmpty) return v;
  } catch (_) {}
  try {
    final v = a.imageUrl;
    if (v is String && v.isNotEmpty) return v;
  } catch (_) {}
  try {
    final v = a.coverImage;
    if (v is String && v.isNotEmpty) return v;
  } catch (_) {}
  try {
    final v = a.image;
    if (v is String && v.isNotEmpty) return v;
  } catch (_) {}
  try {
    final v = a.posterUrl;
    if (v is String && v.isNotEmpty) return v;
  } catch (_) {}
  return null;
}

// ─── FADE SLIDE IN ────────────────────────────────────────────────────────────
// Wraps a section so it fades + slides up into place once on first build,
// with an optional delay to create a staggered cascade effect as sections
// are laid out down the page (each one a little later than the last).
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 520),
    this.offsetY = 24,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: Offset(0, widget.offsetY / 100), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Opacity(
          opacity: _fade.value,
          child: FractionalTranslation(
            translation: _slide.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}
// Wraps a progress fill (0.0–1.0) so it animates from 0 to its target value
// on first build, giving every progress bar in the dashboard a satisfying
// "filling up" entrance instead of popping in at full width instantly.
class AnimatedProgressBar extends StatefulWidget {
  final double value;
  final Color color;
  final Color backgroundColor;
  final double height;
  final BorderRadius? borderRadius;
  final Gradient? gradient;
  final Duration duration;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.color = const Color(0xFF9D4EDD),
    this.backgroundColor = const Color(0x1AFFFFFF),
    this.height = 6,
    this.borderRadius,
    this.gradient,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = Tween<double>(begin: 0, end: widget.value.clamp(0.0, 1.0))
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    // Small delay so it visibly fills after the card itself has appeared
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void didUpdateWidget(AnimatedProgressBar old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _anim = Tween<double>(begin: _anim.value, end: widget.value.clamp(0.0, 1.0))
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(widget.height / 2);
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        height: widget.height,
        color: widget.backgroundColor,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            return FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _anim.value,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.gradient == null ? widget.color : null,
                  gradient: widget.gradient,
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(color: widget.color.withValues(alpha: 0.5), blurRadius: 6),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
// ─── PRESS SCALE ──────────────────────────────────────────────────────────────
// Reusable tactile wrapper for tap targets. Scales the child down slightly
// on press-down, springing back on release, to give buttons a more
// "physical" / premium feel than a flat InkWell ripple alone.
class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _PressScale({
    required this.child,
    this.onTap,
  });

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// Skeleton shimmer effect for content that's still loading (e.g. network
// images while Jikan/AniList fetch resolves). Sweeps a soft diagonal
// highlight across a base color repeatedly.
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color baseColor;
  final Color highlightColor;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.baseColor = const Color(0xFF1A1330),
    this.highlightColor = const Color(0xFF2D1F4D),
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1.0 + _ctrl.value * 3, -0.3),
              end: Alignment(0.0 + _ctrl.value * 3, 0.3),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}
// Counts up from 0 to a target numeric value, preserving any non-numeric
// formatting (e.g. "1.248", "248h", "12.4M") by extracting the leading
// number and animating only that part, then re-appending suffix/prefix.
class AnimatedCounter extends StatefulWidget {
  final String value;
  final TextStyle? style;
  final Duration duration;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 1100),
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  // Parsed pieces of the target value string
  String _prefix = '';
  double _targetNumber = 0;
  int _decimals = 0;
  String _suffix = '';
  String _thousandSep = '';

  @override
  void initState() {
    super.initState();
    _parseValue(widget.value);
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  void _parseValue(String raw) {
    // Match an optional prefix, a number (with . or , as thousand/decimal sep), and a suffix
    final match = RegExp(r'^([^\d]*)([\d.,]+)(.*)$').firstMatch(raw);
    if (match == null) {
      _prefix = '';
      _targetNumber = 0;
      _suffix = raw;
      return;
    }
    _prefix = match.group(1) ?? '';
    final numPart = match.group(2) ?? '0';
    _suffix = match.group(3) ?? '';

    // Heuristic: if there's a single '.' followed by 1-2 digits and no other dots,
    // treat as decimal point (e.g. "12.4"). If multiple groups of 3 digits
    // separated by '.', treat as thousand separator (e.g. "1.248").
    final dotParts = numPart.split('.');
    if (dotParts.length == 2 && dotParts[1].length <= 2 && dotParts[0].length <= 3) {
      _targetNumber = double.tryParse(numPart) ?? 0;
      _decimals = dotParts[1].length;
      _thousandSep = '';
    } else {
      _thousandSep = '.';
      final cleaned = numPart.replaceAll('.', '').replaceAll(',', '');
      _targetNumber = double.tryParse(cleaned) ?? 0;
      _decimals = 0;
    }
  }

  String _format(double v) {
    if (_decimals > 0) {
      return '$_prefix${v.toStringAsFixed(_decimals)}$_suffix';
    }
    final intVal = v.round();
    if (_thousandSep.isEmpty || intVal < 1000) {
      return '$_prefix$intVal$_suffix';
    }
    // Insert thousand separators
    final s = intVal.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(_thousandSep);
      buffer.write(s[i]);
    }
    return '$_prefix$buffer$_suffix';
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final current = _targetNumber * _anim.value;
        return Text(_format(current), style: widget.style);
      },
    );
  }
}
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        const dotColor = Color(0xFFEF4444);
        const dotSize = 10.0;
        return SizedBox(
          width: dotSize * 2.2,
          height: dotSize * 2.2,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Expanding ring
              Opacity(
                opacity: (1 - t).clamp(0.0, 1.0),
                child: Container(
                  width: dotSize + (dotSize * 1.2 * t),
                  height: dotSize + (dotSize * 1.2 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: dotColor, width: 1.2),
                  ),
                ),
              ),
              // Solid core dot
              Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: dotColor.withValues(alpha: 0.7), blurRadius: 4),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
// Reusable wrapper that gives any widget a satisfying tap-down scale + opacity
// feedback, used throughout the dashboard for buttons, cards, and headers.
class _TappableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _TappableScale({
    required this.child,
    this.onTap,
  });

  @override
  State<_TappableScale> createState() => _TappableScaleState();
}

class _TappableScaleState extends State<_TappableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.75 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}

// ─── CARD WRAPPER ──────────────────────────────────────────────────────────────
// Simple, clean white card. Liquid Glass is only used in specific cards
// (Daily Mission, Continue Watching, Anime Room Live) — NOT everywhere.
class DashboardCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const DashboardCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFE8D5F5).withValues(alpha: 0.80),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.10),
            blurRadius: 24,
            spreadRadius: -2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFFEC4899).withValues(alpha: 0.04),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(14),
          child: child,
        ),
      ),
    );
  }
}

// ─── SECTION HEADER ──────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? prefixWidget;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.prefixWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Accent bar — small glowing pink/purple gradient pill before title
              Container(
                width: 3,
                height: 12,
                margin: const EdgeInsets.only(right: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.sakuraPink, Color(0xFF9D4EDD)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.sakuraPink.withValues(alpha: 0.55),
                      blurRadius: 6,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
              ),
              if (prefixWidget != null) ...[
                prefixWidget!,
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  title.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xFF2C2543),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null)
          _TappableScale(
            onTap: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // FIX: Flexible prevents action label from overflowing narrow columns
                Flexible(
                  child: Text(
                    actionLabel!,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Color(0xFF7C7299),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFF7C7299),
                  size: 8,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── 1. UNIVERSE HIGHLIGHT ───────────────────────────────────────────────────
class PremiumPortalStrip extends StatelessWidget {
  const PremiumPortalStrip({super.key});

  static const _items = [
    _PortalItem(
      icon: Icons.auto_awesome_rounded,
      title: 'Mood Match',
      subtitle: 'Cari anime sesuai vibe',
      color: Color(0xFF06B6D4),
    ),
    _PortalItem(
      icon: Icons.groups_2_rounded,
      title: 'Watch Party',
      subtitle: '12 room aktif',
      color: Color(0xFF7C3AED),
    ),
    _PortalItem(
      icon: Icons.diamond_rounded,
      title: 'Daily Drop',
      subtitle: 'Reward siap klaim',
      color: Color(0xFFE25B9A),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 106,
      child: Row(
        children: [
          for (int i = 0; i < _items.length; i++) ...[
            Expanded(child: _PortalTile(item: _items[i])),
            if (i != _items.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _PortalItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _PortalItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}

class _PortalTile extends StatelessWidget {
  final _PortalItem item;

  const _PortalTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onTap: () => _openPremiumPass(context),
      child: Container(
        height: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
          boxShadow: [
            BoxShadow(
              color: item.color.withValues(alpha: 0.10),
              blurRadius: 20,
              spreadRadius: -6,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -12,
              top: -14,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.color.withValues(alpha: 0.10),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        item.color.withValues(alpha: 0.96),
                        item.color.withValues(alpha: 0.62),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: item.color.withValues(alpha: 0.26),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(item.icon, size: 16, color: Colors.white),
                ),
                const Spacer(),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF2C2543),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF7C7299),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    height: 1.18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class UniverseHighlightSection extends StatelessWidget {
  const UniverseHighlightSection({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // ── Background: Solo Leveling banner — network first, asset fallback ──
            Positioned.fill(
              child: Image.network(
                'https://s4.anilist.co/file/anilistcdn/media/anime/banner/166240-FLKBxUEKtxXl.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                loadingBuilder: (ctx, child, prog) => prog == null
                    ? child
                    : Image.asset('asset/Sakura Universe Background.png', fit: BoxFit.cover),
                errorBuilder: (_, __, ___) => Image.asset(
                  'asset/Sakura Universe Background.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),

            // ── Cinematic gradient scrim — heavier bottom ──
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.82),
                      Colors.black.withValues(alpha: 0.95),
                    ],
                    stops: const [0.0, 0.35, 0.70, 1.0],
                  ),
                ),
              ),
            ),

            // ── Purple cinematic tint ──
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      const Color(0xFF4C1D95).withValues(alpha: 0.40),
                      const Color(0xFF9D4EDD).withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),

            // ── Pink left edge glow ──
            Positioned(
              left: 0, top: 0, bottom: 0,
              width: 3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppTheme.sakuraPink.withValues(alpha: 0.60),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── Content ──
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Header label
                    Row(
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            color: AppTheme.sakuraPink,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: AppTheme.sakuraPink.withValues(alpha: 0.6), blurRadius: 6, spreadRadius: 1)],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'UNIVERSE HIGHLIGHT',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.80),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // EPISODE BARU badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.sakuraPink.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.sakuraPink.withValues(alpha: 0.55), width: 0.8),
                      ),
                      child: const Text(
                        'EPISODE BARU',
                        style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Title — big & bold
                    const Text(
                      'SOLO LEVELING',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        height: 1.0,
                        shadows: [
                          Shadow(color: Color(0x88000000), blurRadius: 12, offset: Offset(0, 3)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'EP 13',
                      style: TextStyle(
                        color: AppTheme.sakuraPink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'The system awakens.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.60),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Avatars + viewers
                    Row(
                      children: [
                        ...List.generate(3, (i) => Align(
                          widthFactor: 0.72,
                          child: Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: [const Color(0xFF9D4EDD), const Color(0xFFFF4FA3), const Color(0xFF3B82F6)][i],
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Center(
                              child: Text(
                                ['S', 'A', 'K'][i],
                                style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        )),
                        const SizedBox(width: 14),
                        Text(
                          '+2.3K teman sudah menonton',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Tonton Sekarang — full width glowing button
                    _PressScale(
                      onTap: () {},
                      child: Container(
                        width: double.infinity,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.sakuraPink, Color(0xFFBF55EC)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.sakuraPink.withValues(alpha: 0.50),
                              blurRadius: 16,
                              spreadRadius: 1,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: AppTheme.sakuraPink.withValues(alpha: 0.20),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () {},
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Tonton Sekarang',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Pagination dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) => Container(
                        width: i == 0 ? 16 : 5,
                        height: 5,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: i == 0
                              ? AppTheme.sakuraPink
                              : Colors.white.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: i == 0 ? [
                            BoxShadow(color: AppTheme.sakuraPink.withValues(alpha: 0.6), blurRadius: 6, spreadRadius: 1),
                          ] : null,
                        ),
                      )),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 2. EVENT CARD (SAKURA FESTIVAL) ─────────────────────────────────────────
class EventCardSection extends StatelessWidget {
  const EventCardSection({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // ── Background image with pastel town ──
            Positioned.fill(
              child: Image.asset(
                'asset/images/home screen/Serene spring temple town in pastel.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) => Container(color: const Color(0xFFFDE8F3)),
              ),
            ),

            // ── Glassmorphic white overlay ──
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.80),
                      Colors.white.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
            ),

            // ── Left Column (Title, Badges, Stats, Rewards Track) ──
            Positioned(
              left: 16,
              top: 14,
              bottom: 14,
              right: 140, // Ensure space for Upgrade button on the right
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title & Pass Badge Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'SAKURA FESTIVAL',
                        style: TextStyle(
                          color: Color(0xFFE25B9A),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFFAB7FF7)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.star_rounded, color: Colors.white, size: 8),
                            SizedBox(width: 2),
                            Text(
                              'PREMIUM PASS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // Subtitle
                  const Text(
                    'Season 03 • 14 hari tersisa',
                    style: TextStyle(
                      color: Color(0xFF7C7299),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  // Stats Row
                  Row(
                    children: [
                      const Text(
                        '🔥 Reward baru besok',
                        style: TextStyle(
                          color: Color(0xFF2C2543),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: Color(0xFF7C7299),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        '🌸 28.431 member',
                        style: TextStyle(
                          color: Color(0xFF2C2543),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),

                  // Reward track row
                  Row(
                    children: [
                      _buildTrackCircle(
                        child: ClipOval(
                          child: Image.asset(
                            'asset/Hitaku Avatar Pack.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      _buildTrackLine(),
                      _buildTrackCircle(
                        child: const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                      ),
                      _buildTrackLine(),
                      _buildTrackCircle(
                        child: const Icon(Icons.card_membership_rounded, color: Color(0xFF7C3AED), size: 12),
                      ),
                      _buildTrackLine(),
                      _buildTrackCircle(
                        child: const Icon(Icons.diamond_rounded, color: Color(0xFFEC4899), size: 12),
                      ),
                      _buildTrackLine(),
                      _buildTrackCircle(
                        color: Colors.white.withValues(alpha: 0.8),
                        child: const Icon(Icons.chevron_right_rounded, color: Color(0xFF7C7299), size: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Right Upgrade Button ──
            Positioned(
              right: 16,
              bottom: 14,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE25B9A), Color(0xFFEC4899)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE25B9A).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openPremiumPass(context),
                    borderRadius: BorderRadius.circular(14),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Upgrade Pass',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(Icons.keyboard_double_arrow_right_rounded, color: Colors.white, size: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackCircle({required Widget child, Color? color}) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color ?? Colors.white.withValues(alpha: 0.65),
        border: Border.all(color: Colors.white, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
            blurRadius: 4,
          ),
        ],
      ),
      child: Center(child: child),
    );
  }

  Widget _buildTrackLine() {
    return Container(
      width: 8,
      height: 1.5,
      color: Colors.white.withValues(alpha: 0.9),
    );
  }
}



// ── Event Card fallback placeholder ──────────────────────────────────────────
// ignore: unused_element
class _EventCardPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2D0A4E),
            Color(0xFF1A0533),
            Color(0xFF0A0414),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Moon glow
          Positioned(
            top: -20, right: -20,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0xFFFF4FA3).withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Star dots
          Positioned.fill(
            child: CustomPaint(painter: _StarfieldPainter()),
          ),
        ],
      ),
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final rng = math.Random(99);
    for (int i = 0; i < 25; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = 0.5 + rng.nextDouble() * 1.2;
      paint.color = Colors.white.withValues(alpha: 0.15 + rng.nextDouble() * 0.35);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
    // Pink sakura dots
    final pink = Paint()..color = const Color(0xFFFF4FA3)..style = PaintingStyle.fill;
    for (int i = 0; i < 8; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height * 0.6;
      pink.color = const Color(0xFFFF4FA3).withValues(alpha: 0.12 + rng.nextDouble() * 0.18);
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 6, height: 3), pink);
    }
  }
  @override bool shouldRepaint(_StarfieldPainter o) => false;
}
// ─── 3. CONTINUE YOUR JOURNEY ───────────────────────────────────────────────
class ContinueYourJourneySection extends StatelessWidget {
  const ContinueYourJourneySection({super.key});

  // Other in-progress anime — shown only as small stacked thumbnails ("+N"),
  // never as full scrollable cards. Continue Watching has exactly one job:
  // get the user back into the one anime they're mid-episode on.
  static const _otherThumbs = [
    'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx108465-1ANspF1EWyFx.jpg',
    'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx113415-LHBAeoZDIsnF.jpg',
    'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx154587-qQTzQnEJJ3oB.jpg',
  ];
  static const _otherCount = 3;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Continue Watching', actionLabel: 'Lihat Semua'),
        const SizedBox(height: 12),

        // ── MAIN CARD: single anime, dominant ──
        _MainJourneyCard(
          title: 'Re:Zero',
          subtitle: 'Season 3 · Episode 12',
          timeLeft: '22m tersisa',
          progress: 0.75,
          imageUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx21355-wRVUrGxpvIQQ.jpg',
          onTap: () {},
        ),

        const SizedBox(height: 10),

        // ── "Other in-progress" indicator — small stacked thumbs, not a list ──
        Row(
          children: [
            SizedBox(
              // Explicit width = fixes Stack failing to resolve size when all
              // children are Positioned (no intrinsic-size child) — this was
              // causing a silent layout crash (RenderBox size: MISSING).
              width: (_otherThumbs.length * 18.0) + 28,
              height: 28,
              child: Stack(
                children: [
                  for (int i = 0; i < _otherThumbs.length; i++)
                    Positioned(
                      left: i * 18.0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          image: DecorationImage(
                            image: NetworkImage(_otherThumbs[i]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: _otherThumbs.length * 18.0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF8B5CF6),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '+$_otherCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                '$_otherCount lainnya sedang berjalan',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF7C7299), fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── MAIN JOURNEY CARD (Re:Zero full-width landscape) ────────────────────────
class _MainJourneyCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String timeLeft;
  final double progress;
  final String imageUrl;
  final VoidCallback onTap;

  const _MainJourneyCard({
    required this.title,
    required this.subtitle,
    required this.timeLeft,
    required this.progress,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  State<_MainJourneyCard> createState() => _MainJourneyCardState();
}

class _MainJourneyCardState extends State<_MainJourneyCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 184,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _isHovered
                  ? const Color(0xFFE25B9A).withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.35),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.04),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
              if (_isHovered)
                BoxShadow(
                  color: const Color(0xFFE25B9A).withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: Colors.white.withValues(alpha: 0.45),
                child: Stack(
                  children: [
                    // Background gradient fallback — always visible
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF3B0764), Color(0xFF1A0533), Color(0xFF0D0A20)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),

                    // Atmospheric glow on fallback
                    Positioned(
                      top: -20, right: -20,
                      child: Container(
                        width: 140, height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            const Color(0xFF9D4EDD).withValues(alpha: 0.35),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                    ),

                    // Network image — direct URL
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.88,
                        child: Image.network(
                          widget.imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) =>
                              progress == null ? child : const ShimmerBox(),
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),

                    // Dark gradient overlay bottom
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.05),
                              Colors.black.withValues(alpha: 0.35),
                              Colors.black.withValues(alpha: 0.88),
                            ],
                            stops: const [0.0, 0.40, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Progress bar bottom
                    Positioned(
                      left: 0, right: 0, bottom: 0,
                      height: 4,
                      child: AnimatedProgressBar(
                        value: widget.progress,
                        height: 4,
                        color: AppTheme.sakuraPink,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.zero,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9D4EDD), AppTheme.sakuraPink],
                        ),
                      ),
                    ),

                    // Content bottom left
                    Positioned(
                      left: 16, right: 16, bottom: 14,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // CONTINUE PLAYING badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  margin: const EdgeInsets.only(bottom: 7),
                                  decoration: BoxDecoration(
                                    color: AppTheme.sakuraPink.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: AppTheme.sakuraPink.withValues(alpha: 0.50)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 5, height: 5,
                                        decoration: const BoxDecoration(
                                          color: Colors.redAccent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      const Text(
                                        'CONTINUE PLAYING',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  widget.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.subtitle,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.65),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '${(widget.progress * 100).round()}% Completed',
                                      style: TextStyle(
                                        color: AppTheme.sakuraPink.withValues(alpha: 0.90),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '·  ${widget.timeLeft}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.45),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    // Friends watching avatars
                                    SizedBox(
                                      width: 38,
                                      height: 16,
                                      child: Stack(
                                        children: [
                                          for (int i = 0; i < 3; i++)
                                            Positioned(
                                              left: i * 10.0,
                                              child: Container(
                                                width: 14,
                                                height: 14,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: const Color(0xFF0D0A20), width: 1),
                                                  color: [
                                                    const Color(0xFFEC4899),
                                                    const Color(0xFF8B5CF6),
                                                    const Color(0xFF06B6D4),
                                                  ][i],
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    ['S', 'A', 'K'][i],
                                                    style: const TextStyle(fontSize: 5.5, color: Colors.white, fontWeight: FontWeight.w900),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '3 teman menonton',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.55),
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    // Next Episode preview badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.20),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.skip_next_rounded, color: Colors.white70, size: 10),
                                          const SizedBox(width: 3),
                                          Text(
                                            'Next: EP 13',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.90),
                                              fontSize: 8,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Play button
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isHovered ? AppTheme.sakuraPink : Colors.white.withValues(alpha: 0.20),
                              boxShadow: _isHovered
                                  ? [BoxShadow(color: AppTheme.sakuraPink.withValues(alpha: 0.5), blurRadius: 16, spreadRadius: 2)]
                                  : [],
                            ),
                            child: const Center(
                              child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── SMALL JOURNEY CARD (portrait, horizontal scroll) ────────────────────────
class _SmallJourneyCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final double progress;
  final String imageUrl;
  final VoidCallback onTap;

  const _SmallJourneyCard({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  State<_SmallJourneyCard> createState() => _SmallJourneyCardState();
}

class _SmallJourneyCardState extends State<_SmallJourneyCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  Color get _accentColor {
    final t = widget.title.toLowerCase();
    if (t.contains('mushoku')) return const Color(0xFF06B6D4);
    if (t.contains('jujutsu')) return const Color(0xFFEF4444);
    if (t.contains('frieren')) return const Color(0xFF4ADE80);
    if (t.contains('demon')) return const Color(0xFFFF6B35);
    return AppTheme.sakuraPink;
  }

  List<Color> get _gradientColors {
    final t = widget.title.toLowerCase();
    if (t.contains('mushoku')) return [const Color(0xFF0E7490), const Color(0xFF0D0520)];
    if (t.contains('jujutsu')) return [const Color(0xFF991B1B), const Color(0xFF0D0520)];
    if (t.contains('frieren')) return [const Color(0xFF166534), const Color(0xFF0D0520)];
    if (t.contains('demon')) return [const Color(0xFF9A3412), const Color(0xFF0D0520)];
    return [const Color(0xFF831843), const Color(0xFF0D0520)];
  }

  @override
  Widget build(BuildContext context) {
    final isDone = widget.progress >= 1.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : (_isHovered ? 1.03 : 1.0),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: Container(
            width: 95,
            margin: const EdgeInsets.only(right: 10, top: 2, bottom: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isHovered
                    ? _accentColor.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // LAYER 1: Per-anime gradient base (shows when image loading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _gradientColors,
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),

                // LAYER 2: Network image — full cover, no darkening
                Positioned.fill(
                  child: Image.network(
                    widget.imageUrl,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    loadingBuilder: (ctx, child, prog) =>
                        prog == null ? child : ShimmerBox(baseColor: _accentColor.withValues(alpha: 0.10), highlightColor: _accentColor.withValues(alpha: 0.30)),
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),

                // LAYER 3: Only bottom scrim for text readability
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  height: 70,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.92),
                          Colors.black.withValues(alpha: 0.55),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),

                // LAYER 4: Top micro-scrim for any badge
                Positioned(
                  left: 0, right: 0, top: 0,
                  height: 30,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // LAYER 5: Progress bar
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  height: 3,
                  child: AnimatedProgressBar(
                    value: widget.progress.clamp(0.0, 1.0),
                    height: 3,
                    color: isDone ? const Color(0xFF4ADE80) : _accentColor,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.zero,
                  ),
                ),

                // LAYER 6: Text content + accent glow border on hover
                Positioned(
                  left: 7, right: 7, bottom: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 5, height: 5,
                            decoration: BoxDecoration(
                              color: isDone ? const Color(0xFF4ADE80) : _accentColor,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: _accentColor.withValues(alpha: 0.8), blurRadius: 4, spreadRadius: 1)],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isDone ? 'COMPLETED' : '${(widget.progress * 100).round()}%',
                            style: TextStyle(
                              color: isDone ? const Color(0xFF4ADE80) : _accentColor,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // LAYER 7: Hover accent glow border
                if (_isHovered)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _accentColor.withValues(alpha: 0.80), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: _accentColor.withValues(alpha: 0.30), blurRadius: 12, spreadRadius: 2),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 4. ANIME ROOM LIVE ──────────────────────────────────────────────────────
class AnimeRoomLiveSection extends StatefulWidget {
  /// Per Luxury brief: Home shows at most this many rooms (Featured card
  /// counts as 1). Other pages (e.g. a future "Lihat Semua" room list) can
  /// still show all rooms by omitting this or passing a higher number.
  final int maxRooms;
  const AnimeRoomLiveSection({super.key, this.maxRooms = 4});

  @override
  State<AnimeRoomLiveSection> createState() => _AnimeRoomLiveSectionState();
}

class _AnimeRoomLiveSectionState extends State<AnimeRoomLiveSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section Header ──────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
              children: [
                const Flexible(
                  child: Text(
                  'ANIME ROOM LIVE',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: Color(0xFF2C2543),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                  ),
                ),
                const SizedBox(width: 8),
                // Animated live pill
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, _) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444)
                          .withValues(alpha: 0.10 + _pulseAnim.value * 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFEF4444)
                            .withValues(alpha: 0.30 + _pulseAnim.value * 0.20),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444)
                                .withValues(alpha: _pulseAnim.value),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444)
                                    .withValues(alpha: _pulseAnim.value * 0.6),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '4,291 LIVE',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: Row(
                children: const [
                  Text('Lihat Semua',
                      style: TextStyle(
                          color: Color(0xFF7C7299),
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF7C7299), size: 8),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Featured Room — Dominant Hero Card ─────────────────────────────
        _FeaturedRoomCard(pulseAnim: _pulseAnim),

        const SizedBox(height: 8),

        // ── Other Rooms — Compact Premium Cards (capped by maxRooms) ───────
        // Featured card above counts as 1 room toward maxRooms.
        if (widget.maxRooms > 1)
          _buildCompactRoom(
            title: 'Jujutsu Kaisen Room',
            discussing: 'Hidden Inventory Arc finale',
            current: 89,
            max: 150,
            tag: 'HYPE',
            tagColor: const Color(0xFF9D4EDD),
            avatarColors: const [Color(0xFFEC4899), Color(0xFF8B5CF6), Color(0xFF06B6D4)],
          ),
        if (widget.maxRooms > 2)
          _buildCompactRoom(
            title: 'One Piece Indonesia',
            discussing: 'Gear 5 Reaction & Lore Talk',
            current: 156,
            max: 300,
            tag: 'CHILL',
            tagColor: const Color(0xFF4ADE80),
            avatarColors: const [Color(0xFF4ADE80), Color(0xFF06B6D4), Color(0xFFF59E0B)],
          ),
        if (widget.maxRooms > 3)
          _buildCompactRoom(
            title: 'Demon Slayer Corps',
            discussing: 'Best animation moments S3',
            current: 75,
            max: 100,
            tag: 'DISCUSS',
            tagColor: const Color(0xFFFF8C42),
            avatarColors: const [Color(0xFFFF8C42), Color(0xFFEF4444), Color(0xFFFBBF24)],
          ),
      ],
    );
  }

  Widget _buildCompactRoom({
    required String title,
    required String discussing,
    required int current,
    required int max,
    required String tag,
    required Color tagColor,
    required List<Color> avatarColors,
  }) {
    final fillRatio = (current / max).clamp(0.0, 1.0);
    return _CompactRoomCard(
      title: title,
      discussing: discussing,
      current: current,
      max: max,
      fillRatio: fillRatio,
      tag: tag,
      tagColor: tagColor,
      avatarColors: avatarColors,
    );
  }
}

// ─── FEATURED ROOM HERO CARD ──────────────────────────────────────────────────
class _FeaturedRoomCard extends StatefulWidget {
  final Animation<double> pulseAnim;
  const _FeaturedRoomCard({required this.pulseAnim});

  @override
  State<_FeaturedRoomCard> createState() => _FeaturedRoomCardState();
}

class _FeaturedRoomCardState extends State<_FeaturedRoomCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _isHovered
                ? const Color(0xFF8B5CF6).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.35),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.04),
              blurRadius: 24,
              spreadRadius: -4,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
            if (_isHovered)
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                blurRadius: 20,
                spreadRadius: 2,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Colors.white.withValues(alpha: 0.45),
              child: Stack(
                children: [
                  // Light purple glow blob top-left
                  Positioned(
                    top: -30,
                    left: -20,
                    child: AnimatedBuilder(
                      animation: widget.pulseAnim,
                      builder: (_, _) => Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            const Color(0xFF8B5CF6)
                                .withValues(alpha: 0.15 + widget.pulseAnim.value * 0.05),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                    ),
                  ),

                  // Main content
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row: thumbnail + info
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Room thumbnail with live indicator
                            Stack(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF9D4EDD).withValues(alpha: 0.40),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(
                                          'https://cdn.myanimelist.net/images/anime/1726/148728l.jpg',
                                          fit: BoxFit.cover,
                                          loadingBuilder: (ctx, child, prog) =>
                                              prog == null ? child : const ShimmerBox(),
                                          errorBuilder: (_, __, ___) => Container(
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [Color(0xFF4C1D95), Color(0xFF1E0A3C)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                            ),
                                            child: const Center(
                                              child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 28),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.4)],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // LIVE badge
                                Positioned(
                                  bottom: 4,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: AnimatedBuilder(
                                      animation: widget.pulseAnim,
                                      builder: (_, _) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444)
                                              .withValues(alpha: 0.85 + widget.pulseAnim.value * 0.15),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: const Text(
                                          'LIVE',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 6.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(width: 12),

                            // Room info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Solo Leveling Room',
                                          style: TextStyle(
                                            color: Color(0xFF2C2543),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.1,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8B5CF6)
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: const Color(0xFF8B5CF6)
                                                .withValues(alpha: 0.35),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: const Text(
                                          'HYPE',
                                          style: TextStyle(
                                            color: Color(0xFF7C3AED),
                                            fontSize: 7,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  // Member capacity bar
                                  Row(
                                    children: [
                                      const Text(
                                        '128',
                                        style: TextStyle(
                                          color: Color(0xFF2C2543),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const Text(
                                        ' / 200 member',
                                        style: TextStyle(
                                          color: Color(0xFF7C7299),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: AnimatedProgressBar(
                                          value: 128 / 200,
                                          height: 3,
                                          color: const Color(0xFF8B5CF6),
                                          backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  // Avatar stack
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 72,
                                        height: 18,
                                        child: Stack(
                                          children: [
                                            for (int i = 0; i < 4; i++)
                                              Positioned(
                                                left: i * 14.0,
                                                child: Container(
                                                  width: 18,
                                                  height: 18,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: [
                                                      const Color(0xFFEC4899),
                                                      const Color(0xFF8B5CF6),
                                                      const Color(0xFF06B6D4),
                                                      const Color(0xFFF59E0B),
                                                    ][i],
                                                    border: Border.all(
                                                        color: Colors.white,
                                                        width: 1.5),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      ['A', 'B', 'C', 'D'][i],
                                                      style: const TextStyle(
                                                          fontSize: 6.5,
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w900),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        '+119 aktif sekarang',
                                        style: TextStyle(
                                          color: Color(0xFF7C7299),
                                          fontSize: 8,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Activity: currently discussing
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.10),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4ADE80),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              const Expanded(
                                child: Text(
                                  'Sedang diskusi: EP 13 - The System Awakens',
                                  style: TextStyle(
                                    color: Color(0xFF2C2543),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Energy meter
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.bolt_rounded,
                                        color: Color(0xFFFBBF24), size: 11),
                                    const SizedBox(width: 3),
                                    Text(
                                      'ROOM ENERGY',
                                      style: TextStyle(
                                        color: Color(0xFF7C7299),
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                                const Text(
                                  '87%  🔥',
                                  style: TextStyle(
                                    color: Color(0xFFFBBF24),
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            AnimatedProgressBar(
                              value: 0.87,
                              height: 5,
                              color: const Color(0xFFFBBF24),
                              backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // CTA row
                        Row(
                          children: [
                            Expanded(
                              child: _PressScale(
                                onTap: () {},
                                child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 38,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: _isHovered
                                        ? [
                                            const Color(0xFF9F7AEA),
                                            const Color(0xFFB57CFF),
                                          ]
                                        : [
                                            const Color(0xFF7C3AED),
                                            const Color(0xFF8B5CF6),
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: _isHovered
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF8B5CF6)
                                                .withValues(alpha: 0.40),
                                            blurRadius: 12,
                                            spreadRadius: 1,
                                          )
                                        ]
                                      : [],
                                ),
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () {},
                                  icon: const Icon(Icons.meeting_room_rounded,
                                      color: Colors.white, size: 15),
                                  label: const Text(
                                    'Masuk Room',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.20),
                                ),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.group_add_rounded,
                                    color: Color(0xFF7C3AED), size: 16),
                                onPressed: () {},
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── COMPACT ROOM CARD ────────────────────────────────────────────────────────
class _CompactRoomCard extends StatefulWidget {
  final String title;
  final String discussing;
  final int current;
  final int max;
  final double fillRatio;
  final String tag;
  final Color tagColor;
  final List<Color> avatarColors;

  const _CompactRoomCard({
    required this.title,
    required this.discussing,
    required this.current,
    required this.max,
    required this.fillRatio,
    required this.tag,
    required this.tagColor,
    required this.avatarColors,
  });

  @override
  State<_CompactRoomCard> createState() => _CompactRoomCardState();
}

class _CompactRoomCardState extends State<_CompactRoomCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {},
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _isHovered
                ? Colors.white
                : Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered
                  ? widget.tagColor.withValues(alpha: 0.50)
                  : const Color(0xFF8B5CF6).withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.tagColor.withValues(alpha: 0.08),
                      blurRadius: 10,
                      spreadRadius: 0,
                    )
                  ]
                : [],
          ),
          child: Row(
            children: [
              // Left: status-colored room icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: widget.tagColor.withValues(alpha: 0.12),
                  border: Border.all(
                    color: widget.tagColor.withValues(alpha: 0.30),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    _tagIcon(widget.tag),
                    color: widget.tagColor,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Center: info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              color: Color(0xFF2C2543),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        // Tag badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.tagColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: widget.tagColor.withValues(alpha: 0.40),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            widget.tag,
                            style: TextStyle(
                              color: widget.tagColor,
                              fontSize: 6.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '💬 ${widget.discussing}',
                      style: const TextStyle(
                        color: Color(0xFF7C7299),
                        fontSize: 8,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Member bar + avatar dots
                    Row(
                      children: [
                        // Mini avatar dots
                        Row(
                          children: [
                            for (int i = 0; i < 3; i++)
                              Container(
                                width: 12,
                                height: 12,
                                margin: EdgeInsets.only(right: i < 2 ? 2 : 6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: widget.avatarColors[i],
                                  border: Border.all(color: Colors.white, width: 0.8),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          '${widget.current}/${widget.max}',
                          style: const TextStyle(
                            color: Color(0xFF7C7299),
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: AnimatedProgressBar(
                            value: widget.fillRatio,
                            height: 2.5,
                            color: widget.tagColor.withValues(alpha: 0.80),
                            backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _tagIcon(String tag) {
    switch (tag) {
      case 'HYPE':
        return Icons.local_fire_department_rounded;
      case 'CHILL':
        return Icons.spa_rounded;
      case 'DISCUSS':
        return Icons.forum_rounded;
      case 'CHAOS':
        return Icons.bolt_rounded;
      default:
        return Icons.chat_bubble_rounded;
    }
  }
}

// ─── 5. FRIENDS ACTIVITY (Discord-style live feed) ───────────────────────────
class FriendsActivitySection extends StatelessWidget {
  const FriendsActivitySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SectionHeader(title: 'Friends Activity', actionLabel: 'Lihat Semua'),
        const SizedBox(height: 10),
        _ActivityCard(
          avatarChar: 'S',
          avatarColor: const Color(0xFF7C3AED),
          avatarNetworkUrl: 'https://cdn.myanimelist.net/images/characters/7/284129.jpg',
          name: 'Shiroe',
          isVerified: true,
          status: 'Online',
          eventLabel: 'EPISODE SELESAI',
          eventColor: const Color(0xFF4ADE80),
          eventIcon: Icons.check_circle_rounded,
          targetText: 'Mushoku Tensei S2 EP 8',
          subText: '24 menit watch time',
          time: '2m lalu',
        ),
        const SizedBox(height: 10),
        _ActivityCard(
          avatarChar: 'A',
          avatarColor: AppTheme.sakuraPink,
          avatarNetworkUrl: 'https://cdn.myanimelist.net/images/characters/14/422768.jpg',
          name: 'Aiko Chan',
          status: 'In Room',
          eventLabel: 'BADGE BARU',
          eventColor: const Color(0xFFFBBF24),
          eventIcon: Icons.workspace_premium_rounded,
          targetText: '🌸 Sakura Collector',
          subText: 'Koleksi 50 figure sakura',
          time: '5m lalu',
          badgeEmoji: '🌸',
        ),
        const SizedBox(height: 10),
        _ActivityCard(
          avatarChar: 'K',
          avatarColor: const Color(0xFF06B6D4),
          avatarNetworkUrl: 'https://cdn.myanimelist.net/images/characters/9/131317.jpg',
          name: 'Kirito_01',
          status: 'Idle',
          eventLabel: 'ROOM DIBUAT',
          eventColor: const Color(0xFF9D4EDD),
          eventIcon: Icons.meeting_room_rounded,
          targetText: 'Sword Art Online Room',
          subText: '0/200 member · CHILL',
          time: '10m lalu',
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String avatarChar;
  final Color avatarColor;
  final String? avatarNetworkUrl;
  final String name;
  final bool isVerified;
  final String status;
  final String eventLabel;
  final Color eventColor;
  final IconData eventIcon;
  final String targetText;
  final String subText;
  final String time;
  final String? badgeEmoji;

  const _ActivityCard({
    required this.avatarChar,
    required this.avatarColor,
    this.avatarNetworkUrl,
    required this.name,
    this.isVerified = false,
    required this.status,
    required this.eventLabel,
    required this.eventColor,
    required this.eventIcon,
    required this.targetText,
    required this.subText,
    required this.time,
    this.badgeEmoji,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (status) {
      case 'Online':
        statusColor = const Color(0xFF10B981);
        break;
      case 'In Room':
        statusColor = const Color(0xFF9D4EDD);
        break;
      default:
        statusColor = const Color(0xFFFBBF24);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: avatarColor.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left color accent strip — replaces non-uniform Border side
          Container(
            width: 2.5,
            margin: const EdgeInsets.only(right: 9),
            decoration: BoxDecoration(
              color: avatarColor.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(color: avatarColor.withValues(alpha: 0.5), blurRadius: 4),
              ],
            ),
          ),
          // Avatar + status dot indicator
          Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: avatarColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: avatarColor.withValues(alpha: 0.25),
                  // Network avatar jika tersedia, fallback ke initial char
                  backgroundImage: avatarNetworkUrl != null
                      ? NetworkImage(avatarNetworkUrl!) as ImageProvider
                      : null,
                  onBackgroundImageError: avatarNetworkUrl != null
                      ? (_, __) {} : null,
                  child: avatarNetworkUrl == null
                      ? Text(
                          avatarChar,
                          style: TextStyle(
                            fontSize: 14,
                            color: avatarColor,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Color(0xFF2C2543),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, color: Color(0xFF3B82F6), size: 11),
                    ],
                    const Spacer(),
                    Text(
                      time,
                      style: const TextStyle(color: Color(0xFF7C7299), fontSize: 8, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                // Event badge — own row so the label never gets clipped
                // ("EPISOD...", "BADG...", "ROOM D...")
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: eventColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: eventColor.withValues(alpha: 0.40), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(eventIcon, color: eventColor, size: 8),
                        const SizedBox(width: 3),
                        Text(
                          eventLabel,
                          style: TextStyle(
                            color: eventColor,
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        targetText,
                        style: const TextStyle(
                          color: Color(0xFF2C2543),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subText,
                  style: const TextStyle(
                    color: Color(0xFF7C7299),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (eventLabel == 'BADGE BARU') ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.sakuraPink.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.sakuraPink.withValues(alpha: 0.4), width: 1),
              ),
              child: const Center(
                child: Icon(Icons.local_florist_rounded, color: AppTheme.sakuraPink, size: 16),
              ),
            ),
          ],
        ],
      ),
    ),
    );
  }
}

// ─── 6. DAILY MISSIONS (Checklist style — matches mockup) ────────────────────
class DailyMissionsSection extends StatefulWidget {
  const DailyMissionsSection({super.key});
  @override
  State<DailyMissionsSection> createState() => _DailyMissionsSectionState();
}

class _DailyMissionsSectionState extends State<DailyMissionsSection> {
  final List<Map<String, dynamic>> _missions = [
    {
      'title': 'Tonton 2 Episode',
      'xp': 50,
      'gold': 100,
      'current': 0,
      'total': 2,
      'done': false,
    },
    {
      'title': 'Like 3 Post di Community',
      'xp': 30,
      'gold': 50,
      'current': 1,
      'total': 3,
      'done': false,
    },
    {
      'title': 'Bergabung di 1 Room',
      'xp': 20,
      'gold': 40,
      'current': 0,
      'total': 1,
      'done': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 3, height: 14,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFBBF24), Color(0xFFFF4FA3)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'DAILY MISSIONS',
                    style: TextStyle(
                      color: Color(0xFF2C2543),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0x33FBBF24), Color(0x11FBBF24)],
                      ),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.45)),
                    ),
                    child: const Text(
                      'DAILY',
                      style: TextStyle(color: Color(0xFFFBBF24), fontSize: 6.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF9D4EDD).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF9D4EDD).withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_rounded, color: const Color(0xFF9D4EDD), size: 9),
                    const SizedBox(width: 3),
                    const Text(
                      '14:18:24',
                      style: TextStyle(
                        color: Color(0xFF2C2543),
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Mission progress bar (1/3 done)
          AnimatedProgressBar(
            value: 1 / 3,
            height: 3,
            color: const Color(0xFFFBBF24),
            backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 10),

          // Mission rows
          ...List.generate(_missions.length, (i) {
            final m = _missions[i];
            final isDone = m['done'] as bool;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: isDone
                      ? const Color(0xFF4ADE80).withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDone
                        ? const Color(0xFF4ADE80).withValues(alpha: 0.3)
                        : const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    // Checkbox
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: isDone
                            ? const Color(0xFF4ADE80).withValues(alpha: 0.15)
                            : const Color(0xFF8B5CF6).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: isDone
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFF8B5CF6).withValues(alpha: 0.20),
                          width: 1.5,
                        ),
                      ),
                      child: isDone
                          ? const Icon(Icons.check, color: Color(0xFF4ADE80), size: 11)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    // Title + progress
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m['title'] as String,
                            style: TextStyle(
                              color: isDone
                                  ? const Color(0xFF7C7299)
                                  : const Color(0xFF2C2543),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                              decorationColor: const Color(0xFF7C7299).withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              // XP
                              Row(
                                children: [
                                  const Icon(Icons.auto_awesome, color: Color(0xFF9D4EDD), size: 8),
                                  const SizedBox(width: 2),
                                  Text(
                                    '+${m['xp']} XP',
                                    style: const TextStyle(
                                      color: Color(0xFFC084FC),
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 6),
                              // Gold
                              Row(
                                children: [
                                  const Icon(Icons.monetization_on_rounded, color: Color(0xFFFBBF24), size: 8),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${m['gold']}',
                                    style: const TextStyle(
                                      color: Color(0xFFFBBF24),
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 6),
                              // Progress fraction
                              Text(
                                '${m['current']}/${m['total']}',
                                style: const TextStyle(
                                  color: Color(0xFF7C7299),
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Mulai button
                    if (!isDone)
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFF9D4EDD)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(7),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF9D4EDD).withValues(alpha: 0.40),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Mulai',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 4),
          // Klaim Semua Reward button with pulsing notification dot
          Stack(
            clipBehavior: Clip.none,
            children: [
              _TappableScale(
                onTap: () {},
                child: Container(
                  width: double.infinity,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.sakuraPink, Color(0xFF9D4EDD)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.sakuraPink.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Klaim Semua Reward',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: _PulsingDot(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 7. COLLECTION (Premium Figurines Showcase) ───────────────────────────────
class CollectionSection extends StatelessWidget {
  const CollectionSection({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'YOUR COLLECTION',
                style: TextStyle(color: Color(0xFF2C2543), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8),
              ),
              const Text(
                'Lihat Semua >',
                style: TextStyle(color: Color(0xFF7C3AED), fontSize: 7.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Figure Collection label + count
          const Text(
            'Figure Collection',
            style: TextStyle(color: Color(0xFFFF4FA3), fontSize: 12, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          const Text(
            '24 / 100 Item Terbuka',
            style: TextStyle(color: Color(0xFF7C7299), fontSize: 8, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          AnimatedProgressBar(
            value: 0.24,
            height: 3.5,
            color: const Color(0xFFFF4FA3),
            backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 10),

          // Chibi figures row
          SizedBox(
            height: 90,
            child: Stack(
              children: [
                // Purple glow platform
                Positioned(
                  bottom: 8, left: 0, right: 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [
                        Colors.transparent,
                        Color(0xFF9D4EDD),
                        Color(0xFFE879F9),
                        Color(0xFF9D4EDD),
                        Colors.transparent,
                      ]),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF9D4EDD).withValues(alpha: 0.8), blurRadius: 8, spreadRadius: 2),
                      ],
                    ),
                  ),
                ),
                // 3 chibi figures
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildChibiFigure('asset/images/collection/chibi_hitaku.png', const Color(0xFF9D4EDD), 62),
                    _buildChibiFigure('asset/images/collection/chibi_sakura_priestess.png', const Color(0xFFF472B6), 70),
                    _buildChibiFigure('asset/images/collection/chibi_luna_knight.png', const Color(0xFF9D4EDD), 62),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'Koleksi figure favoritmu!',
              style: TextStyle(color: Color(0x44FFFFFF), fontSize: 7, fontWeight: FontWeight.w600),
            ),
          ),

          // 3D box icon
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9D4EDD), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: const Color(0xFF9D4EDD).withValues(alpha: 0.5), blurRadius: 8)],
              ),
              child: const Icon(Icons.view_in_ar_rounded, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChibiFigure(String assetPath, Color glowColor, double figureHeight) {
    return SizedBox(
      height: figureHeight,
      width: figureHeight * 0.72,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            bottom: -2,
            child: Container(
              width: figureHeight * 0.55,
              height: figureHeight * 0.18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [glowColor.withValues(alpha: 0.55), Colors.transparent]),
              ),
            ),
          ),
          Positioned.fill(
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              errorBuilder: (_, __, ___) => Center(
                child: Icon(Icons.person_rounded, color: glowColor.withValues(alpha: 0.9), size: figureHeight * 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ─── 8. ANIME DNA (Stats Radar centerpiece) ──────────────────────────────────
class AnimeDnaSection extends StatefulWidget {
  const AnimeDnaSection({super.key});
  @override
  State<AnimeDnaSection> createState() => _AnimeDnaSectionState();
}

class _AnimeDnaSectionState extends State<AnimeDnaSection> with SingleTickerProviderStateMixin {
  late AnimationController _rotationCtrl;

  @override
  void initState() {
    super.initState();
    _rotationCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();
  }

  @override
  void dispose() { _rotationCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'YOUR ANIME DNA',
                style: TextStyle(color: Color(0xFF2C2543), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8),
              ),
              const Text(
                'Lihat Detail >',
                style: TextStyle(color: Color(0xFF7C3AED), fontSize: 7.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Archetype title
          Center(
            child: Column(
              children: [
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'BATTLE ',
                        style: TextStyle(color: Color(0xFFEF4444), fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                      ),
                      TextSpan(
                        text: 'SEEKER',
                        style: TextStyle(color: Color(0xFF2C2543), fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Level 42 · Archetype Utama',
                  style: TextStyle(color: Color(0xFF7C7299), fontSize: 7.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Radar chart
          SizedBox(
            height: 130,
            child: Center(
              child: ClipRect(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    RotationTransition(
                      turns: _rotationCtrl,
                      child: Container(
                        width: 108, height: 108,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF9D4EDD).withValues(alpha: 0.15), width: 1.5),
                        ),
                      ),
                    ),
                    CustomPaint(size: const Size(128, 128), painter: _RadarChartPainter()),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Trait tags
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 3,
            runSpacing: 3,
            children: [
              _buildTraitTag('STRIKER', const Color(0xFFEF4444)),
              _buildTraitTag('MYSTICAL', const Color(0xFF8B5CF6)),
              _buildTraitTag('STRATEGIST', const Color(0xFF3B82F6)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTraitTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.2),
      ),
    );
  }
}


class _RadarChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3.0;

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final ringPaint = Paint()
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    final dataPaint = Paint()
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final dataOutlinePaint = Paint()
      ..color = const Color(0xFFA78BFA)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final angles = [
      -math.pi / 2,
      -math.pi / 2 + 2 * math.pi / 5,
      -math.pi / 2 + 4 * math.pi / 5,
      -math.pi / 2 + 6 * math.pi / 5,
      -math.pi / 2 + 8 * math.pi / 5,
    ];

    final labels = ['Action\n88%', 'Fantasy\n76%', 'Psych.\n65%', 'Drama\n54%', 'Adv.\n82%'];
    final dataScale = [0.88, 0.76, 0.65, 0.54, 0.82];

    for (var rFactor in [0.4, 0.7, 1.0]) {
      final path = Path();
      for (int i = 0; i < 5; i++) {
        final x = center.dx + math.cos(angles[i]) * radius * rFactor;
        final y = center.dy + math.sin(angles[i]) * radius * rFactor;
        if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, linePaint);
      if (rFactor == 1.0) canvas.drawPath(path, ringPaint);
    }

    for (int i = 0; i < 5; i++) {
      final x = center.dx + math.cos(angles[i]) * radius;
      final y = center.dy + math.sin(angles[i]) * radius;
      canvas.drawLine(center, Offset(x, y), linePaint);
    }

    final dataPath = Path();
    for (int i = 0; i < 5; i++) {
      final x = center.dx + math.cos(angles[i]) * radius * dataScale[i];
      final y = center.dy + math.sin(angles[i]) * radius * dataScale[i];
      if (i == 0) dataPath.moveTo(x, y); else dataPath.lineTo(x, y);
    }
    dataPath.close();
    canvas.drawPath(dataPath, dataPaint);
    canvas.drawPath(dataPath, dataOutlinePaint);

    final dotPaint = Paint()..color = const Color(0xFFF59E0B)..style = PaintingStyle.fill;
    for (int i = 0; i < 5; i++) {
      final x = center.dx + math.cos(angles[i]) * radius * dataScale[i];
      final y = center.dy + math.sin(angles[i]) * radius * dataScale[i];
      canvas.drawCircle(Offset(x, y), 2.5, dotPaint);
    }

    // FIX: constrain label layout to prevent paint outside canvas bounds
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < 5; i++) {
      textPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(color: Color(0xFF2C2543), fontSize: 7.5, fontWeight: FontWeight.w800, height: 1.2),
      );
      // maxWidth cap prevents label text from being wider than 36px so it never
      // spills outside the 130×130 canvas — key fix for the 22px overflow
      textPainter.layout(maxWidth: 36);
      // Tighten offset: 10 instead of 12 to keep labels inside canvas rect
      final x = (center.dx + math.cos(angles[i]) * (radius + 10) - textPainter.width / 2)
          .clamp(0.0, size.width - textPainter.width);
      final y = (center.dy + math.sin(angles[i]) * (radius + 8) - textPainter.height / 2)
          .clamp(0.0, size.height - textPainter.height);
      textPainter.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// ─── 9. UNIVERSE STATUS (Analytics dashboard) ────────────────────────────────
class UniverseStatusSection extends StatelessWidget {
  const UniverseStatusSection({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 3, height: 14,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9D4EDD), Color(0xFF3B82F6)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'UNIVERSE STATUS',
                style: TextStyle(color: Color(0xFF2C2543), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.8),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRow(
            icon: Icons.people_alt_rounded,
            iconColor: const Color(0xFF3B82F6),
            value: '12.4M',
            label: 'Member Online',
            trend: '+12.4% hari ini',
            points: [10, 15, 8, 20, 18, 25, 30],
          ),
          const SizedBox(height: 8),
          _buildRow(
            icon: Icons.forum_rounded,
            iconColor: const Color(0xFFA855F7),
            value: '92K',
            label: 'Room Active',
            trend: '+4.8% jam lalu',
            points: [5, 12, 10, 15, 13, 22, 18],
          ),
          const SizedBox(height: 8),
          _buildRow(
            icon: Icons.remove_red_eye_rounded,
            iconColor: const Color(0xFF10B981),
            value: '13M',
            label: 'Episode Watched Today',
            trend: 'Sangat Tinggi 🔥',
            points: [20, 22, 25, 24, 28, 32, 35],
          ),
          const SizedBox(height: 12),
          // Planet visual — matches mockup bottom right
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.35, -0.35),
                  radius: 0.85,
                  colors: [
                    Color(0xFF9D4EDD),
                    Color(0xFF6D28D9),
                    Color(0xFF3B0764),
                    Color(0xFF1E0A3C),
                  ],
                  stops: [0.0, 0.35, 0.70, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9D4EDD).withValues(alpha: 0.55),
                    blurRadius: 28,
                    spreadRadius: 5,
                  ),
                  BoxShadow(
                    color: const Color(0xFF4C1D95).withValues(alpha: 0.40),
                    blurRadius: 50,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // Highlight top-left
                  Positioned(
                    top: 10, left: 12,
                    child: Container(
                      width: 20, height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.20),
                      ),
                    ),
                  ),
                  // Equator line 1
                  Positioned(
                    top: 33, left: 0, right: 0,
                    child: Container(height: 1.5, color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  // Equator line 2
                  Positioned(
                    top: 40, left: 0, right: 0,
                    child: Container(height: 1, color: Colors.white.withValues(alpha: 0.04)),
                  ),
                  // Ring shadow edge
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE879F9).withValues(alpha: 0.15), width: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required String trend,
    required List<double> points,
  }) {
    final isPositive = trend.startsWith('+') || trend.contains('Tinggi');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon with glow
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [iconColor.withValues(alpha: 0.25), iconColor.withValues(alpha: 0.08)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: iconColor.withValues(alpha: 0.30), width: 0.8),
              boxShadow: [
                BoxShadow(color: iconColor.withValues(alpha: 0.25), blurRadius: 8, spreadRadius: 0),
              ],
            ),
            child: Center(child: Icon(icon, color: iconColor, size: 16)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedCounter(value: value,
                    style: const TextStyle(
                        color: Color(0xFF2C2543), fontSize: 14, fontWeight: FontWeight.w900, height: 1.0)),
                const SizedBox(height: 2),
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF7C7299),
                        fontSize: 8,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up_rounded : Icons.trending_flat_rounded,
                      color: isPositive ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24),
                      size: 10,
                    ),
                    const SizedBox(width: 3),
                    Text(trend,
                        style: TextStyle(
                            color: isPositive ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24),
                            fontSize: 7.5,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
          // Bigger sparkline
          CustomPaint(
            size: const Size(52, 28),
            painter: _MiniSparklinePainter(points: points, color: iconColor),
          ),
        ],
      ),
    );
  }
}

class _MiniSparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;

  _MiniSparklinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final maxVal = points.reduce((a, b) => a > b ? a : b);
    final minVal = points.reduce((a, b) => a < b ? a : b);
    final range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);
    final widthFactor = size.width / (points.length - 1);

    // Build smooth path using quadratic bezier
    final path = Path();
    final pts = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      pts.add(Offset(
        i * widthFactor,
        size.height * 0.85 - ((points[i] - minVal) / range * size.height * 0.80),
      ));
    }

    path.moveTo(pts[0].dx, pts[0].dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final mid = Offset((pts[i].dx + pts[i + 1].dx) / 2, (pts[i].dy + pts[i + 1].dy) / 2);
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);

    // Fill under curve
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.35), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Stroke line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // Glowing dot at end
    final dotCenter = pts.last;
    canvas.drawCircle(dotCenter, 3.5,
        Paint()..color = color.withValues(alpha: 0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(dotCenter, 2.0, Paint()..color = color..style = PaintingStyle.fill);
    canvas.drawCircle(dotCenter, 1.0, Paint()..color = Colors.white..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_MiniSparklinePainter oldDelegate) => true;
}
