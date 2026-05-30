import 'package:flutter/material.dart';
import 'app_theme.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Your Library"),
          bottom: const TabBar(
            indicatorColor: AppTheme.sakuraPink,
            tabs: [
              Tab(text: "Watchlist"),
              Tab(text: "Favorites"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildEmptyState("Your watchlist is empty"),
            _buildEmptyState("No favorites yet"),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.movie_filter, size: 64, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
        ],
      ),
    );
  }
}