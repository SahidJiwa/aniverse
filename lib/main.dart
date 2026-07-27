import 'dart:async';

import 'package:flutter/material.dart';
import 'package:aniverse/theme/aniverse_theme.dart';
import 'main_wrapper.dart';
import 'mock_data_service.dart';
import 'catalog_store.dart';
import 'notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // NotificationService.init() di-await (bukan unawaited) karena dia setup
  // timezone data + plugin channel — kalau belum selesai saat user tap
  // reminder bell, scheduleReminder() bisa gagal silent. Initnya ringan
  // (bukan I/O berat kayak SharedPreferences) jadi aman untuk nunggu.
  await NotificationService.init();
  // PERF: Do not await initialize() before runApp.
  // All notifiers default to [] so the UI renders correctly on frame 1.
  // SharedPreferences data populates via notifier callbacks ~30–80 ms later.
  unawaited(MockDataService.initialize());
  unawaited(CatalogStore.instance.init());
  runApp(const AniVerseApp());
}

class AniVerseApp extends StatelessWidget {
  const AniVerseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AniVerse',
      themeMode: ThemeMode.dark,
      darkTheme: AniVerseTheme.ghibliDarkTheme,
      home: const MainWrapper(),
    );
  }
}
