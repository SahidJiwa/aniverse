// vault_screen.dart — AniVerse Vault V3
// Upgraded: custom painter visual preview per cosmetic category

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'app_theme.dart';
import 'widgets/dashboard_sections.dart';


const _categoryLabels = {
  'Border' : 'Frame Avatar',
  'BG'     : 'Background',
  'FX'     : 'Efek Profil',
  'Badge'  : 'Badge',
  'Pass'   : 'Season Pass',
  'Banner' : 'Banner Profil',
  'Bubble' : 'Bubble Chat',
  'Emote'  : 'Emote',
  'Deco'   : 'Dekorasi Avatar',
};

// ── Rarity config ─────────────────────────────────────────────────────────────
class _Rarity {
  final String label;
  final Color color;
  final Color bg;           // card background
  final Color badgeBg;      // rarity badge background
  final Color glow;         // box shadow glow
  const _Rarity(this.label, this.color, this.bg, this.badgeBg, this.glow);
}
const _rarities = {
  'Legendary': _Rarity('Legendary', Color(0xFFFF2D78), Color(0xFF1A0618), Color(0xFF3D0A20), Color(0xFFFF2D78)),
  'Limited':   _Rarity('Limited',   Color(0xFFC084FC), Color(0xFF120A22), Color(0xFF2A1050), Color(0xFFC084FC)),
  'Premium':   _Rarity('Premium',   Color(0xFF00E5FF), Color(0xFF061820), Color(0xFF083040), Color(0xFF00E5FF)),
  'Exclusive': _Rarity('Exclusive', Color(0xFFFFD700), Color(0xFF1A1400), Color(0xFF3D2E00), Color(0xFFFFD700)),
  'Rare':      _Rarity('Rare',      Color(0xFF9D4EDD), Color(0xFF0F0A1E), Color(0xFF220D48), Color(0xFF9D4EDD)),
  'Common':    _Rarity('Common',    Color(0xFF7C7299), Color(0xFF0E0D14), Color(0xFF1C1828), Color(0xFF7C7299)),
};

// ── Shop item model ───────────────────────────────────────────────────────────
class _ShopItem {
  final String name;
  final String type;
  final String rarity;
  final String price;
  final IconData icon;
  final Color color;
  final bool owned;
  final String category;
  final String? frameId; // for Border category — maps to _frameConfigs key
  const _ShopItem(this.name, this.type, this.rarity, this.price, this.icon, this.color, this.owned, this.category, {this.frameId});
}

const _allShopItems = [
  _ShopItem('Sakura Emperor',  'Avatar Border', 'Legendary', 'Owned',    Icons.radio_button_checked_rounded, Color(0xFFFF6B9D), true,  'Border', frameId: 'frame_sakura'),
  _ShopItem('Cyberpunk Neon',  'Avatar Border', 'Premium',   '420 Gems', Icons.electric_bolt_rounded,        Color(0xFF00FFCC), false, 'Border', frameId: 'frame_neon'),
  _ShopItem('Demon Slayer',    'Avatar Border', 'Exclusive', '580 Gems', Icons.local_fire_department_rounded, Color(0xFFFF3A1A), false, 'Border', frameId: 'frame_demon'),
  _ShopItem('Dragon Flame',    'Avatar Border', 'Legendary', '680 Gems', Icons.whatshot_rounded,              Color(0xFFFF5722), false, 'Border', frameId: 'frame_dragon'),
  _ShopItem('Moonlit Shrine',  'Avatar Border', 'Rare',      '280 Gems', Icons.brightness_3_rounded,          Color(0xFF9B8BFF), false, 'Border', frameId: 'frame_shrine'),
  _ShopItem('Cosmic Nebula',   'Avatar Border', 'Exclusive', '620 Gems', Icons.auto_awesome_rounded,          Color(0xFFE040FB), false, 'Border', frameId: 'frame_nebula'),
  _ShopItem('Thunder God',     'Avatar Border', 'Legendary', '720 Gems', Icons.flash_on_rounded,              Color(0xFFFFEA00), false, 'Border', frameId: 'frame_thunder'),
  _ShopItem('Wraithling Cloak','Avatar Border', 'Premium',   '380 Gems', Icons.blur_on_rounded,               Color(0xFF7C4DFF), false, 'Border', frameId: 'frame_wraith'),
  _ShopItem('Moonlit Shrine',       'Profile BG',    'Limited',   '480 Gems', Icons.wallpaper_rounded,            Color(0xFFC084FC), false, 'BG'),
  _ShopItem('Cosmic Nebula',        'Profile BG',    'Exclusive', 'Owned',    Icons.auto_awesome_motion_rounded,  Color(0xFF7C3AED), true,  'BG'),
  _ShopItem('Cherry Blossom Garden','Profile BG',    'Rare',      '320 Gems', Icons.local_florist_rounded,        Color(0xFFFF6BA8), false, 'BG'),
  _ShopItem('Falling Sakura Aura',  'Profile FX',    'Premium',   '320 Gems', Icons.auto_awesome_rounded,         Color(0xFF00E5FF), false, 'FX'),
  _ShopItem('Galaxy Sparkle',       'Profile FX',    'Legendary', '540 Gems', Icons.star_rounded,                 Color(0xFFFF2D78), false, 'FX'),
  _ShopItem('Storm Lightning',      'Profile FX',    'Rare',      '240 Gems', Icons.flash_on_rounded,             Color(0xFF9D4EDD), false, 'FX'),
  _ShopItem('Founder Crest',        'Profile Badge', 'Exclusive', 'Owned',    Icons.workspace_premium_rounded,    Color(0xFFFFD700), true,  'Badge'),
  _ShopItem('Season 1 Champion',    'Profile Badge', 'Legendary', '600 Gems', Icons.emoji_events_rounded,         Color(0xFFFF2D78), false, 'Badge'),
  _ShopItem('Elite Watcher',        'Profile Badge', 'Rare',      '180 Gems', Icons.visibility_rounded,           Color(0xFF9D4EDD), false, 'Badge'),
  _ShopItem('Season 1 Pass',        'Premium Pass',  'Rare',      '240 Gems', Icons.card_membership_rounded,      Color(0xFF9D4EDD), false, 'Pass'),
  _ShopItem('Annual Sakura Pass',   'Premium Pass',  'Legendary', '980 Gems', Icons.diamond_rounded,              Color(0xFFFF2D78), false, 'Pass'),
  // ── Banner ────────────────────────────────────────────────────────────────
  _ShopItem('Sakura Horizon',       'Profile Banner','Legendary', 'Owned',    Icons.panorama_rounded,             Color(0xFFFF2D78), true,  'Banner'),
  _ShopItem('Galaxy Drift',         'Profile Banner','Exclusive', '580 Gems', Icons.auto_awesome_motion_rounded,  Color(0xFF7C3AED), false, 'Banner'),
  _ShopItem('Cyber City Night',     'Profile Banner','Premium',   '380 Gems', Icons.location_city_rounded,        Color(0xFF00E5FF), false, 'Banner'),
  _ShopItem('Forest Spirit',        'Profile Banner','Rare',      '220 Gems', Icons.forest_rounded,               Color(0xFF6ECC8E), false, 'Banner'),
  // ── Bubble Chat ───────────────────────────────────────────────────────────
  _ShopItem('Sakura Petal',         'Bubble Chat',   'Legendary', 'Owned',    Icons.chat_bubble_rounded,          Color(0xFFFF6BA8), true,  'Bubble'),
  _ShopItem('Neon Glow',            'Bubble Chat',   'Premium',   '280 Gems', Icons.chat_bubble_outline_rounded,  Color(0xFF00E5FF), false, 'Bubble'),
  _ShopItem('Golden Frame',         'Bubble Chat',   'Exclusive', '450 Gems', Icons.mark_chat_read_rounded,       Color(0xFFFFD700), false, 'Bubble'),
  _ShopItem('Dark Matter',          'Bubble Chat',   'Rare',      '160 Gems', Icons.chat_rounded,                 Color(0xFF9D4EDD), false, 'Bubble'),
  // ── Emote ─────────────────────────────────────────────────────────────────
  _ShopItem('Sakura Dance',         'Emote',         'Legendary', 'Owned',    Icons.self_improvement_rounded,     Color(0xFFFF6BA8), true,  'Emote'),
  _ShopItem('Thunder Clap',         'Emote',         'Premium',   '200 Gems', Icons.flash_on_rounded,             Color(0xFF00E5FF), false, 'Emote'),
  _ShopItem('Galaxy Spin',          'Emote',         'Exclusive', '420 Gems', Icons.rotate_right_rounded,         Color(0xFF7C3AED), false, 'Emote'),
  _ShopItem('Sleepy Panda',         'Emote',         'Rare',      '140 Gems', Icons.bedtime_rounded,              Color(0xFF9D4EDD), false, 'Emote'),
  // ── Avatar Decoration ─────────────────────────────────────────────────────
  _ShopItem('Wraithling Cloak',     'Avatar Deco',   'Legendary', 'Owned',    Icons.auto_awesome_motion_rounded,  Color(0xFFB266FF), true,  'Deco'),
  _ShopItem('Sakura Bloom Halo',    'Avatar Deco',   'Premium',   '380 Gems', Icons.local_florist_rounded,        Color(0xFFFF6BA8), false, 'Deco'),
  _ShopItem('Cyber Pulse Ring',     'Avatar Deco',   'Exclusive', '520 Gems', Icons.electric_bolt_rounded,        Color(0xFF00E5FF), false, 'Deco'),
  _ShopItem('Golden Celestial',     'Avatar Deco',   'Rare',      '260 Gems', Icons.auto_awesome_rounded,         Color(0xFFFFD700), false, 'Deco'),
];

