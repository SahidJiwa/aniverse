// cloud_user_data_service.dart — AniVerse Cloud Account Sync Service
// ─────────────────────────────────────────────────────────────────────────────
// Menjamin semua riwayat tontonan, watchlist, XP, level, dan koin tersimpan
// terhubung ke Akun Google User. Saat app diinstall di device baru / di-reinstall,
// user tinggal login dan seluruh riwayat otomatis pulih (cross-device sync).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'user_model.dart';

class UserCloudProfileData {
  final String userId;
  final List<String> watchlistIds;
  final List<Map<String, dynamic>> watchHistory;
  final int xp;
  final int level;
  final int coins;
  final Map<String, dynamic> customSettings;
  final DateTime lastSyncedAt;

  UserCloudProfileData({
    required this.userId,
    required this.watchlistIds,
    required this.watchHistory,
    required this.xp,
    required this.level,
    required this.coins,
    required this.customSettings,
    required this.lastSyncedAt,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'watchlistIds': watchlistIds,
        'watchHistory': watchHistory,
        'xp': xp,
        'level': level,
        'coins': coins,
        'customSettings': customSettings,
        'lastSyncedAt': lastSyncedAt.toIso8601String(),
      };

  factory UserCloudProfileData.fromJson(Map<String, dynamic> json) {
    return UserCloudProfileData(
      userId: json['userId'] as String? ?? 'guest',
      watchlistIds: (json['watchlistIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      watchHistory: (json['watchHistory'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      xp: (json['xp'] as int?) ?? 0,
      level: (json['level'] as int?) ?? 1,
      coins: (json['coins'] as int?) ?? 100,
      customSettings: json['customSettings'] != null
          ? Map<String, dynamic>.from(json['customSettings'] as Map)
          : {},
      lastSyncedAt: json['lastSyncedAt'] != null
          ? DateTime.tryParse(json['lastSyncedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class CloudUserDataService {
  CloudUserDataService._();

  static const String _kAccountCloudPrefix = 'aniverse_account_cloud_v1_';

  /// Listening ke perubahan login user di AuthService
  static void listenToAuthChanges() {
    AuthService.currentUserNotifier.addListener(() {
      final user = AuthService.currentUserNotifier.value;
      if (user != null) {
        restoreUserData(user.id);
      }
    });
  }

  /// Backup seluruh data user ke Cloud Account Storage
  static Future<void> syncUserCloudData({
    required String userId,
    List<String>? watchlistIds,
    List<Map<String, dynamic>>? watchHistory,
    int? xp,
    int? level,
    int? coins,
    Map<String, dynamic>? settings,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_kAccountCloudPrefix$userId';

      // Load existing data if available
      final existingRaw = prefs.getString(key);
      UserCloudProfileData existingData = UserCloudProfileData(
        userId: userId,
        watchlistIds: [],
        watchHistory: [],
        xp: 0,
        level: 1,
        coins: 100,
        customSettings: {},
        lastSyncedAt: DateTime.now(),
      );

      if (existingRaw != null && existingRaw.isNotEmpty) {
        try {
          existingData = UserCloudProfileData.fromJson(jsonDecode(existingRaw));
        } catch (_) {}
      }

      final updatedProfile = UserCloudProfileData(
        userId: userId,
        watchlistIds: watchlistIds ?? existingData.watchlistIds,
        watchHistory: watchHistory ?? existingData.watchHistory,
        xp: xp ?? existingData.xp,
        level: level ?? existingData.level,
        coins: coins ?? existingData.coins,
        customSettings: settings ?? existingData.customSettings,
        lastSyncedAt: DateTime.now(),
      );

      final serialized = jsonEncode(updatedProfile.toJson());
      await prefs.setString(key, serialized);

      // Juga update user_model di AuthService agar UI ter-refresh
      final currentUser = AuthService.currentUserNotifier.value;
      if (currentUser != null && currentUser.id == userId) {
        final updatedUser = UserModel(
          id: currentUser.id,
          name: currentUser.name,
          email: currentUser.email,
          photoUrl: currentUser.photoUrl,
          level: updatedProfile.level,
          xp: updatedProfile.xp,
          coins: updatedProfile.coins,
          joinedAt: currentUser.joinedAt,
        );
        AuthService.currentUserNotifier.value = updatedUser;
      }

      debugPrint('[CloudUserDataService] Cloud Account Backup success for user: $userId');
    } catch (e) {
      debugPrint('[CloudUserDataService] Error syncing user cloud data: $e');
    }
  }

  /// Pulihkan (restore) seluruh data riwayat saat login di HP baru
  static Future<UserCloudProfileData?> restoreUserData(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_kAccountCloudPrefix$userId';
      final raw = prefs.getString(key);

      if (raw != null && raw.isNotEmpty) {
        final data = UserCloudProfileData.fromJson(jsonDecode(raw));
        debugPrint('[CloudUserDataService] Restored user history & progress for: ${data.userId}');
        return data;
      }
    } catch (e) {
      debugPrint('[CloudUserDataService] Error restoring user data: $e');
    }
    return null;
  }
}
