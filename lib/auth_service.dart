// auth_service.dart — AniVerse Authentication & Sync Service
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ignore: depend_on_referenced_packages
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_model.dart';
import 'cloud_user_data_service.dart';

/// Thrown when Google Sign-In genuinely fails or is cancelled by the user.
/// Callers (e.g. auth_modal.dart) should catch this and show a real error —
/// never silently fall back to a fake account.
class GoogleSignInFailure implements Exception {
  final String message;
  GoogleSignInFailure(this.message);
  @override
  String toString() => message;
}

class AuthService {
  AuthService._();

  static const _kUserPrefKey = 'aniverse_logged_user_v1';

  // Firestore: a single counter document guarantees accountIdNumber is
  // unique across ALL devices/users, not just per-device like the old
  // SharedPreferences-based registry (which caused every device to hand
  // out #0000 independently).
  static const _kCountersCollection = 'meta';
  static const _kAccountCounterDoc = 'account_id_counter';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'profile',
    ],
  );

  /// ValueNotifier untuk memantau status login di seluruh aplikasi
  static final ValueNotifier<UserModel?> currentUserNotifier =
      ValueNotifier<UserModel?>(null);

  /// Inisialisasi AuthService saat aplikasi pertama kali dibuka.
  /// Loads the last-known local session immediately for fast UI, then lets
  /// CloudUserDataService reconcile with Firestore in the background.
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

  /// Allocates the next sequential accountIdNumber atomically via a
  /// Firestore transaction, so two users signing up at the same moment on
  /// different devices can never receive the same number.
  static Future<int> _allocateAccountIdNumber() async {
    final counterRef = FirebaseFirestore.instance
        .collection(_kCountersCollection)
        .doc(_kAccountCounterDoc);

    return FirebaseFirestore.instance.runTransaction<int>((tx) async {
      final snap = await tx.get(counterRef);
      final current = (snap.data()?['next'] as num?)?.toInt() ?? 0;
      tx.set(counterRef, {'next': current + 1}, SetOptions(merge: true));
      return current;
    });
  }

  /// Autentikasi Google Sign-In. Throws [GoogleSignInFailure] if the user
  /// cancels or the SDK errors out — there is no mock/fake-user fallback,
  /// so a caller can never mistake a failed login for a successful one.
  static Future<UserModel> signInWithGoogle() async {
    GoogleSignInAccount? googleUser;
    try {
      googleUser = await _googleSignIn.signIn();
    } catch (e) {
      debugPrint('[AuthService] Google Sign-In SDK error: $e');
      throw GoogleSignInFailure('Login Google gagal: $e');
    }

    if (googleUser == null) {
      // User closed the Google account picker without choosing — this is
      // a genuine cancellation, not an error to paper over.
      throw GoogleSignInFailure('Login dibatalkan.');
    }

    final usersRef =
        FirebaseFirestore.instance.collection('users').doc(googleUser.id);

    try {
      final existingDoc = await usersRef.get();

      UserModel user;
      if (existingDoc.exists) {
        // Returning user — keep their existing progress, just refresh
        // profile fields that may have changed on the Google side.
        final data = existingDoc.data()!;
        final existing = UserModel.fromJson(data);
        user = UserModel(
          id: googleUser.id,
          accountIdNumber: existing.accountIdNumber,
          name: googleUser.displayName ?? existing.name,
          email: googleUser.email,
          photoUrl: googleUser.photoUrl ?? existing.photoUrl,
          level: existing.level,
          xp: existing.xp,
          coins: existing.coins,
          joinedAt: existing.joinedAt,
        );
        await usersRef.set(user.toJson(), SetOptions(merge: true));
      } else {
        // Brand new account — allocate a globally-unique sequential ID.
        final accountIdNumber = await _allocateAccountIdNumber();
        user = UserModel(
          id: googleUser.id,
          accountIdNumber: accountIdNumber,
          name: googleUser.displayName ?? 'Otaku AniVerse',
          email: googleUser.email,
          photoUrl: googleUser.photoUrl ?? '',
          level: 1,
          xp: 0,
          coins: 100,
          joinedAt: DateTime.now(),
        );
        await usersRef.set(user.toJson());
        debugPrint('[AuthService] Pendaftaran akun baru! Account ID: #$accountIdNumber');
      }

      currentUserNotifier.value = user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUserPrefKey, jsonEncode(user.toJson()));

      // Kick off realtime listener so XP/coins/level changes from other
      // devices reflect here live.
      CloudUserDataService.listenToAuthChanges();

      return user;
    } catch (e) {
      debugPrint('[AuthService] Firestore user sync error: $e');
      throw GoogleSignInFailure(
          'Login berhasil tapi gagal sinkron data: $e');
    }
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