const _categories = ['Border', 'BG', 'FX', 'Badge', 'Pass', 'Banner', 'Bubble', 'Emote', 'Deco'];

// ─────────────────────────────────────────────────────────────────────────────
// VAULT SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class VaultScreen extends StatefulWidget {
  final Map<String, String> equipped;
  final void Function(String category, String itemName) onEquip;
  const VaultScreen({super.key, required this.equipped, required this.onEquip});
  @override State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> with TickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late AnimationController _shimmerCtrl;
  late AnimationController _equipFlashCtrl;
  int _selectedCategory = 0;
  int _selectedItem = 0;
  int _userGems = 12480;

  // Per-category equipped item name. Default: owned items.
  final Map<String, String> _equippedPerCategory = {
    'Border': 'Sakura Emperor Frame',
    'BG':     'Cosmic Nebula',
    'Badge':  'Founder Crest',
    'Banner': 'Sakura Horizon',
    'Bubble': 'Sakura Petal',
    'Emote':  'Sakura Dance',
    'Deco':   'Wraithling Cloak',
  };

  List<_ShopItem> get _filteredItems =>
      _allShopItems.where((e) => e.category == _categories[_selectedCategory]).toList();

  _ShopItem get _previewItem {
    final list = _filteredItems;
    return list.isEmpty ? _allShopItems.first : list[_selectedItem.clamp(0, list.length - 1)];
  }

  bool _isEquipped(_ShopItem item) =>
      _equippedPerCategory[item.category] == item.name;

  @override
  void initState() {
    super.initState();
    _glowCtrl    = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _equipFlashCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    // Seed from shared MainWrapper state
    _equippedPerCategory.addAll(widget.equipped);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _shimmerCtrl.dispose();
    _equipFlashCtrl.dispose();
    super.dispose();
  }

  void _onCategorySelect(int index) => setState(() { _selectedCategory = index; _selectedItem = 0; });

  // Equip an owned item
  void _equipItem(_ShopItem item) {
    setState(() => _equippedPerCategory[item.category] = item.name);
    widget.onEquip(item.category, item.name); // sync to MainWrapper → ProfileScreen
    _equipFlashCtrl.forward(from: 0);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: AppTheme.textPrimary, size: 16),
        const SizedBox(width: 8),
        Text('${item.name} dipasang!', style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
      backgroundColor: const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
    ));
  }

  // Buy confirmation bottom sheet
  void _showBuySheet(_ShopItem item) {
    final priceNum = int.tryParse(item.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BuyConfirmSheet(
        item: item,
        userGems: _userGems,
        priceNum: priceNum,
        onConfirm: () {
          Navigator.pop(ctx);
          if (_userGems >= priceNum) {
            setState(() => _userGems -= priceNum);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(children: [
                const Icon(Icons.diamond_rounded, color: AppTheme.textPrimary, size: 16),
                const SizedBox(width: 8),
                Text('\${item.name} berhasil dibeli!', style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
              backgroundColor: const Color(0xFF9D4EDD),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            ));
          }
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }

  // Top Up bottom sheet
  void _showTopUpSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TopUpSheet(
        userGems: _userGems,
        onBuy: (gems, cost) {
          Navigator.pop(ctx);
          setState(() => _userGems += gems);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('+\$gems Gems ditambahkan!', style: const TextStyle(fontWeight: FontWeight.w700)),
            backgroundColor: const Color(0xFFFFD700),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          ));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq      = MediaQuery.of(context);
    final safeTop = mq.padding.top;
    final safeBot = mq.padding.bottom;
    final kTopH   = 96.0 + safeTop;
    final kDockH  = 92.0 + safeBot;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowCtrl,
              builder: (_, __) => CustomPaint(painter: _VaultBgPainter(_glowCtrl.value)),
            ),
          ),
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(top: kTopH, bottom: kDockH + 24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    _SakuraCoinCard(glowAnim: _glowCtrl, gems: _userGems, onTopUp: _showTopUpSheet),
                    const SizedBox(height: 28),
                    _ShopHeader(
                      categories: _categories,
                      selectedIndex: _selectedCategory,
                      onSelect: _onCategorySelect,
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(anim),
                          child: child,
                        ),
                      ),
                      child: _CosmeticPreview(
                        key: ValueKey(_previewItem.name),
                        item: _previewItem,
                        shimmerCtrl: _shimmerCtrl,
                        isEquipped: _isEquipped(_previewItem),
                        onEquip: _previewItem.owned ? () => _equipItem(_previewItem) : null,
                        onBuy: _previewItem.owned ? null : () => _showBuySheet(_previewItem),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ShopGrid(
                      items: _filteredItems,
                      selectedIndex: _selectedItem,
                      shimmerCtrl: _shimmerCtrl,
                      equippedPerCategory: _equippedPerCategory,
                      onSelect: (i) => setState(() => _selectedItem = i),
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel(label: 'KOLEKSI KAMU'),
                    const SizedBox(height: 14),
                    const CollectionSection(),
                    const SizedBox(height: 28),
                    _SectionLabel(label: 'KOSMETIK'),
                    const SizedBox(height: 14),
                    const _OwnedCosmeticsGrid(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0, left: 0, right: 0,
            child: Padding(
              padding: EdgeInsets.only(top: safeTop + 8, left: 16, right: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.surfaceElevated.withOpacity(0.94),
                          AppTheme.surface.withOpacity(0.86),
                          AppTheme.background.withOpacity(0.72),
                        ],
                      ),
                      border: Border.all(color: AppTheme.textPrimary.withOpacity(0.1)),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withOpacity(0.10),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.accent, Color.lerp(AppTheme.accent, AppTheme.highlight, 0.5)!],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.diamond_rounded, color: AppTheme.textPrimary, size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vault Kosmetik',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                'Koleksi & shop eksklusif',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _showTopUpSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.highlight, AppTheme.glow],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.local_florist_rounded, color: AppTheme.textPrimary, size: 12),
                              const SizedBox(width: 5),
                              Text(
                                _fmtGems(_userGems),
                                style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w900),
                              ),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY VISUAL PAINTERS
// ─────────────────────────────────────────────────────────────────────────────

// Border — animated concentric rings around a mini avatar circle
class _BorderPreviewPainter extends CustomPainter {
  final double t;
  final Color color;
  _BorderPreviewPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final pulse = (math.sin(t * math.pi * 2) + 1) / 2;

    // Outer ambient glow layers
    for (int i = 3; i >= 1; i--) {
      final r = size.width * (0.35 + i * 0.07);
      final alpha = (0.18 - i * 0.03 + pulse * 0.08).clamp(0.0, 1.0);
      canvas.drawCircle(c, r, Paint()
        ..color = color.withOpacity( alpha)
        ..style = PaintingStyle.fill);
    }
    // Main spinning dashed ring
    final ringR = size.width * 0.40;
    final dashPaint = Paint()
      ..color = color.withOpacity( 0.75 + pulse * 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    const segCount = 12;
    const segAngle = math.pi * 2 / segCount;
    for (int i = 0; i < segCount; i++) {
      final startA = segAngle * i + t * math.pi * 2;
      final sweepA = segAngle * 0.6;
      canvas.drawArc(Rect.fromCircle(center: c, radius: ringR), startA, sweepA, false, dashPaint);
    }
    // Inner secondary ring
    canvas.drawCircle(c, ringR * 0.78, Paint()
      ..color = color.withOpacity( 0.30 + pulse * 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0);
    // Spinning glint
    final glintA = t * math.pi * 2;
    final gx = c.dx + ringR * math.cos(glintA);
    final gy = c.dy + ringR * math.sin(glintA);
    canvas.drawCircle(Offset(gx, gy), 4.5, Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(Offset(gx, gy), 2.5, Paint()..color = Colors.white);

    // Avatar circle with filled gradient
    canvas.drawCircle(c, size.width * 0.26, Paint()
      ..shader = RadialGradient(colors: [
        color.withOpacity( 0.65),
        color.withOpacity( 0.20),
      ]).createShader(Rect.fromCircle(center: c, radius: size.width * 0.26)));
    canvas.drawCircle(c, size.width * 0.26, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = color.withOpacity( 0.85 + pulse * 0.12));
    // Person icon silhouette — white, fully opaque
    final iconPaint = Paint()..color = Colors.white.withOpacity( 0.90);
    canvas.drawCircle(Offset(c.dx, c.dy - size.width * 0.08), size.width * 0.07, iconPaint);
    final bodyPath = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(c.dx, c.dy + size.width * 0.08),
          width: size.width * 0.22,
          height: size.width * 0.14));
    canvas.drawPath(bodyPath, iconPaint);
  }

  @override
  bool shouldRepaint(_BorderPreviewPainter old) => old.t != t;
}

// BG — layered gradient landscape with floating particles
class _BgPreviewPainter extends CustomPainter {
  final double t;
  final Color color;
  _BgPreviewPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final pulse = (math.sin(t * math.pi * 2) + 1) / 2;

    // Sky gradient — boosted alpha
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withOpacity( 0.55), color.withOpacity( 0.12)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.65));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.65), skyPaint);

    // Mountain silhouettes — much more visible
    void drawMtn(double x, double topY, double w, double alpha) {
      final path = Path()
        ..moveTo(x, size.height * 0.62)
        ..lineTo(x + w * 0.5, topY)
        ..lineTo(x + w, size.height * 0.62)
        ..close();
      canvas.drawPath(path, Paint()..color = color.withOpacity( alpha));
    }
    drawMtn(size.width * 0.0,  size.height * 0.28, size.width * 0.5, 0.60);
    drawMtn(size.width * 0.3,  size.height * 0.18, size.width * 0.45, 0.45);
    drawMtn(size.width * 0.55, size.height * 0.25, size.width * 0.5, 0.52);

    // Ground plane
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.60, size.width, size.height * 0.40),
      Paint()..color = color.withOpacity( 0.30),
    );

    // Stars / particles — boosted
    final rng = math.Random(42);
    for (int i = 0; i < 18; i++) {
      final sx = rng.nextDouble() * size.width;
      final sy = rng.nextDouble() * size.height * 0.55;
      final sa = (math.sin(t * math.pi * 2 + i) + 1) / 2;
      canvas.drawCircle(Offset(sx, sy), 1.4 + rng.nextDouble(),
          Paint()..color = Colors.white.withOpacity( 0.35 + sa * 0.50));
    }

    // Moon — vivid
    final moonX = size.width * 0.78;
    final moonY = size.height * 0.18;
    canvas.drawCircle(Offset(moonX, moonY), size.width * 0.08,
        Paint()..color = color.withOpacity( 0.60 + pulse * 0.20)
               ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawCircle(Offset(moonX, moonY), size.width * 0.065,
        Paint()..color = Colors.white.withOpacity( 0.75 + pulse * 0.20));
  }

  @override
  bool shouldRepaint(_BgPreviewPainter old) => old.t != t;
}


