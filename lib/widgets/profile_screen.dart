// profile_screen.dart — AniVerse Profile V3 Premium
// ─────────────────────────────────────────────────────────────────────────────
// Rebuilt with premium upgrades:
// 1. Live Try-On cosmetics system (avatar header updates in real-time)
// 2. Ambient particle FX overlay (sakura / dragon flame)
// 3. Cybernetic AI Roast Terminal with scanner sweep animation
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mock_data_service.dart';
import 'continue_watching_model.dart';
import 'tier_system.dart';
import 'anime_model.dart';
import 'package:aniverse/app_theme.dart';
import 'settings_screen.dart';
import 'web_download_stub.dart'
    if (dart.library.html) 'web_download_web.dart';

// ── Brand tokens ──────────────────────────────────────────────────────────────
class _C {
  static const bg        = AppTheme.background;
  static const surface   = AppTheme.surface;
  static const card      = AppTheme.surfaceElevated;
  static const pink      = AppTheme.highlight;
  static const purple    = AppTheme.accent;
  static const ink       = AppTheme.textPrimary;
  static const sub       = AppTheme.textSecondary;
  static Color get divider => AppTheme.textPrimary.withOpacity(0.1);
}

// ── Rank bridge ───────────────────────────────────────────────────────────────
typedef _Rank = TierConfig;
_Rank _getRank(int xp)       => TierSystem.getTier(xp);
_Rank? _getNextRank(int xp)  => TierSystem.getNextTier(xp);
double _xpProgress(int xp)   => TierSystem.getProgress(xp);
extension _RankCompat on TierConfig { int get minXp => minXP; }

// ═════════════════════════════════════════════════════════════════════════════
// PROFILE SCREEN
// ═════════════════════════════════════════════════════════════════════════════
class ProfileScreen extends StatefulWidget {
  final Map<String, String> equipped;
  final void Function(String category, String itemName)? onEquip;
  const ProfileScreen({super.key, required this.equipped, this.onEquip});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _auraCtrl;
  late AnimationController _shimmerCtrl;
  late AnimationController _crystalCtrl;
  late AnimationController _crystalInnerCtrl;
  late AnimationController _decorCtrl;

  int _achievementsCount = 3;
  Uint8List? _avatarBytes;
  bool _profileReady = false;

  // Equipped cosmetics
  String get _equippedFrameId     => widget.equipped['Border']    ?? 'frame_sakura';
  String get _equippedBgId        => widget.equipped['BG']        ?? 'bg_default';
  String get _equippedFxId        => widget.equipped['FX']        ?? 'fx_default';
  String get _equippedDecoId      => widget.equipped['Deco']      ?? 'deco_wraithling';
  String get _equippedAuraId      => widget.equipped['Aura']      ?? 'aura_default';
  String get _equippedNameColorId => widget.equipped['NameColor'] ?? 'namecolor_default';
  String get _equippedTitleId     => widget.equipped['Title']     ?? 'title_anime_emperor';

  // ── Live Try-On preview state (null = use equipped) ──────────────────────
  String? _previewFrameId;
  String? _previewDecoId;
  String? _previewFxId;
  String? _previewBgId;
  String? _previewAuraId;
  String? _previewNameColorId;
  String? _previewTitleId;
  bool get _isPreviewMode =>
      _previewFrameId != null || _previewDecoId != null || _previewFxId != null ||
      _previewBgId != null || _previewAuraId != null || _previewNameColorId != null ||
      _previewTitleId != null;

  void _onPreviewCosmetic(String type, String id) {
    setState(() {
      if (type == 'Avatar Border') _previewFrameId = id;
      else if (type == 'Avatar Deco') _previewDecoId = id;
      else if (type == 'Profile FX') _previewFxId = id;
      else if (type == 'Profile BG') _previewBgId = id;
      else if (type == 'Aura') _previewAuraId = id;
      else if (type == 'Name Color') _previewNameColorId = id;
      else if (type == 'Title') _previewTitleId = id;
    });
  }

  static const _typeToCategory = {
    'Avatar Border': 'Border', 'Profile BG': 'BG', 'Profile FX': 'FX',
    'Avatar Deco': 'Deco', 'Profile Banner': 'Banner',
    'Aura': 'Aura', 'Name Color': 'NameColor', 'Title': 'Title',
  };

  void _onEquipCosmetic(String type, String id) {
    final cat = _typeToCategory[type];
    if (cat != null) widget.onEquip?.call(cat, id);
    setState(() {
      if (type == 'Avatar Border') _previewFrameId = null;
      else if (type == 'Avatar Deco') _previewDecoId = null;
      else if (type == 'Profile FX') _previewFxId = null;
      else if (type == 'Profile BG') _previewBgId = null;
      else if (type == 'Aura') _previewAuraId = null;
      else if (type == 'Name Color') _previewNameColorId = null;
      else if (type == 'Title') _previewTitleId = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _auraCtrl         = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _shimmerCtrl      = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _crystalCtrl      = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _crystalInnerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    _decorCtrl        = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final b64 = prefs.getString('profile_avatar_b64');
    if (mounted) setState(() {
      _achievementsCount = prefs.getInt('achievements_count') ?? 3;
      if (b64 != null && b64.isNotEmpty) {
        try {
          final raw = b64.contains(',') ? b64.split(',').last : b64;
          _avatarBytes = base64Decode(raw);
        } catch (_) { _avatarBytes = null; }
      }
      _profileReady = true;
    });
  }

  @override
  void dispose() {
    _auraCtrl.dispose(); _shimmerCtrl.dispose(); _crystalCtrl.dispose();
    _crystalInnerCtrl.dispose(); _decorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // ── Dynamic profile background ───────────────────────────────
          _ProfileBackground(
            bgId: _previewBgId ?? _equippedBgId,
            auraCtrl: _auraCtrl,
          ),
          // ── Ambient particle FX overlay ─────────────────────────────────
          _AtmosphereParticles(fxId: _previewFxId ?? _equippedFxId),          ValueListenableBuilder<int>(
            valueListenable: MockDataService.xpNotifier,
            builder: (_, xp, _) => ValueListenableBuilder<Map<String, AnimeStatus>>(
              valueListenable: MockDataService.myListNotifier,
              builder: (_, myList, _) => ValueListenableBuilder<List<AnimeModel>>(
                valueListenable: MockDataService.recentlyWatchedNotifier,
                builder: (_, recentlyWatched, _) => ValueListenableBuilder<List<ContinueWatchingModel>>(
                  valueListenable: MockDataService.continueWatchingNotifier,
                  builder: (_, continueWatching, _) => ValueListenableBuilder<List<AnimeModel>>(
                    valueListenable: MockDataService.favoritesNotifier,
                    builder: (_, favorites, _) {
                      final rank     = _getRank(xp);
                      final nextRank = _getNextRank(xp);
                      final progress = _xpProgress(xp);
                      return CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(child: SizedBox(height: safeTop + 12)),
                          // ── GLASS HEADER ─────────────────────────────────
                          SliverToBoxAdapter(
                            child: _profileReady
                                ? _ProfileGlassHeader(
                                    rankName: rank.name,
                                    xp: xp,
                                    auraCtrl: _auraCtrl,
                                    crystalCtrl: _crystalCtrl,
                                    crystalInnerCtrl: _crystalInnerCtrl,
                                    decorCtrl: _decorCtrl,
                                    equippedFrameId: _previewFrameId ?? _equippedFrameId,
                                    equippedDecoId: _previewDecoId ?? _equippedDecoId,
                                    equippedBgId: _previewBgId ?? _equippedBgId,
                                    avatarBytes: _avatarBytes,
                                    isPreviewMode: _isPreviewMode,
                                  )
                                : _ProfileHeaderSkeleton(shimmerCtrl: _shimmerCtrl),
                          ),
                          SliverToBoxAdapter(
                            child: Column(children: [
                              const SizedBox(height: 16),
                              // ── IDENTITY BLOCK (stats + XP + currently vibing) ──
                              // Tight 12px spacing within — these three read as
                              // one connected unit describing "who you are right now".
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: _ProfileStatsBar(
                                  achievementsCount: _achievementsCount,
                                ),
                              ),
                              const SizedBox(height: 28),
                              // CURRENT LOADOUT — 7-slot equipped cosmetics carousel
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: _CurrentLoadoutCard(
                                  equippedFrameId: _equippedFrameId,
                                  equippedBgId: _equippedBgId,
                                  equippedFxId: _equippedFxId,
                                  equippedDecoId: _equippedDecoId,
                                  equippedAuraId: _equippedAuraId,
                                  equippedNameColorId: _equippedNameColorId,
                                  equippedTitleId: _equippedTitleId,
                                  onEquip: _onEquipCosmetic,
                                  onPreviewChanged: _onPreviewCosmetic,
                                ),
                              ),
                              const SizedBox(height: 28),
                              // XP BAR
                              _profileReady
                                  ? _XpBar(xp: xp, rank: rank, nextRank: nextRank, progress: progress, shimmerCtrl: _shimmerCtrl)
                                  : _XpBarSkeleton(shimmerCtrl: _shimmerCtrl),
                              const SizedBox(height: 12),
                              // CURRENTLY VIBING
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: const _CurrentlyVibingCard(),
                              ),
                              // ── end identity block ──
                              const SizedBox(height: 28),
                              // ACTION BUTTONS
                              const _ActionButtons(),
                              const SizedBox(height: 28),
                              // ACHIEVEMENT HALL — badge preview row.
                              // Placed right after Action Buttons (which has
                              // the "Achievements"/"Badges" shortcuts) so the
                              // achievement topic stays together instead of
                              // being split by the Cosmetics section.
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: _AchievementHallPreview(),
                              ),
                              const SizedBox(height: 28),
                              // AKTIVITAS & MISI (was: Season Challenge)
                              const _ActivityMissionCard(),
                              const SizedBox(height: 28),
                              // ANIME LIST TABS
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: const _AnimeListTabs(),
                              ),
                              const SizedBox(height: 28),
                              // ── BENTO GRID ──────────────────────────────────
                              // Real staggered bento instead of repeated 2-col
                              // rows: DNA/AI Roast/Share span the full width,
                              // Favorite+WatchTime stack in the right column
                              // next to DNA's height, Alignment/TasteMap sit
                              // side by side, and Recently Watched gets a
                              // wider column than Koleksi Langka (3:1 instead
                              // of the old 3:2) since its list needs more room.
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: StaggeredGrid.count(
                                  crossAxisCount: 4,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  children: [
                                    // Row 1: DNA Analysis — full width, tall
                                    const StaggeredGridTile.count(
                                      crossAxisCellCount: 4,
                                      mainAxisCellCount: 2.5,
                                      child: _AnimeDnaCard(),
                                    ),
                                    // Row 2: Favorite (left) + Watch Time (right)
                                    const StaggeredGridTile.count(
                                      crossAxisCellCount: 2,
                                      mainAxisCellCount: 2.1,
                                      child: _FavoriteAnimeCard(),
                                    ),
                                    const StaggeredGridTile.count(
                                      crossAxisCellCount: 2,
                                      mainAxisCellCount: 1.5,
                                      child: _WatchTimeCard(),
                                    ),
                                    // Row 3: Alignment + Taste Map, equal halves
                                    const StaggeredGridTile.count(
                                      crossAxisCellCount: 2,
                                      mainAxisCellCount: 2.3,
                                      child: _AlignmentCard(),
                                    ),
                                    const StaggeredGridTile.count(
                                      crossAxisCellCount: 2,
                                      mainAxisCellCount: 2.3,
                                      child: _TasteMapCard(),
                                    ),
                                    // Row 4: Recently Watched (wide) + Koleksi Langka (narrow)
                                    StaggeredGridTile.count(
                                      crossAxisCellCount: 3,
                                      mainAxisCellCount: 2.4,
                                      child: _RecentlyWatchedCard(recentlyWatched: recentlyWatched),
                                    ),
                                    const StaggeredGridTile.count(
                                      crossAxisCellCount: 1,
                                      mainAxisCellCount: 2.4,
                                      child: _KoleksiLangkaCard(),
                                    ),
                                  ],
                                ),
                              ),
                              // AI Roast & Share Profile — taken out of the
                              // staggered grid since their content height is
                              // dynamic (roast text length varies, share
                              // card has several stacked sections). Forcing
                              // them into a fixed grid cell caused bottom
                              // overflow once content grew past the cell's
                              // allotted height. Both are already full-width
                              // (crossAxisCellCount was 4/4), so pulling them
                              // out doesn't affect any neighboring tile.
                              const SizedBox(height: 28),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: _AiRoastCard(),
                              ),
                              const SizedBox(height: 16),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: _ShareProfileCard(),
                              ),
                              const SizedBox(height: 100),
                            ]),
                          ),
                        ],
                      );
                    },
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
// ═══════════════════════════════════════════════════════════════════════════
// DYNAMIC PROFILE BACKGROUND
// ═══════════════════════════════════════════════════════════════════════════

// Config for each BG cosmetic
class _BgConfig {
  final List<Color> gradientColors;  // main background gradient
  final List<Color> orb1Colors;      // top-right orb
  final List<Color> orb2Colors;      // left orb
  final List<Color> orb3Colors;      // bottom orb
  final double orb1Opacity;
  final double orb2Opacity;
  final double orb3Opacity;
  final bool hasStars;
  final bool hasScanlines;

  const _BgConfig({
    required this.gradientColors,
    required this.orb1Colors,
    required this.orb2Colors,
    required this.orb3Colors,
    this.orb1Opacity = 0.18,
    this.orb2Opacity = 0.14,
    this.orb3Opacity = 0.10,
    this.hasStars = false,
    this.hasScanlines = false,
  });
}

const Map<String, _BgConfig> _bgConfigs = {
  // Default — subtle purple/pink atmosphere
  'bg_default': _BgConfig(
    gradientColors: [Color(0xFF0A0A14), Color(0xFF0D0B18), Color(0xFF080812)],
    orb1Colors: [Color(0xFF7C4DFF), Color(0xFF3D1678)],
    orb2Colors: [Color(0xFFFF6B9D), Color(0xFF8B0035)],
    orb3Colors: [Color(0xFF2979FF), Color(0xFF01579B)],
    orb1Opacity: 0.12, orb2Opacity: 0.08, orb3Opacity: 0.06,
  ),
  // Moonlit Shrine — deep blue-purple, mystical mist
  'bg_shrine': _BgConfig(
    gradientColors: [Color(0xFF05050F), Color(0xFF0A0820), Color(0xFF0D0B2A)],
    orb1Colors: [Color(0xFF9B8BFF), Color(0xFF3D1A8C)],
    orb2Colors: [Color(0xFF5C6BC0), Color(0xFF1A237E)],
    orb3Colors: [Color(0xFF7E57C2), Color(0xFF311B92)],
    orb1Opacity: 0.28, orb2Opacity: 0.20, orb3Opacity: 0.16,
    hasStars: true,
  ),
  // Cosmic Nebula — deep space, vivid purple-magenta
  'bg_galaxy': _BgConfig(
    gradientColors: [Color(0xFF030010), Color(0xFF0A0020), Color(0xFF120018)],
    orb1Colors: [Color(0xFFE040FB), Color(0xFF6A0080)],
    orb2Colors: [Color(0xFF7B1FA2), Color(0xFF38006B)],
    orb3Colors: [Color(0xFF00B0FF), Color(0xFF01579B)],
    orb1Opacity: 0.35, orb2Opacity: 0.28, orb3Opacity: 0.20,
    hasStars: true,
  ),
};

_BgConfig _getBgConfig(String bgId) => _bgConfigs[bgId] ?? _bgConfigs['bg_default']!;

class _ProfileBackground extends StatefulWidget {
  final String bgId;
  final AnimationController auraCtrl;
  const _ProfileBackground({required this.bgId, required this.auraCtrl});
  @override State<_ProfileBackground> createState() => _ProfileBackgroundState();
}

