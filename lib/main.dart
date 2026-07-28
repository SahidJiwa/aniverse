import 'dart:async';

import 'package:flutter/material.dart';
import 'package:aniverse/theme/aniverse_theme.dart';
import 'main_wrapper.dart';
import 'mock_data_service.dart';
import 'catalog_store.dart';
import 'notification_service.dart';
import 'security_guard.dart';
import 'auth_service.dart';
import 'cloud_user_data_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  unawaited(SecurityGuard.verifyAppIntegrity());
  unawaited(AuthService.init());
  CloudUserDataService.listenToAuthChanges();
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
