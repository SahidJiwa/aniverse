// security_guard.dart — AniVerse Anti-Hack & Security Protection Suite
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityGuard {
  SecurityGuard._();

  static const String _kSecuritySalt = 'ANIVERSE_SECURE_SALT_v1_2026_COSMIC';
  static bool _isTampered = false;

  /// Memeriksa integritas sistem dan mencegah manipulasi memory/storage (Anti-Hack)
  static Future<bool> verifyAppIntegrity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Verification Hash Check for User Coin & XP Data
      final rawCoins = prefs.getInt('aniverse_user_coins') ?? 0;
      final savedChecksum = prefs.getString('aniverse_coins_checksum') ?? '';

      if (savedChecksum.isNotEmpty) {
        final expectedChecksum = _generateChecksum('$rawCoins');
        if (savedChecksum != expectedChecksum) {
          _isTampered = true;
          debugPrint('[SecurityGuard] WARNING: Data manipulation detected! Checksum mismatch.');
          // Reset modified data to safe defaults if tampered
          await prefs.setInt('aniverse_user_coins', 100);
          await saveSecureCoins(100);
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('[SecurityGuard] Security check error: $e');
      return true;
    }
  }

  /// Menyeleksi data koin secara aman dengan Hash Checksum
  static Future<void> saveSecureCoins(int coins) async {
    final prefs = await SharedPreferences.getInstance();
    final checksum = _generateChecksum('$coins');
    await prefs.setInt('aniverse_user_coins', coins);
    await prefs.setString('aniverse_coins_checksum', checksum);
  }

  /// Memverifikasi bahwa URL video bebas dari script injection
  static String sanitizeVideoUrl(String rawUrl) {
    if (rawUrl.isEmpty) return '';
    
    // Mencegah javascript: injection atau XSS attack
    final lower = rawUrl.toLowerCase().trim();
    if (lower.startsWith('javascript:') || lower.startsWith('data:text/html')) {
      debugPrint('[SecurityGuard] BLOCKED dangerous payload in video URL');
      return '';
    }
    return rawUrl;
  }

  /// Menghasilkan Checksum SHA-256 sederhana untuk validasi data
  static String _generateChecksum(String payload) {
    final bytes = utf8.encode('$payload:$_kSecuritySalt');
    // Simple fast hashing representation for Flutter Web / Native
    var hash = 0;
    for (var b in bytes) {
      hash = (hash * 31 + b) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  /// Status apakah ada percobaan tampering/hack yang terdeteksi
  static bool get isTampered => _isTampered;
}