class _ProfileBackgroundState extends State<_ProfileBackground> {
  @override
  Widget build(BuildContext context) {
    final cfg = _getBgConfig(widget.bgId);
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      child: SizedBox.expand(
        key: ValueKey(widget.bgId),
        child: Stack(children: [
          // ── Base gradient ─────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: cfg.gradientColors,
              ),
            ),
          ),

          // ── Animated orb 1 (top-right) ───────────────────────────────
          AnimatedBuilder(
            animation: widget.auraCtrl,
            builder: (_, __) {
              final t = widget.auraCtrl.value;
              return Positioned(
                top: -60 + math.sin(t * math.pi * 2) * 20,
                right: -50 + math.cos(t * math.pi) * 15,
                child: Container(
                  width: sw * 0.75,
                  height: sw * 0.75,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      cfg.orb1Colors[0].withOpacity(cfg.orb1Opacity),
                      cfg.orb1Colors[1].withOpacity(cfg.orb1Opacity * 0.4),
                      Colors.transparent,
                    ]),
                  ),
                ),
              );
            },
          ),

          // ── Animated orb 2 (left-center) ─────────────────────────────
          AnimatedBuilder(
            animation: widget.auraCtrl,
            builder: (_, __) {
              final t = widget.auraCtrl.value;
              return Positioned(
                top: sh * 0.25 + math.cos(t * math.pi * 2) * 25,
                left: -70 + math.sin(t * math.pi) * 20,
                child: Container(
                  width: sw * 0.65,
                  height: sw * 0.65,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      cfg.orb2Colors[0].withOpacity(cfg.orb2Opacity),
                      cfg.orb2Colors[1].withOpacity(cfg.orb2Opacity * 0.3),
                      Colors.transparent,
                    ]),
                  ),
                ),
              );
            },
          ),

          // ── Animated orb 3 (bottom-right) ────────────────────────────
          AnimatedBuilder(
            animation: widget.auraCtrl,
            builder: (_, __) {
              final t = widget.auraCtrl.value;
              return Positioned(
                bottom: sh * 0.1 + math.sin(t * math.pi * 2 + 1) * 30,
                right: -40 + math.cos(t * math.pi + 0.5) * 15,
                child: Container(
                  width: sw * 0.55,
                  height: sw * 0.55,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      cfg.orb3Colors[0].withOpacity(cfg.orb3Opacity),
                      cfg.orb3Colors[1].withOpacity(cfg.orb3Opacity * 0.3),
                      Colors.transparent,
                    ]),
                  ),
                ),
              );
            },
          ),

          // ── Star field (only for shrine / galaxy) ────────────────────
          if (cfg.hasStars) const _StarField(),

          // ── Top vignette — fade top edge to pure dark ─────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            height: 160,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [AppTheme.background.withOpacity(0.6), Colors.transparent],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Static star field painter ──────────────────────────────────────────────────
class _StarField extends StatefulWidget {
  const _StarField();
  @override State<_StarField> createState() => _StarFieldState();
}

class _StarFieldState extends State<_StarField> with SingleTickerProviderStateMixin {
  late AnimationController _twinkle;
  final math.Random _rnd = math.Random(42);
  late final List<_StarDot> _stars;

  @override
  void initState() {
    super.initState();
    _twinkle = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _stars = List.generate(60, (i) => _StarDot(
      x: _rnd.nextDouble(),
      y: _rnd.nextDouble() * 0.6, // only in top 60% of screen
      size: 0.8 + _rnd.nextDouble() * 1.4,
      phase: _rnd.nextDouble(),
    ));
  }

  @override void dispose() { _twinkle.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: AnimatedBuilder(
        animation: _twinkle,
        builder: (_, __) => CustomPaint(
          painter: _StarPainter(_stars, _twinkle.value),
        ),
      ),
    ),
  );
}

class _StarDot { final double x, y, size, phase; const _StarDot({required this.x, required this.y, required this.size, required this.phase}); }

class _StarPainter extends CustomPainter {
  final List<_StarDot> stars;
  final double t;
  const _StarPainter(this.stars, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final s in stars) {
      final alpha = 0.3 + 0.55 * math.sin((t + s.phase) * math.pi);
      paint.color = Colors.white.withOpacity(alpha);
      canvas.drawCircle(Offset(s.x * size.width, s.y * size.height), s.size, paint);
    }
  }

  @override bool shouldRepaint(_StarPainter old) => old.t != t;
}


// ── Particle data model ───────────────────────────────────────────────────────
class _Particle {
  double x, y, vx, vy, size, alpha, rotation, vr;
  _Particle({required this.x, required this.y, required this.vx, required this.vy,
             required this.size, required this.alpha, required this.rotation, required this.vr});
}

// ── Ambient particle overlay ──────────────────────────────────────────────────
class _AtmosphereParticles extends StatefulWidget {
  final String fxId;
  const _AtmosphereParticles({required this.fxId});
  @override State<_AtmosphereParticles> createState() => _AtmosphereParticlesState();
}

class _AtmosphereParticlesState extends State<_AtmosphereParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _ticker;
  final List<_Particle> _particles = [];
  final math.Random _rnd = math.Random();

  bool get _active => widget.fxId != 'fx_default' && widget.fxId != 'none';

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }

  @override void dispose() { _ticker.dispose(); super.dispose(); }

  void _update(Size size) {
    if (!_active) { _particles.clear(); return; }
    if (_particles.length < 20 && _rnd.nextDouble() < 0.12) {
      if (widget.fxId == 'fx_sakura') {
        _particles.add(_Particle(
          x: _rnd.nextDouble() * size.width, y: -15,
          vx: -0.4 - _rnd.nextDouble() * 0.8, vy: 1.0 + _rnd.nextDouble() * 1.2,
          size: 4 + _rnd.nextDouble() * 6, alpha: 0.3 + _rnd.nextDouble() * 0.5,
          rotation: _rnd.nextDouble() * math.pi * 2, vr: 0.01 + _rnd.nextDouble() * 0.03,
        ));
      } else if (widget.fxId == 'fx_dragon') {
        _particles.add(_Particle(
          x: _rnd.nextDouble() * size.width, y: size.height + 10,
          vx: -0.3 + _rnd.nextDouble() * 0.6, vy: -1.2 - _rnd.nextDouble() * 1.5,
          size: 3 + _rnd.nextDouble() * 5, alpha: 0.4 + _rnd.nextDouble() * 0.5,
          rotation: _rnd.nextDouble() * math.pi * 2, vr: -0.02 + _rnd.nextDouble() * 0.04,
        ));
      }
    }
    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.x += p.vx; p.y += p.vy; p.rotation += p.vr;
      bool remove = widget.fxId == 'fx_sakura'
          ? (p.y > size.height + 20 || p.x < -20)
          : (p.y < -20);
      if (remove) _particles.removeAt(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _ticker,
          builder: (_, __) => LayoutBuilder(
            builder: (_, constraints) {
              _update(Size(constraints.maxWidth, constraints.maxHeight));
              return CustomPaint(painter: _ParticlePainter(_particles, widget.fxId));
            },
          ),
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final String fxId;
  _ParticlePainter(this.particles, this.fxId);
  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      if (fxId == 'fx_sakura') {
        canvas.save();
        canvas.translate(p.x, p.y);
        canvas.rotate(p.rotation);
        final paint = Paint()..color = const Color(0xFFFFB7D5).withOpacity(p.alpha);
        final path = Path()
          ..moveTo(0, -p.size)
          ..quadraticBezierTo(p.size * 0.8, -p.size * 0.8, p.size * 0.5, 0)
          ..quadraticBezierTo(p.size * 0.2, p.size * 0.8, 0, p.size)
          ..quadraticBezierTo(-p.size * 0.2, p.size * 0.8, -p.size * 0.5, 0)
          ..quadraticBezierTo(-p.size * 0.8, -p.size * 0.8, 0, -p.size);
        canvas.drawPath(path, paint);
        canvas.restore();
      } else if (fxId == 'fx_dragon') {
        canvas.save();
        canvas.translate(p.x, p.y);
        canvas.drawCircle(Offset.zero, p.size * 2.0,
            Paint()..color = Colors.deepOrangeAccent.withOpacity(p.alpha * 0.3));
        canvas.drawCircle(Offset.zero, p.size * 0.8,
            Paint()..color = Colors.amberAccent.withOpacity(p.alpha));
        canvas.restore();
      }
    }
  }
  @override bool shouldRepaint(_) => true;
}


// ═══════════════════════════════════════════════════════════════════════════
// SKELETON LOADING WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

/// Shimmer box helper — reusable bone shape
class _ShimmerBox extends StatelessWidget {
  final double width, height;
  final double radius;
  final AnimationController shimmerCtrl;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.shimmerCtrl,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerCtrl,
      builder: (_, __) {
        final t = shimmerCtrl.value;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + t * 3, 0),
              end: Alignment(-0.5 + t * 3, 0),
              colors: [
                AppTheme.surface,
                AppTheme.surface.withOpacity(0.6),
                Colors.white.withOpacity(0.12),
                AppTheme.surface.withOpacity(0.6),
                AppTheme.surface,
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton for the glass header (avatar + username + rank badge)
class _ProfileHeaderSkeleton extends StatelessWidget {
  final AnimationController shimmerCtrl;
  const _ProfileHeaderSkeleton({required this.shimmerCtrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.textPrimary.withOpacity(0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Avatar circle skeleton
                _ShimmerBox(width: 56, height: 56, radius: 28, shimmerCtrl: shimmerCtrl),
                const SizedBox(width: 14),
                // Name + rank lines
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ShimmerBox(width: 120, height: 14, radius: 7, shimmerCtrl: shimmerCtrl),
                    const SizedBox(height: 8),
                    _ShimmerBox(width: 80, height: 10, radius: 5, shimmerCtrl: shimmerCtrl),
                  ],
                ),
                const Spacer(),
                // Settings icon skeleton
                _ShimmerBox(width: 32, height: 32, radius: 10, shimmerCtrl: shimmerCtrl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton for XP bar
class _XpBarSkeleton extends StatelessWidget {
  final AnimationController shimmerCtrl;
  const _XpBarSkeleton({required this.shimmerCtrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.textPrimary.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ShimmerBox(width: 90, height: 11, radius: 5, shimmerCtrl: shimmerCtrl),
                _ShimmerBox(width: 60, height: 11, radius: 5, shimmerCtrl: shimmerCtrl),
              ],
            ),
            const SizedBox(height: 10),
            _ShimmerBox(width: double.infinity, height: 8, radius: 4, shimmerCtrl: shimmerCtrl),
            const SizedBox(height: 8),
            _ShimmerBox(width: 140, height: 9, radius: 4, shimmerCtrl: shimmerCtrl),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PROFILE GLASS HEADER
// ═══════════════════════════════════════════════════════════════════════════
class _ProfileGlassHeader extends StatelessWidget {
  final String rankName;
  final int xp;
  final AnimationController auraCtrl, crystalCtrl, crystalInnerCtrl;
  final AnimationController? decorCtrl;
  final String equippedFrameId, equippedDecoId, equippedBgId;
  final Uint8List? avatarBytes;
  final bool isPreviewMode;

  const _ProfileGlassHeader({
    required this.rankName, required this.xp,
    required this.auraCtrl, required this.crystalCtrl, required this.crystalInnerCtrl,
    this.decorCtrl, this.equippedFrameId = 'frame_none',
    this.equippedDecoId = 'none', this.equippedBgId = 'bg_default',
    this.avatarBytes, this.isPreviewMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgCfg = _getBgConfig(equippedBgId);
    // Tint color from the BG's primary orb color — subtle, just for glass card
    final bgTint = bgCfg.orb1Colors[0];
    final hasBgCosmetic = equippedBgId != 'bg_default';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Stack(clipBehavior: Clip.none, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: isPreviewMode
                      ? [const Color(0xFFFFB300).withOpacity(0.18), AppTheme.surfaceElevated.withOpacity(0.88), AppTheme.background.withOpacity(0.72)]
                      : hasBgCosmetic
                        ? [bgTint.withOpacity(0.14), AppTheme.surfaceElevated.withOpacity(0.84), AppTheme.background.withOpacity(0.72)]
                        : [AppTheme.surfaceElevated.withOpacity(0.94), AppTheme.surface.withOpacity(0.86), AppTheme.background.withOpacity(0.72)],
                ),
                border: Border.all(
                  color: isPreviewMode
                      ? const Color(0xFFFFB300).withOpacity(0.55)
                      : hasBgCosmetic
                        ? bgTint.withOpacity(0.28)
                        : AppTheme.textPrimary.withOpacity(0.1),
                  width: isPreviewMode ? 1.5 : hasBgCosmetic ? 1.2 : 1.0,
                ),
                boxShadow: [BoxShadow(
                  color: isPreviewMode
                      ? const Color(0xFFFFB300).withOpacity(0.20)
                      : hasBgCosmetic
                        ? bgTint.withOpacity(0.18)
                        : AppTheme.accent.withOpacity(0.10),
                  blurRadius: 22, spreadRadius: -6, offset: const Offset(0, 10),
                )],
              ),
              child: Row(children: [
                _PngBorderAvatar(
                  frameId: equippedFrameId,
                  size: 96,
                  avatarSize: 72,
                  avatarBytes: avatarBytes,
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      ShaderMask(
                        shaderCallback: (b) => LinearGradient(
                          colors: [AppTheme.textPrimary, AppTheme.highlight.withOpacity(0.85)],
                        ).createShader(Rect.fromLTWH(0,0,b.width,b.height)),
                        child: const Text('HITAKU', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.verified_rounded, color: AppTheme.primary, size: 16),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.highlight.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.highlight.withOpacity(0.30)),
                        ),
                        child: Text(rankName, style: TextStyle(color: AppTheme.highlight, fontSize: 9, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 6),
                      Text('$xp XP', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
                    ]),
                  ],
                )),
                GestureDetector(
                  onTap: () {},
                  child: Container(width: 34, height: 34,
                    decoration: BoxDecoration(color: AppTheme.surface.withOpacity(0.8), shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.textSecondary.withOpacity(0.20))),
                    child: Icon(Icons.ios_share_rounded, color: AppTheme.textSecondary, size: 16)),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push<String>(context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    if (result == 'edit_profile' && context.mounted) _showEditProfileSheet(context);
                  },
                  child: Container(width: 34, height: 34,
                    decoration: BoxDecoration(color: AppTheme.surface.withOpacity(0.8), shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.textSecondary.withOpacity(0.20))),
                    child: Icon(Icons.settings_rounded, color: AppTheme.textSecondary, size: 16)),
                ),
              ]),
            ),
          ),
        ),
        // TRY ON MODE badge
        if (isPreviewMode)
          Positioned(
            top: -6, right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: const Color(0xFFFFB300).withOpacity(0.5), blurRadius: 10, spreadRadius: 1)],
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('🎨', style: TextStyle(fontSize: 9)),
                SizedBox(width: 4),
                Text('TRY ON MODE', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PROFILE STATS BAR — Rating / Views / Streak / Achievement Score
// One glass strip, 4 columns, divided by thin vertical separators.
// Mirrors the _ActivitySummaryStat pattern already used lower in the screen
// (icon → big value → small label) so it feels native to the rest of the UI.
// ═══════════════════════════════════════════════════════════════════════════
class _ProfileStatsBar extends StatelessWidget {
  final int achievementsCount;
  const _ProfileStatsBar({required this.achievementsCount});

  @override
  Widget build(BuildContext context) {
    // TODO: wire these to real data sources when available
    // (profile rating, view count, and achievement score aren't tracked
    // yet in MockDataService — using the login-streak value that's already
    // live, and reasonable placeholders for the rest).
    const rating = '4.9';
    const views = '12.4K';
    const achievementScore = '3.240';

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.surfaceElevated.withOpacity(0.85),
                AppTheme.surface.withOpacity(0.72),
                AppTheme.background.withOpacity(0.55),
              ],
            ),
            border: Border.all(color: AppTheme.textPrimary.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _ProfileStatItem(
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFFFC107),
                  value: rating,
                  label: 'Rating',
                ),
              ),
              _StatDivider(),
              Expanded(
                child: _ProfileStatItem(
                  icon: Icons.visibility_rounded,
                  iconColor: AppTheme.primary,
                  value: views,
                  label: 'Profile Views',
                ),
              ),
              _StatDivider(),
              Expanded(
                child: _ProfileStatItem(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: AppTheme.accent,
                  value: '278',
                  label: 'Day Streak',
                ),
              ),
              _StatDivider(),
              Expanded(
                child: _ProfileStatItem(
                  icon: Icons.emoji_events_rounded,
                  iconColor: const Color(0xFFFFD700),
                  value: achievementScore,
                  label: 'Achievement',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 32,
        color: AppTheme.textSecondary.withOpacity(0.15),
      );
}

