import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'home_screen.dart';
import 'explore_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';
import 'jadwal_screen.dart';
import 'vault_screen.dart';
import 'community_screen.dart';
import 'app_theme.dart';
import 'theme/aniverse_theme.dart';
import 'widgets/liquid_glass.dart';

// Index: 0=Beranda 1=Jadwal 2=Library 3=Universe 4=Vault 5=Profile 6=Community

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _navVisible = true;
  double _lastScrollOffset = 0;

  // ── Nav hide/show — collapse animation ─────────────────────────────────
  // One controller drives slide + scale + fade together so they stay
  // perfectly in sync (previously AnimatedSlide/AnimatedOpacity ran as two
  // separate implicit animations with different durations, which could
  // drift out of step). 1.0 = fully shown, 0.0 = fully collapsed.
  late final AnimationController _navCtrl;
  late final Animation<double> _navSlide; // 0 → 1 (down)
  late final Animation<double> _navScale; // 1 → 0.82
  late final Animation<double> _navFade; // 1 → 0

  @override
  void initState() {
    super.initState();
    _navCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 320),
    );
    // Slide eases out like something settling/collapsing downward rather
    // than a mechanical linear push — steep at the start, gentle landing.
    _navSlide = CurvedAnimation(
      parent: _navCtrl,
      curve: Curves.easeInCubic,
      reverseCurve: Curves.easeOutCubic,
    );
    // Scale shrinks slightly as it collapses (a "melting into the bottom
    // edge" feel) rather than staying full-size while sliding — this is
    // what makes it read as "collapse" instead of "slide".
    _navScale = Tween<double>(begin: 1.0, end: 0.82).animate(
      CurvedAnimation(
        parent: _navCtrl,
        curve: Curves.easeInCubic,
        reverseCurve: Curves.easeOutBack, // slight overshoot on the way back in — premium "pop"
      ),
    );
    // Fade lags slightly behind slide/scale (starts at 60% progress) so the
    // bar is already visually "gone" by the time it's fully off-screen,
    // instead of a flat linear fade racing the slide.
    _navFade = CurvedAnimation(
      parent: _navCtrl,
      curve: const Interval(0.0, 1.0, curve: Curves.easeIn),
      reverseCurve: const Interval(0.0, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _navCtrl.dispose();
    super.dispose();
  }

  void _setNavVisible(bool visible) {
    if (_navVisible == visible) return;
    setState(() => _navVisible = visible);
    if (visible) {
      _navCtrl.reverse();
    } else {
      _navCtrl.forward();
    }
  }

  // Single source of truth for equipped cosmetics
  final Map<String, String> _equipped = {
    'Border': 'Sakura Emperor Frame',
    'BG':     'Cosmic Nebula',
    'Badge':  'Founder Crest',
    'Banner': 'Sakura Horizon',
    'Bubble': 'Sakura Petal',
    'Emote':  'Sakura Dance',
    'Deco':   'Wraithling Cloak',
  };

  void _onEquip(String category, String itemName) {
    setState(() => _equipped[category] = itemName);
  }

  // Lets HomeScreen's compact summary cards (Komunitas/Toko/etc.) jump
  // straight to the relevant tab instead of duplicating that content on
  // Home itself. Index mapping matches the comment at the top of this file.
  void _goToTab(int index) {
    setState(() => _currentIndex = index);
  }

  List<Widget> get _screens => [
    HomeScreen(onNavigateToTab: _goToTab),
    const JadwalScreen(),
    const LibraryScreen(),
    const ExploreScreen(),
    VaultScreen(equipped: Map.unmodifiable(_equipped), onEquip: _onEquip),
    ProfileScreen(equipped: Map.unmodifiable(_equipped), onEquip: _onEquip),
    const CommunityScreen(),
  ];

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label coming soon'),
        backgroundColor: AniVerseTheme.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is UserScrollNotification) {
      final direction = notification.direction;
      if (direction == ScrollDirection.reverse && _navVisible) {
        // Scrolling down → hide nav
        _setNavVisible(false);
      } else if (direction == ScrollDirection.forward && !_navVisible) {
        // Scrolling up → show nav
        _setNavVisible(true);
      }
    }
    // Always show nav when scroll stops at the very top
    if (notification is ScrollUpdateNotification) {
      if (notification.metrics.pixels <= 0 && !_navVisible) {
        _setNavVisible(true);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafePadding = MediaQuery.of(context).viewPadding.bottom;
    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: Container(
          decoration: AniVerseTheme.backgroundDecoration, // Apply the Ghibli-style gradient
          child: IndexedStack(index: _currentIndex, children: _screens),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: AnimatedBuilder(
        animation: _navCtrl,
        builder: (context, child) {
          final slideT = _navSlide.value; // 0 (shown) → 1 (hidden)
          // Slide further than fully off-screen (1.4x its own height) so
          // the tail end of the bar doesn't peek back into view during the
          // scale-down — the whole thing genuinely leaves the viewport.
          final offsetY = slideT * 130.0;
          return Transform.translate(
            offset: Offset(0, offsetY),
            child: Transform.scale(
              scale: _navScale.value,
              // Anchor the scale to the bottom-center so it shrinks toward
              // where it's "collapsing into", not toward the middle of the
              // bar — reinforces the melt-downward feel instead of just
              // shrinking in place.
              alignment: Alignment.bottomCenter,
              child: Opacity(opacity: 1.0 - _navFade.value, child: child),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            14,
            0,
            14,
            // Always reserve at least 8px, but respect the device's
            // home indicator / gesture bar safe area when present.
            math.max(8.0, bottomSafePadding + 4),
          ),
          child: SizedBox(
            height: 90,
            child: _AniVerseBottomNav(
              currentIndex: _currentIndex,
              onTabSelected: (index) => setState(() => _currentIndex = index),
              onComingSoon: _showComingSoon,
            ),
          ),
        ),
      ),
    );
  }
}

class _AniVerseBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final ValueChanged<String> onComingSoon;

  const _AniVerseBottomNav({
    required this.currentIndex,
    required this.onTabSelected,
    required this.onComingSoon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 38,
            right: 38,
            bottom: 7,
            height: 48,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: AniVerseTheme.glow.withValues(alpha: 0.20),
                      blurRadius: 30,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LiquidGlassPill(
              borderRadius: 28,
              height: 72,
              padding: EdgeInsets.zero,
              alignment: Alignment.center,
              child: SizedBox(
                width: double.infinity,
                height: 72,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Left group: Beranda, Jadwal, Library ──
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _NavItem(
                            iconActive: Icons.home_rounded,
                            iconInactive: Icons.home_outlined,
                            label: 'Beranda',
                            isActive: currentIndex == 0,
                            onTap: () => onTabSelected(0),
                          ),
                          _NavItem(
                            iconActive: Icons.calendar_month_rounded,
                            iconInactive: Icons.calendar_month_outlined,
                            label: 'Jadwal',
                            isActive: currentIndex == 1,
                            onTap: () => onTabSelected(1),
                          ),
                          _NavItem(
                            iconActive: Icons.video_library_rounded,
                            iconInactive: Icons.video_library_outlined,
                            label: 'Library',
                            isActive: currentIndex == 2,
                            onTap: () => onTabSelected(2),
                          ),
                        ],
                      ),
                    ),
                    // ── Fixed center gap for Universe orb ──
                    const SizedBox(width: 64),
                    // ── Right group: Vault, Room, Profile ──
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _NavItem(
                            iconActive: Icons.diamond_rounded,
                            iconInactive: Icons.diamond_outlined,
                            label: 'Vault',
                            isActive: currentIndex == 4,
                            onTap: () => onTabSelected(4),
                          ),
                          _NavItem(
                            iconActive: Icons.groups_2_rounded,
                            iconInactive: Icons.groups_2_outlined,
                            label: 'Room',
                            isActive: currentIndex == 6,
                            onTap: () => onTabSelected(6),
                          ),
                          _NavItem(
                            iconActive: Icons.person_rounded,
                            iconInactive: Icons.person_outline_rounded,
                            label: 'Profile',
                            isActive: currentIndex == 5,
                            onTap: () => onTabSelected(5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Connector glow: soft bloom merging orb into navbar ──
          // Alpha lowered and radius widened (was 90×40 @ alpha 0.22) —
          // now that the bar itself is LiquidGlassPill (thin, translucent)
          // instead of a solid-tinted Container, that small dense blob
          // read as a distinct dark patch sitting ON TOP of the glass
          // instead of blending into it, visually "cutting" the bar in
          // two right where the orb sits. A larger, much fainter glow
          // fades into the glass instead of interrupting it.
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: IgnorePointer(
                child: Container(
                  width: 140,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(56),
                    gradient: RadialGradient(
                      colors: [
                        AniVerseTheme.glow.withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            left: 0,
            right: 0,
            child: Center(
              child: _CenterNavItem(
                isActive: currentIndex == 3,
                onTap: () => onTabSelected(3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomQuickEntry extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _RoomQuickEntry({
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isActive
                ? [AniVerseTheme.accent, AniVerseTheme.glow]
                : [AniVerseTheme.surface, AniVerseTheme.surfaceElevated],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive
                ? Colors.white.withValues(alpha: 0.5)
                : AppTheme.highlight.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.highlight.withValues(alpha: isActive ? 0.35 : 0.14),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.groups_2_rounded,
              size: 16,
              color: isActive ? AniVerseTheme.background : AniVerseTheme.highlight,
            ),
            const SizedBox(width: 6),
            Text(
              'Room',
              style: TextStyle(
                color: isActive ? AniVerseTheme.background : AniVerseTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData? iconActive;
  final IconData? iconInactive;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    this.iconActive,
    this.iconInactive,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _ctrl;
  late Animation<double> _pillAnim;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: widget.isActive ? 1.0 : 0.0,
    );
    // Pill pops in with overshoot when active, fades smoothly when inactive
    _pillAnim = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
    // Icon does a quick bounce when becoming active
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.95), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 35),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_NavItem old) {
    super.didUpdateWidget(old);
    if (widget.isActive != old.isActive) {
      widget.isActive ? _ctrl.forward(from: 0) : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.82 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final pillT = _pillAnim.value.clamp(0.0, 1.0);
              final bounce = widget.isActive ? _bounceAnim.value : 1.0;
              return Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      if (pillT > 0.01)
                        Transform.scale(
                          scale: 0.6 + (pillT * 0.4),
                          child: Opacity(
                            opacity: pillT.clamp(0.0, 1.0),
                            child: SizedBox(
                              width: 46,
                              height: 30,
                              child: LiquidGlassPill(
                                borderRadius: 999,
                                height: 30,
                                padding: EdgeInsets.zero,
                                alignment: Alignment.center,
                                compact: true,
                                child: const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ),
                      Transform.scale(
                        scale: bounce,
                        child: Icon(
                          widget.isActive
                              ? (widget.iconActive ?? Icons.home_rounded)
                              : (widget.iconInactive ?? Icons.home_outlined),
                          size: widget.isActive ? 21 : 20,
                          color: widget.isActive
                              ? AppTheme.highlight
                              : AniVerseTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.isActive
                          ? AppTheme.highlight
                          : AniVerseTheme.textSecondary,
                      fontSize: widget.isActive ? 8.5 : 8,
                      fontWeight: widget.isActive ? FontWeight.w900 : FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: widget.isActive ? 14 : 3,
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: widget.isActive
                          ? AppTheme.highlight
                          : Colors.transparent,
                      boxShadow: widget.isActive
                          ? [
                              BoxShadow(
                                color: AppTheme.highlight.withValues(alpha: 0.70),
                                blurRadius: 9,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// Painter bintang 8 sudut — dengan 4 titik diamond kecil di antaranya
class _StarPainter extends CustomPainter {
  final Color color;
  final double glowRadius;
  final double glowAlpha;

  const _StarPainter({
    required this.color,
    required this.glowRadius,
    required this.glowAlpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Bintang 8 sudut: 4 spike panjang + 4 spike pendek (diamond style)
    final outerR = size.width / 2;
    final midR = outerR * 0.35;   // lekukan dalam antar spike

    // Build path: 8 outer points, alternating long and short
    // Pattern: long(0°), notch, long(90°), notch, ... 
    // Actually we do 16 points total: outer, inner, outer, inner...
    // Spike at 0,90,180,270 (kartu) dan 45,135,225,315 (diagonal lebih pendek)
    final path = Path();
    const totalPoints = 16;
    for (int i = 0; i < totalPoints; i++) {
      // -pi/2 biar spike pertama di atas, lalu offset pi/8 agar spike panjang tepat di atas/bawah/kiri/kanan
      final angle = (i * 2 * math.pi / totalPoints) - math.pi / 2 + math.pi / 8;
      double r;
      if (i % 4 == 0) {
        r = outerR; // spike panjang (atas/bawah/kiri/kanan)
      } else if (i % 2 == 0) {
        r = outerR * 0.72; // spike sedang (diagonal)
      } else {
        r = midR; // lekukan dalam
      }
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Glow layer luar
    final outerGlowPaint = Paint()
      ..color = color.withValues(alpha: glowAlpha * 0.4)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius * 1.8);
    canvas.drawPath(path, outerGlowPaint);

    // Glow layer dalam
    final innerGlowPaint = Paint()
      ..color = color.withValues(alpha: glowAlpha * 0.7)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius * 0.7);
    canvas.drawPath(path, innerGlowPaint);

    // Fill solid
    final fillPaint = Paint()..color = color;
    canvas.drawPath(path, fillPaint);

    // Highlight titik tengah (center bright dot)
    final centerGlowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius * 0.6);
    canvas.drawCircle(Offset(cx, cy), outerR * 0.22, centerGlowPaint);
    canvas.drawCircle(
      Offset(cx, cy),
      outerR * 0.1,
      Paint()..color = AniVerseTheme.highlight,
    );
  }

  @override
  bool shouldRepaint(_StarPainter old) =>
      old.color != color ||
      old.glowRadius != glowRadius ||
      old.glowAlpha != glowAlpha;
}

class _SparkParticlePainter extends CustomPainter {
  final double progress;
  final Color color;

  _SparkParticlePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxRadius = size.width * 0.65;

    // Use seed to make particle paths consistent and smooth
    final rand = math.Random(54321);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 10; i++) {
      final angle = rand.nextDouble() * 2 * math.pi;
      final speed = 0.4 + rand.nextDouble() * 0.6;
      final p = (progress * speed + rand.nextDouble()) % 1.0;

      final distance = p * maxRadius;
      final px = cx + distance * math.cos(angle);
      final py = cy + distance * math.sin(angle);

      final opacity = (1.0 - p) * 0.75;
      final sizeMult = (1.0 - p) * 2.0 + 0.6;

      paint.color = color.withValues(alpha: opacity);
      
      // Draw tiny glowing circles/stars
      canvas.drawCircle(Offset(px, py), sizeMult, paint);
      
      // Outer subtle glow for sparks
      final glowPaint = Paint()
        ..color = color.withValues(alpha: opacity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(px, py), sizeMult * 1.8, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkParticlePainter old) => old.progress != progress || old.color != color;
}

class _CenterNavItem extends StatefulWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _CenterNavItem({required this.isActive, required this.onTap});

  @override
  State<_CenterNavItem> createState() => _CenterNavItemState();
}

class _CenterNavItemState extends State<_CenterNavItem>
    with TickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _rotateCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOutSine),
    );

    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: const Offset(0, -6),
            child: AnimatedScale(
              scale: _pressed ? 0.85 : 1.0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: AnimatedBuilder(
                animation: Listenable.merge([_pulseAnim, _rotateCtrl]),
                builder: (context, _) {
                  final pulse = _pulseAnim.value;
                  return SizedBox(
                    width: 90,
                    height: 90,
                    child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Pulse ring luar
                      Transform.scale(
                        scale: 0.78 + pulse * 0.13,
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AniVerseTheme.glow.withValues(
                                alpha: isActive
                                    ? (1.0 - pulse) * 0.9
                                    : (1.0 - pulse) * 0.4,
                              ),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      // Glow ring
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: isActive ? 72 : 66,
                        height: isActive ? 72 : 66,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            stops: const [0.0, 0.55, 0.85, 1.0],
                            colors: [
                              AniVerseTheme.highlight.withValues(alpha: 0.25),
                              AppTheme.highlight.withValues(alpha: isActive ? 0.22 : 0.14),
                              AniVerseTheme.accent.withValues(alpha: isActive ? 0.18 : 0.12),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      // Universe orb (image background)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: isActive ? 66 : 60,
                        height: isActive ? 66 : 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AniVerseTheme.accent,
                              AniVerseTheme.glow,
                              AniVerseTheme.background,
                            ],
                          ),
                          border: Border.all(
                            color: AniVerseTheme.highlight.withValues(alpha: 0.40),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AniVerseTheme.glow.withValues(
                                alpha: isActive
                                    ? 0.44 + (pulse * 0.20)
                                    : 0.28,
                              ),
                              blurRadius: isActive ? 26 : 16,
                              spreadRadius: isActive ? 2 : 0,
                            ),
                            BoxShadow(
                              color: AppTheme.highlight.withValues(alpha: 0.35),
                              blurRadius: 14,
                              spreadRadius: -2,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: SizedBox(
                            width: isActive ? 66 : 60,
                            height: isActive ? 66 : 60,
                            child: RotationTransition(
                              turns: _rotateCtrl,
                              child: Transform.scale(
                                scale: 1.8,
                                child: Image.asset(
                                  'asset/images/icon/icon_universe.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    decoration: const BoxDecoration(
                                      gradient: RadialGradient(
                                        colors: [
                                          AniVerseTheme.highlight,
                                          AniVerseTheme.glow,
                                          AniVerseTheme.background,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Sparks/particles floating outwards
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _SparkParticlePainter(
                              progress: _pulseAnim.value,
                              color: isActive
                                  ? AniVerseTheme.highlight
                                  : AniVerseTheme.primary.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                      // Ring tipis di sekitar bintang
                      Container(
                        width: isActive ? 44 : 38,
                        height: isActive ? 44 : 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AniVerseTheme.primary.withValues(
                              alpha: isActive ? 0.5 + pulse * 0.3 : 0.25,
                            ),
                            width: 1.0,
                          ),
                        ),
                      ),
                    ],
                    ),
                  );
                },
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -6),
            child: Text(
              'Universe',
              style: TextStyle(
                color: isActive
                    ? AniVerseTheme.background
                    : AniVerseTheme.textSecondary,
                fontSize: 9.5,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w400,
                letterSpacing: 0,
                shadows: [
                  Shadow(
                    color: AniVerseTheme.glow.withValues(alpha: 0.60),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
