// premium_pass_screen.dart — AniVerse Premium Pass
// Sakura Festival Season Pass: hero banner, XP bar, rewards grid, purchase CTA
// Enhanced with premium animations, interactive states, hover effects, and full light-theme compatibility.

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Konstanta warna ──────────────────────────────────────────────────────────
const _kBg = Color(0xFFFFF7FC);
const _kCard = Colors.white;
const _kCardBright = Color(0xFFFFECF7);
const _kBorder = Color(0xFFF0D7EA);
const _kPurple = Color(0xFF9D4EDD);
const _kPink = Color(0xFFFF2D87);
const _kPinkLight = Color(0xFFFF6EB4);
const _kGold = Color(0xFFFFB800);
const _kInk = Color(0xFF241329);
const _kMuted = Color(0xFF7C7299);

// ─── Data model reward ────────────────────────────────────────────────────────
enum _RewardType { coin, crystal, ticket, frame, avatar, chest, emote, unknown }

class _Reward {
  final _RewardType type;
  final String label;
  final bool claimed;
  final bool locked;
  final bool isPremiumHighlight; // glowing pink card

  const _Reward({
    required this.type,
    required this.label,
    this.claimed = false,
    this.locked = false,
    this.isPremiumHighlight = false,
  });

  _Reward copyWith({
    _RewardType? type,
    String? label,
    bool? claimed,
    bool? locked,
    bool? isPremiumHighlight,
  }) {
    return _Reward(
      type: type ?? this.type,
      label: label ?? this.label,
      claimed: claimed ?? this.claimed,
      locked: locked ?? this.locked,
      isPremiumHighlight: isPremiumHighlight ?? this.isPremiumHighlight,
    );
  }
}

// Total levels in this season's pass — drives both the timeline and the
// per-level reward lists below.
const int _kMaxLevel = 50;
// Player's current progress — levels at or below this are claimable/claimed;
// levels above are locked. Set to 35 (not max) for demo purposes, so the
// timeline actually shows a mix of claimed, current, and locked levels
// instead of everything being claimed at once.
const int _kCurrentLevel = 35;

final _levels = [47, 48, 49, 50, 51]; // kept for any legacy call sites

/// Deterministic per-level reward generator — every level gets a distinct
/// free reward and premium reward instead of the previous flat 5-item mock,
/// so the new horizontal timeline actually has 50 different levels to walk
/// through rather than repeating the same 5 cards.
List<_Reward> _generateFreeRewards() {
  return List.generate(_kMaxLevel, (i) {
    final level = i + 1;
    final claimed = level <= _kCurrentLevel;
    // Milestone levels (every 10th, and the final level) get a standout
    // frame/avatar instead of plain currency, so the free track isn't pure
    // coins all the way down.
    if (level == _kMaxLevel) {
      return _Reward(type: _RewardType.frame, label: 'Sakura Frame', claimed: claimed);
    }
    if (level % 10 == 0) {
      return _Reward(type: _RewardType.chest, label: 'Misteri Box', claimed: claimed);
    }
    if (level % 5 == 0) {
      return _Reward(type: _RewardType.crystal, label: 'x${20 + level}', claimed: claimed);
    }
    return _Reward(type: _RewardType.coin, label: 'x${100 + level * 10}', claimed: claimed);
  });
}

List<_Reward> _generatePremiumRewards() {
  return List.generate(_kMaxLevel, (i) {
    final level = i + 1;
    final claimed = level <= _kCurrentLevel;
    if (level == _kMaxLevel) {
      return _Reward(
        type: _RewardType.avatar,
        label: 'Sakura Emperor',
        claimed: claimed,
        isPremiumHighlight: true,
      );
    }
    if (level % 10 == 0) {
      return _Reward(type: _RewardType.chest, label: 'Epic Chest', claimed: claimed);
    }
    if (level % 5 == 0) {
      return _Reward(type: _RewardType.avatar, label: 'Chibi Sakura', claimed: claimed);
    }
    return _Reward(type: _RewardType.crystal, label: 'x${50 + level * 5}', claimed: claimed);
  });
}

final _benefitItems = [
  {'icon': _RewardType.frame, 'label': 'Exclusive\nFrames'},
  {'icon': _RewardType.emote, 'label': 'Exclusive\nChat Bubbles'},
  {'icon': _RewardType.avatar, 'label': 'Special\nAvatar'},
  {'icon': _RewardType.emote, 'label': 'Premium\nEmotes'},
  {'icon': _RewardType.unknown, 'label': '+ Banyak\nLagi!'},
];

// ─── Shared Hover effect wrapper ────────────────────────────────────────────────
class _HoverScale extends StatefulWidget {
  final Widget child;
  final double scale;
  final VoidCallback? onTap;

  const _HoverScale({
    required this.child,
    this.scale = 1.03,
    this.onTap,
  });