class _ProfileStatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  const _ProfileStatItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppTheme.textSecondary.withOpacity(0.7),
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ACHIEVEMENT HALL — compact badge preview row for the main profile flow.
// Mirrors the badge data used in _BadgesSheet (kept in sync manually, same
// pattern as _ActivityMissionCard mirroring the streak/mission/challenge
// cards) so the two never show conflicting unlock states. Tapping any badge
// or "Lihat Semua" opens the existing full _BadgesSheet — no new sheet here.
// ═══════════════════════════════════════════════════════════════════════════
class _AchievementHallPreview extends StatelessWidget {
  const _AchievementHallPreview();

  // Mirrors _BadgesSheet._badges — same order, same unlock states.
  static const _previewBadges = [
    {'emoji': '🎖️', 'title': 'Seasonal\nPioneer', 'unlocked': true},
    {'emoji': '🚀', 'title': 'XP\nOverlord', 'unlocked': true},
    {'emoji': '🔥', 'title': '7-Day\nStreak', 'unlocked': true},
    {'emoji': '💎', 'title': 'Legendary\nCollector', 'unlocked': false},
    {'emoji': '🎬', 'title': 'Marathon\nMaster', 'unlocked': false},
    {'emoji': '🌸', 'title': 'Sakura\nEmperor', 'unlocked': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surfaceElevated.withOpacity(0.85),
            AppTheme.surface.withOpacity(0.72),
            AppTheme.background.withOpacity(0.55),
          ],
        ),
        border: Border.all(color: AppTheme.textPrimary.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'ACHIEVEMENT HALL',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _openBadgesSheet(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Lihat Semua',
                        style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                    Icon(Icons.chevron_right_rounded,
                        color: AppTheme.accent, size: 14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: _previewBadges
                .map((b) => Expanded(
                      child: GestureDetector(
                        onTap: () => _openBadgesSheet(context),
                        child: _AchievementHallBadge(
                          emoji: b['emoji'] as String,
                          title: b['title'] as String,
                          unlocked: b['unlocked'] as bool,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  void _openBadgesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _BadgesSheet(),
    );
  }
}

class _AchievementHallBadge extends StatelessWidget {
  final String emoji;
  final String title;
  final bool unlocked;
  const _AchievementHallBadge({
    required this.emoji,
    required this.title,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: unlocked
                ? LinearGradient(
                    colors: [
                      AppTheme.highlight.withOpacity(0.22),
                      AppTheme.accent.withOpacity(0.14),
                    ],
                  )
                : null,
            color: unlocked ? null : AppTheme.surface.withOpacity(0.5),
            border: Border.all(
              color: unlocked
                  ? AppTheme.highlight.withOpacity(0.35)
                  : AppTheme.textSecondary.withOpacity(0.12),
            ),
          ),
          child: Opacity(
            opacity: unlocked ? 1.0 : 0.35,
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: unlocked
                ? AppTheme.textSecondary
                : AppTheme.textSecondary.withOpacity(0.45),
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
      ],
    );
  }
}

void _showEditProfileSheet(BuildContext context) {
  showModalBottomSheet(
    context: context, isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      height: 300,
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Center(child: Text('Edit Profile', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700))),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// MINI DUAL RING AVATAR
// ═══════════════════════════════════════════════════════════════════════════
Widget _avatarFallback() => Container(
  width: 72, height: 72,
  decoration: BoxDecoration(
    gradient: LinearGradient(colors: [AppTheme.surface, AppTheme.surfaceElevated],
      begin: Alignment.topLeft, end: Alignment.bottomRight),
  ),
  child: Icon(Icons.person_rounded, color: AppTheme.textSecondary, size: 34),
);

// ── PNG Border System ─────────────────────────────────────────────────────────
// Maps frameId → asset path + glow color config
class _FrameConfig {
  final String assetPath;
  final Color glowColor;
  final Color glowColorAlt;
  final double rotationSpeed; // 0 = no rotate, positive = slow spin

  const _FrameConfig({
    required this.assetPath,
    required this.glowColor,
    this.glowColorAlt = Colors.transparent,
    this.rotationSpeed = 0,
  });
}

const Map<String, _FrameConfig> _frameConfigs = {
  'frame_sakura':  _FrameConfig(assetPath: 'assets/border/Sakura Emperor.png',  glowColor: Color(0xFFFF6B9D), glowColorAlt: Color(0xFFFFB3D1), rotationSpeed: 0.4),
  'frame_neon':    _FrameConfig(assetPath: 'assets/border/Cyberpunk Neon.png',  glowColor: Color(0xFF00FFCC), glowColorAlt: Color(0xFF0099FF), rotationSpeed: 0.6),
  'frame_demon':   _FrameConfig(assetPath: 'assets/border/Demon Slayer.png',    glowColor: Color(0xFFFF3A1A), glowColorAlt: Color(0xFFFF8C00), rotationSpeed: 0.3),
  'frame_dragon':  _FrameConfig(assetPath: 'assets/border/Dragon Flame.png',    glowColor: Color(0xFFFF5722), glowColorAlt: Color(0xFFFFD700), rotationSpeed: 0.5),
  'frame_shrine':  _FrameConfig(assetPath: 'assets/border/Moonlit Shrine.png',  glowColor: Color(0xFF9B8BFF), glowColorAlt: Color(0xFF6A5ACD), rotationSpeed: 0.2),
  'frame_nebula':  _FrameConfig(assetPath: 'assets/border/Cosmic Nebula.png',   glowColor: Color(0xFFE040FB), glowColorAlt: Color(0xFF7B1FA2), rotationSpeed: 0.35),
  'frame_thunder': _FrameConfig(assetPath: 'assets/border/Thunder God.png',     glowColor: Color(0xFFFFEA00), glowColorAlt: Color(0xFF00B0FF), rotationSpeed: 0.7),
  'frame_wraith':  _FrameConfig(assetPath: 'assets/border/Wraithling Cloak.png',glowColor: Color(0xFF7C4DFF), glowColorAlt: Color(0xFF311B92), rotationSpeed: 0.25),
};

_FrameConfig _getFrameConfig(String frameId) =>
    _frameConfigs[frameId] ?? _frameConfigs['frame_sakura']!;

// ── PNG Border Widget — renders asset + animated glow + slow spin ─────────────
class _PngBorderAvatar extends StatefulWidget {
  final String frameId;
  final double size;
  final double avatarSize;
  final Uint8List? avatarBytes;
  final AnimationController? pulseCtrl; // optional external pulse

  const _PngBorderAvatar({
    required this.frameId,
    this.size = 96,
    this.avatarSize = 72,
    this.avatarBytes,
    this.pulseCtrl,
  });

  @override
  State<_PngBorderAvatar> createState() => _PngBorderAvatarState();
}

class _PngBorderAvatarState extends State<_PngBorderAvatar>
    with TickerProviderStateMixin {
  late AnimationController _rotCtrl;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    final cfg = _getFrameConfig(widget.frameId);

    _rotCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (8000 / (cfg.rotationSpeed + 0.01)).round()),
    );
    if (cfg.rotationSpeed > 0) _rotCtrl.repeat();

    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(_PngBorderAvatar old) {
    super.didUpdateWidget(old);
    if (old.frameId != widget.frameId) {
      final cfg = _getFrameConfig(widget.frameId);
      _rotCtrl.duration = Duration(milliseconds: (8000 / (cfg.rotationSpeed + 0.01)).round());
      if (cfg.rotationSpeed > 0) { _rotCtrl.repeat(); } else { _rotCtrl.stop(); _rotCtrl.reset(); }
    }
  }

  @override
  void dispose() { _rotCtrl.dispose(); _glowCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cfg = _getFrameConfig(widget.frameId);
    final s = widget.size;
    final av = widget.avatarSize;

    return SizedBox(
      width: s, height: s,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rotCtrl, _glowAnim]),
        builder: (_, __) {
          final glow = _glowAnim.value;
          return Stack(alignment: Alignment.center, children: [
            // Outer glow halo — pulsing
            Container(
              width: s, height: s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: cfg.glowColor.withOpacity(0.30 + glow * 0.25),
                    blurRadius: 18 + glow * 14,
                    spreadRadius: 2 + glow * 3,
                  ),
                  BoxShadow(
                    color: cfg.glowColorAlt.withOpacity(0.12 + glow * 0.10),
                    blurRadius: 36,
                    spreadRadius: -4,
                  ),
                ],
              ),
            ),

            // PNG border — slow spin if rotationSpeed > 0, tampil raw tanpa blend
            Transform.rotate(
              angle: cfg.rotationSpeed > 0 ? _rotCtrl.value * math.pi * 2 : 0,
              child: Image.asset(
                cfg.assetPath,
                width: s, height: s,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _fallbackRing(cfg, s, glow),
              ),
            ),

            // Avatar di tengah
            Container(
              width: av, height: av,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: cfg.glowColor.withOpacity(0.55 + glow * 0.25),
                  width: 1.5,
                ),
                boxShadow: [BoxShadow(
                  color: cfg.glowColor.withOpacity(0.18 + glow * 0.12),
                  blurRadius: 8, spreadRadius: 1,
                )],
              ),
              child: ClipOval(
                child: widget.avatarBytes != null
                  ? Image.memory(widget.avatarBytes!, width: av, height: av, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatarFallback())
                  : Image.asset('asset/Hitaku Avatar Pack.png', width: av, height: av, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatarFallback()),
              ),
            ),
          ]);
        },
      ),
    );
  }

  // Fallback kalau asset belum ada — simple glow ring
  Widget _fallbackRing(_FrameConfig cfg, double s, double glow) {
    return Container(
      width: s, height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: cfg.glowColor.withOpacity(0.7 + glow * 0.3), width: 3),
      ),
    );
  }
}

// ── Backward compat: small ring used in cosmetics cards (no avatar) ───────────
class _PngBorderRing extends StatefulWidget {
  final String frameId;
  final double size;
  const _PngBorderRing({required this.frameId, this.size = 48});
  @override State<_PngBorderRing> createState() => _PngBorderRingState();
}

class _PngBorderRingState extends State<_PngBorderRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glow;
  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _glow = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);
  }
  @override void dispose() { _glowCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cfg = _getFrameConfig(widget.frameId);
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, __) => SizedBox(
        width: widget.size, height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Glow ring behind PNG — subtle ambient shadow
            Container(
              width: widget.size, height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: cfg.glowColor.withOpacity(0.30 + _glow.value * 0.30),
                    blurRadius: 12 + _glow.value * 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            // PNG border — NO clip, NO color blend, raw asset tampil utuh
            Image.asset(
              cfg.assetPath,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                width: widget.size, height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: cfg.glowColor.withOpacity(0.8), width: 2.5),
                  boxShadow: [BoxShadow(color: cfg.glowColor.withOpacity(0.4), blurRadius: 8)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// XP BAR
// ═══════════════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════
// CURRENTLY VIBING CARD
// ═══════════════════════════════════════════════════════════════════════════
class _CurrentlyVibingCard extends StatefulWidget {
  const _CurrentlyVibingCard();
  @override State<_CurrentlyVibingCard> createState() => _CurrentlyVibingCardState();
}

class _CurrentlyVibingCardState extends State<_CurrentlyVibingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ContinueWatchingModel>>(
      valueListenable: MockDataService.continueWatchingNotifier,
      builder: (_, list, __) {
        // Use the most recently watched entry (first in list)
        final cw = list.isNotEmpty ? list.first : null;

        if (cw == null) return _emptyState();

        final title    = cw.animeTitle.isNotEmpty ? cw.animeTitle : 'Anime';
        final epLabel  = 'Episode ${cw.episodeNumber}';
        final prog     = cw.watchProgress.clamp(0.0, 1.0);
        final thumbUrl = cw.thumbnailUrl.isNotEmpty ? cw.thumbnailUrl : null;
        final initials = title.split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join();

        return AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) {
            final pulse = _pulseCtrl.value;
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [AppTheme.surfaceElevated, AppTheme.surface.withOpacity(0.92)],
                ),
                border: Border.all(color: AppTheme.highlight.withOpacity(0.22 + pulse * 0.12), width: 1.5),
                boxShadow: [BoxShadow(color: AppTheme.highlight.withOpacity(0.10 + pulse * 0.08), blurRadius: 20, spreadRadius: -2, offset: const Offset(0, 6))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(children: [
                        Container(
                          width: 64, height: 80,
                          color: AppTheme.surfaceElevated,
                          child: thumbUrl != null
                            ? Image.network(thumbUrl, width: 64, height: 80, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _thumbFallback(initials))
                            : _thumbFallback(initials),
                        ),
                        // Progress bar di bawah thumbnail
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: Stack(children: [
                            Container(height: 4, color: AppTheme.background.withOpacity(0.5)),
                            FractionallySizedBox(
                              widthFactor: prog,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [AppTheme.highlight, AppTheme.accent]),
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 14),
                    // Info
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Live badge
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [AppTheme.sage.withOpacity(0.25), AppTheme.sage.withOpacity(0.10)]),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.sage.withOpacity(0.50)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 5, height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.sage,
                                boxShadow: [BoxShadow(color: AppTheme.sage.withOpacity(0.6 + pulse * 0.4), blurRadius: 4 + pulse * 3)],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text('LAGI DITONTON', style: TextStyle(color: AppTheme.sage, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 7),
                      Text(title,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w900, height: 1.2)),
                      const SizedBox(height: 4),
                      Text(epLabel, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: prog,
                          minHeight: 5,
                          backgroundColor: AppTheme.surfaceElevated,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.highlight),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('${(prog * 100).round()}% selesai',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.w700)),
                        Text('Lanjut →',
                          style: TextStyle(color: AppTheme.highlight, fontSize: 9, fontWeight: FontWeight.w900)),
                      ]),
                    ])),
                  ]),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _emptyState() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      color: AppTheme.surfaceElevated,
      border: Border.all(color: AppTheme.textPrimary.withOpacity(0.08)),
    ),
    child: Row(children: [
      Icon(Icons.play_circle_outline_rounded, color: AppTheme.textSecondary.withOpacity(0.4), size: 36),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Belum ada yang ditonton', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Mulai nonton anime & progress-mu bakal muncul di sini.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, height: 1.4)),
      ])),
    ]),
  );

  Widget _thumbFallback(String initials) => Container(
    width: 64, height: 80,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [AppTheme.surfaceElevated, AppTheme.highlight.withOpacity(0.15)],
      ),
    ),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.play_circle_rounded, color: AppTheme.highlight.withOpacity(0.7), size: 28),
      const SizedBox(height: 4),
      Text(initials.toUpperCase(), style: TextStyle(color: AppTheme.highlight, fontSize: 9, fontWeight: FontWeight.w900)),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// XP BAR
