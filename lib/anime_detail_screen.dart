import 'package:flutter/material.dart';
import 'anime_model.dart';
import 'app_theme.dart';
import 'mock_data_service.dart';
import 'watch_screen.dart';

class AnimeDetailScreen extends StatelessWidget {
  final AnimeModel anime;

  const AnimeDetailScreen({super.key, required this.anime});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 450,
            pinned: true,
            stretch: true,
            backgroundColor: AppTheme.backgroundDark,
            // ── Action buttons in AppBar ──────────────────────────────────
            actions: [
              _FavoriteButton(anime: anime),
              _WatchlistButton(anime: anime),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'anime-hero-${anime.id}',
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppTheme.backgroundDark.withValues(alpha: 0.7),
                        AppTheme.backgroundDark,
                      ],
                    ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
                  },
                  blendMode: BlendMode.dstIn,
                  child: Image.network(
                    anime.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          anime.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildRatingBadge(anime.rating),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildChip(anime.genre, isAccent: true),
                      _buildChip('${anime.episodes.length} Episodes'),
                      _buildChip('HD'),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Synopsis',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.sakuraPink,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    anime.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Watch Now button ──────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: anime.episodes.isEmpty
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => WatchScreen(
                                    anime: anime,
                                    initialEpisodeIndex: 0,
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(Icons.play_arrow_rounded, size: 28),
                      label: const Text(
                        'Watch Now',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.sakuraPink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Secondary action row ──────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _SecondaryActionButton(
                          anime: anime,
                          notifier: MockDataService.libraryNotifier,
                          isActiveCheck: MockDataService.isInWatchlist,
                          onToggle: MockDataService.toggleWatchlist,
                          activeIcon: Icons.bookmark,
                          inactiveIcon: Icons.bookmark_outline,
                          label: 'Watchlist',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SecondaryActionButton(
                          anime: anime,
                          notifier: MockDataService.favoritesNotifier,
                          isActiveCheck: MockDataService.isFavorite,
                          onToggle: MockDataService.toggleFavorite,
                          activeIcon: Icons.favorite,
                          inactiveIcon: Icons.favorite_outline,
                          label: 'Favorite',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // ── Episode list ──────────────────────────────────────────
                  if (anime.episodes.isNotEmpty) ...[
                    Text(
                      'Episodes',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.sakuraPink,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: anime.episodes.length,
                      separatorBuilder: (_, __) => Divider(
                        color: Colors.white.withValues(alpha: 0.06),
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final ep = anime.episodes[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              ep.thumbnailUrl,
                              width: 80,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 80,
                                height: 50,
                                color: AppTheme.surfaceDark,
                                child: const Icon(Icons.movie_outlined,
                                    color: Colors.white24, size: 20),
                              ),
                            ),
                          ),
                          title: Text(
                            ep.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            ep.duration,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 11),
                          ),
                          trailing: const Icon(Icons.play_circle_outline,
                              color: AppTheme.sakuraPink),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => WatchScreen(
                                  anime: anime,
                                  initialEpisodeIndex: index,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBadge(double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
          const SizedBox(width: 4),
          Text(
            rating.toString(),
            style: const TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, {bool isAccent = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isAccent
            ? AppTheme.sakuraPink.withValues(alpha: 0.15)
            : AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAccent
              ? AppTheme.sakuraPink.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isAccent ? AppTheme.sakuraPink : Colors.white70,
          fontSize: 12,
          fontWeight: isAccent ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

// ── AppBar icon buttons (Favorite & Watchlist) ────────────────────────────────

class _FavoriteButton extends StatelessWidget {
  final AnimeModel anime;
  const _FavoriteButton({required this.anime});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<AnimeModel>>(
      valueListenable: MockDataService.favoritesNotifier,
      builder: (context, list, _) {
        final active = list.any((a) => a.id == anime.id);
        return IconButton(
          tooltip: active ? 'Remove from Favorites' : 'Add to Favorites',
          icon: Icon(
            active ? Icons.favorite : Icons.favorite_outline,
            color: active ? AppTheme.sakuraPink : Colors.white,
          ),
          onPressed: () {
            MockDataService.toggleFavorite(anime);
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(active
                    ? 'Removed from Favorites'
                    : 'Added to Favorites'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        );
      },
    );
  }
}

class _WatchlistButton extends StatelessWidget {
  final AnimeModel anime;
  const _WatchlistButton({required this.anime});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<AnimeModel>>(
      valueListenable: MockDataService.libraryNotifier,
      builder: (context, list, _) {
        final active = list.any((a) => a.id == anime.id);
        return IconButton(
          tooltip: active ? 'Remove from Watchlist' : 'Add to Watchlist',
          icon: Icon(
            active ? Icons.bookmark : Icons.bookmark_outline,
            color: active ? AppTheme.sakuraPink : Colors.white,
          ),
          onPressed: () {
            MockDataService.toggleWatchlist(anime);
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(active
                    ? 'Removed from Watchlist'
                    : 'Added to Watchlist'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        );
      },
    );
  }
}

// ── Secondary action button (inside body) ────────────────────────────────────

class _SecondaryActionButton extends StatelessWidget {
  final AnimeModel anime;
  final ValueNotifier<List<AnimeModel>> notifier;
  final bool Function(String id) isActiveCheck;
  final void Function(AnimeModel) onToggle;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;

  const _SecondaryActionButton({
    required this.anime,
    required this.notifier,
    required this.isActiveCheck,
    required this.onToggle,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<AnimeModel>>(
      valueListenable: notifier,
      builder: (context, _, __) {
        final active = isActiveCheck(anime.id);
        return OutlinedButton.icon(
          onPressed: () => onToggle(anime),
          icon: Icon(
            active ? activeIcon : inactiveIcon,
            size: 18,
            color: active ? AppTheme.sakuraPink : Colors.white60,
          ),
          label: Text(
            label,
            style: TextStyle(
              color: active ? AppTheme.sakuraPink : Colors.white60,
              fontSize: 13,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: active
                  ? AppTheme.sakuraPink.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.15),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
    );
  }
}
