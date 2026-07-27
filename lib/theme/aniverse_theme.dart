import 'package:flutter/material.dart';

class AniVerseTheme {
  // --- Warna yang Disesuaikan untuk Nuansa "Shibli Gelap" yang Lebih Hangat ---
  static const Color background = Color(0xFF283232); // Deep Forest Night - lebih lembut, sedikit keabu-abuan
  static const Color surface = Color(0xFF384545);    // Muted Moss Green - permukaan yang lebih ramah
  static const Color surfaceElevated = Color(0xFF4C6060); // Ancient Stone Gray - menonjolkan elemen tanpa keras
  static const Color primary = Color(0xFFA5B8A8); // Lightened Moss - warna dasar yang menenangkan
  static const Color accent = Color(0xFFD99066); // Autumn Sunset Orange - lebih cerah, hangat, dan mengundang
  static const Color glow = Color(0xFFBF7A4E);    // Ember Warmth - cahaya yang lebih dalam dan alami
  static const Color highlight = Color(0xFFF0D08A); // Golden Whisper - highlight yang lembut dan elegan
  static const Color success = Color(0xFF709989); // Forest Whisper Green
  static const Color warning = Color(0xFFE6A700); // Goldenrod Warning - tetap efektif, sedikit lebih alami
  static const Color textPrimary = Color(0xFFEFEFEF); // Soft Moonlight - sangat lembut, mudah dibaca
  static const Color textSecondary = Color(0xFFC0C8C8); // Misty Gray - harmonis dengan latar belakang


  // Radius scale — dipakai di seluruh app (home_screen, library_screen,
  // jadwal_screen, dll). Sebelumnya radiusLg/radiusMd dipanggil di file ini
  // sendiri tapi tidak pernah didefinisikan, dan radiusXl dipanggil dari
  // screen lain — itu yang bikin "Undefined name" / "Member not found".
  static const double opacityLow = 0.1;
  static const double opacityMedium = 0.3;
  static const double opacityHigh = 0.5;

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusPill = 999;

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.18),
      blurRadius: 18,
      spreadRadius: -4,
      offset: const Offset(0, 8),
    ),
  ];

  // Background decoration for a subtle gradient effect
  static BoxDecoration get backgroundDecoration {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          background, // Starting with the base background color
          background.withOpacity(0.98), // Sedikit lebih transparan
          Color(0xFF1E2828), // Lebih gelap untuk kedalaman yang halus
        ],
        stops: const [0.0, 0.5, 1.0],
      ),
    );
  }

  // Soft glow shadow — dipakai di beberapa screen (mis. library_screen)
  // sebagai `AniVerseTheme.glowShadow(color, opacity)`. Mengembalikan satu
  // BoxShadow lembut dengan warna & intensitas yang bisa diatur, konsisten
  // dipakai sebagai pengganti shadow hitam polos di atas background gelap.
  static List<BoxShadow> glowShadow(Color color, [double opacity = 0.15]) {
    return [
      BoxShadow(
        color: color.withOpacity(opacity),
        blurRadius: 20,
        spreadRadius: -2,
        offset: const Offset(0, 8),
      ),
    ];
  }

  static TextTheme get darkTextTheme => TextTheme(
    headlineMedium: TextStyle(
      color: textPrimary,
      fontFamily: 'ShipporiMinchoB1', // Ghibli-style font
      fontSize: 28,
      fontWeight: FontWeight.w800,
      height: 1.08,
    ),
    titleLarge: TextStyle(
      color: textPrimary,
      fontFamily: 'ShipporiMinchoB1', // Ghibli-style font
      fontSize: 20,
      fontWeight: FontWeight.w800,
      height: 1.15,
    ),
    titleMedium: TextStyle(
      color: textPrimary,
      fontFamily: 'ShipporiMinchoB1', // Ghibli-style font
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
    bodyMedium: TextStyle(
      color: textSecondary,
      fontFamily: 'MPLUSRounded1c', // Ghibli-style font
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.35,
    ),
    labelLarge: TextStyle(
      color: textPrimary,
      fontFamily: 'MPLUSRounded1c', // Ghibli-style font
      fontSize: 14,
      fontWeight: FontWeight.w800,
    ),
  );

  static ThemeData get ghibliDarkTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark, // Changed to dark
      surface: surface,
      primary: primary,
      secondary: accent,
      background: background,
      onBackground: textPrimary,
      onSurface: textPrimary,
      onPrimary: textPrimary,
      onSecondary: textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark, // Changed to dark
      colorScheme: scheme,
      textTheme: darkTextTheme, // Use darkTextTheme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: textPrimary,
        titleTextStyle: darkTextTheme.titleLarge?.copyWith(color: textPrimary),
        iconTheme: IconThemeData(color: textPrimary),
        actionsIconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surfaceElevated,
        elevation: 4, // Sedikit tingkatkan elevasi untuk kedalaman
        shadowColor: glow.withOpacity(0.4), // Perkuat shadow glow
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background, // Changed to background
        elevation: 0,
        indicatorColor: accent.withOpacity(0.25), // Perkuat indikator
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? textPrimary
                : textSecondary,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceElevated,
        contentTextStyle: darkTextTheme.bodyMedium?.copyWith(color: textPrimary),
      ),
      // Add more theme properties as needed for a complete dark theme
    );
  }


  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: Color(0xFFF0F2F5), // Light Grayish Blue
      primary: Color(0xFF6B8F7F), // Harmonious Green
      secondary: Color(0xFFD48B5F), // Muted Terracotta
      background: Color(0xFFFFFFFF), // White
      onBackground: Color(0xFF2E3D3C), // Dark Forest Green
      onSurface: Color(0xFF2E3D3C), // Dark Forest Green
      onPrimary: Color(0xFFFFFFFF), // White
      onSecondary: Color(0xFFFFFFFF), // White
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: Color(0xFFFDFDFD), // Slightly off-white
      textTheme: TextTheme(
        headlineMedium: TextStyle(color: Color(0xFF2E3D3C), fontSize: 28, fontWeight: FontWeight.w800, height: 1.08),
        titleLarge: TextStyle(color: Color(0xFF2E3D3C), fontSize: 20, fontWeight: FontWeight.w800, height: 1.15),
        titleMedium: TextStyle(color: Color(0xFF2E3D3C), fontSize: 16, fontWeight: FontWeight.w700, height: 1.2),
        bodyMedium: TextStyle(color: Color(0xFF5A6F6E), fontSize: 13, fontWeight: FontWeight.w500, height: 1.35),
        labelLarge: TextStyle(color: Color(0xFF2E3D3C), fontSize: 14, fontWeight: FontWeight.w800),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: Color(0xFF2E3D3C),
        titleTextStyle: TextTheme(
          titleLarge: TextStyle(color: Color(0xFF2E3D3C)),
        ).titleLarge,
        iconTheme: IconThemeData(color: Color(0xFF2E3D3C)),
        actionsIconTheme: IconThemeData(color: Color(0xFF2E3D3C)),
      ),
      cardTheme: CardThemeData(
        color: Color(0xFFFFFFFF),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Color(0xFFFDFDFD),
        elevation: 0,
        indicatorColor: Color(0xFFD48B5F).withOpacity(0.18),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? Color(0xFF2E3D3C)
                : Color(0xFF5A6F6E),
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Color(0xFFFFFFFF),
        contentTextStyle: TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF2E3D3C)),
        ).bodyMedium,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ghibliDarkTheme;
  }
}