// ═══════════════════════════════════════════════════════════════════════════
class _XpBar extends StatelessWidget {
  final int xp;
  final _Rank rank;
  final _Rank? nextRank;
  final double progress;
  final AnimationController shimmerCtrl;
  const _XpBar({required this.xp, required this.rank, required this.nextRank, required this.progress, required this.shimmerCtrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppTheme.surfaceElevated, AppTheme.surface.withOpacity(0.9)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.highlight.withOpacity(0.20)),
          boxShadow: [BoxShadow(color: AppTheme.accent.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            ShaderMask(
              shaderCallback: (b) => LinearGradient(colors: [AppTheme.highlight, AppTheme.accent]).createShader(Rect.fromLTWH(0,0,b.width,b.height)),
              child: Text(rank.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
            ),
            if (nextRank != null)
              Text('Next: ${nextRank!.name}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          ]),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: shimmerCtrl,
            builder: (_, __) {
              return Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.surface.withOpacity(0.8),
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.highlight),
                    minHeight: 10,
                  ),
                ),
                // Shimmer sweep
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LayoutBuilder(builder: (_, c) {
                    final w = c.maxWidth * progress;
                    return Container(
                      height: 10, width: w,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(shimmerCtrl.value * 2 - 1.5, 0),
                          end: Alignment(shimmerCtrl.value * 2, 0),
                          colors: [Colors.transparent, Colors.white.withOpacity(0.35), Colors.transparent],
                        ),
                      ),
                    );
                  }),
                ),
              ]);
            },
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('$xp XP', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
            if (nextRank != null)
              Text('${nextRank!.minXP - xp} XP lagi', style: TextStyle(color: AppTheme.highlight, fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ACTION BUTTONS
// ═══════════════════════════════════════════════════════════════════════════
class _ActionButtons extends StatelessWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context) {
    final btns = [
      (Icons.edit_rounded, 'Edit Profil', AppTheme.highlight),
      (Icons.military_tech_rounded, 'Badges', AppTheme.accent),
      (Icons.emoji_events_rounded, 'Achievements', const Color(0xFFFFB300)),
      (Icons.history_rounded, 'Watch History', AppTheme.primary),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: btns.map((b) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => _showActionSheet(context, b.$2),
              child: Column(children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: b.$3.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: b.$3.withOpacity(0.30)),
                    boxShadow: [BoxShadow(color: b.$3.withOpacity(0.12), blurRadius: 8)],
                  ),
                  child: Icon(b.$1, color: b.$3, size: 20),
                ),
                const SizedBox(height: 5),
                Text(b.$2, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        )).toList(),
      ),
    );
  }

  void _showActionSheet(BuildContext context, String title) {
    Widget sheet;
    if (title == 'Edit Profil') {
      sheet = const _EditProfileSheet();
    } else if (title == 'Badges') {
      sheet = const _BadgesSheet();
    } else if (title == 'Achievements') {
      sheet = const _AchievementsSheet();
    } else {
      sheet = const _WatchHistorySheet();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SPECIALIZED INTERACTIVE SHEETS
// ═══════════════════════════════════════════════════════════════════════════
class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet();
  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _nameController = TextEditingController(text: "HITAKU");
  final _bioController = TextEditingController(text: "Wibu akut penyuka action shonen. Don't touch me I'm watching One Piece.");
  int _selectedAvatarIndex = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.highlight.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Edit Profil', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PILIH AVATAR PRESET', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 70,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 5,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) {
                        final sel = i == _selectedAvatarIndex;
                        return GestureDetector(
                          onTap: () {
                            Feedback.forTap(context);
                            setState(() => _selectedAvatarIndex = i);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 60, height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: sel ? AppTheme.highlight : AppTheme.textSecondary.withOpacity(0.2), width: sel ? 3.0 : 1.5),
                              boxShadow: sel ? [BoxShadow(color: AppTheme.highlight.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)] : [],
                            ),
                            child: ClipOval(
                              child: Container(
                                color: AppTheme.surface,
                                child: Center(
                                  child: Text(
                                    ['🦊', '🧙‍♂️', '🥷', '🐉', '👾'][i],
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('USERNAME', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.surface.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.textSecondary.withOpacity(0.15))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.highlight, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('BIO', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w800)),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _bioController,
                        builder: (_, val, __) {
                          return Text('${val.text.length}/80', style: TextStyle(color: val.text.length > 80 ? Colors.red : AppTheme.textSecondary, fontSize: 10));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bioController,
                    maxLines: 3,
                    maxLength: 80,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.surface.withOpacity(0.5),
                      counterText: "",
                      contentPadding: const EdgeInsets.all(16),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.textSecondary.withOpacity(0.15))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.highlight, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  GestureDetector(
                    onTap: () {
                      Feedback.forTap(context);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppTheme.highlight, AppTheme.accent]),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: AppTheme.highlight.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: const Text('Simpan Perubahan', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgesSheet extends StatefulWidget {
  const _BadgesSheet();
  @override
  State<_BadgesSheet> createState() => _BadgesSheetState();
}

class _BadgesSheetState extends State<_BadgesSheet> {
  int _selectedBadgeIndex = 0;

  final List<Map<String, dynamic>> _badges = [
    {'emoji': '🎖️', 'title': 'Seasonal Pioneer', 'unlocked': true, 'desc': 'Diberikan karena mengikuti event Summer Season Pass 2026.', 'color': AppTheme.highlight},
    {'emoji': '🚀', 'title': 'XP Overlord', 'unlocked': true, 'desc': 'Mencapai peringkat Tier Newbie Nyasar ke atas.', 'color': AppTheme.accent},
    {'emoji': '🔥', 'title': '7-Day Streak', 'unlocked': true, 'desc': 'Menonton minimal 1 episode setiap hari selama 7 hari berturut-turut.', 'color': Colors.orangeAccent},
    {'emoji': '💎', 'title': 'Legendary Collector', 'unlocked': false, 'desc': 'Kunci pembuka: Memiliki minimal 5 kosmetik berperingkat LEGENDARY.', 'color': Colors.purpleAccent},
    {'emoji': '🎬', 'title': 'Marathon Master', 'unlocked': false, 'desc': 'Kunci pembuka: Menonton 5 episode anime secara berurutan dalam 24 jam.', 'color': Colors.cyanAccent},
    {'emoji': '🌸', 'title': 'Sakura Emperor', 'unlocked': false, 'desc': 'Kunci pembuka: Klaim seasonal pass tier 50 ke atas.', 'color': const Color(0xFFFF80AB)},
  ];

  @override
  Widget build(BuildContext context) {
    final badge = _badges[_selectedBadgeIndex];
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.highlight.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Lencana Profil', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
          Text('Pamerkan lencana pencapaian terbaikmu di profil', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: _badges.length,
                    itemBuilder: (_, i) {
                      final b = _badges[i];
                      final sel = i == _selectedBadgeIndex;
                      final unl = b['unlocked'] as bool;
                      final c = b['color'] as Color;
                      return GestureDetector(
                        onTap: () {
                          Feedback.forTap(context);
                          setState(() => _selectedBadgeIndex = i);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: sel ? c.withOpacity(0.08) : AppTheme.surface.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: sel ? c : (unl ? c.withOpacity(0.25) : AppTheme.textSecondary.withOpacity(0.1)), width: sel ? 2 : 1),
                            boxShadow: sel ? [BoxShadow(color: c.withOpacity(0.15), blurRadius: 8)] : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Opacity(
                                opacity: unl ? 1.0 : 0.4,
                                child: Text(b['emoji'] as String, style: const TextStyle(fontSize: 32)),
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  b['title'] as String,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: unl ? AppTheme.textPrimary : AppTheme.textSecondary,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: badge['color'].withOpacity(0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(badge['emoji'] as String, style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(badge['title'] as String, style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 2),
                                  Text(
                                    badge['unlocked'] as bool ? 'DISEMATKAN & UNLOCKED' : 'TERKUNCI',
                                    style: TextStyle(color: badge['unlocked'] as bool ? AppTheme.success : AppTheme.textSecondary, fontSize: 8.5, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          badge['desc'] as String,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementsSheet extends StatefulWidget {
  const _AchievementsSheet();
  @override
  State<_AchievementsSheet> createState() => _AchievementsSheetState();
}

class _AchievementsSheetState extends State<_AchievementsSheet> {
  final List<Map<String, dynamic>> _achievements = [
    {'id': 'a1', 'title': 'Wibu Sejati 🎌', 'desc': 'Tonton akumulasi anime hingga mencapai 10.000 jam.', 'progress': 1.0, 'current': '14,280', 'target': '10,000', 'xp': 250, 'claimed': false, 'claimable': true},
    {'id': 'a2', 'title': 'Kolektor Pemula 🛍️', 'desc': 'Miliki 3 jenis kosmetik avatar di storefront.', 'progress': 0.66, 'current': '2', 'target': '3', 'xp': 100, 'claimed': false, 'claimable': false},
    {'id': 'a3', 'title': 'Penilai Ulung ⭐', 'desc': 'Berikan rating dan komentar ke 5 episode baru.', 'progress': 1.0, 'current': '5', 'target': '5', 'xp': 50, 'claimed': true, 'claimable': false},
    {'id': 'a4', 'title': 'Pioneer Musiman 🌊', 'desc': 'Selesaikan seluruh misi seasonal challenge Summer 2026.', 'progress': 0.33, 'current': '1', 'target': '3', 'xp': 180, 'claimed': false, 'claimable': false},
  ];

  void _claimXp(int index) {
    final ach = _achievements[index];
    if (ach['claimable'] as bool && !(ach['claimed'] as bool)) {
      Feedback.forTap(context);
      setState(() {
        _achievements[index]['claimed'] = true;
        _achievements[index]['claimable'] = false;
      });
      MockDataService.xpNotifier.value += ach['xp'] as int;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.success,
          content: Text('Selamat! Kamu berhasil mengklaim +${ach['xp']} XP!', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.highlight.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Pencapaian', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
          Text('Selesaikan misi untuk mendapatkan tambahan XP gratis!', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _achievements.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, idx) {
                final ach = _achievements[idx];
                final prog = ach['progress'] as double;
                final claimable = ach['claimable'] as bool;
                final claimed = ach['claimed'] as bool;
                final xp = ach['xp'] as int;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: claimable ? AppTheme.highlight.withOpacity(0.3) : AppTheme.textPrimary.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ach['title'] as String, style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(ach['desc'] as String, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: prog,
                                      backgroundColor: AppTheme.textPrimary.withOpacity(0.06),
                                      valueColor: AlwaysStoppedAnimation<Color>(prog == 1.0 ? AppTheme.success : AppTheme.highlight),
                                      minHeight: 5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text('${ach["current"]}/${ach["target"]}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 9.5, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        children: [
                          if (claimed)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(color: AppTheme.textSecondary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                              child: Text('Klaim', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w900)),
                            )
                          else if (claimable)
                            GestureDetector(
                              onTap: () => _claimXp(idx),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [AppTheme.highlight, AppTheme.accent]),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [BoxShadow(color: AppTheme.highlight.withOpacity(0.2), blurRadius: 6)],
                                ),
                                child: Text('Klaim +$xp', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(color: AppTheme.textPrimary.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                              child: Text('+$xp XP', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
                            )
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchHistorySheet extends StatelessWidget {
  const _WatchHistorySheet();

  final List<Map<String, dynamic>> _history = const [
    {'title': 'Dungeon Meshi', 'ep': 'Episode 22', 'time': '2 jam yang lalu', 'prog': 0.92, 'emoji': '🍲'},
    {'title': 'One Piece', 'ep': 'Episode 1082', 'time': 'Kemarin', 'prog': 0.40, 'emoji': '🏴‍☠️'},
    {'title': 'Demon Slayer S4', 'ep': 'Episode 8', 'time': '3 hari yang lalu', 'prog': 0.62, 'emoji': '⚔️'},
    {'title': 'Blue Lock S2', 'ep': 'Episode 5', 'time': '5 hari yang lalu', 'prog': 0.42, 'emoji': '⚽'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.highlight.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Riwayat Menonton', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
          Text('Kembali tonton episode yang baru saja kamu tinggalkan', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _history.length,
              itemBuilder: (context, idx) {
                final h = _history[idx];
                final prog = h['prog'] as double;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: AppTheme.accent.withOpacity(0.2))),
                            child: Center(child: Text(h['emoji'] as String, style: const TextStyle(fontSize: 16))),
                          ),
                          if (idx < _history.length - 1)
                            Container(width: 2, height: 40, color: AppTheme.textSecondary.withOpacity(0.15)),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(h['title'] as String, style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 2),
                            Text('${h["ep"]} • ${h["time"]}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: prog,
                                      backgroundColor: AppTheme.textPrimary.withOpacity(0.06),
                                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.highlight),
                                      minHeight: 4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text('${(prog * 100).toInt()}%', style: TextStyle(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          Feedback.forTap(context);
                          Navigator.pop(context);
                        },
                        child: Icon(Icons.play_circle_fill_rounded, color: AppTheme.highlight, size: 28),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CURRENT LOADOUT — compact 7-slot equipped cosmetics carousel
// ═══════════════════════════════════════════════════════════════════════════
class _LoadoutSlotDef {
  final String label;
  final String type; // matches _CosmeticItem.type / _typeToCategory key
  final IconData fallbackIcon;
  const _LoadoutSlotDef({required this.label, required this.type, required this.fallbackIcon});
}

const List<_LoadoutSlotDef> _kLoadoutSlots = [
  _LoadoutSlotDef(label: 'Border',      type: 'Avatar Border', fallbackIcon: Icons.radio_button_checked_rounded),
  _LoadoutSlotDef(label: 'Background',  type: 'Profile BG',    fallbackIcon: Icons.wallpaper_rounded),
  _LoadoutSlotDef(label: 'Effect',      type: 'Profile FX',    fallbackIcon: Icons.auto_awesome_rounded),
  _LoadoutSlotDef(label: 'Avatar Deco', type: 'Avatar Deco',   fallbackIcon: Icons.blur_on_rounded),
  _LoadoutSlotDef(label: 'Aura',        type: 'Aura',          fallbackIcon: Icons.blur_circular_rounded),
  _LoadoutSlotDef(label: 'Name Color',  type: 'Name Color',    fallbackIcon: Icons.text_fields_rounded),
  _LoadoutSlotDef(label: 'Title',       type: 'Title',         fallbackIcon: Icons.emoji_events_rounded),
];

class _CurrentLoadoutCard extends StatefulWidget {
  final String equippedFrameId, equippedBgId, equippedFxId, equippedDecoId;
  final String equippedAuraId, equippedNameColorId, equippedTitleId;
  final Function(String, String) onEquip;
  final Function(String, String)? onPreviewChanged;
  const _CurrentLoadoutCard({
    required this.equippedFrameId, required this.equippedBgId, required this.equippedFxId,
    required this.equippedDecoId, required this.equippedAuraId, required this.equippedNameColorId,
    required this.equippedTitleId, required this.onEquip, this.onPreviewChanged,
  });
  @override State<_CurrentLoadoutCard> createState() => _CurrentLoadoutCardState();
}

class _CurrentLoadoutCardState extends State<_CurrentLoadoutCard> {
  late final PageController _pageCtrl;
  double _page = 0;
  static const int _perPage = 4;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 1.0)
      ..addListener(() {
        setState(() => _page = _pageCtrl.page ?? 0);
      });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  _CosmeticItem? _equippedItemFor(_LoadoutSlotDef slot) {
    String equippedId;
    List<_CosmeticItem> pool;
    switch (slot.type) {
      case 'Avatar Border': equippedId = widget.equippedFrameId; pool = _kAllCosmeticItems; break;
      case 'Profile BG':    equippedId = widget.equippedBgId;    pool = _kAllCosmeticItems; break;
      case 'Profile FX':    equippedId = widget.equippedFxId;    pool = _kAllCosmeticItems; break;
      case 'Avatar Deco':   equippedId = widget.equippedDecoId;  pool = _kAllCosmeticItems; break;
      case 'Aura':          equippedId = widget.equippedAuraId;      pool = _kAuraItems; break;
      case 'Name Color':    equippedId = widget.equippedNameColorId; pool = _kNameColorItems; break;
      case 'Title':         equippedId = widget.equippedTitleId;     pool = _kTitleItems; break;
      default: return null;
    }
    for (final item in pool) {
      if (item.id == equippedId) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = (_kLoadoutSlots.length / _perPage).ceil();
    return _Card(
      entranceDelay: const Duration(milliseconds: 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('CURRENT LOADOUT', style: TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
          const Spacer(),
          Text('Customize  ›', style: TextStyle(color: AppTheme.highlight, fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 92,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: pageCount,
            itemBuilder: (context, pageIndex) {
              final start = pageIndex * _perPage;
              final end = math.min(start + _perPage, _kLoadoutSlots.length);
              final slots = _kLoadoutSlots.sublist(start, end);
              return Row(
                children: [
                  for (final slot in slots)
                    Expanded(child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _LoadoutSlotTile(
                        slot: slot,
                        item: _equippedItemFor(slot),
                        isEquippedSlot: start == 0 && slot == _kLoadoutSlots.first,
                      ),
                    )),
                ],
              );
            },
          ),
        ),
        if (pageCount > 1) ...[
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (int i = 0; i < pageCount; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: (_page.round() == i) ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: (_page.round() == i) ? AppTheme.highlight : AppTheme.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ]),
        ],
      ]),
    );
  }
}

class _LoadoutSlotTile extends StatelessWidget {
  final _LoadoutSlotDef slot;
  final _CosmeticItem? item;
  final bool isEquippedSlot;
  const _LoadoutSlotTile({required this.slot, required this.item, required this.isEquippedSlot});

  @override
  Widget build(BuildContext context) {
    final color = item?.color ?? AppTheme.textSecondary;
    return Column(children: [
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [color.withOpacity(0.20), AppTheme.surface],
          ),
          border: Border.all(color: isEquippedSlot ? AppTheme.highlight : color.withOpacity(0.4), width: isEquippedSlot ? 1.6 : 1),
        ),
        child: Icon(item?.icon ?? slot.fallbackIcon, color: color, size: 22),
      ),
      const SizedBox(height: 6),
      Text(slot.label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.w700), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PROFILE COSMETICS SHOWCASE (with Live Try-On callback)
// ═══════════════════════════════════════════════════════════════════════════
class _CosmeticItem {
  final String id, type, name, rarity, price;
  final IconData icon;
  final Color color;
  final bool owned;
  const _CosmeticItem({required this.id, required this.type, required this.name, required this.rarity, required this.price, required this.icon, required this.color, required this.owned});
  _CosmeticItem copyWith({bool? owned}) => _CosmeticItem(id: id, type: type, name: name, rarity: rarity, price: price, icon: icon, color: color, owned: owned ?? this.owned);
}

// ── Loadout item pools for the 3 new slot types (Aura / Name Color / Title) ──
const List<_CosmeticItem> _kAuraItems = [
  _CosmeticItem(id: 'aura_default',   type: 'Aura', name: 'No Aura',        rarity: 'COMMON',    price: 'Owned',    icon: Icons.circle_outlined,          color: Color(0xFF8A8A9E), owned: true),
  _CosmeticItem(id: 'aura_violet',    type: 'Aura', name: 'Violet Pulse',   rarity: 'LEGENDARY', price: 'Owned',    icon: Icons.blur_circular_rounded,    color: Color(0xFF7C4DFF), owned: true),
  _CosmeticItem(id: 'aura_inferno',   type: 'Aura', name: 'Inferno Ring',   rarity: 'MYSTIC',    price: '640 Gems', icon: Icons.local_fire_department_rounded, color: Color(0xFFFF5722), owned: false),
  _CosmeticItem(id: 'aura_frost',     type: 'Aura', name: 'Frostbound',     rarity: 'PREMIUM',   price: '400 Gems', icon: Icons.ac_unit_rounded,          color: Color(0xFF64C8FF), owned: false),
];

const List<_CosmeticItem> _kNameColorItems = [
  _CosmeticItem(id: 'namecolor_default', type: 'Name Color', name: 'Classic White', rarity: 'COMMON',    price: 'Owned',    icon: Icons.text_fields_rounded, color: Color(0xFFF2F2F7), owned: true),
  _CosmeticItem(id: 'namecolor_purple',  type: 'Name Color', name: 'HITAKU Violet',  rarity: 'LEGENDARY', price: 'Owned',    icon: Icons.text_fields_rounded, color: Color(0xFF9B6BFF), owned: true),
  _CosmeticItem(id: 'namecolor_gold',    type: 'Name Color', name: 'Emperor Gold',   rarity: 'MYSTIC',    price: '700 Gems', icon: Icons.text_fields_rounded, color: Color(0xFFFFC94D), owned: false),
  _CosmeticItem(id: 'namecolor_crimson', type: 'Name Color', name: 'Crimson Blade',  rarity: 'PREMIUM',   price: '350 Gems', icon: Icons.text_fields_rounded, color: Color(0xFFFF4B6E), owned: false),
];

const List<_CosmeticItem> _kTitleItems = [
  _CosmeticItem(id: 'title_newbie',         type: 'Title', name: 'Newbie Nyasar',  rarity: 'COMMON',    price: 'Owned',    icon: Icons.emoji_events_outlined, color: Color(0xFF8A8A9E), owned: true),
  _CosmeticItem(id: 'title_anime_emperor',  type: 'Title', name: 'Anime Emperor',  rarity: 'LEGENDARY', price: 'Owned',    icon: Icons.emoji_events_rounded,  color: Color(0xFFFFC94D), owned: true),
  _CosmeticItem(id: 'title_battle_seeker',  type: 'Title', name: 'Battle Seeker',  rarity: 'MYSTIC',    price: '500 Gems', icon: Icons.emoji_events_rounded,  color: Color(0xFF7C4DFF), owned: false),
  _CosmeticItem(id: 'title_founder',        type: 'Title', name: 'Founder',        rarity: 'LEGENDARY', price: 'Owned',    icon: Icons.workspace_premium_rounded, color: Color(0xFFFF6B9D), owned: true),
];

// ── Shared pool: Border / Background / Effect / Avatar Deco items ──────────
// (extracted from the old cosmetics storefront so _CurrentLoadoutCard and any
// future picker can reference equipped items by id without needing the
// storefront widget itself)
const List<_CosmeticItem> _kAllCosmeticItems = [
  _CosmeticItem(id: 'deco_wraithling', type: 'Avatar Deco', name: 'Wraithling Cloak', rarity: 'LEGENDARY', price: 'Owned', icon: Icons.blur_on_rounded, color: Color(0xFF7C4DFF), owned: true),
  _CosmeticItem(id: 'frame_sakura',  type: 'Avatar Border', name: 'Sakura Emperor',   rarity: 'LEGENDARY', price: 'Owned',    icon: Icons.radio_button_checked_rounded, color: Color(0xFFFF6B9D), owned: true),
  _CosmeticItem(id: 'frame_neon',    type: 'Avatar Border', name: 'Cyberpunk Neon',   rarity: 'MYSTIC',    price: '600 Gems', icon: Icons.filter_tilt_shift_rounded,    color: Color(0xFF00FFCC), owned: false),
  _CosmeticItem(id: 'frame_demon',   type: 'Avatar Border', name: 'Demon Slayer',      rarity: 'LEGENDARY', price: '720 Gems', icon: Icons.whatshot_rounded,              color: Color(0xFFFF3A1A), owned: false),
  _CosmeticItem(id: 'frame_dragon',  type: 'Avatar Border', name: 'Dragon Flame',      rarity: 'MYSTIC',    price: '750 Gems', icon: Icons.local_fire_department_rounded, color: Color(0xFFFF5722), owned: false),
  _CosmeticItem(id: 'frame_shrine',  type: 'Avatar Border', name: 'Moonlit Shrine',    rarity: 'LIMITED',   price: '480 Gems', icon: Icons.nightlight_round,              color: Color(0xFF9B8BFF), owned: false),
  _CosmeticItem(id: 'frame_nebula',  type: 'Avatar Border', name: 'Cosmic Nebula',     rarity: 'LEGENDARY', price: '550 Gems', icon: Icons.blur_circular_rounded,         color: Color(0xFFE040FB), owned: false),
  _CosmeticItem(id: 'frame_thunder', type: 'Avatar Border', name: 'Thunder God',       rarity: 'MYSTIC',    price: '680 Gems', icon: Icons.bolt_rounded,                  color: Color(0xFFFFEA00), owned: false),
  _CosmeticItem(id: 'frame_wraith',  type: 'Avatar Border', name: 'Wraithling Cloak',  rarity: 'LEGENDARY', price: '800 Gems', icon: Icons.dark_mode_rounded,             color: Color(0xFF7C4DFF), owned: false),
  _CosmeticItem(id: 'bg_shrine',  type: 'Profile BG', name: 'Moonlit Shrine',  rarity: 'LIMITED',   price: '480 Gems', icon: Icons.wallpaper_rounded,      color: AppTheme.accent,        owned: false),
  _CosmeticItem(id: 'bg_galaxy',  type: 'Profile BG', name: 'Cosmic Nebula',   rarity: 'LEGENDARY', price: '550 Gems', icon: Icons.blur_circular_rounded,  color: Color(0xFFE040FB),      owned: false),
  _CosmeticItem(id: 'fx_sakura',  type: 'Profile FX', name: 'Falling Sakura',  rarity: 'PREMIUM',   price: '320 Gems', icon: Icons.auto_awesome_rounded,   color: AppTheme.accent,        owned: false),
  _CosmeticItem(id: 'fx_dragon',  type: 'Profile FX', name: 'Dragon Flame',    rarity: 'MYSTIC',    price: '750 Gems', icon: Icons.whatshot_rounded,        color: Color(0xFFFF5252),      owned: false),
];


class _RarityBadge extends StatelessWidget {
  final String rarity; final Color color;
  const _RarityBadge({required this.rarity, required this.color});
  @override
  Widget build(_) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.3))),
    child: Text(rarity, style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.w900)),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// AKTIVITAS & MISI (ported from home_screen.dart, replaces Season Challenge)
// ═══════════════════════════════════════════════════════════════════════════
// Home's "Aktivitas & Misi" summary card taps through to Profile expecting
// a Daily Login/Mission section here — Season Challenge was a different
// feature (seasonal challenges, not daily streak/missions), so it's been
// swapped out for the real _ActivityMissionCard cluster from Home. Collapsed
// by default: 3-stat summary row (Login Streak / Daily Mission / Weekly
// Challenge %) with a "Lihat Semua" toggle that expands to the full 3 cards.
class _ActivityMissionCard extends StatefulWidget {
  const _ActivityMissionCard();
  @override
  State<_ActivityMissionCard> createState() => _ActivityMissionCardState();
}

class _ActivityMissionCardState extends State<_ActivityMissionCard> {
  bool _expanded = false;

  // Summary numbers — mirrors the data inside _DailyLoginStreakCard,
  // _DailyMissionCard, and _WeeklyChallengeCard (kept in sync manually
  // since those widgets manage their own internal state/animations).
  static const int _loginStreak = 7;
  static const int _missionDone = 2;
  static const int _missionTotal = 3;
  static const double _challengeProg = 17 / 28; // 7+3+1+6 of 10+5+3+10

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.22),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // ── Background artwork — trophy/achievement theme, with the
              // left side kept dark/empty by design so the stat row and
              // "Lihat Semua" toggle stay legible without extra darkening
              // there. Falls back to the old gold gradient if the asset is
              // ever missing.
              Positioned.fill(
                child: Image.asset(
                  'asset/images/home screen/Aktivitas & Misi.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color.lerp(AppTheme.surface, const Color(0xFF3D2A0F), 0.55)!,
                          Color.lerp(AppTheme.surfaceElevated, const Color(0xFFFFD700), 0.10)!,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              ),
              // Warm darken so text/glass stay legible over the artwork,
              // heavier on the right where the trophy illustration is busiest.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: 0.15),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Collapsed summary row ──
              Row(
                children: [
                  Expanded(
                    child: _ActivitySummaryStat(
                      icon: Icons.local_fire_department_rounded,
                      iconColor: AppTheme.accent,
                      value: '$_loginStreak Hari',
                      label: 'Login Streak',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: AppTheme.textSecondary.withValues(alpha: 0.15),
                  ),
                  Expanded(
                    child: _ActivitySummaryStat(
                      icon: Icons.task_alt_rounded,
                      iconColor: AppTheme.primary,
                      value: '$_missionDone/$_missionTotal',
                      label: 'Daily Mission',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: AppTheme.textSecondary.withValues(alpha: 0.15),
                  ),
                  Expanded(
                    child: _ActivitySummaryStat(
                      icon: Icons.emoji_events_rounded,
                      iconColor: const Color(0xFFFFD700),
                      value: '${(_challengeProg * 100).round()}%',
                      label: 'Weekly Challenge',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // ── Lihat Semua / Sembunyikan toggle ──
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _expanded ? 'Sembunyikan' : 'Lihat Semua',
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.accent,
                          size: 15,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // ── Expanded detail (original widgets, untouched) ──
              if (_expanded) ...[
                const SizedBox(height: 14),
                const _DailyLoginStreakCard(),
                const SizedBox(height: 14),
                _DailyMissionCard(),
                const SizedBox(height: 14),
                const _WeeklyChallengeCard(),
              ],
            ],
          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _ActivitySummaryStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  const _ActivitySummaryStat({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary.withValues(alpha: 0.7),
            fontSize: 8,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
class _DailyMissionCard extends StatelessWidget {
  _DailyMissionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: -4,
            offset: Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              // Alpha lowered from 0.60 — this card sits inside
              // _ActivityMissionCard which now has real background artwork;
              // a lighter tint lets it show through as true glass instead
              // of being fully covered.
              color: AppTheme.surfaceElevated.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primary.withValues(alpha: 0.14),
                          ),
                          child: const Icon(
                            Icons.assignment_turned_in_rounded,
                            color: AppTheme.primary,
                            size: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'DAILY MISSION',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    RichText(
                      text: const TextSpan(
                        text: '2',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                        children: [
                          TextSpan(
                            text: '/3',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildMissionItem(
                  icon: Icons.play_circle_fill_rounded,
                  title: 'Tonton 2 Episode',
                  progressText: '1/2',
                  progress: 0.5,
                  xp: '+30 XP',
                ),
                const SizedBox(height: 8),
                _buildMissionItem(
                  icon: Icons.favorite_rounded,
                  title: 'Like 3 Post',
                  progressText: '1/3',
                  progress: 0.33,
                  xp: '+30 XP',
                ),
                const SizedBox(height: 8),
                _buildMissionItem(
                  icon: Icons.chat_bubble_rounded,
                  title: 'Gabung di 1 Room',
                  progressText: '0/1',
                  progress: 0.0,
                  xp: '+20 XP',
                ),
                const SizedBox(height: 12),
                // Klaim All button
                Container(
                  width: double.infinity,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.highlight, AppTheme.accent],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.highlight.withValues(alpha: 0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.card_giftcard_rounded,
                                  color: AppTheme.background,
                                  size: 13,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Klaim All',
                                  style: TextStyle(
                                    color: AppTheme.background,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              '80 XP',
                              style: TextStyle(
                                color: AppTheme.background,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildMissionItem({
    required IconData icon,
    required String title,
    required String progressText,
    required double progress,
    required String xp,
  }) {
    final done = progress >= 1.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 26,
          height: 26,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 2.4,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    done ? const Color(0xFF22C55E) : AppTheme.primary,
                  ),
                ),
              ),
              Icon(
                done ? Icons.check_rounded : icon,
                color: done ? const Color(0xFF22C55E) : AppTheme.primary,
                size: 11,
              ),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    progressText,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    xp,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
class _WeeklyChallengeCard extends StatefulWidget {
  const _WeeklyChallengeCard();
  @override
  State<_WeeklyChallengeCard> createState() => _WeeklyChallengeCardState();
}

class _WeeklyChallengeCardState extends State<_WeeklyChallengeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmer;

  final _challenges = <_Challenge>[
    _Challenge(
      'Tonton 10 Episode',
      7,
      10,
      120,
      Icons.play_circle_rounded,
      AppTheme.accent,
    ),
    _Challenge(
      'Kumpulkan 5 Badge',
      3,
      5,
      80,
      Icons.workspace_premium_rounded,
      AppTheme.accent,
    ),
    _Challenge(
      'Ikut 3 Voice Chat',
      1,
      3,
      100,
      Icons.mic_rounded,
      const Color(0xFF06B6D4),
    ),
    _Challenge(
      'Like 10 Post',
      6,
      10,
      60,
      Icons.favorite_rounded,
      const Color(0xFF22C55E),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalXp = _challenges.fold(0, (s, c) => s + c.xp);
    final earnedXp = _challenges.fold(
      0,
      (s, c) => s + (c.progress / c.total * c.xp).round(),
    );
    final overallProg =
        _challenges.fold<int>(0, (s, c) => s + c.progress) /
        _challenges.fold<int>(0, (s, c) => s + c.total);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.accent.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.20),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            // Was a solid dark-brown→background gradient fill that fully
            // covered the parent card's background artwork. Liquid glass
            // treatment (blur + low-alpha tint) lets it show through,
            // matching _DailyLoginStreakCard and _DailyMissionCard above.
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.06),
                    AppTheme.primary.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.accent, AppTheme.primary],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.emoji_events_rounded,
                          color: AppTheme.surfaceElevated,
                          size: 10,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'MINGGU INI',
                          style: TextStyle(
                            color: AppTheme.surfaceElevated,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(overallProg * 100).round()}%',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFD700).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$earnedXp/$totalXp XP',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              // Overall progress
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: overallProg.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: AppTheme.surfaceElevated.withValues(alpha: 0.10),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.accent,
                  ),
                ),
              ),
              SizedBox(height: 14),
              // Challenge list
              ...List.generate(_challenges.length, (i) {
                final c = _challenges[i];
                final done = c.progress >= c.total;
                final prog = (c.progress / c.total).clamp(0.0, 1.0);
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: i == _challenges.length - 1 ? 0 : 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: done
                              ? Color(0xFFFFD700).withValues(alpha: 0.15)
                              : c.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: done
                                ? Color(0xFFFFD700).withValues(alpha: 0.4)
                                : c.color.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Icon(
                          c.icon,
                          color: done ? const Color(0xFFFFD700) : c.color,
                          size: 14.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.title,
                              style: TextStyle(
                                color: done
                                    ? const Color(0xFFFFD700)
                                    : AppTheme.surfaceElevated,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: prog,
                                      minHeight: 4,
                                      backgroundColor: AppTheme.surfaceElevated.withValues(
                                        alpha: 0.08,
                                      ),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        done
                                            ? const Color(0xFFFFD700)
                                            : c.color,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '${c.progress}/${c.total}',
                                  style: TextStyle(
                                    color: AppTheme.surfaceElevated.withValues(alpha: 0.5),
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: done
                              ? Color(0xFFFFD700).withValues(alpha: 0.12)
                              : c.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          done ? '✓' : '+${c.xp}',
                          style: TextStyle(
                            color: done ? const Color(0xFFFFD700) : c.color,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              // Reward preview
              SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Color(0xFFFFD700).withValues(alpha: 0.15),
                  ),
                  color: Color(0xFFFFD700).withValues(alpha: 0.04),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFF8800)],
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppTheme.surfaceElevated,
                        size: 13,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Selesaikan semua tantangan untuk mendapatkan **Void Border** eksklusif!',
                        style: TextStyle(
                          color: AppTheme.surfaceElevated.withValues(alpha: 0.70),
                          fontSize: 9,
                          height: 1.3,
                        ),
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

class _Challenge {
  final String title;
  final int progress;
  final int total;
  final int xp;
  final IconData icon;
  final Color color;
  const _Challenge(
    this.title,
    this.progress,
    this.total,
    this.xp,
    this.icon,
    this.color,
  );
}
class _DailyLoginStreakCard extends StatefulWidget {
  const _DailyLoginStreakCard();
  @override
  State<_DailyLoginStreakCard> createState() => _DailyLoginStreakCardState();
}

class _DailyLoginStreakCardState extends State<_DailyLoginStreakCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  final int _currentStreak = 7;
  final int _maxStreak = 30;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 7-day streak preview
    // NOTE: streak is 1-indexed within the week (Day 1..Day 7), so mapping
    // must land in [1, 7]. A plain `% 7` sends any multiple of 7 (7, 14, 21…)
    // to 0, which matches nothing in `days` and silently kills the
    // "today"/"checked" highlight — that's why the row looked all-grey at
    // streak 7 before this fix.
    final days = List.generate(7, (i) => i + 1);
    final currentDay = ((_currentStreak - 1) % 7) + 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.accent.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            // True liquid glass: was a solid surface→surfaceElevated fill
            // that fully covered the parent card's background artwork.
            // A blurred, low-alpha tint lets that artwork show through
            // instead, consistent with _LiquidGlassPill elsewhere.
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.07),
                    AppTheme.accent.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.accent, AppTheme.highlight],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      color: AppTheme.background,
                      size: 13,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'DAILY LOGIN',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _ctrl,
                          builder: (_, __) => Icon(
                            Icons.local_fire_department_rounded,
                            color: AppTheme.accent.withValues(
                              alpha: 0.6 + 0.4 * _ctrl.value,
                            ),
                            size: 11,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$_currentStreak Hari',
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 6),
                  // Compact reward chip — replaces the old full-width
                  // "Hadiah Day 30" strip that used to sit below the day
                  // row; same info, sejajar dengan badge streak di header.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.highlight.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.highlight.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.card_giftcard_rounded,
                          color: AppTheme.highlight,
                          size: 10,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${_maxStreak - _currentStreak}h',
                          style: const TextStyle(
                            color: AppTheme.highlight,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Responsive day row — sizes itself from the available width
              // instead of a hardcoded 7 × 38px (266px), which overflowed
              // on narrower screens ("OVERFLOWED BY 44 PIXELS").
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 6.0;
                  final itemWidth =
                      ((constraints.maxWidth - gap * 6) / 7).clamp(30.0, 42.0);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (i) {
                      final day = days[i];
                      final checked = day < currentDay;
                      final today = day == currentDay;

                      return GestureDetector(
                    onTap: () {},
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: itemWidth,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        gradient: today
                            ? const LinearGradient(
                                colors: [AppTheme.accent, AppTheme.highlight],
                              )
                            : (checked
                                  ? LinearGradient(
                                      colors: [
                                        AppTheme.primary,
                                        AppTheme.primary.withValues(alpha: 0.75),
                                      ],
                                    )
                                  : null),
                        color: today || checked
                            ? null
                            : AppTheme.surface.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: today
                            ? Border.all(
                                color: AppTheme.textPrimary.withValues(alpha: 0.55),
                                width: 1.5,
                              )
                            : null,
                        boxShadow: today
                            ? [
                                BoxShadow(
                                  color: AppTheme.accent.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Day $day',
                            style: TextStyle(
                              color: today || checked
                                  ? AppTheme.background
                                  : AppTheme.textSecondary,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Icon(
                            checked
                                ? Icons.check_circle_rounded
                                : (today
                                      ? Icons.circle_rounded
                                      : Icons.radio_button_unchecked_rounded),
                            size: 13,
                            color: today || checked
                                ? AppTheme.background
                                : AppTheme.textSecondary.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 3),
                          if (i == 0 || i == 2 || i == 6)
                            Icon(
                              i == 0
                                  ? Icons.card_giftcard_rounded
                                  : (i == 2
                                        ? Icons.diamond_rounded
                                        : Icons.workspace_premium_rounded),
                              size: 7.5,
                              color: today || checked
                                  ? AppTheme.background.withValues(alpha: 0.7)
                                  : AppTheme.textSecondary.withValues(alpha: 0.3),
                            )
                          else
                            const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  );
                    }),
                  );
                },
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

// ═══════════════════════════════════════════════════════════════════════════
// ANIME LIST TABS
// ═══════════════════════════════════════════════════════════════════════════
class _AnimeListTabs extends StatefulWidget {
  const _AnimeListTabs();
  @override State<_AnimeListTabs> createState() => _AnimeListTabsState();
}

class _AnimeListTabsState extends State<_AnimeListTabs> {
  int _tab = 0;
  final _tabs = const [
    {'label':'Watching','count':12,'icon':'▶️'},
    {'label':'Completed','count':247,'icon':'✅'},
    {'label':'Plan to Watch','count':58,'icon':'📌'},
    {'label':'Dropped','count':6,'icon':'🗑️'},
  ];
  final _lists = const [
    [{'title':'Demon Slayer S4','ep':'Ep 8/13','genre':'Action','score':9.1,'emoji':'⚔️','prog':0.62},
     {'title':'One Piece','ep':'Ep 1082/?','genre':'Adventure','score':9.4,'emoji':'🏴‍☠️','prog':0.40},
     {'title':'Blue Lock S2','ep':'Ep 5/12','genre':'Sports','score':8.7,'emoji':'⚽','prog':0.42},
     {'title':'Dungeon Meshi','ep':'Ep 22/24','genre':'Fantasy','score':8.9,'emoji':'🍲','prog':0.92}],
    [{'title':'Attack on Titan','ep':'Ep 87/87','genre':'Action','score':9.9,'emoji':'🔱','prog':1.0},
     {'title':'Fullmetal Alchemist','ep':'Ep 64/64','genre':'Action','score':9.8,'emoji':'⚗️','prog':1.0},
     {'title':'Jujutsu Kaisen','ep':'Ep 47/47','genre':'Supernatural','score':9.0,'emoji':'👁️','prog':1.0}],
    [{'title':'Vinland Saga S3','ep':'Ep 0/24','genre':'Historical','score':null,'emoji':'⚓','prog':0.0},
     {'title':'Berserk (2025)','ep':'Ep 0/26','genre':'Dark Fantasy','score':null,'emoji':'🗡️','prog':0.0}],
    [{'title':'Boruto','ep':'Ep 14/293','genre':'Action','score':4.0,'emoji':'💤','prog':0.05}],
  ];

  @override
  Widget build(BuildContext context) {
    final list = _lists[_tab];
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.highlight.withOpacity(0.12)),
        boxShadow: [BoxShadow(color: AppTheme.accent.withOpacity(0.08), blurRadius: 18, spreadRadius: -4, offset: const Offset(0,8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(16,16,16,0), child: Row(children: [
          ShaderMask(
            shaderCallback: (b) => LinearGradient(colors: [AppTheme.highlight, AppTheme.accent]).createShader(Rect.fromLTWH(0,0,b.width,b.height)),
            child: Text('My Anime List', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
          ),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.highlight.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.highlight.withOpacity(0.2))),
            child: Text('323 Total', style: TextStyle(color: AppTheme.highlight, fontSize: 10, fontWeight: FontWeight.w900)),
          ),
        ])),
        const SizedBox(height: 12),
        SizedBox(height: 38, child: ListView.separated(
          scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemCount: _tabs.length,
          itemBuilder: (_, i) {
            final t = _tabs[i]; final active = i == _tab;
            return GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: active ? LinearGradient(colors: [AppTheme.highlight, AppTheme.accent]) : null,
                  color: active ? null : AppTheme.surface.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? Colors.transparent : AppTheme.textPrimary.withOpacity(0.15)),
                  boxShadow: active ? [BoxShadow(color: AppTheme.highlight.withOpacity(0.35), blurRadius: 10, offset: const Offset(0,4))] : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(t['icon'] as String, style: const TextStyle(fontSize: 11)),
                  const SizedBox(width: 5),
                  Text(t['label'] as String, style: TextStyle(color: active ? Colors.white : AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 5),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: active ? Colors.white.withOpacity(0.25) : AppTheme.textPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text('${t["count"]}', style: TextStyle(color: active ? Colors.white : AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.w900)),
                  ),
                ]),
              ),
            );
          },
        )),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Column(key: ValueKey(_tab), children: [
            ...list.map((a) {
              final score = a['score'] as double?;
              final prog = a['prog'] as double;
              return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5), child: Row(children: [
                Container(width: 44, height: 44,
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [AppTheme.accent.withOpacity(0.12), AppTheme.highlight.withOpacity(0.12)]), borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(a['emoji'] as String, style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a['title'] as String, style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(a['ep'] as String, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                    const SizedBox(width: 6),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(a['genre'] as String, style: TextStyle(color: AppTheme.accent, fontSize: 8, fontWeight: FontWeight.w800))),
                  ]),
                  if (_tab == 0) ...[ const SizedBox(height: 4),
                    ClipRRect(borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: prog, backgroundColor: AppTheme.textPrimary.withOpacity(0.08), valueColor: AlwaysStoppedAnimation<Color>(AppTheme.highlight), minHeight: 5)),
                  ],
                ])),
                if (score != null) ...[const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.highlight.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.highlight.withOpacity(0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [const Text('⭐',style:TextStyle(fontSize:9)), const SizedBox(width:2), Text(score.toStringAsFixed(1), style: TextStyle(color: AppTheme.highlight, fontSize: 10, fontWeight: FontWeight.w900))])),
                ],
              ]));
            }),
            const SizedBox(height: 8),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: GestureDetector(
              onTap: () {},
              child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: AppTheme.highlight.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.highlight.withOpacity(0.2))),
                child: Text('Lihat Semua ${_tabs[_tab]["count"]} Anime →', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.highlight, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            )),
            const SizedBox(height: 14),
          ]),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ANIME DNA CARD
// ═══════════════════════════════════════════════════════════════════════════
class _AnimeDnaCard extends StatelessWidget {
  const _AnimeDnaCard();
  @override
  Widget build(BuildContext context) {
    final genres = [
      ('Action', 0.68, AppTheme.highlight),
      ('Fantasy', 0.15, AppTheme.accent),
      ('Romance', 0.09, const Color(0xFFFF80AB)),
      ('Sci-Fi', 0.05, const Color(0xFF00E5FF)),
      ('Comedy', 0.03, const Color(0xFFFFD740)),
    ];
    return _Card(
      entranceDelay: const Duration(milliseconds: 200),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ANIME DNA', style: TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
        const SizedBox(height: 12),
        ...genres.map((g) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(g.$1, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
            Text('${(g.$2 * 100).toInt()}%', style: TextStyle(color: g.$3, fontSize: 10, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: g.$2,
            backgroundColor: AppTheme.textPrimary.withOpacity(0.06),
            valueColor: AlwaysStoppedAnimation<Color>(g.$3), minHeight: 6)),
        ]))),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FAVORITE ANIME CARD
// ═══════════════════════════════════════════════════════════════════════════
class _FavoriteAnimeCard extends StatelessWidget {
  const _FavoriteAnimeCard();
  static const _favs = [
    {'rank':1,'title':'Solo Leveling','rating':9.8,'color':AppTheme.accent,'emoji':'⚡'},
    {'rank':2,'title':'Attack on Titan','rating':9.7,'color':AppTheme.highlight,'emoji':'🔱'},
    {'rank':3,'title':'Re:Zero','rating':9.6,'color':Color(0xFF4FC3F7),'emoji':'🌹'},
  ];
  @override
  Widget build(BuildContext context) {
    return _Card(
      entranceDelay: const Duration(milliseconds: 200),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('FAVORITE', style: TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
          Text('Top 3 ›', style: TextStyle(color: AppTheme.highlight, fontSize: 10, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        ..._favs.map((f) {
          final c = f['color'] as Color;
          return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withOpacity(0.22)), color: AppTheme.surfaceElevated),
            child: Row(children: [
              Container(width: 28, height: 28, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(7)),
                child: Center(child: Text('${f["rank"]}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)))),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(f['title'] as String, style: TextStyle(color: AppTheme.textPrimary, fontSize: 10, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                Row(children: [Icon(Icons.star_rounded, color: c, size: 10), const SizedBox(width: 2), Text('${f["rating"]}', style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w900))]),
              ])),
            ]),
          );
        }),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WATCH TIME CARD
// ═══════════════════════════════════════════════════════════════════════════
class _WatchTimeCard extends StatelessWidget {
  const _WatchTimeCard();
  @override
  Widget build(BuildContext context) {
    return _Card(
      entranceDelay: const Duration(milliseconds: 300),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('WATCH TIME', style: TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [AppTheme.highlight, AppTheme.accent]), borderRadius: BorderRadius.circular(20)),
            child: const Text('Top 1%', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: ShaderMask(
                shaderCallback: (b) => LinearGradient(colors: [AppTheme.highlight, AppTheme.accent]).createShader(Rect.fromLTWH(0,0,b.width,b.height)),
                child: const Text('14.280', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('jam ditonton', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11), overflow: TextOverflow.ellipsis),
              Text('≈ 595 hari', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10), overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _statPill('Episodes', '4,820', AppTheme.highlight),
          const SizedBox(width: 8),
          _statPill('Series', '247', AppTheme.accent),
          const SizedBox(width: 8),
          _statPill('Movies', '38', const Color(0xFFFFB300)),
        ]),
      ]),
    );
  }

  Widget _statPill(String label, String value, Color c) => Expanded(
    child: Container(padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withOpacity(0.2))),
      child: Column(children: [
        Text(value, style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w900)),
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
      ]),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// ALIGNMENT + TASTE MAP CARDS
// ═══════════════════════════════════════════════════════════════════════════
// ─── Data ────────────────────────────────────────────────────────────────────
const _kAlignmentTraits = [
  {'label': 'Hero',       'pct': 0.80, 'icon': '🛡️', 'desc': 'Suka protagonis yang berjuang demi orang lain'},
  {'label': 'Villain',    'pct': 0.40, 'icon': '🔥', 'desc': 'Tertarik sama antagonis yang punya motivasi kuat'},
  {'label': 'Chaos',      'pct': 0.90, 'icon': '⚡', 'desc': 'Paling suka moment unpredictable & plot twist gila'},
  {'label': 'Friendship', 'pct': 0.60, 'icon': '💛', 'desc': 'Bonding antar karakter selalu bikin baper'},
];

const _kRadarGenres = [
  {'label': 'Action',        'pct': 0.85, 'desc': '68% tontonan — mostly Shonen & battle anime'},
  {'label': 'Fantasy',       'pct': 0.60, 'desc': '15% — isekai & world-building favorit'},
  {'label': 'Psychological', 'pct': 0.40, 'desc': '9% — suka tapi butuh mood yang tepat'},
  {'label': 'Romance',       'pct': 0.55, 'desc': '5% — lebih ke side romance bukan main genre'},
  {'label': 'Comedy',        'pct': 0.70, 'desc': '3% — pelengkap, jarang nonton pure comedy'},
];

// ─── Alignment Card ──────────────────────────────────────────────────────────
class _AlignmentCard extends StatefulWidget {
  const _AlignmentCard();
  @override State<_AlignmentCard> createState() => _AlignmentCardState();
}

class _AlignmentCardState extends State<_AlignmentCard> {
  int? _tappedTrait;
  OverlayEntry? _overlay;
  final GlobalKey _cardKey = GlobalKey();

  void _showTooltip(int idx, TapDownDetails details) {
    _removeOverlay();
    final trait = _kAlignmentTraits[idx];
    final box = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final cardPos = box.localToGlobal(Offset.zero);
    final pct = trait['pct'] as double;
    final color = idx == 0 ? const Color(0xFF4FC3F7)
        : idx == 1 ? const Color(0xFFEF5350)
        : idx == 2 ? AppTheme.accent
        : AppTheme.highlight;

    _overlay = OverlayEntry(builder: (_) => Stack(children: [
      // dismiss tap catcher
      Positioned.fill(child: GestureDetector(onTap: _removeOverlay, behavior: HitTestBehavior.translucent,
        child: const ColoredBox(color: Colors.transparent))),
      Positioned(
        left: (cardPos.dx + details.localPosition.dx - 70).clamp(8.0, 280.0),
        top: cardPos.dy + details.localPosition.dy - 90,
        child: Material(color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 140,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.45), width: 1.5),
                boxShadow: [BoxShadow(color: color.withOpacity(0.20), blurRadius: 16, offset: const Offset(0,4))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Text(trait['icon'] as String, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(trait['label'] as String, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  Text('${(pct * 100).toInt()}%', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
                  value: pct, minHeight: 5,
                  backgroundColor: color.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation(color),
                )),
                const SizedBox(height: 6),
                Text(trait['desc'] as String, style: TextStyle(color: AppTheme.textSecondary, fontSize: 8.5, height: 1.35)),
              ]),
            ),
          ),
        ),
      ),
    ]));
    Overlay.of(context).insert(_overlay!);
    setState(() => _tappedTrait = idx);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() => _tappedTrait = null);
  }

  @override void dispose() { _removeOverlay(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return _Card(
      key: _cardKey,
      entranceDelay: const Duration(milliseconds: 350),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ALIGNMENT', style: TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Center(child: GestureDetector(
          onTapDown: (d) => _showTooltip(2, d), // default: Chaos (highest)
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AppTheme.highlight.withOpacity(0.3), AppTheme.highlight.withOpacity(0.05)]),
              border: Border.all(color: AppTheme.highlight.withOpacity(0.4), width: 2),
            ),
            child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('⚡', style: TextStyle(fontSize: 20)),
              Text('Chaotic', style: TextStyle(color: AppTheme.highlight, fontSize: 8, fontWeight: FontWeight.w900)),
              Text('Good', style: TextStyle(color: AppTheme.textSecondary, fontSize: 7)),
            ])),
          ),
        )),
        const SizedBox(height: 8),
        // Mini trait dots — tap each for detail
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_kAlignmentTraits.length, (i) {
          final t = _kAlignmentTraits[i];
          final isActive = _tappedTrait == i;
          final colors = [const Color(0xFF4FC3F7), const Color(0xFFEF5350), AppTheme.accent, AppTheme.highlight];
          return GestureDetector(
            onTapDown: (d) => _showTooltip(i, d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: colors[i].withOpacity(isActive ? 0.25 : 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colors[i].withOpacity(isActive ? 0.7 : 0.2)),
              ),
              child: Text(t['icon'] as String, style: const TextStyle(fontSize: 9)),
            ),
          );
        })),
        const SizedBox(height: 6),
        Text('Action & Shonen lover', style: TextStyle(color: AppTheme.textSecondary, fontSize: 9.5), textAlign: TextAlign.center),
      ]),
    );
  }
}

// ─── Taste Map Card ───────────────────────────────────────────────────────────
class _TasteMapCard extends StatefulWidget {
  const _TasteMapCard();
  @override State<_TasteMapCard> createState() => _TasteMapCardState();
}

class _TasteMapCardState extends State<_TasteMapCard> {
  int? _selectedIdx;
  OverlayEntry? _overlay;
  final GlobalKey _canvasKey = GlobalKey();

  static const _axes = 5;
  static const _values = [0.85, 0.60, 0.40, 0.55, 0.70];

  int? _hitTest(Offset local, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = size.width / 2 - 4;
    double minDist = double.infinity;
    int? best;
    for (int i = 0; i < _axes; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / _axes;
      final px = cx + r * _values[i] * math.cos(angle);
      final py = cy + r * _values[i] * math.sin(angle);
      final d = (local - Offset(px, py)).distance;
      if (d < 22 && d < minDist) { minDist = d; best = i; }
    }
    return best;
  }

  void _onTapDown(TapDownDetails details) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    const canvasSize = Size(80, 80);
    final idx = _hitTest(details.localPosition, canvasSize);
    if (idx == null) { _removeOverlay(); return; }

    _removeOverlay();
    setState(() => _selectedIdx = idx);
    final genre = _kRadarGenres[idx];
    final globalPos = box.localToGlobal(details.localPosition);
    final screenW = MediaQuery.of(context).size.width;

    _overlay = OverlayEntry(builder: (_) => Stack(children: [
      Positioned.fill(child: GestureDetector(onTap: _removeOverlay, behavior: HitTestBehavior.translucent,
        child: const ColoredBox(color: Colors.transparent))),
      Positioned(
        left: (globalPos.dx - 70).clamp(8.0, screenW - 158.0),
        top: globalPos.dy - 100,
        child: Material(color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 150,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.highlight.withOpacity(0.45), width: 1.5),
                boxShadow: [BoxShadow(color: AppTheme.highlight.withOpacity(0.18), blurRadius: 16, offset: const Offset(0,4))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Text(genre['label'] as String, style: TextStyle(color: AppTheme.highlight, fontSize: 11, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  Text('${((genre['pct'] as double) * 100).toInt()}%', style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
                  value: genre['pct'] as double, minHeight: 5,
                  backgroundColor: AppTheme.highlight.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation(AppTheme.highlight),
                )),
                const SizedBox(height: 6),
                Text(genre['desc'] as String, style: TextStyle(color: AppTheme.textSecondary, fontSize: 8.5, height: 1.35)),
              ]),
            ),
          ),
        ),
      ),
    ]));
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() => _selectedIdx = null);
  }

  @override void dispose() { _removeOverlay(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return _Card(
      entranceDelay: const Duration(milliseconds: 350),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('TASTE MAP', style: TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Center(
          child: GestureDetector(
            key: _canvasKey,
            onTapDown: _onTapDown,
            child: CustomPaint(
              size: const Size(80, 80),
              painter: _RadarPainter(selectedIdx: _selectedIdx),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _selectedIdx != null
              ? (_kRadarGenres[_selectedIdx!]['label'] as String)
              : 'Balanced dengan spike Action',
          style: TextStyle(
            color: _selectedIdx != null ? AppTheme.highlight : AppTheme.textSecondary,
            fontSize: 8.5, fontWeight: _selectedIdx != null ? FontWeight.w900 : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final int? selectedIdx;
  const _RadarPainter({this.selectedIdx});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = size.width / 2 - 4;
    const axes = 5;
    const values = [0.85, 0.60, 0.40, 0.55, 0.70];
    final bgPaint = Paint()..style = PaintingStyle.stroke..color = AppTheme.textPrimary.withOpacity(0.08)..strokeWidth = 1;
    for (int ring = 1; ring <= 3; ring++) {
      final rr = r * ring / 3;
      final path = Path();
      for (int i = 0; i < axes; i++) {
        final angle = -math.pi / 2 + i * 2 * math.pi / axes;
        final x = cx + rr * math.cos(angle), y = cy + rr * math.sin(angle);
        if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, bgPaint);
    }
    final fillPath = Path();
    for (int i = 0; i < axes; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / axes;
      final x = cx + r * values[i] * math.cos(angle), y = cy + r * values[i] * math.sin(angle);
      if (i == 0) fillPath.moveTo(x, y); else fillPath.lineTo(x, y);
    }
    fillPath.close();
    canvas.drawPath(fillPath, Paint()..style = PaintingStyle.fill..color = AppTheme.highlight.withOpacity(0.18));
    canvas.drawPath(fillPath, Paint()..style = PaintingStyle.stroke..color = AppTheme.highlight.withOpacity(0.7)..strokeWidth = 1.5);
    // Dots — highlight selected
    for (int i = 0; i < axes; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / axes;
      final px = cx + r * values[i] * math.cos(angle);
      final py = cy + r * values[i] * math.sin(angle);
      final isSelected = selectedIdx == i;
      if (isSelected) {
        canvas.drawCircle(Offset(px, py), 9, Paint()..color = AppTheme.highlight.withOpacity(0.20));
        canvas.drawCircle(Offset(px, py), 5.5, Paint()..color = AppTheme.accent);
      } else {
        canvas.drawCircle(Offset(px, py), 3.5, Paint()..color = AppTheme.highlight);
      }
    }
  }
  @override bool shouldRepaint(_RadarPainter old) => old.selectedIdx != selectedIdx;
}

// ═══════════════════════════════════════════════════════════════════════════
// RECENTLY WATCHED + KOLEKSI LANGKA CARDS
// ═══════════════════════════════════════════════════════════════════════════
class _RecentlyWatchedCard extends StatelessWidget {
  final List<AnimeModel> recentlyWatched;
  const _RecentlyWatchedCard({required this.recentlyWatched});
  @override
  Widget build(BuildContext context) {
    final items = recentlyWatched.isNotEmpty ? recentlyWatched.take(3).toList()
      : [AnimeModel(id: '1', title: 'Solo Leveling', imageUrl: '', rating: 9.8, genres: const ['Action'], description: ''),
         AnimeModel(id: '2', title: 'Attack on Titan', imageUrl: '', rating: 9.9, genres: const ['Action'], description: '')];
    return _Card(
      entranceDelay: const Duration(milliseconds: 400),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('RECENTLY WATCHED', style: TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
          Text('All ›', style: TextStyle(color: AppTheme.highlight, fontSize: 10, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        ...items.map((a) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.accent.withOpacity(0.2))),
            child: ClipRRect(borderRadius: BorderRadius.circular(8), child: a.imageUrl.isNotEmpty
              ? Image.network(a.imageUrl, fit: BoxFit.cover, errorBuilder: (_,__,___) => Icon(Icons.movie_rounded, color: AppTheme.accent, size: 18))
              : Icon(Icons.movie_rounded, color: AppTheme.accent, size: 18))),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.title, style: TextStyle(color: AppTheme.textPrimary, fontSize: 10, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(a.genre, style: TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
          ])),
          Icon(Icons.play_circle_rounded, color: AppTheme.highlight, size: 20),
        ]))),
      ]),
    );
  }
}

