import 'package:flutter/material.dart';

class AppTheme {
  static const Color sakuraPink = Color(0xFFFF2D55);
  static const Color backgroundDark = Color(0xFF090414);
  static const Color surfaceDark = Color(0xFF1A1527);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: sakuraPink,
        brightness: Brightness.dark,
        surface: backgroundDark,
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}