// FX — particle burst / sparkles radiating from center
class _FxPreviewPainter extends CustomPainter {
  final double t;
  final Color color;
  _FxPreviewPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final pulse = (math.sin(t * math.pi * 2) + 1) / 2;

    // Soft core glow — boosted
    canvas.drawCircle(c, size.width * 0.14 + pulse * 5, Paint()
      ..color = color.withOpacity( 0.50 + pulse * 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));

    // Radiating rays — vivid
    const rayCount = 8;
    for (int i = 0; i < rayCount; i++) {
      final angle = (math.pi * 2 / rayCount) * i + t * math.pi * 2 * 0.3;
      final len = size.width * (0.26 + pulse * 0.07);
      final x2 = c.dx + len * math.cos(angle);
      final y2 = c.dy + len * math.sin(angle);
      canvas.drawLine(c, Offset(x2, y2), Paint()
        ..color = color.withOpacity( 0.55 + pulse * 0.30)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round);
    }

    // Orbiting particles — vivid
    const particleCount = 12;
    final rng = math.Random(7);
    for (int i = 0; i < particleCount; i++) {
      final baseAngle = (math.pi * 2 / particleCount) * i;
      final orbitR = size.width * (0.28 + rng.nextDouble() * 0.12);
      final speed = 0.5 + rng.nextDouble() * 0.8;
      final angle = baseAngle + t * math.pi * 2 * speed;
      final px = c.dx + orbitR * math.cos(angle);
      final py = c.dy + orbitR * math.sin(angle);
      final particleA = (math.sin(t * math.pi * 4 + i) + 1) / 2;
      final pSize = 2.0 + rng.nextDouble() * 3.0;
      canvas.drawCircle(Offset(px, py), pSize,
          Paint()..color = Colors.white.withOpacity( 0.55 + particleA * 0.40));
    }

    // 4-point star sparkles — vivid
    void drawStar(double x, double y, double r, double alpha) {
      final p = Paint()..color = Colors.white.withOpacity( alpha);
      for (int i = 0; i < 4; i++) {
        final a = math.pi / 2 * i + t * math.pi;
        canvas.drawLine(
          Offset(x - math.cos(a) * r * 0.3, y - math.sin(a) * r * 0.3),
          Offset(x + math.cos(a) * r, y + math.sin(a) * r),
          p..strokeWidth = 2.0..strokeCap = StrokeCap.round,
        );
      }
    }
    final rng2 = math.Random(13);
    for (int i = 0; i < 6; i++) {
      final sx = size.width * (0.12 + rng2.nextDouble() * 0.76);
      final sy = size.height * (0.1 + rng2.nextDouble() * 0.8);
      final sa = (math.sin(t * math.pi * 2 * 1.5 + i * 1.3) + 1) / 2;
      drawStar(sx, sy, 5 + rng2.nextDouble() * 5, 0.40 + sa * 0.55);
    }
  }

  @override
  bool shouldRepaint(_FxPreviewPainter old) => old.t != t;
}