class _KoleksiLangkaCard extends StatelessWidget {
  const _KoleksiLangkaCard();
  @override
  Widget build(BuildContext context) {
    final items = [
      ('Chibi Hitaku', '⭐ LEGENDARY', AppTheme.highlight),
      ('Luna Knight', '💠 MYSTIC', AppTheme.accent),
      ('Sakura Priestess', '🌸 RARE', const Color(0xFFFF80AB)),
    ];
    return _Card(
      entranceDelay: const Duration(milliseconds: 400),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('KOLEKSI LANGKA', style: TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        ...items.map((it) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () {
              Feedback.forTap(context);
              showDialog(
                context: context,
                builder: (_) => _CollectibleFlipDialog(
                  name: it.$1,
                  rarity: it.$2,
                  color: it.$3,
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: it.$3.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: it.$3.withOpacity(0.2)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it.$1, style: TextStyle(color: AppTheme.textPrimary, fontSize: 9, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(it.$2, style: TextStyle(color: it.$3, fontSize: 8, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        )),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 3D COLLECTIBLE CARD FLIP DIALOG
// ═══════════════════════════════════════════════════════════════════════════
class _CollectibleFlipDialog extends StatefulWidget {
  final String name;
  final String rarity;
  final Color color;
  const _CollectibleFlipDialog({required this.name, required this.rarity, required this.color});

  @override
  State<_CollectibleFlipDialog> createState() => _CollectibleFlipDialogState();
}

class _CollectibleFlipDialogState extends State<_CollectibleFlipDialog> {
  bool _isFlipped = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () {
          Feedback.forTap(context);
          setState(() => _isFlipped = !_isFlipped);
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: _isFlipped ? math.pi : 0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
          builder: (context, angle, child) {
            final isBack = angle >= math.pi / 2;
            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012) // perspective
                ..rotateY(angle),
              alignment: Alignment.center,
              child: isBack
                  ? Transform(
                      transform: Matrix4.identity()..rotateY(math.pi),
                      alignment: Alignment.center,
                      child: _buildCardBack(),
                    )
                  : _buildCardFront(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCardFront() {
    return Container(
      width: 250,
      height: 380,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.color.withOpacity(0.35),
            AppTheme.surfaceElevated.withOpacity(0.95),
            Colors.black.withOpacity(0.85),
          ],
        ),
        border: Border.all(color: widget.color.withOpacity(0.7), width: 2),
        boxShadow: [
          BoxShadow(color: widget.color.withOpacity(0.4), blurRadius: 25, spreadRadius: 2)
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: widget.color.withOpacity(0.5)),
            ),
            child: Text(widget.rarity, style: TextStyle(color: widget.color, fontSize: 9, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 24),
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withOpacity(0.1),
              border: Border.all(color: widget.color.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(color: widget.color.withOpacity(0.2), blurRadius: 15)
              ]
            ),
            child: Center(
              child: Text(
                widget.name.contains('Chibi') ? '🦊' : (widget.name.contains('Luna') ? '💠' : '🌸'),
                style: const TextStyle(fontSize: 52),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(widget.name, style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Text('TAP UNTUK FLIP KARTU', style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.6), fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
        ],
      ),
    );
  }

  Widget _buildCardBack() {
    return Container(
      width: 250,
      height: 380,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withOpacity(0.9),
            AppTheme.surfaceElevated.withOpacity(0.95),
            widget.color.withOpacity(0.2),
          ],
        ),
        border: Border.all(color: widget.color.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: widget.color.withOpacity(0.3), blurRadius: 20)
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('CARD DETAIL', style: TextStyle(color: widget.color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
          const SizedBox(height: 16),
          Text(widget.name, style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Divider(color: AppTheme.textPrimary.withOpacity(0.1)),
          const SizedBox(height: 12),
          Text(
            widget.name.contains('Chibi')
                ? 'Mitra rubah kecil yang selalu menemani perjalananmu di jagat raya AniVerse. Memberikan bonus stat +5% XP Gain saat aktif.'
                : (widget.name.contains('Luna')
                    ? 'Ksatria penjaga rembulan yang anggun. Dihiasi oleh baja kosmik penangkal energi hitam. Memberikan perlindungan total.'
                    : 'Pendeta kuil bunga sakura. Menghadirkan kesejukan kelopak gugur yang menenangkan. Mengaktifkan visual partikel sakura.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.5),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatMini('POWER', '88'),
              _buildStatMini('MYSTIC', '92'),
              _buildStatMini('XP gain', '+5%'),
            ],
          ),
          const SizedBox(height: 24),
          Text('TAP UNTUK KEMBALI', style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5), fontSize: 8, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildStatMini(String label, String value) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: widget.color, fontSize: 13, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 7, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARE PROFILE CARD
// ═══════════════════════════════════════════════════════════════════════════
class _ShareProfileCard extends StatefulWidget {
  const _ShareProfileCard();
  @override State<_ShareProfileCard> createState() => _ShareProfileCardState();
}

class _ShareProfileCardState extends State<_ShareProfileCard> {
  final GlobalKey _cardKey = GlobalKey();
  bool _isGenerating = false;

  Future<void> _generateAndDownload() async {
    setState(() => _isGenerating = true);
    await Future.delayed(const Duration(milliseconds: 120)); // let UI settle

    try {
      final boundary = _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to capture');

      final bytes = byteData.buffer.asUint8List();
      final base64 = base64Encode(bytes);
      final dataUrl = 'data:image/png;base64,$base64';

      // Web: trigger browser download. Mobile: no-op (SnackBar confirms instead)
      triggerWebDownload(
        dataUrl,
        'aniverse_profile_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Share card berhasil didownload! 🎉'),
          backgroundColor: AppTheme.highlight,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal generate: $e'),
          backgroundColor: AppTheme.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      entranceDelay: const Duration(milliseconds: 500),
      child: Column(children: [
        // Preview share card (ini yang di-capture jadi PNG)
        RepaintBoundary(
          key: _cardKey,
          child: _ShareCardCanvas(),
        ),
        const SizedBox(height: 12),
        // Download button
        GestureDetector(
          onTap: _isGenerating ? null : _generateAndDownload,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              gradient: _isGenerating
                ? LinearGradient(colors: [AppTheme.surfaceElevated, AppTheme.surface])
                : const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFC17E74)]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: _isGenerating ? [] : [
                BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.40), blurRadius: 14, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (_isGenerating)
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.highlight))
              else
                const Icon(Icons.download_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 7),
              Text(
                _isGenerating ? 'Generating...' : 'Download PNG',
                style: TextStyle(
                  color: _isGenerating ? AppTheme.textSecondary : Colors.white,
                  fontSize: 11, fontWeight: FontWeight.w900,
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Share card canvas — ini yang jadi PNG ────────────────────────────────────
class _ShareCardCanvas extends StatelessWidget {
  const _ShareCardCanvas();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1A1208), Color(0xFF0D0D0D), Color(0xFF1A0D0A)],
        ),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.45), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(children: [
          // Corner decorations
          Positioned(top: -20, right: -20, child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: const Color(0xFFD4AF37).withOpacity(0.08)),
          )),
          Positioned(bottom: -20, left: -20, child: Container(
            width: 60, height: 60,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: const Color(0xFFC17E74).withOpacity(0.08)),
          )),

          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Top: brand + username
              Row(children: [
                Flexible(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                        colors: [Color(0xFFD4AF37), Color(0xFFC17E74)],
                      ).createShader(Rect.fromLTWH(0,0,b.width,b.height)),
                      child: const Text('HITAKU ✨', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    ),
                    const SizedBox(height: 2),
                    Text('Battle Seeker  •  Lv.3000', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 8.5, fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(width: 8),
                // AniVerse brand
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.40)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('AniVerse', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                ),
              ]),

              const SizedBox(height: 10),
              Container(height: 1, color: const Color(0xFFD4AF37).withOpacity(0.15)),
              const SizedBox(height: 10),

              // Stats grid 2x2
              Row(children: [
                _StatBox(label: 'Ditonton', value: '323', icon: Icons.tv_rounded),
                const SizedBox(width: 8),
                _StatBox(label: 'Selesai', value: '247', icon: Icons.check_circle_rounded),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _StatBox(label: 'Jam Nonton', value: '14.093', icon: Icons.access_time_rounded),
                const SizedBox(width: 8),
                _StatBox(label: 'Rating Rata', value: '8.4 ⭐', icon: Icons.star_rounded),
              ]),

              const SizedBox(height: 10),
              Container(height: 1, color: const Color(0xFFD4AF37).withOpacity(0.15)),
              const SizedBox(height: 8),

              // Genre top 3
              Text('TOP GENRE', style: TextStyle(color: Colors.white.withOpacity(0.40), fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
              const SizedBox(height: 6),
              Row(children: [
                _GenreChip('Action', 0.68, const Color(0xFFD4AF37)),
                const SizedBox(width: 5),
                _GenreChip('Fantasy', 0.45, const Color(0xFFC17E74)),
                const SizedBox(width: 5),
                _GenreChip('Psycho', 0.30, const Color(0xFF7B9E87)),
              ]),

              const SizedBox(height: 10),
              // Bottom tagline
              Center(
                child: Text('aniverse.app  •  Gabung & track anime-mu', style: TextStyle(color: Colors.white.withOpacity(0.28), fontSize: 7.5, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _StatBox({required this.label, required this.value, required this.icon});
  @override
  Widget build(_) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37).withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.15)),
      ),
      child: Row(children: [
        Icon(icon, color: const Color(0xFFD4AF37), size: 13),
        const SizedBox(width: 6),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 7.5, fontWeight: FontWeight.w700)),
        ])),
      ]),
    ),
  );
}

class _GenreChip extends StatelessWidget {
  final String label;
  final double prog;
  final Color color;
  const _GenreChip(this.label, this.prog, this.color);
  @override
  Widget build(_) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 8, fontWeight: FontWeight.w800)),
      const SizedBox(height: 3),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: prog, minHeight: 4,
          backgroundColor: Colors.white.withOpacity(0.08),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
      const SizedBox(height: 2),
      Text('${(prog * 100).round()}%', style: TextStyle(color: color.withOpacity(0.80), fontSize: 7, fontWeight: FontWeight.w700)),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// AI ROAST CARD (Neural Terminal Aesthetic V3)
// ═══════════════════════════════════════════════════════════════════════════
class _AiRoastCard extends StatefulWidget {
  const _AiRoastCard();

  @override
  State<_AiRoastCard> createState() => _AiRoastCardState();
}

class _AiRoastCardState extends State<_AiRoastCard> with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _roasted = false;
  late AnimationController _scannerCtrl;
  late AnimationController _pulseCtrl;
  
  // Console output log
  final List<String> _terminalLines = [];
  int _currentLineIndex = 0;
  String _typedText = "";
  int _charIndex = 0;
  
  int _roastIndex = 0;

  static const _roastPool = [
    "🤖 [SYSTEM_ROAST] >> Lu nonton Demon Slayer sama Solo Leveling mulu biar ngerasa overpower, padahal kehidupan nyata lu cuma dapet rating IMDb 3.2. Cobalah sesekali bersosialisasi sama NPC di dunia nyata!",
    "🤖 [SYSTEM_ROAST] >> 14.280 jam nonton? Itu setara 595 hari. Artinya hampir 2 tahun hidup lu cuma liat orang lain dapat character development, sementara arc lu sendiri masih stuck di 'Bangun-Scroll-Tidur'.",
    "🤖 [SYSTEM_ROAST] >> 68% genre Action — lu bukan anime enjoyer, lu otomatis nge-skip ke fight scene. Buka slice-of-life sekali kali, biar tau ada kehidupan selain ngeluarin ultimate move.",
    "🤖 [SYSTEM_ROAST] >> 323 anime ditonton tapi rating rata-rata 8.4? Lu rating-nya lebih murah hati dari user MAL. Setiap anime dapet 8, termasuk filler arc yang harusnya masuk tempat sampah.",
    "🤖 [SYSTEM_ROAST] >> Watch party 0/1? Jadi lu nonton sendirian 14 ribu jam tapi nggak bisa jadwalin satu sesi bareng temen. Mungkin temennya yang nggak ada, atau mungkin animenya yang jadi temen lu.",
    "🤖 [SYSTEM_ROAST] >> TOP 0.5% watch time global — selamat, lu berhasil beat 99.5% populasi dalam hal paling nggak produktif di alam semesta. Kalau ini Olimpiade, lu dapet medali emas kategori Skill Issue.",
    "🤖 [SYSTEM_ROAST] >> Lu koleksi 7 cosmetic di vault tapi yang di-equip cuma satu. Itu bukan flex, itu hoarding. KonMari method: kalau cosmeticnya nggak spark joy, unequip aja semuanya termasuk self-esteem.",
    "🤖 [SYSTEM_ROAST] >> Psychological genre cuma 9%? Jadi lu takut anime yang butuh mikir? Aman, tetap di zona nyaman Action — nggak ada consequences, nggak ada moral dilemma, sama kayak hidup lu.",
    "🤖 [SYSTEM_ROAST] >> Newbie Nyasar rank dengan 0 XP? Lu udah nonton 323 anime tapi masih 'Newbie'. Itu bukan humble, itu sistem yang tau persis lo belum buka aplikasi ini dengan serius.",
    "🤖 [SYSTEM_ROAST] >> 247 anime completed tapi 58 masih di Plan to Watch — statistiknya jelas: lu lebih jago janji sama diri sendiri daripada nepatin. Isekai real life lu: dunia di mana todo list terus bertambah.",
    "🤖 [SYSTEM_ROAST] >> Season Challenge progress 1/3 — lu udah halfway ke nowhere. Watch party masih 0/1 karena nggak ada yang mau nemenin marathon 8 jam nonstop sambil lu nggak pause buat ngobrol.",
    "🤖 [SYSTEM_ROAST] >> Vault cosmetic 'Wraithling Cloak' dipakai 810 orang lain. Lu pikir itu rare? Itu lebih umum dari common sense yang apparently juga jarang lu temuin.",
  ];

  List<String> get _rawTerminalScript => [
    "⚡ [SYS_INIT] >> Establishing link to AniVerse AI Core...",
    "⚡ [STAT_ANALYSIS] >> Parsing 323 watched titles & DNA markers...",
    "⚡ [STAT_ANALYSIS] >> Warning: Critical Action-Shonen saturation (68%)!",
    "⚡ [STAT_ANALYSIS] >> Watch time: 14.280 hours (Touch grass priority: EXTREME)",
    _roastPool[_roastIndex % _roastPool.length],
  ];

  @override
  void initState() {
    super.initState();
    _scannerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scannerCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startRoast() {
    setState(() {
      _isLoading = true;
      _roasted = false;
      _terminalLines.clear();
      _currentLineIndex = 0;
      _typedText = "";
      _charIndex = 0;
    });

    _scannerCtrl.repeat();

    // Simulate scanning/loading for 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      _scannerCtrl.stop();
      setState(() {
        _isLoading = false;
        _roasted = true;
      });
      _nextTerminalLine();
    });
  }


  void _refreshRoast() {
    setState(() {
      _roastIndex = (_roastIndex + 1) % _roastPool.length;
    });
    _startRoast();
  }

  void _nextTerminalLine() {
    if (_currentLineIndex >= _rawTerminalScript.length) return;
    final line = _rawTerminalScript[_currentLineIndex];
    _charIndex = 0;
    _typedText = "";
    
    // Typewriter effect interval
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 15));
      if (!mounted) return false;
      setState(() {
        _typedText += line[_charIndex];
        _charIndex++;
      });
      return _charIndex < line.length;
    }).then((_) {
      if (!mounted) return;
      setState(() {
        _terminalLines.add(_typedText);
        _currentLineIndex++;
      });
      // Pause slightly between lines
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _nextTerminalLine();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      entranceDelay: const Duration(milliseconds: 500),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accent.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🤖', style: TextStyle(fontSize: 10)),
                        const SizedBox(width: 5),
                        Text('NEURAL ROASTER V3',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            )),
                      ],
                    ),
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isLoading ? const Color(0xFF00FFCC) : (_roasted ? AppTheme.highlight : AppTheme.textSecondary),
                        boxShadow: [
                          BoxShadow(
                            color: (_isLoading ? const Color(0xFF00FFCC) : (_roasted ? AppTheme.highlight : AppTheme.textSecondary))
                                .withOpacity(_pulseCtrl.value * 0.6),
                            blurRadius: 6,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Terminal screen
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 140),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.textPrimary.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isLoading && !_roasted) ...[
                      const Text(
                        "⚡ [SYS_READY] >> Awaiting diagnostic directive...",
                        style: TextStyle(
                          color: Color(0xFF00FFCC),
                          fontFamily: 'monospace',
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Click 'SCAN PROFILE' to run a neural diagnostics and let the AI compile a personalized roast card.",
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ] else if (_isLoading) ...[
                      const Text(
                        "⚡ [SYS_SCANNING] >> Analyzing database collections...\n⚡ [SYS_SCANNING] >> Recalculating watch index stats...\n⚡ [SYS_SCANNING] >> Running glitched avatar stack diagnostics...",
                        style: TextStyle(
                          color: Color(0xFFFFB300),
                          fontFamily: 'monospace',
                          fontSize: 10.5,
                          height: 1.5,
                        ),
                      ),
                    ] else ...[
                      // Typewriter console log
                      ..._terminalLines.map((line) => _buildTerminalLine(line)),
                      // Currently typing line
                      if (_currentLineIndex < _rawTerminalScript.length && _typedText.isNotEmpty)
                        _buildTerminalLine(_typedText, isTyping: true),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // Trigger Button
              if (!_isLoading)
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _startRoast,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppTheme.highlight, AppTheme.accent]),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: AppTheme.highlight.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                        ),
                        child: Text(
                          _roasted ? 'RE-SCAN' : 'SCAN PROFILE',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ),
                  if (_roasted) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _refreshRoast,
                      child: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.accent.withOpacity(0.35)),
                        ),
                        child: const Icon(Icons.refresh_rounded, color: AppTheme.accent, size: 20),
                      ),
                    ),
                  ],
                ])
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.textPrimary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.textPrimary.withOpacity(0.12)),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FFCC)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          
          // Scanner sweep overlay
          if (_isLoading)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _scannerCtrl,
                  builder: (_, __) => CustomPaint(
                    painter: _ScannerSweepPainter(value: _scannerCtrl.value),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTerminalLine(String line, {bool isTyping = false}) {
    Color labelColor = const Color(0xFF00FFCC);
    Color contentColor = AppTheme.textPrimary;
    
    if (line.contains("[SYSTEM_ROAST]")) {
      labelColor = AppTheme.highlight;
      contentColor = const Color(0xFFFF80AB);
    } else if (line.contains("[STAT_ANALYSIS]")) {
      labelColor = const Color(0xFF00E5FF);
    }

    // Split at " >> "
    final parts = line.split(" >> ");
    final label = parts.isNotEmpty ? parts[0] + " >> " : "";
    final content = parts.length > 1 ? parts[1] : "";

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10.5,
            height: 1.4,
          ),
          children: [
            TextSpan(text: label, style: TextStyle(color: labelColor, fontWeight: FontWeight.bold)),
            TextSpan(text: content, style: TextStyle(color: contentColor)),
            if (isTyping)
              const WidgetSpan(
                child: _BlinkingCursor(),
              ),
          ],
        ),
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..repeat(reverse: true);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: _ctrl.value > 0.5 ? 1.0 : 0.0,
        child: const Text('█', style: TextStyle(color: Color(0xFF00FFCC), fontSize: 10.5)),
      ),
    );
  }
}

