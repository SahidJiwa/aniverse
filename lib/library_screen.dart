import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'mock_data_service.dart';
import 'anime_model.dart';
import 'anime_card.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Your Library'),
          bottom: const TabBar(
            indicatorColor: AppTheme.sakuraPink,
            labelColor: AppTheme.sakuraPink,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Watchlist'),
              Tab(text: 'Favorites'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AnimeListTab(
              notifier: MockDataService.libraryNotifier,
              emptyIcon: Icons.bookmark_outline,
              emptyMessage: 'Your watchlist is empty',
              emptySubtitle: 'Add anime from the detail page',
            ),
            _AnimeListTab(
              notifier: MockDataService.favoritesNotifier,
              emptyIcon: Icons.favorite_outline,
              emptyMessage: 'No favorites yet',
              emptySubtitle: 'Heart an anime to save it here',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable tab content ───────────────────────────────────────────────────────

class _AnimeListTab extends StatelessWidget {
  final ValueNotifier<List<AnimeModel>> notifier;
  final IconData emptyIcon;
  final String emptyMessage;
  final String emptySubtitle;

  const _AnimeListTab({
    required this.notifier,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<AnimeModel>>(
      valueListenable: notifier,
      builder: (context, list, _) {
        if (list.isEmpty) {
          return _EmptyState(
            icon: emptyIcon,
            message: emptyMessage,
            subtitle: emptySubtitle,
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.62,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) => AnimeCard(
            anime: list[index],
            width: double.infinity,
          ),
        );
      },
    );
  }
}

// ── Empty state widget ────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