// Badge — layered emblem with radiating glory lines
class _BadgePreviewPainter extends CustomPainter {
  final double t;
  final Color color;
  _BadgePreviewPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final pulse = (math.sin(t * math.pi * 2) + 1) / 2;

    // Glory rays behind shield
    const rayCount = 16;
    for (int i = 0; i < rayCount; i++) {
      final angle = (math.pi * 2 / rayCount) * i;
      final innerR = size.width * 0.22;
      final outerR = size.width * (0.38 + pulse * 0.04);
      canvas.drawLine(
        Offset(c.dx + innerR * math.cos(angle), c.dy + innerR * math.sin(angle)),
        Offset(c.dx + outerR * math.cos(angle), c.dy + outerR * math.sin(angle)),
        Paint()
          ..color = color.withOpacity( 0.45 + pulse * 0.25)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // Outer glow disc
    canvas.drawCircle(c, size.width * 0.26, Paint()
      ..color = color.withOpacity( 0.40 + pulse * 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));

    // Shield shape
    final shield = Path();
    final sw = size.width * 0.32;
    final sh = size.height * 0.38;
    final sl = c.dx - sw / 2;
    final st = c.dy - sh / 2;
    shield.moveTo(c.dx, st);
    shield.lineTo(sl + sw, st);
    shield.lineTo(sl + sw, st + sh * 0.65);
    shield.quadraticBezierTo(sl + sw, st + sh, c.dx, st + sh);
    shield.quadraticBezierTo(sl, st + sh, sl, st + sh * 0.65);
    shield.lineTo(sl, st);
    shield.close();

    // Shield fill
    canvas.drawPath(shield, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withOpacity( 0.70 + pulse * 0.20), color.withOpacity( 0.35)],
      ).createShader(Rect.fromLTWH(sl, st, sw, sh)));

    // Shield border
    canvas.drawPath(shield, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = Colors.white.withOpacity( 0.80 + pulse * 0.18));

    // Star in center
    final starR = size.width * 0.10;
    final starPath = Path();
    for (int i = 0; i < 5; i++) {
      final outerA = math.pi / 2 * 3 + (math.pi * 2 / 5) * i;
      final innerA = outerA + math.pi / 5;
      final ox = c.dx + starR * math.cos(outerA);
      final oy = c.dy - size.height * 0.04 + starR * math.sin(outerA);
      final ix = c.dx + starR * 0.45 * math.cos(innerA);
      final iy = c.dy - size.height * 0.04 + starR * 0.45 * math.sin(innerA);
      if (i == 0) { starPath.moveTo(ox, oy); } else { starPath.lineTo(ox, oy); }
      starPath.lineTo(ix, iy);
    }
    starPath.close();
    canvas.drawPath(starPath, Paint()
      ..color = color.withOpacity( 0.80 + pulse * 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
    canvas.drawPath(starPath, Paint()..color = Colors.white.withOpacity( 0.85));
  }

  @override
  bool shouldRepaint(_BadgePreviewPainter old) => old.t != t;
}

// Pass — holographic card with shimmer sweep
class _PassPreviewPainter extends CustomPainter {
  final double t;
  final Color color;
  _PassPreviewPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final pulse = (math.sin(t * math.pi * 2) + 1) / 2;
    final cw = size.width * 0.78;
    final ch = size.height * 0.56;
    final cl = (size.width - cw) / 2;
    final ct = (size.height - ch) / 2;
    final cardRect = RRect.fromRectAndRadius(Rect.fromLTWH(cl, ct, cw, ch), const Radius.circular(12));

    // Card shadow
    canvas.drawRRect(cardRect, Paint()
      ..color = color.withOpacity( 0.45 + pulse * 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));

    // Card base gradient
    canvas.drawRRect(cardRect, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [color.withOpacity( 0.75), AppTheme.accent.withOpacity(0.55), color.withOpacity( 0.45)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(cl, ct, cw, ch)));

    // Holographic shimmer sweep
    final shimmerX = cl + cw * ((t * 1.6) % 1.2 - 0.1);
    canvas.save();
    canvas.clipRRect(cardRect);
    canvas.drawRect(
      Rect.fromLTWH(shimmerX - 30, ct, 60, ch),
      Paint()..shader = LinearGradient(
        begin: Alignment.centerLeft, end: Alignment.centerRight,
        colors: [Colors.transparent, Colors.white.withOpacity( 0.65 + pulse * 0.20), Colors.transparent],
      ).createShader(Rect.fromLTWH(shimmerX - 30, ct, 60, ch)),
    );
    canvas.restore();

    // Card border
    canvas.drawRRect(cardRect, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color.withOpacity( 0.85 + pulse * 0.12));

    // Chip
    final chipRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cl + 12, ct + 14, 28, 20), const Radius.circular(4));
    canvas.drawRRect(chipRect, Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFFFFD700).withOpacity( 0.8), const Color(0xFFB8860B).withOpacity( 0.7)],
      ).createShader(Rect.fromLTWH(cl + 12, ct + 14, 28, 20)));
    canvas.drawRRect(chipRect, Paint()..style = PaintingStyle.stroke..strokeWidth = 0.8..color = const Color(0xFFFFD700).withOpacity( 0.9));

    // Horizontal stripe lines
    for (int i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(cl + 10, ct + ch * (0.62 + i * 0.12)),
        Offset(cl + cw - 10, ct + ch * (0.62 + i * 0.12)),
        Paint()..color = Colors.white.withOpacity( 0.45)..strokeWidth = 1.2,
      );
    }

    // Contactless icon
    for (int i = 1; i <= 3; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cl + cw - 20, ct + 24), radius: i * 5.0),
        -math.pi / 3, math.pi * 2 / 3, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = color.withOpacity( 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(_PassPreviewPainter old) => old.t != t;
}

// ── Shimmer sweep overlay (diagonal light over thumbnail) ────────────────────
class _ShimmerSweep extends StatelessWidget {
  final double t;
  const _ShimmerSweep({required this.t});

  @override
  Widget build(BuildContext context) {
    // t goes 0→1 repeatedly. Sweep crosses the thumbnail every cycle.
    return CustomPaint(
      painter: _ShimmerSweepPainter(t),
    );
  }
}

class _ShimmerSweepPainter extends CustomPainter {
  final double t;
  const _ShimmerSweepPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Diagonal sweep: x position = t * (width + stripWidth) - stripWidth
    const stripWidth = 40.0;
    final x = t * (size.width + stripWidth * 2) - stripWidth;
    final gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Colors.transparent,
        Colors.white.withOpacity( 0.12),
        Colors.white.withOpacity( 0.22),
        Colors.white.withOpacity( 0.12),
        Colors.transparent,
      ],
      stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
    );
    final rect = Rect.fromLTWH(x, 0, stripWidth, size.height);
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..blendMode = BlendMode.plus;
    // Skew the strip diagonally
    canvas.save();
    canvas.skew(-0.4, 0);
    canvas.drawRect(
      Rect.fromLTWH(x, -size.height * 0.5, stripWidth, size.height * 2),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShimmerSweepPainter old) => old.t != t;
}

// ── Category painter factory ──────────────────────────────────────────────────
CustomPainter _categoryPainter(String category, double t, Color color) {
  switch (category) {
    case 'Border': return _BgPreviewPainter(t, color); // fallback — PNG overrides this
    case 'BG':     return _BgPreviewPainter(t, color);
    case 'FX':     return _FxPreviewPainter(t, color);
    case 'Badge':  return _BadgePreviewPainter(t, color);
    case 'Pass':   return _PassPreviewPainter(t, color);
    case 'Banner': return _BannerPreviewPainter(color, t);
    case 'Bubble': return _BubblePreviewPainter(color, t);
    case 'Deco':   return _DecorationPreviewPainter(t, color);
    default:       return _FxPreviewPainter(t, color);
  }
}

