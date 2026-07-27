// notification_service.dart — AniVerse
// Wraps flutter_local_notifications to schedule EXACT-time reminders for
// anime releases. Kept as its own file (rather than folded into
// jadwal_screen.dart) so it can be initialized once from main() and reused
// by any screen, not just Jadwal.
//
// SETUP REQUIRED BEFORE THIS COMPILES/RUNS — see the bottom of this file
// for the full checklist (pubspec deps, AndroidManifest permissions,
// main() wiring). Read that before wiring this into jadwal_screen.dart.

import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Call once, early in main() — see setup checklist at the bottom of this
  /// file. Safe to call multiple times; subsequent calls are no-ops.
  static Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    // Falls back to the device's local timezone. If your users are all in
    // one region (this app's anime schedule is in WIB/Indonesia time), you
    // can hardcode tz.setLocalLocation(tz.getLocation('Asia/Jakarta'))
    // instead — that avoids relying on the OS timezone database being
    // correctly configured on every device, at the cost of always
    // scheduling in WIB even if a user is traveling abroad.
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false, // requested explicitly below instead
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// Requests the OS permissions needed for exact-time notifications.
  /// Returns true if the app can schedule EXACT alarms; false means the
  /// caller should either fall back to approximate scheduling or tell the
  /// user reminders won't be precise.
  ///
  /// Two distinct permissions are involved on Android:
  ///   1. POST_NOTIFICATIONS (Android 13+) — without this, no notification
  ///      shows at all, exact or not.
  ///   2. SCHEDULE_EXACT_ALARM (Android 12+) — without this, exact-time
  ///      alarms silently degrade to inexact (can fire late by 10+ minutes)
  ///      rather than throwing an error, so it's easy to miss this is even
  ///      needed until someone notices reminders arriving late.
  static Future<bool> requestPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    if (Platform.isIOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }

    // Android from here on.
    final notifStatus = await Permission.notification.request();
    if (!notifStatus.isGranted) return false;

    // SCHEDULE_EXACT_ALARM only exists as a concept from API 31+; on older
    // OS versions permission_handler's exactAlarm check effectively no-ops
    // (returns granted), so this call is safe to make unconditionally
    // rather than branching on SDK version here.
    final exactStatus = await Permission.scheduleExactAlarm.request();
    return exactStatus.isGranted;
  }

  /// Schedules a single exact-time reminder for [animeId] at
  /// [episodeAirsAt] minus a short lead time (default 10 minutes before —
  /// enough notice to actually get to a screen without being so early the
  /// reminder feels disconnected from the event).
  ///
  /// Silently does nothing if the target time (after subtracting lead time)
  /// has already passed — flutter_local_notifications throws if you try to
  /// schedule a notification in the past, and a caller toggling a reminder
  /// for an episode that's already airing shouldn't crash the app over it.
  static Future<void> scheduleReminder({
    required String animeId,
    required String animeTitle,
    required DateTime episodeAirsAt,
    Duration leadTime = const Duration(minutes: 10),
  }) async {
    if (!_initialized) await init();

    final fireAt = episodeAirsAt.subtract(leadTime);
    final scheduledTz = tz.TZDateTime.from(fireAt, tz.local);
    if (scheduledTz.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    await _plugin.zonedSchedule(
      _notificationIdFor(animeId),
      'Segera tayang: $animeTitle',
      leadTime.inMinutes > 0
          ? 'Episode baru tayang ${leadTime.inMinutes} menit lagi'
          : 'Episode baru tayang sekarang',
      scheduledTz,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'jadwal_reminders',
          'Pengingat Jadwal Rilis',
          channelDescription: 'Notifikasi episode anime yang akan tayang',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancels any pending reminder for [animeId]. Safe to call even if none
  /// was ever scheduled.
  static Future<void> cancelReminder(String animeId) async {
    if (!_initialized) await init();
    await _plugin.cancel(_notificationIdFor(animeId));
  }

  /// Deterministic small-int notification ID derived from the anime ID
  /// string. flutter_local_notifications requires a 32-bit int ID, and
  /// AnimeModel IDs may be arbitrary strings, so this hashes down rather
  /// than assuming the ID is already numeric.
  static int _notificationIdFor(String animeId) =>
      animeId.hashCode & 0x7FFFFFFF;
}

// ─────────────────────────────────────────────────────────────────────────
// SETUP CHECKLIST — do these BEFORE wiring NotificationService calls into
// jadwal_screen.dart, or the app will fail to build/run.
//
// 1. pubspec.yaml — already added for you:
//      flutter_local_notifications: ^18.0.1
//      timezone: ^0.9.4
//      permission_handler: ^11.3.1
//    Run `flutter pub get` after applying the updated pubspec.yaml.
//
// 2. android/app/src/main/AndroidManifest.xml — add INSIDE <manifest>,
//    as siblings of the existing <uses-permission android:name=
//    "android.permission.INTERNET"/> line you already have:
//
//      <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
//      <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
//      <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
//      <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
//
//    RECEIVE_BOOT_COMPLETED matters because Android clears all scheduled
//    exact alarms on device reboot — without this permission (and the
//    plugin's built-in boot receiver, which flutter_local_notifications
//    registers automatically once this permission is present), every
//    reminder silently vanishes the next time the user restarts their
//    phone, with no visible error anywhere.
//
// 3. android/app/build.gradle (or build.gradle.kts) — check
//    minSdkVersion / minSdk. flutter_local_notifications 18.x requires
//    minSdk 21+, which is almost certainly already satisfied, but
//    confirm compileSdkVersion / compileSdk is 34+ (needed for the
//    POST_NOTIFICATIONS permission constant to resolve at compile time).
//    Since you weren't sure of your current SDK versions, this is the one
//    most likely to need a bump.
//
// 4. main.dart — call this before runApp():
//
//      void main() async {
//        WidgetsFlutterBinding.ensureInitialized();
//        await NotificationService.init();
//        runApp(const MyApp());
//      }
//
// 5. Requesting permission — call NotificationService.requestPermissions()
//    once, at a point where it makes sense to ask (e.g. the first time the
//    user taps ANY reminder bell, not on app launch — asking for
//    notification permission before the user has expressed any interest
//    in reminders is a common cause of users reflexively denying it).
//
// Once all 5 are done, ReminderService.toggle() in jadwal_screen.dart can
// call NotificationService.scheduleReminder(...) / .cancelReminder(...) in
// its onToggle callback. That wiring is NOT done automatically by adding
// this file — see the follow-up edit to jadwal_screen.dart.
// ─────────────────────────────────────────────────────────────────────────
