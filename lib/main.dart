import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'main_wrapper.dart';

void main() {
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