// ── PNG border preview path helper ───────────────────────────────────────────
const Map<String, String> _borderAssetPaths = {
  'frame_sakura':  'assets/border/Sakura Emperor.png',
  'frame_neon':    'assets/border/Cyberpunk Neon.png',
  'frame_demon':   'assets/border/Demon Slayer.png',
  'frame_dragon':  'assets/border/Dragon Flame.png',
  'frame_shrine':  'assets/border/Moonlit Shrine.png',
  'frame_nebula':  'assets/border/Cosmic Nebula.png',
  'frame_thunder': 'assets/border/Thunder God.png',
  'frame_wraith':  'assets/border/Wraithling Cloak.png',
};

// Widget that renders PNG for borders, CustomPaint for everything else
class _CategoryPreview extends StatelessWidget {
  final _ShopItem item;
  final double t;
  final Size size;
  const _CategoryPreview({required this.item, required this.t, required this.size});

  @override
  Widget build(BuildContext context) {
    if (item.category == 'Border' && item.frameId != null) {
      final assetPath = _borderAssetPaths[item.frameId!];
      if (assetPath != null) {
        return SizedBox.fromSize(
          size: size,
          child: Center(
            child: Image.asset(
              assetPath,
              width: size.height * 0.90,
              height: size.height * 0.90,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => CustomPaint(
                size: size,
                painter: _categoryPainter(item.category, t, item.color),
              ),
            ),
          ),
        );
      }
    }
    return CustomPaint(
      size: size,
      painter: _categoryPainter(item.category, t, item.color),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION LABEL
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 3, height: 14, decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFFFF2D78), Color(0xFF9D4EDD)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      borderRadius: BorderRadius.circular(2),
    )),
    const SizedBox(width: 10),
    Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// SAKURA COIN CARD
// ─────────────────────────────────────────────────────────────────────────────
class _SakuraCoinCard extends StatelessWidget {
  final Animation<double> glowAnim;
  final int gems;
  final VoidCallback onTopUp;
  const _SakuraCoinCard({required this.glowAnim, required this.gems, required this.onTopUp});

