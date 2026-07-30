// cloud_user_data_service.dart — AniVerse Cloud Account Sync Service
// ─────────────────────────────────────────────────────────────────────────────
// Menjamin semua riwayat tontonan, watchlist, XP, level, dan koin tersimpan
// terhubung ke Akun Google User, di Firestore — bukan cuma di device lokal.
// Saat app diinstall di device baru / di-reinstall, user tinggal login dan
// seluruh riwayat otomatis pulih (real cross-device sync).
//
// SharedPreferences di sini HANYA dipakai sebagai cache offline: biar UI
// tetap tampil sesuatu saat tidak ada koneksi. Firestore adalah source of
// truth begitu sudah pernah berhasil terhubung.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  static const String _kProfilesCollection = 'user_profiles';

  static StreamSubscription<DocumentSnapshot>? _profileSub;
  static String? _listeningUserId;

  /// Listening ke perubahan login user di AuthService. Setiap kali user
  /// login/ganti akun, langsung attach realtime Firestore listener untuk
  /// profile data mereka — jadi XP/koin/history yang berubah dari device
  /// lain terpantul otomatis ke sini juga.
  static void listenToAuthChanges() {
    AuthService.currentUserNotifier.addListener(() {
      final user = AuthService.currentUserNotifier.value;
      if (user != null) {
        _attachProfileListener(user.id);
      } else {
        _profileSub?.cancel();
        _listeningUserId = null;
      }
    });
    // Also attach immediately if a user is already logged in.
    final user = AuthService.currentUserNotifier.value;
    if (user != null) _attachProfileListener(user.id);
  }

  static void _attachProfileListener(String userId) {
    if (_listeningUserId == userId) return; // already listening
    _profileSub?.cancel();
    _listeningUserId = userId;

    _profileSub = FirebaseFirestore.instance
        .collection(_kProfilesCollection)
        .doc(userId)
        .snapshots()
        .listen((snap) async {
      if (!snap.exists || snap.data() == null) return;
      try {
        final data = UserCloudProfileData.fromJson(snap.data()!);
        await _cacheLocally(data);

        // Reflect xp/level/coins into the live UserModel so the whole app
        // (profile, vault, etc.) sees updates immediately.
        final currentUser = AuthService.currentUserNotifier.value;
        if (currentUser != null && currentUser.id == userId) {
          AuthService.currentUserNotifier.value = UserModel(
            id: currentUser.id,
            accountIdNumber: currentUser.accountIdNumber,
            name: currentUser.name,
            email: currentUser.email,
            photoUrl: currentUser.photoUrl,
            level: data.level,
            xp: data.xp,
            coins: data.coins,
            joinedAt: currentUser.joinedAt,
          );
        }
      } catch (e) {
        debugPrint('[CloudUserDataService] Error parsing Firestore profile snapshot: $e');
      }
    }, onError: (e) {
      debugPrint('[CloudUserDataService] Firestore profile listen error (using local cache): $e');
    });
  }

  /// Backup seluruh data user ke Firestore. Falls back to local-only save
  /// if offline/write fails, so nothing is lost — it just won't be visible
  /// on other devices until the next successful sync.
  static Future<void> syncUserCloudData({
    required String userId,
    List<String>? watchlistIds,
    List<Map<String, dynamic>>? watchHistory,
    int? xp,
    int? level,
    int? coins,
    Map<String, dynamic>? settings,
  }) async {
    // Merge with whatever we currently know (local cache first, since it's
    // fast and always available) so partial updates don't wipe other
    // fields.
    final existingData = await _loadLocalCache(userId) ??
        UserCloudProfileData(
          userId: userId,
          watchlistIds: [],
          watchHistory: [],
          xp: 0,
          level: 1,
          coins: 100,
          customSettings: {},
          lastSyncedAt: DateTime.now(),
        );

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

    // Always cache locally first — instant, and a safety net if the
    // Firestore write below fails.
    await _cacheLocally(updatedProfile);

    try {
      await FirebaseFirestore.instance
          .collection(_kProfilesCollection)
          .doc(userId)
          .set(updatedProfile.toJson(), SetOptions(merge: true));

      // Keep the live UserModel in sync for immediate UI feedback.
      final currentUser = AuthService.currentUserNotifier.value;
      if (currentUser != null && currentUser.id == userId) {
        AuthService.currentUserNotifier.value = UserModel(
          id: currentUser.id,
          accountIdNumber: currentUser.accountIdNumber,
          name: currentUser.name,
          email: currentUser.email,
          photoUrl: currentUser.photoUrl,
          level: updatedProfile.level,
          xp: updatedProfile.xp,
          coins: updatedProfile.coins,
          joinedAt: currentUser.joinedAt,
        );
      }

      debugPrint('[CloudUserDataService] Firestore sync success for user: $userId');
    } catch (e) {
      debugPrint('[CloudUserDataService] Firestore write failed, kept in local cache only: $e');
    }
  }

  /// Pulihkan (restore) seluruh data riwayat saat login di HP baru.
  /// Tries Firestore first (authoritative); falls back to local cache if
  /// offline.
  static Future<UserCloudProfileData?> restoreUserData(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_kProfilesCollection)
          .doc(userId)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = UserCloudProfileData.fromJson(doc.data()!);
        await _cacheLocally(data);
        debugPrint('[CloudUserDataService] Restored from Firestore for: ${data.userId}');
        return data;
      }
    } catch (e) {
      debugPrint('[CloudUserDataService] Firestore restore failed, trying local cache: $e');
    }

    // Offline fallback — better than nothing while waiting to reconnect.
    return _loadLocalCache(userId);
  }

  static Future<void> _cacheLocally(UserCloudProfileData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_kAccountCloudPrefix${data.userId}';
      await prefs.setString(key, jsonEncode(data.toJson()));
    } catch (e) {
      debugPrint('[CloudUserDataService] Local cache write error: $e');
    }
  }

  static Future<UserCloudProfileData?> _loadLocalCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_kAccountCloudPrefix$userId';
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        return UserCloudProfileData.fromJson(jsonDecode(raw));
      }
    } catch (e) {
      debugPrint('[CloudUserDataService] Local cache read error: $e');
    }
    return null;
  }
}