  @override
  State<_HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<_HoverScale> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? widget.scale : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class PremiumPassScreen extends StatefulWidget {
  const PremiumPassScreen({super.key});

  @override
  State<PremiumPassScreen> createState() => _PremiumPassScreenState();
}

class _PremiumPassScreenState extends State<PremiumPassScreen>
    with TickerProviderStateMixin {
  int _tab = 0; // 0=Rewards, 1=Missions
  late AnimationController _shimmerCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late ScrollController _scrollCtrl;
  double _headerOpacity = 0;

  // Interactive States
  bool _isPremiumPurchased = false;
  late List<_Reward> _stateFreeRewards;
  late List<_Reward> _statePremiumRewards;
  // Level currently focused in the timeline/rewards-below-it view — starts
  // on the player's current level so they land on "where they are" rather
  // than level 1.
  int _selectedLevel = _kCurrentLevel;
  late ScrollController _timelineScrollCtrl;

  @override
  void initState() {
    super.initState();
    _stateFreeRewards = _generateFreeRewards();
    _statePremiumRewards = _generatePremiumRewards();
    _timelineScrollCtrl = ScrollController();

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    _scrollCtrl = ScrollController()
      ..addListener(() {
        final opacity = (_scrollCtrl.offset / 150).clamp(0.0, 1.0);
        if ((opacity - _headerOpacity).abs() > 0.01) {
          setState(() => _headerOpacity = opacity);
        }
      });
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _pulseCtrl.dispose();
    _scrollCtrl.dispose();
    _timelineScrollCtrl.dispose();
    super.dispose();
  }

  void _showPurchaseSuccessDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'SuccessDialog',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final scale = Tween<double>(begin: 0.8, end: 1.0).animate(
          CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
        );
        final opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: anim1, curve: Curves.easeIn),
        );
        return Opacity(
          opacity: opacity.value,
          child: Transform.scale(
            scale: scale.value,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Dialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  backgroundColor: Colors.transparent,
                  elevation: 24,
                  child: Container(
                    width: 340,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E093D), Color(0xFF13011F)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _kPink, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: _kPink.withValues(alpha: 0.4),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(child: _Sparkles()),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '👑 UNLOCKED 👑',
                              style: TextStyle(
                                color: _kGold,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: _kPink.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: _kPinkLight, width: 2),
                              ),
                              child: const Center(
                                child: Text('🌸', style: TextStyle(fontSize: 44)),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Sakura Emperor',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Selamat! Akun Anda kini telah di-upgrade ke Premium Pass. Dapatkan seluruh reward eksklusif season ini!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _HoverScale(
                              onTap: () {
                                Navigator.of(context).pop();
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [_kPink, _kPurple],
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _kPink.withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    'Klaim Sekarang!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _upgradePremium() {
    setState(() {
      _isPremiumPurchased = true;
    });
    _showPurchaseSuccessDialog();
  }

  void _claimReward(int index, bool isPremiumRow) {
    setState(() {
      if (isPremiumRow) {
        _statePremiumRewards[index] = _statePremiumRewards[index].copyWith(claimed: true);
      } else {
        _stateFreeRewards[index] = _stateFreeRewards[index].copyWith(claimed: true);
      }
    });

    final r = isPremiumRow ? _statePremiumRewards[index] : _stateFreeRewards[index];
    final emoji = _getEmoji(r.type);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'Reward berhasil diklaim: $emoji ${r.label.isEmpty ? "Spesial Item" : r.label}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: _kPink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Finds the next reward worth spotlighting: first priority is an
  // unclaimed PREMIUM reward the user can actually claim right now (already
  // unlocked); falls back to the next unclaimed FREE reward; falls back to
  // the next unclaimed but still-locked PREMIUM reward (so premium buyers
  // always see what's coming) — never surfaces an already-claimed reward.
  ({_Reward reward, bool isPremiumRow, int index})? _nextUnclaimedReward() {
    if (_isPremiumPurchased) {
      for (var i = 0; i < _statePremiumRewards.length; i++) {
        final r = _statePremiumRewards[i];
        if (!r.claimed && !r.locked) {
          return (reward: r, isPremiumRow: true, index: i);
        }
      }
    }
    for (var i = 0; i < _stateFreeRewards.length; i++) {
      final r = _stateFreeRewards[i];
      if (!r.claimed) return (reward: r, isPremiumRow: false, index: i);
    }
    for (var i = 0; i < _statePremiumRewards.length; i++) {
      final r = _statePremiumRewards[i];
      if (!r.claimed) return (reward: r, isPremiumRow: true, index: i);
    }
    return null; // everything claimed
  }

  String _getEmoji(_RewardType type) {
    switch (type) {
      case _RewardType.coin: return '🪙';
      case _RewardType.crystal: return '💎';
      case _RewardType.ticket: return '🎫';
      case _RewardType.frame: return '🪞';
      case _RewardType.avatar: return '🎴';
      case _RewardType.chest: return '📦';
      case _RewardType.emote: return '😊';
      default: return '❓';
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _kBg,
        body: Stack(
          children: [
            // Scroll content
            CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                // Hero banner
                SliverToBoxAdapter(
                  child: _HeroBanner(
                    safeTop: safeTop,
                    isPremium: _isPremiumPurchased,
                    onUpgrade: _upgradePremium,
                  ),
                ),
                // XP progress bar
                SliverToBoxAdapter(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: Opacity(
                          opacity: value,
                          child: child,
                        ),
                      );
                    },
                    child: _XpBar(pulseAnim: _pulseAnim),
                  ),
                ),
                // Tab selector
                SliverToBoxAdapter(
                  child: _TabSelector(
                    current: _tab,
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                ),
                // Content
                if (_tab == 0) ...[
                  SliverToBoxAdapter(
                    child: _NextRewardSpotlight(
                      reward: _nextUnclaimedReward(),
                      isPremiumActive: _isPremiumPurchased,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _LevelTimeline(
                      scrollController: _timelineScrollCtrl,
                      maxLevel: _kMaxLevel,
                      currentLevel: _kCurrentLevel,
                      selectedLevel: _selectedLevel,
                      onSelect: (level) => setState(() => _selectedLevel = level),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 30 * (1 - value)),
                          child: Opacity(opacity: value, child: child),
                        );
                      },
                      child: _RewardsGrid(
                        pulseAnim: _pulseAnim,
                        isPremiumActive: _isPremiumPurchased,
                        selectedLevel: _selectedLevel,
                        freeRewards: _stateFreeRewards,
                        premiumRewards: _statePremiumRewards,
                        onClaimReward: _claimReward,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 30 * (1 - value)),
                          child: Opacity(opacity: value, child: child),
                        );
                      },
                      child: _BenefitsRow(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 750),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 30 * (1 - value)),
                          child: Opacity(opacity: value, child: child),
                        );
                      },
                      child: _PurchaseCard(
                        shimmer: _shimmerCtrl,
                        isPremium: _isPremiumPurchased,
                        onUpgrade: _upgradePremium,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ] else ...[
                  SliverToBoxAdapter(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 30 * (1 - value)),
                          child: Opacity(opacity: value, child: child),
                        );
                      },
                      child: _MissionsTab(),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ],
            ),
            // Floating top bar (fades in on scroll with frosted glass)
            _FloatingAppBar(opacity: _headerOpacity, safeTop: safeTop),
          ],
        ),
      ),
    );
  }
}

