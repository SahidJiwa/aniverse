import 'package:flutter/material.dart';
import 'anime_card.dart';
import 'anime_model.dart';
import 'continue_watching_model.dart';
import 'mock_data_service.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final allAnimes = MockDataService.getMockAnimes();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Library'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ValueListenableBuilder<List<ContinueWatchingModel>>(
            valueListenable: MockDataService.continueWatchingNotifier,
            builder: (context, list, _) {
              final mapped = list
                  .map((item) {
                    for (final anime in allAnimes) {
                      if (anime.id == item.animeId) return anime;
                    }
                    return null;
                  })
                  .whereType<AnimeModel>()
                  .toList();
              return _LibrarySection(
                title: 'Continue Watching',
                list: mapped,
                emptyIcon: Icons.play_circle_outline,
                emptyMessage: 'No continue watching items',
                emptySubtitle: 'Start watching an episode to see it here',
              );
            },
          ),
          ValueListenableBuilder<List<AnimeModel>>(
            valueListenable: MockDataService.recentlyWatchedNotifier,
            builder: (context, list, _) {
              return _LibrarySection(
                title: 'Recently Watched',
                list: list,
                emptyIcon: Icons.history,
                emptyMessage: 'No recently watched anime',
                emptySubtitle: 'Open an anime detail page to populate this section',
              );
            },
          ),
          ValueListenableBuilder<List<AnimeModel>>(
            valueListenable: MockDataService.libraryNotifier,
            builder: (context, list, _) {
              return _LibrarySection(
                title: 'Watchlist',
                list: list,
                emptyIcon: Icons.bookmark_outline,
                emptyMessage: 'Your watchlist is empty',
                emptySubtitle: 'Add anime from the detail page',
              );
            },
          ),
          ValueListenableBuilder<List<AnimeModel>>(
            valueListenable: MockDataService.favoritesNotifier,
            builder: (context, list, _) {
              return _LibrarySection(
                title: 'Favorites',
                list: list,
                emptyIcon: Icons.favorite_outline,
                emptyMessage: 'No favorites yet',
                emptySubtitle: 'Heart an anime to save it here',
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LibrarySection extends StatelessWidget {
  final String title;
  final List<AnimeModel> list;
  final IconData emptyIcon;
  final String emptyMessage;
  final String emptySubtitle;

  const _LibrarySection({
    required this.title,
    required this.list,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (list.isEmpty)
            _InlineEmptyState(
              icon: emptyIcon,
              message: emptyMessage,
              subtitle: emptySubtitle,
            )
          else
            SizedBox(
              height: 220,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                itemBuilder: (context, index) => AnimeCard(
                  anime: list[index],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subtitle;

  const _InlineEmptyState({
    required this.icon,
    required this.message,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.35), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
