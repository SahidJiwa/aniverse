// ─────────────────────────────────────────────────────────────────────────────
// tier_system.dart
//
// Semua konfigurasi tier AniVerse ada di sini.
// Kalau mau update nama, XP, warna, badge, atau privilege — cukup edit
// bagian "KONFIGURASI TIER" di bawah. Gak perlu sentuh file lain.
//
// Cara import di file lain:
//   import 'tier_system.dart';
//
// Cara pakai:
//   final tier = TierSystem.getTier(userXP);
//   Text(tier.name);           // "Ketagihan Akut"
//   Text(tier.badge);          // "💘"
//   Container(color: tier.color);
//   tier.glowColor             // untuk efek glow/shimmer
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

// ═════════════════════════════════════════════════════════════════════════════
// KONFIGURASI TIER — edit bagian ini kalau mau update
// ═════════════════════════════════════════════════════════════════════════════

/// Daftar tier dari terendah ke tertinggi.
/// [minXP] = XP minimum untuk masuk tier ini.
/// Tier pertama selalu mulai dari 0.
const List<TierConfig> kTiers = [
  TierConfig(
    id: 1,
    name: 'Newbie Nyasar',
    badge: '🫥',
    minXP: 0,
    color: Color(0xFF9E9E9E),       // abu netral
    glowColor: Color(0x339E9E9E),
    nameStyle: TierNameStyle.plain,
  ),
  TierConfig(
    id: 2,
    name: 'Santuy Mode',
    badge: '🛋️',
    minXP: 200,
    color: Color(0xFF66BB6A),       // hijau santai
    glowColor: Color(0x3366BB6A),
    nameStyle: TierNameStyle.plain,
  ),
  TierConfig(
    id: 3,
    name: 'Ketagihan Akut',
    badge: '💘',
    minXP: 500,
    color: Color(0xFF42A5F5),       // biru muda
    glowColor: Color(0x3342A5F5),
    nameStyle: TierNameStyle.plain,
  ),
  TierConfig(
    id: 4,
    name: 'Algoritmanya Gue',
    badge: '👆',
    minXP: 1000,
    color: Color(0xFFFF7043),       // oranye aktif
    glowColor: Color(0x33FF7043),
    nameStyle: TierNameStyle.plain,
  ),
  TierConfig(
    id: 5,
    name: 'Wibu Undercover',
    badge: '🎌',
    minXP: 1800,
    color: Color(0xFFEF5350),       // merah
    glowColor: Color(0x33EF5350),
    nameStyle: TierNameStyle.bold,
  ),
  TierConfig(
    id: 6,
    name: 'Otaku No Kiri',
    badge: '🔥',
    minXP: 3000,
    color: Color(0xFFAB47BC),       // ungu medium
    glowColor: Color(0x33AB47BC),
    nameStyle: TierNameStyle.bold,
  ),
  TierConfig(
    id: 7,
    name: 'Sigma Ter-atas',
    badge: '💜',
    minXP: 4500,
    color: Color(0xFF7E57C2),       // ungu dalam
    glowColor: Color(0x557E57C2),
    nameStyle: TierNameStyle.glow,
  ),
  TierConfig(
    id: 8,
    name: 'No Life Fr Fr',
    badge: '☠️',
    minXP: 6500,
    color: Color(0xFFB0BEC5),       // silver
    glowColor: Color(0x55B0BEC5),
    nameStyle: TierNameStyle.shimmer,
  ),
  TierConfig(
    id: 9,
    name: 'Cosmic Weebu',
    badge: '🌌',
    minXP: 9000,
    color: Color(0xFF00E5FF),       // cyan galaxy (mulai gradient di widget)
    glowColor: Color(0x5500E5FF),
    nameStyle: TierNameStyle.rainbow,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// KONFIGURASI XP — edit ini kalau mau ubah reward per aktivitas
// ─────────────────────────────────────────────────────────────────────────────

class XPReward {
  /// Nonton episode pertama dari anime baru (discovery bonus)
  static const int firstEpisodeNewAnime = 30;

  /// Nonton episode sampai selesai (>90%)
  static const int episodeCompleted = 15;

  /// Bonus nonton 3 episode berturut-turut ("satu lagi ah" trap)
  static const int streakBonus3Episodes = 25;

  /// Komentar di episode
  static const int comment = 10;

  /// Dapat like di komentar
  static const int commentLikeReceived = 5;

  /// Tambah ke watchlist
  static const int addToWatchlist = 8;

  /// Reward episode (First Watch badge)
  static const int firstWatchReward = 40;

  /// Tamat semua episode anime (big reward, jarang)
  static const int animeCompleted = 80;

  /// Login harian (habit loop)
  static const int dailyLogin = 5;
}

// ═════════════════════════════════════════════════════════════════════════════
// ENGINE — gak perlu diubah kecuali mau tambah fitur baru
// ═════════════════════════════════════════════════════════════════════════════

/// Gaya tampilan nama di chat/komentar/profil per tier.
enum TierNameStyle {
  plain,    // putih biasa (tier 1-4)
  bold,     // bold + warna tier (tier 5-6)
  glow,     // bold + warna + soft glow (tier 7)
  shimmer,  // silver shimmer effect (tier 8)
  rainbow,  // rainbow gradient animatif (tier 9)
}

/// Data konfigurasi satu tier. const — aman dipakai di widget tree.
class TierConfig {
  final int id;
  final String name;
  final String badge;
  final int minXP;
  final Color color;
  final Color glowColor;
  final TierNameStyle nameStyle;

  const TierConfig({
    required this.id,
    required this.name,
    required this.badge,
    required this.minXP,
    required this.color,
    required this.glowColor,
    required this.nameStyle,
  });
}

/// Helper utama — semua logic tier ada di sini.
class TierSystem {
  TierSystem._(); // private constructor, semua method static

  // ── Getter dasar ────────────────────────────────────────────────────────────

  /// Ambil tier berdasarkan XP saat ini.
  static TierConfig getTier(int xp) {
    TierConfig result = kTiers.first;
    for (final tier in kTiers) {
      if (xp >= tier.minXP) result = tier;
    }
    return result;
  }

  /// Tier berikutnya (null kalau udah di tier tertinggi).
  static TierConfig? getNextTier(int xp) {
    final current = getTier(xp);
    final idx = kTiers.indexWhere((t) => t.id == current.id);
    if (idx == -1 || idx >= kTiers.length - 1) return null;
    return kTiers[idx + 1];
  }

  /// Progress ke tier berikutnya (0.0 – 1.0).
  static double getProgress(int xp) {
    final current = getTier(xp);
    final next = getNextTier(xp);
    if (next == null) return 1.0; // sudah max tier
    final span = next.minXP - current.minXP;
    final done = xp - current.minXP;
    return (done / span).clamp(0.0, 1.0);
  }

  /// XP yang masih dibutuhkan untuk naik ke tier berikutnya.
  static int xpToNextTier(int xp) {
    final next = getNextTier(xp);
    if (next == null) return 0;
    return (next.minXP - xp).clamp(0, 999999);
  }

  /// Apakah XP ini tepat di threshold tier baru (baru naik)?
  static bool isNewTier(int oldXP, int newXP) {
    return getTier(oldXP).id != getTier(newXP).id;
  }

  // ── Widget helpers ──────────────────────────────────────────────────────────

  /// Badge emoji + nama tier dalam satu Text widget.
  /// Style nama disesuaikan otomatis per tier (plain/bold/glow/shimmer/rainbow).
  static Widget buildTierLabel(TierConfig tier, {double fontSize = 12}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tier.badge, style: TextStyle(fontSize: fontSize)),
        const SizedBox(width: 4),
        _TierNameText(tier: tier, fontSize: fontSize),
      ],
    );
  }

  /// Progress bar menuju tier berikutnya.
  static Widget buildXPBar(int xp, {double height = 6, BorderRadius? radius}) {
    final progress = getProgress(xp);
    final tier = getTier(xp);
    return ClipRRect(
      borderRadius: radius ?? BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: height,
        backgroundColor: tier.color.withValues(alpha: 0.15),
        valueColor: AlwaysStoppedAnimation<Color>(tier.color),
      ),
    );
  }

  /// Card ringkas: badge + nama + XP bar + "X XP lagi".
  static Widget buildTierCard(int xp, {EdgeInsets? padding}) {
    final tier = getTier(xp);
    final next = getNextTier(xp);
    final remaining = xpToNextTier(xp);
    return Padding(
      padding: padding ?? const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          buildTierLabel(tier, fontSize: 14),
          const SizedBox(height: 8),
          buildXPBar(xp, height: 7),
          const SizedBox(height: 6),
          next == null
              ? Text(
                  'Tier tertinggi 🌌',
                  style: TextStyle(
                    color: tier.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : Text(
                  '$remaining XP lagi → ${next.badge} ${next.name}',
                  style: TextStyle(
                    color: tier.color.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ],
      ),
    );
  }
}

// ── Internal widget untuk nama tier dengan style berbeda per level ─────────

class _TierNameText extends StatelessWidget {
  final TierConfig tier;
  final double fontSize;
  const _TierNameText({required this.tier, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    switch (tier.nameStyle) {
      case TierNameStyle.plain:
        return Text(
          tier.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        );
      case TierNameStyle.bold:
        return Text(
          tier.name,
          style: TextStyle(
            color: tier.color,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        );
      case TierNameStyle.glow:
        return Text(
          tier.name,
          style: TextStyle(
            color: tier.color,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            shadows: [
              Shadow(color: tier.glowColor, blurRadius: 8),
              Shadow(color: tier.glowColor, blurRadius: 16),
            ],
          ),
        );
      case TierNameStyle.shimmer:
        // Silver shimmer — pakai ShaderMask dengan gradient silver
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFFB0BEC5),
              Colors.white,
              Color(0xFFB0BEC5),
              Color(0xFF78909C),
            ],
            stops: [0.0, 0.4, 0.7, 1.0],
          ).createShader(bounds),
          child: Text(
            tier.name,
            style: TextStyle(
              color: Colors.white, // warna di-override oleh ShaderMask
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
            ),
          ),
        );
      case TierNameStyle.rainbow:
        // Rainbow gradient — Cosmic Weebu
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFFFF6B6B), // merah
              Color(0xFFFFD93D), // kuning
              Color(0xFF6BCB77), // hijau
              Color(0xFF4D96FF), // biru
              Color(0xFFCC5DE8), // ungu
            ],
          ).createShader(bounds),
          child: Text(
            tier.name,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
            ),
          ),
        );
    }
  }
}
