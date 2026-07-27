// ══════════════════════════════════════════════════════════════════════════════
// PATCH: vault_screen.dart — Avatar Decoration category
// Cara pakai: tempel masing-masing blok ke lokasi yang ditandai di file asli
// ══════════════════════════════════════════════════════════════════════════════

// ── [1] GANTI baris ini di _categoryLabels: ──────────────────────────────────
//    'Emote'  : 'Emote',
// };
// DENGAN:
//    'Emote'  : 'Emote',
//    'Deco'   : 'Dekorasi Avatar',
// };

// ── [2] GANTI baris ini: ─────────────────────────────────────────────────────
//    const _categories = ['Border', 'BG', 'FX', 'Badge', 'Pass', 'Banner', 'Bubble', 'Emote'];
// DENGAN:
//    const _categories = ['Border', 'BG', 'FX', 'Badge', 'Pass', 'Banner', 'Bubble', 'Emote', 'Deco'];

// ── [3] TAMBAH items baru setelah blok Emote di _allShopItems: ───────────────
//    (setelah baris: _ShopItem('Sleepy Panda', 'Emote', ...),)
//    TAMBAH:
//
//  // ── Avatar Decoration ─────────────────────────────────────────────────────
//  _ShopItem('Wraithling Cloak',  'Avatar Deco',   'Legendary', 'Owned',    Icons.flourish,                     Color(0xFFB266FF), true,  'Deco'),
//  _ShopItem('Sakura Bloom Halo', 'Avatar Deco',   'Premium',   '380 Gems', Icons.local_florist_rounded,        Color(0xFFFF6BA8), false, 'Deco'),
//  _ShopItem('Cyber Pulse Ring',  'Avatar Deco',   'Exclusive', '520 Gems', Icons.electric_bolt_rounded,        Color(0xFF00E5FF), false, 'Deco'),
//  _ShopItem('Golden Celestial',  'Avatar Deco',   'Rare',      '260 Gems', Icons.auto_awesome_rounded,         Color(0xFFFFD700), false, 'Deco'),
//
// Catatan: Icons.flourish tidak ada di Flutter Material; pakai Icons.auto_awesome_motion_rounded untuk Wraithling.
// Replace Icons.flourish → Icons.auto_awesome_motion_rounded

// ── [4] TAMBAH di _equippedPerCategory map (di _VaultScreenState.initState area):
//    'Deco': 'Wraithling Cloak',

// ── [5] GANTI _categoryPainter factory:
//    (ganti baris: default: return _FxPreviewPainter(t, color); }})
// DENGAN:
//    case 'Deco':   return _DecorationPreviewPainter(t, color);
//    default:       return _FxPreviewPainter(t, color);
//  }}

// ══════════════════════════════════════════════════════════════════════════════
// PAINTER BARU — tempel setelah _BubblePreviewPainter (sebelum baris terakhir file)
// ══════════════════════════════════════════════════════════════════════════════

// ignore: unused_element
class _DecorationPreviewPainter extends CustomPainter {
  final Color color;
  final double t;
  _DecorationPreviewPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final pulse = (math.sin(t * math.pi * 2) + 1) / 2;

    // ── Avatar placeholder circle ────────────────────────────────────────────
    canvas.drawCircle(c, size.width * 0.22, Paint()
      ..color = color.withOpacity(0.18)
      ..style = PaintingStyle.fill);
    canvas.drawCircle(c, size.width * 0.22, Paint()
      ..color = color.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
    // Person icon
    canvas.drawCircle(Offset(c.dx, c.dy - size.width * 0.07), size.width * 0.055,
        Paint()..color = Colors.white.withOpacity(0.75));
    final bodyPath = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(c.dx, c.dy + size.width * 0.065),
          width: size.width * 0.17,
          height: size.width * 0.11));
    canvas.drawPath(bodyPath, Paint()..color = Colors.white.withOpacity(0.75));

    // ── Wraithling-style animated wing arcs ──────────────────────────────────
    // 3 layered arcs per side, rotating outward and back like a cloak/wings
    const sides = 2; // left & right
    for (int s = 0; s < sides; s++) {
      final sign = s == 0 ? -1.0 : 1.0; // left = -1, right = +1

      for (int layer = 0; layer < 3; layer++) {
        final layerT = (t + layer * 0.15) % 1.0;
        final layerPulse = (math.sin(layerT * math.pi * 2) + 1) / 2;
        final alpha = (0.25 + layerPulse * 0.45) * (1 - layer * 0.18);
        final strokeW = 2.8 - layer * 0.6;

        // Wing arc radius grows outward
        final arcR = size.width * (0.28 + layer * 0.09 + layerPulse * 0.04);

        // Sweep angle: wide at pulse peak, narrow at trough
        final sweepDeg = 75.0 + layerPulse * 35.0;
        final sweepRad = sweepDeg * math.pi / 180;

        // Base angle faces outward from avatar, tilted slightly upward
        // Right side: starts at ~230° and sweeps upward
        // Left side: starts at ~-50° (mirror)
        final baseAngle = sign > 0
            ? (math.pi * 1.28 - sweepRad / 2) + (layerPulse - 0.5) * 0.25
            : (math.pi * 1.72 - sweepRad / 2) - (layerPulse - 0.5) * 0.25;

        // Slow subtle rotation over time
        final rotation = t * math.pi * 0.4 * sign;

        canvas.drawArc(
          Rect.fromCircle(center: c, radius: arcR),
          baseAngle + rotation,
          sweepRad,
          false,
          Paint()
            ..color = color.withOpacity(alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW
            ..strokeCap = StrokeCap.round,
        );

        // Glowing tip dot at arc end
        if (layer == 0) {
          final tipAngle = baseAngle + rotation + sweepRad;
          final tx = c.dx + arcR * math.cos(tipAngle);
          final ty = c.dy + arcR * math.sin(tipAngle);
          canvas.drawCircle(Offset(tx, ty), 3.5 + layerPulse * 1.5,
              Paint()
                ..color = color.withOpacity(0.70 + layerPulse * 0.25)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
          canvas.drawCircle(Offset(tx, ty), 2.0,
              Paint()..color = Colors.white.withOpacity(0.85));
        }
      }
    }

    // ── Floating rune particles orbiting the avatar ──────────────────────────
    const particleCount = 8;
    final rng = math.Random(99);
    for (int i = 0; i < particleCount; i++) {
      final baseAngle = (math.pi * 2 / particleCount) * i;
      final orbitR = size.width * (0.30 + rng.nextDouble() * 0.10);
      final speed = (i % 2 == 0 ? 1.0 : -0.7); // alternating directions
      final angle = baseAngle + t * math.pi * 2 * speed * 0.5;
      final px = c.dx + orbitR * math.cos(angle);
      final py = c.dy + orbitR * math.sin(angle);
      final pa = (math.sin(t * math.pi * 2 * 1.5 + i) + 1) / 2;
      canvas.drawCircle(Offset(px, py), 1.8 + pa * 1.2,
          Paint()
            ..color = color.withOpacity(0.45 + pa * 0.40)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
    }

    // ── Top crown arc (glowing halo above avatar) ─────────────────────────────
    final haloR = size.width * 0.27;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: haloR),
      math.pi + 0.4,                   // start (below left)
      math.pi * 1.2,                   // sweep (above, wrapping right)
      false,
      Paint()
        ..color = color.withOpacity(0.35 + pulse * 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(_DecorationPreviewPainter o) => o.t != t;
}
