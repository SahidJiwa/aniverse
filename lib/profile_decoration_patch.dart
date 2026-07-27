// ══════════════════════════════════════════════════════════════════════════════
// PATCH: profile_screen.dart — Animated Avatar Decoration (Discord-style)
// ══════════════════════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════════════════
// [A] TAMBAH di _ProfileScreenState — controller baru + getter
// ════════════════════════════════════════════════════════════════════════
// Di class _ProfileScreenState, setelah baris:
//   late AnimationController _crystalInnerCtrl;
// TAMBAH:
//   late AnimationController _decorCtrl; // avatar decoration overlay

// Di initState(), setelah baris:
//   _crystalInnerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
// TAMBAH:
//   _decorCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

// Di dispose(), tambah:
//   _decorCtrl.dispose();

// Tambah getter equipped decoration:
//   String get _equippedDecoId => widget.equipped['Deco'] ?? 'Wraithling Cloak';

// ════════════════════════════════════════════════════════════════════════
// [B] PASS _decorCtrl ke _ProfileGlassHeader dan _HeroHeader
// ════════════════════════════════════════════════════════════════════════

// Lokasi di build():
//   _ProfileGlassHeader(
//     ...existing params...
//     crystalInnerCtrl: _crystalInnerCtrl,   ← setelah baris ini tambah:
//     decorCtrl: _decorCtrl,
//     equippedDecoId: _equippedDecoId,
//   )

// Dan di _HeroHeader (di section 4 _ProfileCosmeticsShowcase area — HeroHeader sudah ada di sliver):
// Cari di dalam sliver/column yang membangun hero area — pass parameter baru ke _HeroHeader jika ada.
// (Catatan: _HeroHeader dipanggil dari _ProfileCosmeticsShowcase atau section terpisah)

// ════════════════════════════════════════════════════════════════════════
// [C] UPDATE _ProfileGlassHeader & _MiniDualRingAvatar — terima decorCtrl
// ════════════════════════════════════════════════════════════════════════

// GANTI class _MiniDualRingAvatar dengan versi baru di bawah:

class _MiniDualRingAvatar extends StatelessWidget {
  final AnimationController auraCtrl;
  final AnimationController crystalCtrl;
  final AnimationController crystalInnerCtrl;
  final AnimationController? decorCtrl; // ← baru, nullable agar backward-compat
  final String equippedFrameId;
  final String equippedDecoId; // ← baru
  final Uint8List? avatarBytes;

  const _MiniDualRingAvatar({
    required this.auraCtrl,
    required this.crystalCtrl,
    required this.crystalInnerCtrl,
    this.decorCtrl,
    required this.equippedFrameId,
    this.equippedDecoId = 'none',
    this.avatarBytes,
  });