// ─── Floating app bar (Frosted Glass) ─────────────────────────────────────────
class _FloatingAppBar extends StatelessWidget {
  final double opacity, safeTop;
  const _FloatingAppBar({required this.opacity, required this.safeTop});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: opacity * 15,
            sigmaY: opacity * 15,
          ),
          child: Container(
            padding: EdgeInsets.only(top: safeTop),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: opacity * 0.75),
              border: Border(
                bottom: BorderSide(
                  color: _kPink.withValues(alpha: opacity * 0.15),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _HoverScale(
                    scale: 1.1,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                          )
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: _kInk, size: 16),
                    ),
                  ),
                  const Spacer(),
                  Opacity(
                    opacity: opacity,
                    child: const Text(
                      'Premium Pass 🌸',
                      style: TextStyle(
                        color: _kInk,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _TopActionBtn(icon: Icons.help_outline_rounded, label: 'Guide'),
                  const SizedBox(width: 10),
                  _TopActionBtn(
                      icon: Icons.storefront_outlined, label: 'Pass Store'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TopActionBtn({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return _HoverScale(
      scale: 1.08,
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _kMuted, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: _kMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Single "26 / HARI" style unit used inside the hero banner's countdown
// card — a big bold number with a small caption underneath, rather than
// all-inline text, so the remaining time actually reads as urgent.
class _CountdownUnit extends StatelessWidget {
  final String value;
  final String label;
  const _CountdownUnit({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: _kInk,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: _kMuted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

// ─── Hero banner ──────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final double safeTop;
  final bool isPremium;
  final VoidCallback onUpgrade;

  const _HeroBanner({
    required this.safeTop,
    required this.isPremium,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 470 + safeTop,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Hero key-art — falls back to nothing (gradient below still
          // covers full-bleed) if the asset isn't dropped in yet.
          Positioned.fill(
            child: Image.asset(
              'asset/images/vault/pass_hero_sakura.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          // Gradient overlay — tint only, not a full backdrop, so the key
          // art shows through once it's in place. Kept fully opaque at the
          // very bottom so it still blends cleanly into the rest of the
          // page even without the art.
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99FFE6F3),
                  Color(0x66F6E8FF),
                  Color(0x33FFF7FC),
                  _kBg,
                ],
                stops: [0.0, 0.4, 0.75, 1.0],
              ),
            ),
          ),
          // Sakura petal particles
          _SakuraPetals(),
          // Sparkle particles
          _Sparkles(),
          // Radial glow behind content
          Positioned(
            right: -20,
            top: safeTop - 20,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _kPink.withValues(alpha: 0.22),
                    _kPurple.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.fromLTRB(20, safeTop + 48, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Season badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _kPink.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kPink.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: _kPink.withValues(alpha: 0.05),
                        blurRadius: 8,
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.star_rounded, color: _kPink, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'SEASON 1',
                        style: TextStyle(
                          color: _kPink,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // SAKURA FESTIVAL title
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [_kInk, _kPinkLight, _kPink],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: const Text(
                    'SAKURA\nFESTIVAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      height: 0.95,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Unlock exclusive rewards and\nbecome a legend of AniVerse.',
                  style: TextStyle(
                    color: _kInk,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                // Countdown — a standalone visual card with big numbers
                // instead of small inline text, so the season's urgency
                // actually registers instead of blending into the caption
                // row above it.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kPink.withValues(alpha: 0.35), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: _kPink.withValues(alpha: 0.10),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_rounded, color: _kPink, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Berakhir dalam',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _kInk.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      _CountdownUnit(value: '26', label: 'HARI'),
                      const SizedBox(width: 8),
                      Text(':', style: TextStyle(color: _kInk.withValues(alpha: 0.4), fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 8),
                      _CountdownUnit(value: '14', label: 'JAM'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Upgrade button + Pass Level badge
                Row(
                  children: [
                    _HoverScale(
                      onTap: isPremium ? null : onUpgrade,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: isPremium
                              ? const LinearGradient(
                                  colors: [Color(0xFF2A0845), Color(0xFF6441A5)],
                                )
                              : const LinearGradient(
                                  colors: [_kPink, Color(0xFFD81B60)],
                                ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: (isPremium ? _kPurple : _kPink).withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPremium ? Icons.workspace_premium_rounded : Icons.offline_bolt_rounded,
                              color: isPremium ? _kGold : Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isPremium ? 'Premium Active 👑' : 'Upgrade Pass',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Pass Level badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _kPink.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _kPink.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Pass Level',
                            style: TextStyle(
                              color: _kMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 1),
                          ShaderMask(
                            shaderCallback: (b) => const LinearGradient(
                              colors: [_kInk, _kPinkLight],
                            ).createShader(b),
                            child: const Text(
                              '$_kCurrentLevel',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kPink,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              _kCurrentLevel >= _kMaxLevel ? 'MAX' : '/ $_kMaxLevel',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
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
          // Back + top actions (always visible back button backdrop)
          Positioned(
            top: safeTop + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _HoverScale(
                  scale: 1.1,
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
                const Spacer(),
                _TopActionBtn(icon: Icons.help_outline_rounded, label: 'Guide'),
                const SizedBox(width: 16),
                _TopActionBtn(
                    icon: Icons.storefront_outlined, label: 'Pass Store'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sakura petals painter ────────────────────────────────────────────────────
class _SakuraPetals extends StatefulWidget {
  @override
  State<_SakuraPetals> createState() => _SakuraPetalsState();
}

class _SakuraPetalsState extends State<_SakuraPetals>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _rng = math.Random(7);
  late List<_Petal> _petals;

  @override
  void initState() {
    super.initState();
    _petals = List.generate(
        18,
        (_) => _Petal(
              x: _rng.nextDouble(),
              y: _rng.nextDouble(),
              size: 5 + _rng.nextDouble() * 8,
              speed: 0.015 + _rng.nextDouble() * 0.035,
              opacity: 0.15 + _rng.nextDouble() * 0.4,
              drift: (_rng.nextDouble() - 0.3) * 0.012,
              angle: _rng.nextDouble() * math.pi * 2,
              spin: (_rng.nextDouble() - 0.5) * 0.02,
            ));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
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
      builder: (_, __) {
        for (final p in _petals) {
          p.y += p.speed * 0.01;
          p.x += p.drift;
          p.angle += p.spin;
          if (p.y > 1.05) {
            p.y = -0.05;
            p.x = _rng.nextDouble();
          }
          if (p.x > 1.05 || p.x < -0.05) {
            p.x = _rng.nextDouble();
            p.y = -0.05;
          }
        }
        return CustomPaint(
          size: Size.infinite,
          painter: _PetalPainter(_petals),
        );
      },
    );
  }
}

class _Petal {
  double x, y, size, speed, opacity, drift, angle, spin;
  _Petal({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.drift,
    required this.angle,
    required this.spin,
  });
}

class _PetalPainter extends CustomPainter {
  final List<_Petal> petals;
  _PetalPainter(this.petals);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in petals) {
      final paint = Paint()
        ..color = _kPink.withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill;
      canvas.save();
      canvas.translate(p.x * size.width, p.y * size.height);
      canvas.rotate(p.angle);
      // Simple oval petal
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset.zero, width: p.size, height: p.size * 0.55),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PetalPainter old) => true;
}

// ─── Sparkles painter ─────────────────────────────────────────────────────────
class _Sparkles extends StatefulWidget {
  const _Sparkles();

  @override
  State<_Sparkles> createState() => _SparklesState();
}

class _SparklesState extends State<_Sparkles>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _rng = math.Random(19);
  late List<_Sparkle> _sparkles;

  @override
  void initState() {
    super.initState();
    _sparkles = List.generate(
        12,
        (_) => _Sparkle(
              x: _rng.nextDouble(),
              y: _rng.nextDouble(),
              maxSize: 4 + _rng.nextDouble() * 6,
              speed: 0.04 + _rng.nextDouble() * 0.08,
              phase: _rng.nextDouble() * math.pi * 2,
            ));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
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
      builder: (_, __) {
        for (final s in _sparkles) {
          s.phase += s.speed * 0.1;
        }
        return CustomPaint(
          size: Size.infinite,
          painter: _SparklePainter(_sparkles),
        );
      },
    );
  }
}

class _Sparkle {
  double x, y, maxSize, speed, phase;
  _Sparkle({
    required this.x,
    required this.y,
    required this.maxSize,
    required this.speed,
    required this.phase,
  });
}

class _SparklePainter extends CustomPainter {
  final List<_Sparkle> sparkles;
  _SparklePainter(this.sparkles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in sparkles) {
      final opacity = (math.sin(s.phase).abs() * 0.6).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = _kGold.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      
      final cx = s.x * size.width;
      final cy = s.y * size.height;
      final r = s.maxSize * (0.25 + math.sin(s.phase).abs() * 0.75);

      final path = Path();
      path.moveTo(cx, cy - r);
      path.quadraticBezierTo(cx, cy, cx + r, cy);
      path.quadraticBezierTo(cx, cy, cx, cy + r);
      path.quadraticBezierTo(cx, cy, cx - r, cy);
      path.quadraticBezierTo(cx, cy, cx, cy - r);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => true;
}

// ─── XP progress bar ─────────────────────────────────────────────────────────
class _XpBar extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _XpBar({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _kPink.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Sakura icon
              AnimatedBuilder(
                animation: pulseAnim,
                builder: (_, child) => Transform.scale(
                  scale: 1.0 + pulseAnim.value * 0.08,
                  child: child,
                ),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Image.asset(
                    'asset/images/vault/badge_level_frame.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _kPink.withValues(alpha: 0.35),
                            _kPurple.withValues(alpha: 0.1),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: const Center(
                          child: Text('🌸', style: TextStyle(fontSize: 24))),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level $_kCurrentLevel',
                    style: const TextStyle(
                      color: _kInk,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kPink,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _kCurrentLevel >= _kMaxLevel ? 'MAX' : '/ $_kMaxLevel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '1000 / 1000 XP',
                style: TextStyle(
                  color: _kInk.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AnimatedBuilder(
              animation: pulseAnim,
              builder: (_, __) => Stack(
                children: [
                  Container(
                    height: 10,
                    color: const Color(0xFFF4D9EA),
                  ),
                  FractionallySizedBox(
                    widthFactor: 1.0,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_kPink, _kPinkLight],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _kPink.withValues(
                                alpha: 0.4 + pulseAnim.value * 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Shimmer
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: pulseAnim,
                      builder: (_, __) => FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: pulseAnim.value,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.3),
                                Colors.transparent,
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
          ),
        ],
      ),
    );
  }
}

// ─── Tab selector ─────────────────────────────────────────────────────────────
class _TabSelector extends StatelessWidget {
  final int current;
  final ValueChanged<int> onChanged;
  const _TabSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _kPink.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          _Tab(
            label: 'Rewards',
            iconAsset: 'icon_rewards_tab.png',
            isActive: current == 0,
            onTap: () => onChanged(0),
          ),
          _Tab(
            label: 'Missions',
            iconAsset: 'icon_missions_tab.png',
            isActive: current == 1,
            onTap: () => onChanged(1),
            hasDot: true,
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final String iconAsset;
  final bool isActive, hasDot;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.iconAsset,
    required this.isActive,
    required this.onTap,
    this.hasDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: _HoverScale(
        scale: 1.02,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    colors: [_kPink, _kPurple])
                : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: _kPink.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'asset/images/vault/$iconAsset',
                width: 18,
                height: 18,
                // Active tab: icon rendered over a gradient (pink/purple),
                // so recolor it white to stay legible. Inactive tab: keep
                // the icon's own gold tone as-is.
                color: isActive ? Colors.white : null,
                errorBuilder: (_, __, ___) => Icon(
                  label == 'Rewards' ? Icons.card_giftcard_rounded : Icons.checklist_rounded,
                  size: 16,
                  color: isActive ? Colors.white : _kMuted,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : _kMuted,
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
              if (hasDot) ...[
                const SizedBox(width: 5),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: _kPink,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Rewards grid ─────────────────────────────────────────────────────────────
// A horizontal, scrollable level track — nodes for every level connected by
// a line, the selected level enlarged/highlighted, tap-to-jump anywhere
// along the track. Replaces the old static "47 48 49 50 51" header row so
// the pass actually reads as a path being walked rather than a flat grid.
class _LevelTimeline extends StatefulWidget {
  final ScrollController scrollController;
  final int maxLevel;
  final int currentLevel;
  final int selectedLevel;
  final ValueChanged<int> onSelect;

  const _LevelTimeline({
    required this.scrollController,
    required this.maxLevel,
    required this.currentLevel,
    required this.selectedLevel,
    required this.onSelect,
  });

  @override
  State<_LevelTimeline> createState() => _LevelTimelineState();
}

class _LevelTimelineState extends State<_LevelTimeline> {
  static const double _nodeWidth = 56;
  bool _didInitialScroll = false;

  @override
  void didUpdateWidget(covariant _LevelTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLevel != widget.selectedLevel) {
      _scrollToSelected(animate: true);
    }
  }

  void _scrollToSelected({required bool animate}) {
    if (!widget.scrollController.hasClients) return;
    final target = ((widget.selectedLevel - 1) * _nodeWidth) -
        (widget.scrollController.position.viewportDimension / 2) +
        (_nodeWidth / 2);
    final clamped = target.clamp(
      0.0,
      widget.scrollController.position.maxScrollExtent,
    );
    if (animate) {
      widget.scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      widget.scrollController.jumpTo(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Auto-center on the selected level exactly once, after this frame has
    // laid out and the ScrollController has real viewport metrics —
    // attempting it in initState/build directly would read a
    // maxScrollExtent of 0 before layout has happened.
    if (!_didInitialScroll) {
      _didInitialScroll = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected(animate: false));
    }

    return Container(
      height: 92,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.builder(
        controller: widget.scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: widget.maxLevel,
        itemBuilder: (context, i) {
          final level = i + 1;
          final isSelected = level == widget.selectedLevel;
          final isPast = level <= widget.currentLevel;
          final isFirst = i == 0;
          final isLast = i == widget.maxLevel - 1;

          return SizedBox(
            width: _nodeWidth,
            child: GestureDetector(
              onTap: () => widget.onSelect(level),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Connector line + node — the line only actually needs to
                  // exist between nodes, so each node draws half a line to
                  // its left and half to its right; the outer edges just
                  // skip their outward half so the track doesn't dangle
                  // past the first/last level.
                  SizedBox(
                    height: 34,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 3,
                                color: isFirst
                                    ? Colors.transparent
                                    : (isPast ? _kPink : _kBorder),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 3,
                                color: isLast
                                    ? Colors.transparent
                                    : (isPast && level < widget.currentLevel
                                        ? _kPink
                                        : _kBorder),
                              ),
                            ),
                          ],
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          width: isSelected ? 34 : 22,
                          height: isSelected ? 34 : 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isSelected
                                ? const LinearGradient(
                                    colors: [_kPink, _kPurple],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: isSelected
                                ? null
                                : (isPast ? _kPinkLight.withValues(alpha: 0.35) : _kCard),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : (isPast ? _kPink.withValues(alpha: 0.5) : _kBorder),
                              width: isSelected ? 2.5 : 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: _kPink.withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isPast && !isSelected
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$level',
                    style: TextStyle(
                      color: isSelected ? _kPink : _kInk.withValues(alpha: 0.55),
                      fontSize: isSelected ? 13 : 11,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NextRewardSpotlight extends StatelessWidget {
  final ({_Reward reward, bool isPremiumRow, int index})? reward;
  final bool isPremiumActive;
  const _NextRewardSpotlight({required this.reward, required this.isPremiumActive});

  @override
  Widget build(BuildContext context) {
    final r = reward;
    if (r == null) {
      // Everything claimed — a quiet "all caught up" state instead of
      // just vanishing, so the layout doesn't jump.
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.celebration_rounded, color: _kGold, size: 18),
            const SizedBox(width: 8),
            Text(
              'Semua reward level ini sudah diklaim!',
              style: TextStyle(color: _kInk.withValues(alpha: 0.7), fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final needsPurchase = r.reward.locked && !isPremiumActive;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: needsPurchase
              ? [const Color(0xFF33084C), const Color(0xFF19012A)]
              : [Colors.white.withValues(alpha: 0.85), Colors.white.withValues(alpha: 0.55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: needsPurchase ? _kGold.withValues(alpha: 0.5) : _kPink.withValues(alpha: 0.35),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: (needsPurchase ? _kGold : _kPink).withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: needsPurchase ? 0.08 : 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: _RewardIcon(type: r.reward.type, claimed: false, label: r.reward.label),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reward Berikutnya',
                  style: TextStyle(
                    color: needsPurchase ? _kGold : _kPink,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  r.reward.label.isEmpty ? 'Item Spesial' : r.reward.label,
                  style: TextStyle(
                    color: needsPurchase ? Colors.white : _kInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (needsPurchase)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _kGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _kGold.withValues(alpha: 0.4)),
              ),
              child: const Text(
                'PREMIUM',
                style: TextStyle(color: _kGold, fontSize: 10, fontWeight: FontWeight.w900),
              ),
            )
          else
            Icon(Icons.arrow_forward_rounded, color: _kPink.withValues(alpha: 0.6), size: 20),
        ],
      ),
    );
  }
}

class _RewardsGrid extends StatelessWidget {
  final Animation<double> pulseAnim;
  final bool isPremiumActive;
  final int selectedLevel;
  final List<_Reward> freeRewards;
  final List<_Reward> premiumRewards;
  final Function(int, bool) onClaimReward;

  const _RewardsGrid({
    required this.pulseAnim,
    required this.isPremiumActive,
    required this.selectedLevel,
    required this.freeRewards,
    required this.premiumRewards,
    required this.onClaimReward,
  });

  @override
  Widget build(BuildContext context) {
    final index = selectedLevel - 1;
    final freeReward = freeRewards[index];
    final premiumReward = premiumRewards[index];
    final isMaxLevel = selectedLevel == _kMaxLevel;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kPink.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          // Frosted-glass shell — semi-transparent white over a blurred
          // backdrop, instead of a flat opaque card, so this reads as one
          // continuous glass surface with the painterly hero banner above
          // it rather than a plain sheet of paper sitting on top of it.
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 1.4,
              ),
            ),
            child: Stack(
              children: [
                // Top sheen — faint bright streak along the upper edge,
                // the same "this is glass, not paper" cue used elsewhere.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.35),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Column(
                  children: [
                    // Selected-level header — the timeline above already
                    // handles picking a level, so this just confirms which
                    // one is being shown here.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: Row(
                        children: [
                          Text(
                            'Level $selectedLevel',
                            style: const TextStyle(
                              color: _kInk,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (isMaxLevel) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _kPink.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'MAX',
                                style: TextStyle(color: _kPink, fontSize: 10, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Divider(color: _kBorder.withValues(alpha: 0.6), height: 1, thickness: 1.2),
                    const SizedBox(height: 4),
                    // FREE reward for this level
                    _SingleLevelRewardTile(
                      rowLabel: 'FREE',
                      rowIcon: Icons.star_outline_rounded,
                      rowColor: _kPurple,
                      reward: freeReward,
                      pulseAnim: pulseAnim,
                      onClaim: () => onClaimReward(index, false),
                    ),
                    // Connector line
                    SizedBox(
                      height: 20,
                      child: Center(
                        child: Container(
                          width: 2.5,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_kPurple, _kPink],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    // PREMIUM reward for this level — same gold-glow
                    // treatment as before, still visually outranking FREE.
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _kGold.withValues(alpha: isPremiumActive ? 0.14 : 0.08),
                            _kGold.withValues(alpha: 0.0),
                          ],
                        ),
                        border: Border.all(
                          color: _kGold.withValues(alpha: isPremiumActive ? 0.35 : 0.18),
                          width: 1.2,
                        ),
                      ),
                      child: _SingleLevelRewardTile(
                        rowLabel: 'PREMIUM',
                        rowIcon: Icons.workspace_premium_rounded,
                        rowColor: _kGold,
                        reward: premiumReward.copyWith(
                          locked: premiumReward.locked || !isPremiumActive,
                        ),
                        pulseAnim: pulseAnim,
                        isPremiumRow: true,
                        onClaim: () => onClaimReward(index, true),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// A single reward — icon/label column on the left (FREE/PREMIUM), then one
// big reward card for the currently-selected level. Replaces the old
// horizontal 5-column _RewardRow now that level selection lives in the
// timeline above instead of side-by-side columns here.
class _SingleLevelRewardTile extends StatelessWidget {
  final String rowLabel;
  final IconData rowIcon;
  final Color rowColor;
  final _Reward reward;
  final Animation<double> pulseAnim;
  final bool isPremiumRow;
  final VoidCallback onClaim;

  const _SingleLevelRewardTile({
    required this.rowLabel,
    required this.rowIcon,
    required this.rowColor,
    required this.reward,
    required this.pulseAnim,
    this.isPremiumRow = false,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(rowIcon, color: rowColor, size: isPremiumRow ? 26 : 20),
                const SizedBox(height: 4),
                Text(
                  rowLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: rowColor,
                    fontSize: isPremiumRow ? 11 : 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _RewardCell(
              reward: reward,
              pulseAnim: pulseAnim,
              isPremiumRow: isPremiumRow,
              onTap: onClaim,
            ),
          ),
        ],
      ),
    );
  }
}


class _RewardCell extends StatelessWidget {
  final _Reward reward;
  final Animation<double> pulseAnim;
  final bool isPremiumRow;
  final VoidCallback onTap;

  const _RewardCell({
    required this.reward,
    required this.pulseAnim,
    required this.isPremiumRow,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = reward;

    if (r.isPremiumHighlight) {
      return _HoverScale(
        scale: 1.08,
        onTap: onTap,
        child: AnimatedBuilder(
          animation: pulseAnim,
          builder: (_, __) {
            // Locked: dim to a faint, static glow instead of the full
            // pulsing pink — a locked reward shouldn't glow as invitingly
            // as one that's active or already claimed.
            final glowAlpha = r.locked
                ? 0.18
                : 0.6 + pulseAnim.value * 0.4;
            final shadowAlpha = r.locked
                ? 0.08
                : 0.35 + pulseAnim.value * 0.2;
            return Container(
            margin: const EdgeInsets.all(4),
            height: isPremiumRow ? 88 : 76,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF33084C), Color(0xFF19012A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _kPink.withValues(alpha: glowAlpha),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: _kPink.withValues(alpha: shadowAlpha),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RewardIcon(type: r.type, claimed: r.claimed, label: r.label),
                      const SizedBox(height: 2),
                      Text(
                        'Emperor',
                        style: TextStyle(
                          color: _kPinkLight.withValues(alpha: 0.9),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    ],
                  ),
                ),
                if (r.claimed)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: _kPink,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 10),
                    ),
                  ),
                if (r.locked && !r.claimed)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.4),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.lock_rounded, color: _kGold, size: 14),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
          },
        ),
      );
    }

    // Claimed-state color differs by track, so a claimed FREE item and a
    // claimed PREMIUM item still read as visually distinct — previously
    // both used the same pink tint, which made every claimed row look
    // "premium" regardless of which track it actually came from.
    final claimedTint = isPremiumRow ? _kPink : _kGold;

    final cellBg = r.claimed
        ? _kCardBright.withValues(alpha: 0.6)
        : r.locked
            ? _kCard
            : _kCardBright;

    return _HoverScale(
      scale: 1.05,
      onTap: onTap,
      // Breathing effect: only for rewards that are actually actionable
      // right now (not locked, not already claimed) — a gentle scale+glow
      // pulse that draws the eye to "this one needs you" without being as
      // loud as the dedicated Emperor spotlight card above.
      child: AnimatedBuilder(
        animation: pulseAnim,
        builder: (context, child) {
          final breathing = !r.locked && !r.claimed;
          final t = breathing ? pulseAnim.value : 0.0;
          return Transform.scale(
            scale: 1.0 + t * 0.035,
            child: child,
          );
        },
        child: Builder(
          builder: (context) {
            final breathing = !r.locked && !r.claimed;
            return Container(
              margin: const EdgeInsets.all(4),
              height: isPremiumRow ? 88 : 76,
              decoration: BoxDecoration(
                color: cellBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: r.claimed
                      ? claimedTint.withValues(alpha: 0.3)
                      : _kBorder,
                  width: r.claimed ? 1.5 : 1,
                ),
                boxShadow: [
                  if (breathing)
                    BoxShadow(
                      color: (isPremiumRow ? _kGold : _kPurple)
                          .withValues(alpha: 0.10 + pulseAnim.value * 0.14),
                      blurRadius: 6 + pulseAnim.value * 6,
                      spreadRadius: pulseAnim.value * 1.5,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RewardIcon(type: r.type, claimed: r.claimed, label: r.label),
                  if (r.label.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        r.label,
                        style: TextStyle(
                          color: r.claimed ? _kMuted : _kInk,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (r.claimed)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: claimedTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 10),
                ),
              ),
            if (r.locked && !r.claimed)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.5),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_rounded, color: Colors.white, size: 12),
                      ),
                    ),
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

class _RewardIcon extends StatelessWidget {
  final _RewardType type;
  final bool claimed;
  final String label;
  const _RewardIcon({required this.type, required this.claimed, this.label = ''});

  // Specific reward art takes priority over the generic per-type asset —
  // e.g. "Sakura Frame" and "Imperial Frame" are both _RewardType.frame but
  // need visually distinct art, not one shared frame icon.
  String? get _specificAsset {
    final l = label.toLowerCase();
    if (l.contains('sakura frame')) return 'reward_premium_sakura_frame.png';
    if (l.contains('imperial frame')) return 'reward_premium_imperial_frame.png';
    if (l.contains('chibi sakura')) return 'reward_premium_chibi_sakura.png';
    if (l.contains('sakura emperor')) return 'reward_premium_emperor_crest.png';
    if (l.contains('misteri') || l.contains('mystery')) return 'reward_premium_mystery_box.png';
    if (l.contains('epic chest')) return 'reward_premium_epic_chest.png';
    return null;
  }

  String? get _typeAsset {
    switch (type) {
      case _RewardType.coin:
        return 'reward_free_coin.png';
      case _RewardType.crystal:
        return 'reward_premium_gem_diamond.png';
      case _RewardType.ticket:
        return 'reward_premium_ticket.png';
      default:
        return null; // frame/avatar/chest/emote/unknown are label-specific
                     // or intentionally left to the emoji fallback below.
    }
  }

  String get _emojiFallback {
    switch (type) {
      case _RewardType.coin:
        return '🪙';
      case _RewardType.crystal:
        return '💎';
      case _RewardType.ticket:
        return '🎫';
      case _RewardType.frame:
        return '🪞';
      case _RewardType.avatar:
        return '🎴';
      case _RewardType.chest:
        return '📦';
      case _RewardType.emote:
        return '😊';
      case _RewardType.unknown:
        return '❓';
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetName = _specificAsset ?? _typeAsset;
    if (assetName == null) return _EmojiIcon(_emojiFallback, claimed);
    return Opacity(
      opacity: claimed ? 0.45 : 1.0,
      child: Image.asset(
        'asset/images/vault/$assetName',
        width: 28,
        height: 28,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Text(
          _emojiFallback,
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}

class _EmojiIcon extends StatelessWidget {
  final String emoji;
  final bool claimed;
  const _EmojiIcon(this.emoji, this.claimed);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: claimed ? 0.45 : 1.0,
      child: Text(emoji, style: const TextStyle(fontSize: 22)),
    );
  }
}

// ─── Benefits row ─────────────────────────────────────────────────────────────
class _BenefitsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B072C), Color(0xFF0F021D)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kPink.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _kPink.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [_kPinkLight, _kPink],
                  ).createShader(b),
                  child: const Text(
                    'Beli Premium Pass',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'dan dapatkan\nhadiah eksklusif!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _benefitItems.map((item) {
                  return _BenefitItem(
                    type: item['icon'] as _RewardType,
                    label: item['label'] as String,
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final _RewardType type;
  final String label;
  const _BenefitItem({required this.type, required this.label});

  @override
  Widget build(BuildContext context) {
    String emoji;
    switch (type) {
      case _RewardType.frame: emoji = '🪞'; break;
      case _RewardType.emote: emoji = '💬'; break;
      case _RewardType.avatar: emoji = '🎴'; break;
      default: emoji = '❓';
    }
    return _HoverScale(
      scale: 1.1,
      child: Container(
        width: 64,
        margin: const EdgeInsets.only(left: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _kPink.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kPink.withValues(alpha: 0.3)),
              ),
              child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 9,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Purchase card (Luxurious Dark Gradient) ──────────────────────────────────
class _PurchaseCard extends StatelessWidget {
  final AnimationController shimmer;
  final bool isPremium;
  final VoidCallback onUpgrade;

  const _PurchaseCard({
    required this.shimmer,
    required this.isPremium,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2F0A3F), // Rich Deep Cosmic Purple
            Color(0xFF13011E), // Dark Velvet
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPremium ? _kGold.withValues(alpha: 0.6) : _kPink.withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isPremium ? _kGold : _kPink).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Sparkles inside the purchase card
          const Positioned.fill(child: _Sparkles()),
          Row(
            children: [
              // Trophy icon
              _HoverScale(
                scale: 1.1,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        _kPink.withValues(alpha: 0.25),
                        Colors.transparent,
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: _kGold.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: const Center(
                      child: Text('🏆', style: TextStyle(fontSize: 38))),
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sakura Festival Pass',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const _BulletItem('Semua reward Premium Pass'),
                    const _BulletItem('+20% XP dari semua aktivitas'),
                    const _BulletItem('Akses ke Pass Store eksklusif'),
                    Row(
                      children: [
                        Text(
                          '• Badge eksklusif ',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        ShaderMask(
                          shaderCallback: (b) => const LinearGradient(
                            colors: [_kPinkLight, _kPink],
                          ).createShader(b),
                          child: const Text(
                            'Sakura Emperor',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Price + CTA
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isPremium) ...[
                    Row(
                      children: [
                        Text(
                          'Rp 89.000',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '-30%',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Rp 62.000',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'AKTIF 👑',
                      style: TextStyle(
                        color: _kGold,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: shimmer,
                    builder: (_, child) => ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: const [
                          _kPink,
                          Color(0xFFFF8EC7),
                          _kPink,
                        ],
                        stops: [
                          (shimmer.value - 0.3).clamp(0, 1),
                          shimmer.value.clamp(0, 1),
                          (shimmer.value + 0.3).clamp(0, 1),
                        ],
                      ).createShader(bounds),
                      child: child,
                    ),
                    child: _HoverScale(
                      onTap: isPremium ? null : onUpgrade,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: isPremium
                              ? const LinearGradient(
                                  colors: [Color(0xFF4A148C), Color(0xFF311B92)],
                                )
                              : const LinearGradient(
                                  colors: [_kPink, Color(0xFFAD1457)],
                                ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: (isPremium ? Colors.purple : _kPink).withValues(alpha: 0.45),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          isPremium ? 'Miliki Sekarang' : 'Upgrade\nSekarang',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isPremium ? 'Terima kasih atas dukungannya!' : 'Berlaku sampai 31 Mei 2024',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text(
            '• ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 11,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Missions tab (fixed light-theme text colors) ───────────────────────────────
class _MissionsTab extends StatefulWidget {
  const _MissionsTab();

  @override
  State<_MissionsTab> createState() => _MissionsTabState();
}

class _MissionsTabState extends State<_MissionsTab> {
  final List<Map<String, dynamic>> _missions = [
    {'title': 'Tonton 5 Episode', 'progress': 3, 'total': 5, 'xp': '+50 XP', 'reward': '💎 x2', 'claimed': false},
    {'title': 'Like 10 Post Komunitas', 'progress': 10, 'total': 10, 'xp': '+30 XP', 'reward': '🪙 x100', 'claimed': true},
    {'title': 'Bergabung 1 Anime Room', 'progress': 0, 'total': 1, 'xp': '+20 XP', 'reward': '🎫 x1', 'claimed': false},
    {'title': 'Buat 3 Post Community', 'progress': 1, 'total': 3, 'xp': '+40 XP', 'reward': '💎 x5', 'claimed': false},
    {'title': 'Selesaikan 1 Anime', 'progress': 0, 'total': 1, 'xp': '+100 XP', 'reward': '🏆 x1', 'claimed': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        children: _missions.asMap().entries.map((entry) {
          final _ = entry.key;
          final m = entry.value;
          final prog = m['progress'] as int;
          final total = m['total'] as int;
          final done = prog >= total;
          final claimed = m['claimed'] as bool;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: claimed
                  ? _kPink.withValues(alpha: 0.05)
                  : _kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: claimed
                    ? _kPink.withValues(alpha: 0.3)
                    : _kBorder,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _kInk.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                // Completion icon container
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: claimed
                        ? _kPink.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.03),
                    border: Border.all(
                      color: claimed
                          ? _kPink.withValues(alpha: 0.3)
                          : _kBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: claimed
                        ? const Icon(Icons.check_rounded, color: _kPink, size: 22)
                        : Icon(Icons.play_circle_outline_rounded, color: _kMuted.withValues(alpha: 0.6), size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                // Title and progress info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m['title'] as String,
                        style: TextStyle(
                          color: claimed ? _kInk.withValues(alpha: 0.5) : _kInk,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          decoration: claimed ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: prog / total,
                          backgroundColor: Colors.black.withValues(alpha: 0.05),
                          valueColor: AlwaysStoppedAnimation<Color>(
                              claimed ? _kPink : _kPurple),
                          minHeight: 5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$prog / $total • ${m['xp']}',
                        style: TextStyle(
                          color: _kMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Rewards and Action CTA
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      m['reward'] as String,
                      style: TextStyle(
                        color: claimed ? _kInk.withValues(alpha: 0.6) : _kPink,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _HoverScale(
                      onTap: done && !claimed
                          ? () {
                              setState(() {
                                m['claimed'] = true;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Misi selesai! Klaim reward ${m['reward']} berhasil 🎉'),
                                  backgroundColor: _kPink,
                                ),
                              );
                            }
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: done && !claimed
                              ? const LinearGradient(colors: [_kPurple, _kPink])
                              : null,
                          color: !done
                              ? Colors.black.withValues(alpha: 0.04)
                              : claimed
                                  ? Colors.transparent
                                  : null,
                          borderRadius: BorderRadius.circular(8),
                          border: claimed ? Border.all(color: _kPink.withValues(alpha: 0.2)) : null,
                        ),
                        child: Text(
                          claimed
                              ? 'Selesai'
                              : done
                                  ? 'Klaim'
                                  : 'Mulai',
                          style: TextStyle(
                            color: done && !claimed
                                ? Colors.white
                                : claimed
                                    ? _kPink.withValues(alpha: 0.7)
                                    : _kMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
