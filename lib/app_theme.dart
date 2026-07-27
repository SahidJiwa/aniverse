import 'package:flutter/material.dart';
import 'theme/aniverse_theme.dart';

// AppTheme is a thin passthrough over AniVerseTheme — the single source of
// truth for every color/radius in the app. Screens should ALWAYS reach for
// a name here (or add a new one to AniVerseTheme first) instead of writing
// a raw Color(0xFF...) hex value inline. That's the one rule that makes
// "edit aniverse_theme.dart once, every screen updates" actually true —
// without it, screens drift back into hardcoded hex the moment someone
// needs a color that isn't exposed here yet.
class AppTheme {
  // ── Core palette — every AniVerseTheme color, not just 3 of them ──────────
  static const Color background = AniVerseTheme.background;
  static const Color surface = AniVerseTheme.surface;
  static const Color surfaceElevated = AniVerseTheme.surfaceElevated;
  static const Color primary = AniVerseTheme.primary;
  static const Color accent = AniVerseTheme.accent;
  static const Color glow = AniVerseTheme.glow;
  static const Color highlight = AniVerseTheme.highlight;
  static const Color success = AniVerseTheme.success;
  static const Color warning = AniVerseTheme.warning;
  static const Color textPrimary = AniVerseTheme.textPrimary;
  static const Color textSecondary = AniVerseTheme.textSecondary;

  static const Color sage = AniVerseTheme.primary;
  static const Color terracotta = AniVerseTheme.accent;
  static const Color surfaceRaised = AniVerseTheme.surfaceElevated;
  static const Color border = AniVerseTheme.textSecondary;

  // ── Legacy aliases — kept so existing call sites (AppTheme.sakuraPink,
  // .backgroundDark, .surfaceDark) don't break while screens get migrated
  // off hardcoded hex over time. New code should prefer the names above
  // (or add a properly-named color to AniVerseTheme) over these aliases.
  static const Color sakuraPink = AniVerseTheme.highlight;
  static const Color backgroundDark = AniVerseTheme.background;
  static const Color surfaceDark = AniVerseTheme.surface;

  // ── Radius scale ──────────────────────────────────────────────────────────
  static const double radiusSm = AniVerseTheme.radiusSm;
  static const double radiusMd = AniVerseTheme.radiusMd;
  static const double radiusLg = AniVerseTheme.radiusLg;
  static const double radiusXl = AniVerseTheme.radiusXl;
  static const double radiusPill = AniVerseTheme.radiusPill;

  // ── Shared helpers ────────────────────────────────────────────────────────
  static List<BoxShadow> glowShadow(Color color, [double opacity = 0.15]) =>
      AniVerseTheme.glowShadow(color, opacity);

  static ThemeData get darkTheme => AniVerseTheme.darkTheme;
  static ThemeData get lightTheme => AniVerseTheme.lightTheme;
}