  @override
  Widget build(BuildContext context) {
    const double size = 52;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Aura glow
          AnimatedBuilder(
            animation: auraCtrl,
            builder: (_, __) {
              final pulse = (math.sin(auraCtrl.value * math.pi * 2) + 1) / 2;
              final frameClr = _frameColor(equippedFrameId);
              return Container(
                width: size + pulse * 4,
                height: size + pulse * 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      frameClr.withOpacity(0.0),
                      frameClr.withOpacity(0.20 + pulse * 0.12),
                      Colors.transparent,
                    ],
                    stops: const [0.4, 0.72, 1.0],
                  ),
                ),
              );
            },
          ),
          // Dual contra-rotating rings
          AnimatedBuilder(
            animation: Listenable.merge([crystalCtrl, crystalInnerCtrl, auraCtrl]),
            builder: (_, __) {
              final pulse = (math.sin(auraCtrl.value * math.pi * 2) + 1) / 2;
              return CustomPaint(
                size: const Size(size, size),
                painter: _DualCrystalRingPainter(
                  outerT: crystalCtrl.value,
                  innerT: crystalInnerCtrl.value,
                  pulse: pulse,
                  frameId: equippedFrameId,
                ),
              );
            },
          ),
          // Avatar circle
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppTheme.highlight, AppTheme.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: _frameColor(equippedFrameId), width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: avatarBytes != null
                ? Image.memory(avatarBytes!, fit: BoxFit.cover)
                : const Icon(Icons.person_rounded, color: AppTheme.textPrimary, size: 18),
          ),
          // ── Avatar Decoration overlay (Discord-style) ──────────────────────
          if (decorCtrl != null && equippedDecoId != 'none')
            AnimatedBuilder(
              animation: decorCtrl!,
              builder: (_, __) => CustomPaint(
                size: const Size(size, size),
                painter: _AvatarDecorationPainter(
                  t: decorCtrl!.value,
                  decoId: equippedDecoId,
                  small: true, // mini variant — thinner strokes
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Color _frameColor(String frameId) {
    if (frameId.contains('Gold') || frameId.contains('gold')) return const Color(0xFFFFD700);
    if (frameId.contains('Sakura') || frameId.contains('sakura')) return AppTheme.highlight;
    if (frameId.contains('Crystal') || frameId.contains('crystal')) return const Color(0xFF7EB8F7);
    if (frameId.contains('Cosmic') || frameId.contains('cosmic')) return AppTheme.accent;
    return AppTheme.accent;
  }
}

// ════════════════════════════════════════════════════════════════════════
// [D] UPDATE _HeroHeader — tambah decorCtrl + overlay layer di avatar stack
// ════════════════════════════════════════════════════════════════════════

// Di _HeroHeader:
// 1. Tambah field:
//   final AnimationController? decorCtrl;
//   final String equippedDecoId;
// 2. Tambah di constructor:
//   this.decorCtrl,
//   this.equippedDecoId = 'none',

// 3. Di avatar Stack (setelah "Online dot" Positioned), TAMBAH layer baru:
//
//   // ── Decoration overlay ──────────────────────────────────────────
//   if (decorCtrl != null && equippedDecoId != 'none')
//     AnimatedBuilder(
//       animation: decorCtrl!,
//       builder: (_, __) => CustomPaint(
//         size: const Size(112, 112),
//         painter: _AvatarDecorationPainter(
//           t: decorCtrl!.value,
//           decoId: equippedDecoId,
//           small: false, // full-size variant
//         ),
//       ),
//     ),

// ════════════════════════════════════════════════════════════════════════
// [E] PAINTER BARU — tempel di akhir file profile_screen.dart
// ════════════════════════════════════════════════════════════════════════

/// Discord-style animated avatar decoration overlay.
/// Renders on top of the avatar and crystal rings.
/// [small] = true untuk mini header (52px), false untuk hero avatar (112px).
class _AvatarDecorationPainter extends CustomPainter {
  final double t;
  final String decoId;
  final bool small;

  const _AvatarDecorationPainter({
    required this.t,
    required this.decoId,
    this.small = false,
  });

  // Map decoration ID → base color
  Color get _decoColor {
    if (decoId.contains('Sakura') || decoId.contains('sakura')) return AppTheme.highlight;
    if (decoId.contains('Cyber') || decoId.contains('cyber'))   return const Color(0xFF00E5FF);
    if (decoId.contains('Golden') || decoId.contains('gold'))   return const Color(0xFFFFD700);
    // Wraithling default — deep violet/purple
    return const Color(0xFFB266FF);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final color = _decoColor;
    final pulse = (math.sin(t * math.pi * 2) + 1) / 2;
    final scale = small ? 0.47 : 1.0; // proportional shrink for mini

    // ── Route to style-specific painter ──────────────────────────────────────
    if (decoId.contains('Sakura') || decoId.contains('sakura')) {
      _paintSakuraBloom(canvas, size, c, color, pulse, scale);
    } else if (decoId.contains('Cyber') || decoId.contains('cyber')) {
      _paintCyberPulse(canvas, size, c, color, pulse, scale);
    } else if (decoId.contains('Golden') || decoId.contains('golden')) {
      _paintGoldenCelestial(canvas, size, c, color, pulse, scale);
    } else {
      // Default: Wraithling Cloak
      _paintWraithlingCloak(canvas, size, c, color, pulse, scale);
    }
  }

  // ── WRAITHLING CLOAK — dark wing arcs, violet tentacles ──────────────────
  void _paintWraithlingCloak(
    Canvas canvas, Size size, Offset c, Color color, double pulse, double scale
  ) {
    // 3-layer wing arcs per side
    for (int s = 0; s < 2; s++) {
      final sign = s == 0 ? -1.0 : 1.0;
      for (int layer = 0; layer < 3; layer++) {
        final layerT = (t + layer * 0.13) % 1.0;
        final lp = (math.sin(layerT * math.pi * 2) + 1) / 2;
        final alpha = (0.30 + lp * 0.50) * (1 - layer * 0.20);
        final sw = (3.5 - layer * 0.8) * scale;
        final arcR = size.width * (0.38 + layer * 0.08 + lp * 0.03) * scale;
        final sweepRad = (80.0 + lp * 40.0) * math.pi / 180;
        final baseAngle = sign > 0
            ? math.pi * 1.30 - sweepRad / 2 + (lp - 0.5) * 0.3
            : math.pi * 1.70 - sweepRad / 2 - (lp - 0.5) * 0.3;
        final rot = t * math.pi * 0.35 * sign;

        canvas.drawArc(
          Rect.fromCircle(center: c, radius: arcR),
          baseAngle + rot, sweepRad, false,
          Paint()
            ..color = color.withOpacity(alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = sw
            ..strokeCap = StrokeCap.round,
        );

        // Bright tip glint on outermost arc
        if (layer == 0) {
          final tipA = baseAngle + rot + sweepRad;
          final tx = c.dx + arcR * math.cos(tipA);
          final ty = c.dy + arcR * math.sin(tipA);
          final glintR = (4.0 + lp * 2.0) * scale;
          canvas.drawCircle(Offset(tx, ty), glintR,
              Paint()
                ..color = color.withOpacity(0.75 + lp * 0.20)
                ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * scale));
          canvas.drawCircle(Offset(tx, ty), glintR * 0.45,
              Paint()..color = Colors.white.withOpacity(0.90));
        }
      }
    }

    // Orbiting rune particles
    const pc = 10;
    final rng = math.Random(77);
    for (int i = 0; i < pc; i++) {
      final ba = (math.pi * 2 / pc) * i;
      final or_ = size.width * (0.40 + rng.nextDouble() * 0.10) * scale;
      final spd = i % 2 == 0 ? 0.55 : -0.40;
      final a = ba + t * math.pi * 2 * spd;
      final px = c.dx + or_ * math.cos(a);
      final py = c.dy + or_ * math.sin(a);
      final pa = (math.sin(t * math.pi * 3 + i) + 1) / 2;
      canvas.drawCircle(Offset(px, py), (2.2 + pa * 1.4) * scale,
          Paint()
            ..color = color.withOpacity(0.50 + pa * 0.40)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * scale));
    }

    // Crown halo arc (top glow)
    final haloR = size.width * 0.37 * scale;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: haloR),
      math.pi + 0.35, math.pi * 1.30, false,
      Paint()
        ..color = color.withOpacity(0.40 + pulse * 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5 * scale
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * scale),
    );
    // Bright inner halo line
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: haloR),
      math.pi + 0.35, math.pi * 1.30, false,
      Paint()
        ..color = Colors.white.withOpacity(0.30 + pulse * 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale
        ..strokeCap = StrokeCap.round,
    );
  }

  // ── SAKURA BLOOM HALO — petal arcs + cherry blossom particles ────────────
  void _paintSakuraBloom(
    Canvas canvas, Size size, Offset c, Color color, double pulse, double scale
  ) {
    // 5 petal-shaped arcs rotating slowly
    const petalCount = 5;
    for (int i = 0; i < petalCount; i++) {
      final baseA = (math.pi * 2 / petalCount) * i + t * math.pi * 0.25;
      final lp = (math.sin(t * math.pi * 2 + i * 0.8) + 1) / 2;
      final arcR = size.width * (0.36 + lp * 0.04) * scale;
      final sweepRad = 0.65 + lp * 0.15;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: arcR),
        baseA, sweepRad, false,
        Paint()
          ..color = color.withOpacity(0.35 + lp * 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (4.0 + lp * 2.0) * scale
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * scale),
      );
      // Petal end dot
      final ex = c.dx + arcR * math.cos(baseA + sweepRad);
      final ey = c.dy + arcR * math.sin(baseA + sweepRad);
      canvas.drawCircle(Offset(ex, ey), (3.5 + lp * 1.5) * scale,
          Paint()..color = color.withOpacity(0.70 + lp * 0.25)
                 ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * scale));
      canvas.drawCircle(Offset(ex, ey), 2.0 * scale,
          Paint()..color = Colors.white.withOpacity(0.80));
    }

    // Floating sakura petals (small diamond/petal shapes)
    final rng = math.Random(42);
    for (int i = 0; i < 8; i++) {
      final orbitR = size.width * (0.35 + rng.nextDouble() * 0.12) * scale;
      final a = (math.pi * 2 / 8) * i + t * math.pi * 0.5 * (i % 2 == 0 ? 1 : -0.6);
      final px = c.dx + orbitR * math.cos(a);
      final py = c.dy + orbitR * math.sin(a);
      final pa = (math.sin(t * math.pi * 4 + i) + 1) / 2;
      // Mini petal: two intersecting arcs
      final pr = (3.0 + pa * 1.5) * scale;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(px, py), width: pr * 1.6, height: pr),
        Paint()..color = color.withOpacity(0.55 + pa * 0.35),
      );
    }
  }

  // ── CYBER PULSE RING — neon scan-line rings expanding outward ─────────────
  void _paintCyberPulse(
    Canvas canvas, Size size, Offset c, Color color, double pulse, double scale
  ) {
    // 2 expanding pulse rings
    for (int ring = 0; ring < 2; ring++) {
      final rt = (t + ring * 0.5) % 1.0;
      final ringR = size.width * (0.32 + rt * 0.18) * scale;
      final alpha = (1.0 - rt) * 0.65;
      canvas.drawCircle(c, ringR, Paint()
        ..color = color.withOpacity(alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (3.5 - rt * 2.5) * scale);
    }

    // Rotating segmented ring (dashed neon)
    final segR = size.width * 0.38 * scale;
    const segCount = 8;
    const segAngle = math.pi * 2 / segCount;
    final rot = t * math.pi * 2;
    for (int i = 0; i < segCount; i++) {
      final sa = segAngle * i + rot;
      final lp = (math.sin(t * math.pi * 4 + i) + 1) / 2;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: segR),
        sa, segAngle * 0.55, false,
        Paint()
          ..color = color.withOpacity(0.55 + lp * 0.40)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0 * scale
          ..strokeCap = StrokeCap.round,
      );
    }

    // Scanline glint orbiting fast
    final glintA = t * math.pi * 4;
    final gx = c.dx + segR * math.cos(glintA);
    final gy = c.dy + segR * math.sin(glintA);
    canvas.drawCircle(Offset(gx, gy), 5.0 * scale,
        Paint()..color = color..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * scale));
    canvas.drawCircle(Offset(gx, gy), 2.5 * scale,
        Paint()..color = Colors.white);
  }

  // ── GOLDEN CELESTIAL — angelic arc + sparkle stars ────────────────────────
  void _paintGoldenCelestial(
    Canvas canvas, Size size, Offset c, Color color, double pulse, double scale
  ) {
    // Top halo — thick gold ring arc
    final haloR = size.width * 0.34 * scale;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: haloR),
      math.pi + 0.20, math.pi * 1.60, false,
      Paint()
        ..color = color.withOpacity(0.50 + pulse * 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.5 * scale
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * scale),
    );
    // Gold bright outline
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: haloR),
      math.pi + 0.20, math.pi * 1.60, false,
      Paint()
        ..color = Colors.white.withOpacity(0.60 + pulse * 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 * scale
        ..strokeCap = StrokeCap.round,
    );

    // Rotating 4-point star sparkles around avatar
    const starCount = 6;
    final rng = math.Random(17);
    for (int i = 0; i < starCount; i++) {
      final baseA = (math.pi * 2 / starCount) * i;
      final or_ = size.width * (0.36 + rng.nextDouble() * 0.08) * scale;
      final a = baseA + t * math.pi * 0.60;
      final sx = c.dx + or_ * math.cos(a);
      final sy = c.dy + or_ * math.sin(a);
      final sp = (math.sin(t * math.pi * 3 + i * 1.2) + 1) / 2;
      final sr = (4.0 + sp * 3.0) * scale;
      // Draw 4-point star
      for (int arm = 0; arm < 4; arm++) {
        final armA = math.pi / 2 * arm + t * math.pi;
        canvas.drawLine(
          Offset(sx, sy),
          Offset(sx + math.cos(armA) * sr, sy + math.sin(armA) * sr),
          Paint()
            ..color = color.withOpacity(0.70 + sp * 0.25)
            ..strokeWidth = 2.0 * scale
            ..strokeCap = StrokeCap.round,
        );
      }
      // Center dot
      canvas.drawCircle(Offset(sx, sy), 2.2 * scale,
          Paint()..color = Colors.white.withOpacity(0.85));
    }
  }

  @override
  bool shouldRepaint(_AvatarDecorationPainter o) => o.t != t || o.decoId != decoId;
}
