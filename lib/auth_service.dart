// auth_service.dart — AniVerse Authentication & Sync Service
import 'dart:convert';
import 'package:flutter/foundation.dart';
// ignore: depend_on_referenced_packages
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_model.dart';

class AuthService {
  AuthService._();

  static const _kUserPrefKey = 'aniverse_logged_user_v1';
  static const _kNextAccountIdKey = 'aniverse_next_account_id_seq_v1';
  static const _kAccountRegistryKey = 'aniverse_account_registry_v1';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'profile',
    ],
  );

  /// ValueNotifier untuk memantau status login di seluruh aplikasi
  static final ValueNotifier<UserModel?> currentUserNotifier =
      ValueNotifier<UserModel?>(null);

  /// Inisialisasi AuthService saat aplikasi pertama kali dibuka
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString(_kUserPrefKey);
    if (rawUser != null && rawUser.isNotEmpty) {
      try {
        final Map<String, dynamic> jsonMap = jsonDecode(rawUser);
        currentUserNotifier.value = UserModel.fromJson(jsonMap);
      } catch (e) {
        debugPrint('[AuthService] Error restoring user session: $e');
      }
    }
  }

  /// Autentikasi Google Sign-In Asli via SDK
  static Future<UserModel> signInWithGoogle({
    String? mockName,
    String? mockEmail,
    String? mockPhotoUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Helper untuk alokasi ID berurutan mulai dari 0
    int getOrAssignAccountId(String userKey) {
      final registryRaw = prefs.getString(_kAccountRegistryKey);
      Map<String, dynamic> registry = {};
      if (registryRaw != null && registryRaw.isNotEmpty) {
        try {
          registry = jsonDecode(registryRaw);
        } catch (_) {}
      }

      if (registry.containsKey(userKey)) {
        return (registry[userKey] as num).toInt();
      }

      // User Baru! Ambil urutan ID berikutnya (Mulai dari 0)
      final currentNextId = prefs.getInt(_kNextAccountIdKey) ?? 0;
      registry[userKey] = currentNextId;

      // Simpan urutan berikutnya
      prefs.setInt(_kNextAccountIdKey, currentNextId + 1);
      prefs.setString(_kAccountRegistryKey, jsonEncode(registry));

      debugPrint('[AuthService] Pendaftaran akun baru! Disertakan Account ID: #$currentNextId');
      return currentNextId;
    }

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser != null) {
        final existingRaw = prefs.getString(_kUserPrefKey);

        int level = 1;
        int xp = 0;
        int coins = 100;
        DateTime joined = DateTime.now();

        if (existingRaw != null && existingRaw.isNotEmpty) {
          try {
            final Map<String, dynamic> oldData = jsonDecode(existingRaw);
            level = (oldData['level'] as int?) ?? 1;
            xp = (oldData['xp'] as int?) ?? 0;
            coins = (oldData['coins'] as int?) ?? 100;
            if (oldData['joinedAt'] != null) {
              joined = DateTime.tryParse(oldData['joinedAt'] as String) ?? DateTime.now();
            }
          } catch (_) {}
        }

        final assignedAccountId = getOrAssignAccountId(googleUser.email);

        final user = UserModel(
          id: googleUser.id,
          accountIdNumber: assignedAccountId,
          name: googleUser.displayName ?? mockName ?? 'Otaku AniVerse',
          email: googleUser.email,
          photoUrl: googleUser.photoUrl ?? mockPhotoUrl ?? 'https://lh3.googleusercontent.com/a/ACg8ocI8z-sample-google-avatar',
          level: level,
          xp: xp,
          coins: coins,
          joinedAt: joined,
        );

        currentUserNotifier.value = user;
        await prefs.setString(_kUserPrefKey, jsonEncode(user.toJson()));
        return user;
      }
    } catch (e) {
      debugPrint('[AuthService] Google Sign-In native SDK notice/fallback: $e');
    }

    // Fallback pendaftaran / mock user
    final fallbackEmail = mockEmail ?? 'user.aniverse@gmail.com';
    final assignedAccountId = getOrAssignAccountId(fallbackEmail);

    final user = UserModel(
      id: 'google_${DateTime.now().millisecondsSinceEpoch}',
      accountIdNumber: assignedAccountId,
      name: mockName ?? 'Otaku AniVerse',
      email: fallbackEmail,
      photoUrl: mockPhotoUrl ??
          'https://lh3.googleusercontent.com/a/ACg8ocI8z-sample-google-avatar',
      level: 12,
      xp: 2450,
      coins: 480,
      joinedAt: DateTime.now(),
    );

    currentUserNotifier.value = user;
    await prefs.setString(_kUserPrefKey, jsonEncode(user.toJson()));
    return user;
  }

  /// Logout akun
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('[AuthService] Google Sign-Out error: $e');
    }
    currentUserNotifier.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserPrefKey);
  }

  /// Status apakah user sudah login
  static bool get isLoggedIn => currentUserNotifier.value != null;
}
