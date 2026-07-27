import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'main_wrapper.dart';
import 'mock_data_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MockDataService.initialize();
  runApp(const AniVerseApp());
}

class AniVerseApp extends StatelessWidget {
  const AniVerseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AniVerse',
      theme: AppTheme.darkTheme,
      home: const MainWrapper(),
    );
  }
}