class _ScannerSweepPainter extends CustomPainter {
  final double value;
  const _ScannerSweepPainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * value;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          const Color(0xFF00FFCC).withOpacity(0.02),
          const Color(0xFF00FFCC).withOpacity(0.18),
          const Color(0xFF00FFCC).withOpacity(0.70),
          const Color(0xFF00FFCC).withOpacity(0.18),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.48, 0.50, 0.52, 1.0],
      ).createShader(Rect.fromLTRB(0, y - 12, size.width, y + 12));

    canvas.drawRect(Rect.fromLTRB(0, y - 12, size.width, y + 12), paint);
    
    // Laser line
    final linePaint = Paint()
      ..color = const Color(0xFF00FFCC)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
  }

  @override
  bool shouldRepaint(_ScannerSweepPainter old) => old.value != value;
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED: _Card wrapper (Glassmorphism card V3)
// ═══════════════════════════════════════════════════════════════════════════
class _Card extends StatefulWidget {
  final Widget child;
  final Duration entranceDelay;
  const _Card({super.key, required this.child, this.entranceDelay = Duration.zero});

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _opacity;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
    );
    _slide = Tween<double>(begin: 25.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic),
    );

    Future.delayed(widget.entranceDelay, () {
      if (mounted) _fadeCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeCtrl,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _slide.value),
        child: Opacity(
          opacity: _opacity.value,
          child: child,
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.surfaceElevated.withOpacity(0.85),
              AppTheme.surface.withOpacity(0.75),
              AppTheme.background.withOpacity(0.60),
            ],
          ),
          border: Border.all(
            color: AppTheme.textPrimary.withOpacity(0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