  String _fmt(int n) {
    if (n >= 1000000) return '${(n/1000000).toStringAsFixed(1)}M';
    if (n >= 1000) {
      final s = n.toString();
      return s.length > 3 ? '${s.substring(0, s.length-3)},${s.substring(s.length-3)}' : s;
    }
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowAnim,
      builder: (_, __) {
        final g = glowAnim.value;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.surfaceElevated,
                AppTheme.surface.withOpacity(0.95),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: AppTheme.highlight.withOpacity(0.28 + g * 0.12),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(color: AppTheme.highlight.withOpacity(0.10 + g * 0.06), blurRadius: 32, spreadRadius: 0, offset: const Offset(0, 8)),
              BoxShadow(color: AppTheme.accent.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4)),
              BoxShadow(color: AppTheme.surfaceElevated, blurRadius: 0, spreadRadius: 0, offset: Offset.zero),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: icon + label + daily badge ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Coin orb
                  AnimatedBuilder(
                    animation: glowAnim,
                    builder: (_, __) => Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [AppTheme.highlight, AppTheme.highlight, AppTheme.glow],
                          stops: [0.0, 0.55, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.highlight.withOpacity(0.45 + g * 0.30),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: AppTheme.highlight.withOpacity(0.15),
                            blurRadius: 40,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: Icon(Icons.local_florist_rounded, color: AppTheme.textPrimary, size: 26),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SAKURA COIN',
                          style: TextStyle(
                            color: AppTheme.textSecondary.withOpacity(0.8),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          transitionBuilder: (child, anim) => SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero).animate(anim),
                            child: FadeTransition(opacity: anim, child: child),
                          ),
                          child: Text(
                            _fmt(gems),
                            key: ValueKey(gems),
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Daily badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.success.withOpacity(0.40)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.add_circle_rounded, color: AppTheme.success, size: 11),
                        SizedBox(width: 4),
                        Text('+50 Hari Ini', style: TextStyle(color: AppTheme.success, fontSize: 9.5, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── Divider with shimmer hint ──
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppTheme.highlight.withOpacity(0.25 + g * 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Bottom row: gem breakdown + top up CTA ──
              Row(
                children: [
                  // Breakdown chips
                  _statChip(Icons.diamond_rounded, AppTheme.accent, 'Gems', _fmt(gems)),
                  const SizedBox(width: 10),
                  _statChip(Icons.emoji_events_rounded, AppTheme.highlight, 'Season', 'S1'),
                  const Spacer(),
                  // Top Up button
                  GestureDetector(
                    onTap: onTopUp,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.highlight, AppTheme.accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.sakuraPink.withOpacity( 0.40 + g * 0.15),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.add_rounded, color: AppTheme.textPrimary, size: 15),
                          SizedBox(width: 5),
                          Text('Top Up', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.2)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statChip(IconData icon, Color color, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: color.withOpacity( 0.70), fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHOP HEADER + TABS
// ─────────────────────────────────────────────────────────────────────────────
class _ShopHeader extends StatelessWidget {
  final List<String> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  const _ShopHeader({required this.categories, required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('TOKO KOSMETIK', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.highlight.withOpacity(0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.highlight.withOpacity(0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.timer_rounded, color: AppTheme.highlight, size: 11),
              SizedBox(width: 4),
              Text('Drop Terbatas', style: TextStyle(color: AppTheme.highlight, fontSize: 10, fontWeight: FontWeight.w900)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final sel = i == selectedIndex;
              return GestureDetector(
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: sel ? LinearGradient(
                      colors: [AppTheme.accent, Color.lerp(AppTheme.accent, AppTheme.highlight, 0.5)!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ) : null,
                    color: sel ? null : AppTheme.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: sel ? Colors.transparent : AppTheme.textPrimary.withOpacity(0.1),
                      width: 1.0,
                    ),
                    boxShadow: sel ? [
                      BoxShadow(color: AppTheme.highlight.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 4), spreadRadius: -2),
                    ] : [
                      BoxShadow(color: AppTheme.background.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Text(
                    _categoryLabels[categories[i]] ?? categories[i],
                    style: TextStyle(
                      color: sel ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: sel ? FontWeight.w900 : FontWeight.w600,
                      letterSpacing: sel ? 0.2 : 0,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COSMETIC PREVIEW — full dramatic card, large painter area on top
// ─────────────────────────────────────────────────────────────────────────────
class _CosmeticPreview extends StatelessWidget {
  final _ShopItem item;
  final AnimationController shimmerCtrl;
  final bool isEquipped;
  final VoidCallback? onEquip;
  final VoidCallback? onBuy;
  const _CosmeticPreview({
    super.key,
    required this.item,
    required this.shimmerCtrl,
    this.isEquipped = false,
    this.onEquip,
    this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final rarity = _rarities[item.rarity] ?? _rarities['Common']!;
    final c = item.color;
    return AnimatedBuilder(
      animation: shimmerCtrl,
      builder: (_, __) {
        final t = shimmerCtrl.value;
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: c.withOpacity( 0.12), width: 1.0),
            boxShadow: [
              BoxShadow(color: c.withOpacity( 0.22), blurRadius: 48, spreadRadius: -8, offset: const Offset(0, 16)),
              BoxShadow(color: AppTheme.background.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── LARGE VISUAL AREA — upgraded ──────────────────────────
                SizedBox(
                  height: 240,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Base gradient — richer, more dramatic
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              rarity.bg,
                              Color.lerp(rarity.bg, c, 0.35)!,
                              c.withOpacity( 0.70),
                            ],
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight,
                          ),
                        ),
                      ),

                      // Ambient radial glow from center
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(0.2, -0.1),
                              radius: 0.85,
                              colors: [
                                c.withOpacity( 0.50),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // PNG for borders, CustomPaint for everything else
                      _CategoryPreview(
                        item: item,
                        t: t,
                        size: const Size(double.infinity, 240),
                      ),

                      // Legendary/Exclusive diagonal shimmer sweep
                      if (item.rarity == 'Legendary' || item.rarity == 'Exclusive')
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(-1.8 + t * 5.0, -0.6),
                                end: Alignment(-1.0 + t * 5.0, 1.0),
                                colors: [
                                  Colors.white.withOpacity( 0.0),
                                  Colors.white.withOpacity( 0.22),
                                  Colors.white.withOpacity( 0.0),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                        ),

                      // Edge vignette — left and right darkness for depth
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                AppTheme.background.withOpacity(0.28),
                                Colors.transparent,
                                AppTheme.background.withOpacity(0.18),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Bottom fade — smooth transition to white info area
                      Positioned(
                        left: 0, right: 0, bottom: 0, height: 90,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                AppTheme.surface,
                                AppTheme.surface.withOpacity(0.85),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.4, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Rarity badge — top left, more refined
                      Positioned(
                        top: 14, left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: rarity.color,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(color: rarity.color.withOpacity( 0.60), blurRadius: 14, spreadRadius: -2, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Text(
                            rarity.label.toUpperCase(),
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                          ),
                        ),
                      ),

                      // Owned badge — top right
                      if (item.owned)
                        Positioned(
                          top: 14, right: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity( 0.50), blurRadius: 14, offset: const Offset(0, 4))],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_rounded, color: AppTheme.textPrimary, size: 11),
                                SizedBox(width: 4),
                                Text('Owned', style: TextStyle(color: AppTheme.textPrimary, fontSize: 9, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── INFO SECTION — upgraded ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type + rarity row
                      Row(
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.type.toUpperCase(),
                            style: TextStyle(color: c, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Item name — bigger and bolder
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w900, height: 1.05, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 18),

                      // Buy / Equip button — full width, more premium
                      GestureDetector(
                        onTap: item.owned ? onEquip : onBuy,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: isEquipped
                                ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
                                : item.owned
                                    ? LinearGradient(colors: [AppTheme.sakuraPink.withOpacity( 0.12), AppTheme.sakuraPink.withOpacity( 0.06)])
                                    : LinearGradient(
                                        colors: [c, Color.lerp(c, AppTheme.accent, 0.55)!],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                            borderRadius: BorderRadius.circular(16),
                            border: (item.owned && !isEquipped)
                                ? Border.all(color: AppTheme.sakuraPink.withOpacity( 0.35), width: 1.5)
                                : null,
                            boxShadow: isEquipped
                                ? [BoxShadow(color: const Color(0xFF10B981).withOpacity( 0.40), blurRadius: 20, offset: const Offset(0, 6))]
                                : item.owned
                                    ? null
                                    : [BoxShadow(color: c.withOpacity( 0.45), blurRadius: 20, offset: const Offset(0, 6), spreadRadius: -4)],
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isEquipped) ...[
                                Icon(Icons.radio_button_checked_rounded, color: AppTheme.textPrimary, size: 15),
                                const SizedBox(width: 8),
                                const Text('Equipped', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.2)),
                              ] else if (item.owned) ...[
                                Icon(Icons.check_circle_rounded, color: AppTheme.sakuraPink, size: 15),
                                const SizedBox(width: 8),
                                Text('Equip Sekarang', style: TextStyle(color: AppTheme.sakuraPink, fontSize: 14, fontWeight: FontWeight.w900)),
                              ] else ...[
                                Icon(Icons.diamond_rounded, color: AppTheme.textPrimary.withOpacity(0.95), size: 15),
                                const SizedBox(width: 8),
                                Text(item.price, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.2)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHOP GRID — filtered, dengan animated painter di tiap card
// ─────────────────────────────────────────────────────────────────────────────
class _ShopGrid extends StatelessWidget {
  final List<_ShopItem> items;
  final int selectedIndex;
  final AnimationController shimmerCtrl;
  final Map<String, String> equippedPerCategory;
  final ValueChanged<int> onSelect;
  const _ShopGrid({required this.items, required this.selectedIndex, required this.shimmerCtrl, required this.equippedPerCategory, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.78,
      ),
      itemBuilder: (_, i) => _ShopItemCard(
        item: items[i],
        selected: i == selectedIndex,
        isEquipped: equippedPerCategory[items[i].category] == items[i].name,
        shimmerCtrl: shimmerCtrl,
        onTap: () => onSelect(i),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHOP ITEM CARD — with category painter thumbnail
// ─────────────────────────────────────────────────────────────────────────────
class _ShopItemCard extends StatefulWidget {
  final _ShopItem item;
  final bool selected;
  final bool isEquipped;
  final AnimationController shimmerCtrl;
  final VoidCallback onTap;
  const _ShopItemCard({required this.item, required this.selected, this.isEquipped = false, required this.shimmerCtrl, required this.onTap});
  @override State<_ShopItemCard> createState() => _ShopItemCardState();
}

class _ShopItemCardState extends State<_ShopItemCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final rarity = _rarities[widget.item.rarity] ?? _rarities['Common']!;
    final isOwned = widget.item.owned || widget.isEquipped;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedBuilder(
          animation: widget.shimmerCtrl,
          builder: (_, __) {
            final t = widget.shimmerCtrl.value;
            final glowAlpha = widget.selected
                ? 0.55 + t * 0.30
                : 0.20 + t * 0.15;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                // Dark rarity-tinted card background
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    rarity.bg,
                    Color.lerp(rarity.bg, AppTheme.background, 0.3)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: widget.selected
                      ? rarity.color.withOpacity( 0.85)
                      : rarity.color.withOpacity( 0.30),
                  width: widget.selected ? 1.8 : 1.0,
                ),
                boxShadow: [
                  // Rarity glow
                  BoxShadow(
                    color: rarity.glow.withOpacity( glowAlpha),
                    blurRadius: widget.selected ? 24 : 12,
                    spreadRadius: widget.selected ? 1 : 0,
                    offset: const Offset(0, 3),
                  ),
                  // Depth shadow
                  BoxShadow(
                    color: AppTheme.background.withOpacity(0.45),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Thumbnail ────────────────────────────────────────────
                  Stack(
                    children: [
                      Container(
                        height: 88,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              rarity.color.withOpacity( 0.75),
                              rarity.color.withOpacity( 0.30),
                              AppTheme.background.withOpacity(0.4),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: rarity.color.withOpacity( 0.25)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _CategoryPreview(
                            item: widget.item,
                            t: t,
                            size: const Size(double.infinity, 88),
                          ),
                        ),
                      ),
                      // Shimmer sweep over thumbnail
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _ShimmerSweep(t: t),
                        ),
                      ),
                      // Owned/equipped badge on thumbnail
                      if (isOwned)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: widget.isEquipped
                                  ? AppTheme.success
                                  : AppTheme.background.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: widget.isEquipped
                                    ? AppTheme.success
                                    : AppTheme.textPrimary.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              widget.isEquipped ? '● Equipped' : '✓ Owned',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  // ── Rarity + type ────────────────────────────────────────
                  Row(children: [
                    Expanded(
                      child: Text(
                        widget.item.type,
                        style: TextStyle(
                          color: AppTheme.textSecondary.withOpacity(0.45),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: rarity.badgeBg,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: rarity.color.withOpacity( 0.4)),
                      ),
                      child: Text(
                        rarity.label,
                        style: TextStyle(
                          color: rarity.color,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  // ── Item name ────────────────────────────────────────────
                  Text(
                    widget.item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const Spacer(),
                  // ── Price / CTA button ───────────────────────────────────
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: double.infinity,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: isOwned
                          ? null
                          : LinearGradient(
                              colors: [rarity.color, AppTheme.accent],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                      color: widget.isEquipped
                          ? const Color(0xFF10B981)
                          : isOwned
                              ? AppTheme.surface.withOpacity(0.07)
                              : null,
                      borderRadius: BorderRadius.circular(10),
                      border: isOwned && !widget.isEquipped
                          ? Border.all(
                              color: rarity.color.withOpacity( 0.3))
                          : null,
                      boxShadow: isOwned
                          ? null
                          : [
                              BoxShadow(
                                color: rarity.glow.withOpacity( 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.isEquipped
                          ? '● Equipped'
                          : widget.item.owned
                              ? '✓ Owned'
                              : widget.item.price,
                      style: TextStyle(
                        color: isOwned
                            ? AppTheme.textSecondary.withOpacity(0.55)
                            : AppTheme.textPrimary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OWNED COSMETICS GRID
// ─────────────────────────────────────────────────────────────────────────────
class _OwnedCosmeticsGrid extends StatelessWidget {
  const _OwnedCosmeticsGrid();
  @override
  Widget build(BuildContext context) {
    const items = [
      _CosmeticStat('Border',      '8 Dimiliki',  Icons.crop_square_rounded,      Color(0xFF9D4EDD)),
      _CosmeticStat('Bubble Chat', '5 Dimiliki',  Icons.chat_bubble_rounded,       Color(0xFFF472B6)),
      _CosmeticStat('Profile BG',  '3 Dimiliki',  Icons.wallpaper_rounded,          Color(0xFF7C3AED)),
      _CosmeticStat('Badge',       '42 Dimiliki', Icons.workspace_premium_rounded,  Color(0xFFFFD700)),
    ];
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 1.50,
      children: items.map((e) => _CosmeticStatCard(stat: e)).toList(),
    );
  }
}

class _CosmeticStat {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  const _CosmeticStat(this.title, this.subtitle, this.icon, this.color);
}

class _CosmeticStatCard extends StatefulWidget {
  final _CosmeticStat stat;
  const _CosmeticStatCard({required this.stat});
  @override State<_CosmeticStatCard> createState() => _CosmeticStatCardState();
}

class _CosmeticStatCardState extends State<_CosmeticStatCard> with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  // Per-category config: gradient colors + visual elements
  List<Color> get _gradientColors {
    switch (widget.stat.title) {
      case 'Border':      return [const Color(0xFFFFD9F1), const Color(0xFFFFF0FA)];
      case 'Bubble Chat': return [const Color(0xFFFFE4F5), const Color(0xFFFFF5FF)];
      case 'Profile BG':  return [const Color(0xFFEADBFF), const Color(0xFFF5F0FF)];
      case 'Badge':       return [const Color(0xFFFFF8D6), const Color(0xFFFFFDF0)];
      default:            return [const Color(0xFFF0F4FF), Colors.white];
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stat;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedBuilder(
          animation: _anim,
          builder: (_, __) {
            final g = _anim.value;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: s.color.withOpacity( 0.20 + g * 0.10),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: s.color.withOpacity( 0.12 + g * 0.06),
                    blurRadius: 18,
                    spreadRadius: -2,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: AppTheme.background.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Decorative background shape
                    Positioned(
                      right: -18, top: -18,
                      child: Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: s.color.withOpacity( 0.10 + g * 0.06),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8, bottom: -12,
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: s.color.withOpacity( 0.07),
                        ),
                      ),
                    ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top row: icon + chevron
                          Row(
                            children: [
                              Container(
                                width: 38, height: 38,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [s.color, s.color.withOpacity( 0.65)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: s.color.withOpacity( 0.35 + g * 0.15),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Icon(s.icon, color: Colors.white, size: 18),
                              ),
                              const Spacer(),
                              Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity( 0.70),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: s.color.withOpacity( 0.20)),
                                ),
                                child: Icon(Icons.chevron_right_rounded, color: s.color, size: 14),
                              ),
                            ],
                          ),

                          // Bottom: title + count badge
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.title,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: s.color.withOpacity( 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: s.color.withOpacity( 0.25)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: s.color, size: 9),
                                    const SizedBox(width: 4),
                                    Text(
                                      s.subtitle,
                                      style: TextStyle(
                                        color: s.color,
                                        fontSize: 9,
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

// ─────────────────────────────────────────────────────────────────────────────
// BACKGROUND PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _VaultBgPainter extends CustomPainter {
  final double t;
  _VaultBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final b = (math.sin(t * math.pi * 2) + 1) / 2;
    void bloom(Color c, double cx, double cy, double r, double a) {
      canvas.drawRect(Offset.zero & size, Paint()
        ..shader = RadialGradient(colors: [c.withOpacity( a + b * 0.04), Colors.transparent])
            .createShader(Rect.fromCircle(center: Offset(size.width * cx, size.height * cy), radius: size.width * r)));
    }
    // Crisp, more defined bloom spots — less muddy than original
    bloom(const Color(0xFFFFE8F5), 0.15, 0.08, 0.55, 0.22);
    bloom(const Color(0xFFEEE0FF), 0.85, 0.12, 0.50, 0.18);
    bloom(const Color(0xFFFFD9F1), 0.08, 0.45, 0.45, 0.16);
    bloom(const Color(0xFFE8D8FF), 0.92, 0.55, 0.45, 0.14);
    bloom(const Color(0xFFFFF0D6), 0.50, 0.02, 0.60, 0.12);
  }

  @override
  bool shouldRepaint(_VaultBgPainter old) => old.t != t;
}

// ═════════════════════════════════════════════════════════════════════════════
// BUY CONFIRM BOTTOM SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _BuyConfirmSheet extends StatelessWidget {
  final _ShopItem item;
  final int userGems;
  final int priceNum;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _BuyConfirmSheet({
    required this.item,
    required this.userGems,
    required this.priceNum,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final rarity = _rarities[item.rarity] ?? _rarities['Common']!;
    final canAfford = userGems >= priceNum;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: AppTheme.background.withOpacity(0.12), blurRadius: 40, offset: const Offset(0, -8))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE0D0F0), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),

          // Item preview mini
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.color.withOpacity( 0.15),
              border: Border.all(color: item.color.withOpacity( 0.4), width: 2),
            ),
            child: Icon(item.icon, color: item.color, size: 30),
          ),
          const SizedBox(height: 12),

          // Rarity badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: rarity.bg, borderRadius: BorderRadius.circular(20)),
            child: Text(rarity.label, style: TextStyle(color: rarity.color, fontSize: 10, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 8),

          Text(item.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
          Text(item.type, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 20),

          // Gem cost row
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: canAfford ? const Color(0xFFF5EEFF) : const Color(0xFFFFF0F0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Harga', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                Row(children: [
                  Icon(Icons.diamond_rounded, color: item.color, size: 14),
                  const SizedBox(width: 4),
                  Text(item.price, style: TextStyle(color: item.color, fontSize: 14, fontWeight: FontWeight.w900)),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Saldo kamu', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                Text('${_fmtGems(userGems)} Gems', style: TextStyle(
                  color: canAfford ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  fontSize: 11, fontWeight: FontWeight.w700,
                )),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: onCancel,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F0FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: canAfford ? onConfirm : null,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: canAfford
                          ? LinearGradient(colors: [item.color, Color.lerp(item.color, AppTheme.accent, 0.5)!])
                          : null,
                      color: canAfford ? null : const Color(0xFFE0D0F0),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: canAfford
                          ? [BoxShadow(color: item.color.withOpacity( 0.35), blurRadius: 14, offset: const Offset(0, 5))]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      canAfford ? 'Beli Sekarang' : 'Gems Tidak Cukup',
                      style: TextStyle(
                        color: canAfford ? AppTheme.textPrimary : AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TOP UP BOTTOM SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _TopUpPackage {
  final int gems;
  final String price;
  final String bonus;
  final Color color;
  final bool popular;
  const _TopUpPackage(this.gems, this.price, this.bonus, this.color, {this.popular = false});
}

class _TopUpSheet extends StatelessWidget {
  final int userGems;
  final void Function(int gems, String cost) onBuy;

  const _TopUpSheet({required this.userGems, required this.onBuy});

  static const _packages = [
    _TopUpPackage(100,  'Rp 15.000',  '',          Color(0xFF9D4EDD)),
    _TopUpPackage(500,  'Rp 65.000',  '+50 Bonus', Color(0xFF00B4D8)),
    _TopUpPackage(1200, 'Rp 140.000', '+200 Bonus',Color(0xFFFF2D78), popular: true),
    _TopUpPackage(3000, 'Rp 320.000', '+600 Bonus',Color(0xFFFFD700)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: AppTheme.background.withOpacity(0.12), blurRadius: 40, offset: const Offset(0, -8))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE0D0F0), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          const Text('Top Up Gems', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Saldo: ${_fmtGems(userGems)} Gems', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: _packages.map((pkg) => _TopUpCard(pkg: pkg, onBuy: onBuy)).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _TopUpCard extends StatefulWidget {
  final _TopUpPackage pkg;
  final void Function(int gems, String cost) onBuy;
  const _TopUpCard({required this.pkg, required this.onBuy});
  @override State<_TopUpCard> createState() => _TopUpCardState();
}

class _TopUpCardState extends State<_TopUpCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pkg = widget.pkg;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onBuy(pkg.gems, pkg.price); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [pkg.color.withOpacity( 0.12), pkg.color.withOpacity( 0.04)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: pkg.color.withOpacity( 0.30), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(Icons.diamond_rounded, color: pkg.color, size: 14),
                const SizedBox(width: 4),
                Text('${pkg.gems}', style: TextStyle(color: pkg.color, fontSize: 14, fontWeight: FontWeight.w900)),
                if (pkg.bonus.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: pkg.color, borderRadius: BorderRadius.circular(8)),
                    child: Text(pkg.bonus, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 7.5, fontWeight: FontWeight.w900)),
                  ),
                ],
                if (pkg.popular) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFF2D78), borderRadius: BorderRadius.circular(8)),
                    child: const Text('HOT', style: TextStyle(color: AppTheme.textPrimary, fontSize: 7.5, fontWeight: FontWeight.w900)),
                  ),
                ],
              ]),
              Text(pkg.price, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmtGems(int n) {
  if (n >= 1000000) return '${(n/1000000).toStringAsFixed(1)}M';
  if (n >= 1000) {
    final s = n.toString();
    return '${s.substring(0, s.length-3)},${s.substring(s.length-3)}';
  }
  return n.toString();
}

// ── Banner preview — horizontal landscape strip with gradient sky + sakura ──
class _BannerPreviewPainter extends CustomPainter {
  final Color color;
  final double t;
  _BannerPreviewPainter(this.color, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    // Sky gradient
    paint.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [color.withOpacity(0.85), color.withOpacity(0.3), AppTheme.surface],
    ).createShader(Offset.zero & size);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)), paint);
    // Animated shimmer line
    final shimmerPaint = Paint()
      ..color = AppTheme.textPrimary.withOpacity(0.08 + t * 0.06)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.55, size.width, size.height * 0.03), shimmerPaint);
    // Dots simulating banner art
    final dotPaint = Paint()..color = AppTheme.textPrimary.withOpacity(0.2);
    for (var i = 0; i < 6; i++) {
      canvas.drawCircle(Offset(size.width * (0.1 + i * 0.15), size.height * 0.4), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_BannerPreviewPainter o) => o.t != t;
}

// ── Avatar Decoration preview — animated wing arcs Discord-style ──────────────
class _DecorationPreviewPainter extends CustomPainter {
  final Color color;
  final double t;
  _DecorationPreviewPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final pulse = (math.sin(t * math.pi * 2) + 1) / 2;

    // Avatar placeholder circle
    canvas.drawCircle(c, size.width * 0.22, Paint()
      ..color = color.withOpacity(0.18)
      ..style = PaintingStyle.fill);
    canvas.drawCircle(c, size.width * 0.22, Paint()
      ..color = color.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
    // Person icon silhouette
    canvas.drawCircle(Offset(c.dx, c.dy - size.width * 0.07), size.width * 0.055,
        Paint()..color = Colors.white.withOpacity(0.75));
    final bodyPath = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(c.dx, c.dy + size.width * 0.065),
          width: size.width * 0.17,
          height: size.width * 0.11));
    canvas.drawPath(bodyPath, Paint()..color = Colors.white.withOpacity(0.75));

    // 3-layer wing arcs per side
    for (int s = 0; s < 2; s++) {
      final sign = s == 0 ? -1.0 : 1.0;
      for (int layer = 0; layer < 3; layer++) {
        final layerT = (t + layer * 0.13) % 1.0;
        final lp = (math.sin(layerT * math.pi * 2) + 1) / 2;
        final alpha = (0.30 + lp * 0.50) * (1 - layer * 0.20);
        final sw = 3.5 - layer * 0.8;
        final arcR = size.width * (0.38 + layer * 0.08 + lp * 0.03);
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

        // Bright glint tip on outermost arc
        if (layer == 0) {
          final tipA = baseAngle + rot + sweepRad;
          final tx = c.dx + arcR * math.cos(tipA);
          final ty = c.dy + arcR * math.sin(tipA);
          canvas.drawCircle(Offset(tx, ty), 4.0 + lp * 2.0,
              Paint()
                ..color = color.withOpacity(0.75 + lp * 0.20)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
          canvas.drawCircle(Offset(tx, ty), 2.0,
              Paint()..color = Colors.white.withOpacity(0.90));
        }
      }
    }

    // Orbiting rune particles
    const pc = 10;
    final rng = math.Random(77);
    for (int i = 0; i < pc; i++) {
      final ba = (math.pi * 2 / pc) * i;
      final or_ = size.width * (0.40 + rng.nextDouble() * 0.10);
      final spd = i % 2 == 0 ? 0.55 : -0.40;
      final a = ba + t * math.pi * 2 * spd;
      final px = c.dx + or_ * math.cos(a);
      final py = c.dy + or_ * math.sin(a);
      final pa = (math.sin(t * math.pi * 3 + i) + 1) / 2;
      canvas.drawCircle(Offset(px, py), 2.2 + pa * 1.4,
          Paint()
            ..color = color.withOpacity(0.50 + pa * 0.40)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }

    // Crown halo arc
    final haloR = size.width * 0.27;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: haloR),
      math.pi + 0.35, math.pi * 1.30, false,
      Paint()
        ..color = color.withOpacity(0.40 + pulse * 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: haloR),
      math.pi + 0.35, math.pi * 1.30, false,
      Paint()
        ..color = Colors.white.withOpacity(0.30 + pulse * 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_DecorationPreviewPainter o) => o.t != t;
}

// ── Bubble chat preview — rounded speech bubble shape ─────────────────────────
class _BubblePreviewPainter extends CustomPainter {
  final Color color;
  final double t;
  _BubblePreviewPainter(this.color, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.25 + t * 0.1)
      ..style = PaintingStyle.fill;
    final w = size.width * 0.75;
    final h = size.height * 0.45;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH((size.width - w) / 2, size.height * 0.15, w, h),
      const Radius.circular(14),
    );
    canvas.drawRRect(rect, paint);
    // Bubble tail
    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.15 + h)
      ..lineTo(size.width * 0.18, size.height * 0.15 + h + 10)
      ..lineTo(size.width * 0.38, size.height * 0.15 + h);
    canvas.drawPath(path, paint);
    // Border
    paint
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(rect, paint);
    // Text lines inside bubble
    final linePaint = Paint()
      ..color = AppTheme.textPrimary.withOpacity(0.3)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.35),
      Offset(size.width * 0.7, size.height * 0.35),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.45),
      Offset(size.width * 0.6, size.height * 0.45),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_BubblePreviewPainter o) => o.t != t;
}

