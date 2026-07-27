import 'package:flutter/material.dart';
import 'anime_api_service.dart';
import 'anime_card.dart';
import 'anime_model.dart';
import 'app_theme.dart';
import 'continue_watching_model.dart';
import 'episode_model.dart';
import 'mock_data_service.dart';
import 'watch_screen.dart';

class AnimeDetailScreen extends StatefulWidget {
  final AnimeModel anime;

  const AnimeDetailScreen({super.key, required this.anime});

  @override
  State<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends State<AnimeDetailScreen> {
  bool _recentlyWatchedQueued = false;
  late Future<JikanAnimeDetail> _detailFuture;
  late Future<List<EpisodeModel>> _episodesFuture;
  late Future<List<AnimeModel>> _recommendationsFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = AnimeApiService.fetchAnimeDetail(widget.anime.id);
    _episodesFuture = AnimeApiService.fetchAnimeEpisodes(widget.anime.id);
    _recommendationsFuture =
        AnimeApiService.fetchAnimeRecommendations(widget.anime.id);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_recentlyWatchedQueued) return;
    _recentlyWatchedQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      MockDataService.addRecentlyWatched(widget.anime);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<JikanAnimeDetail>(
      future: _detailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Anime Detail')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        color: Colors.white54, size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      'Failed to load anime detail.',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _detailFuture =
                              AnimeApiService.fetchAnimeDetail(widget.anime.id);
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final detail = snapshot.data!;
        final displayGenre =
            detail.genres.isEmpty ? widget.anime.genre : detail.genres.first;
        final displayEpisodes = detail.episodes ?? widget.anime.episodes.length;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 450,
                pinned: true,
                stretch: true,
                backgroundColor: AppTheme.backgroundDark,
                actions: [
                  _FavoriteButton(anime: widget.anime),
                  _WatchlistButton(anime: widget.anime),
                  const SizedBox(width: 4),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Hero(
                    tag: 'anime-hero-${widget.anime.id}',
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
                        detail.largeImageUrl,
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
                              detail.title,
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
                          _buildRatingBadge(detail.score),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildChip(displayGenre, isAccent: true),
                          _buildChip('$displayEpisodes Episodes'),
                          _buildChip(detail.status),
                          _buildChip(
                            detail.rank != null ? 'Rank #${detail.rank}' : 'Rank N/A',
                          ),
                        ],
                      ),
                      if (detail.genres.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: detail.genres
                              .map((g) => _buildChip(g))
                              .toList(),
                        ),
                      ],
                      if (detail.studios.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Studios: ${detail.studios.join(', ')}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 13,
                          ),
                        ),
                      ],
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
                        detail.synopsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Recommendations',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppTheme.sakuraPink,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<List<AnimeModel>>(
                        future: _recommendationsFuture,
                        builder: (context, recSnapshot) {
                          if (recSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          if (recSnapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                'Failed to load recommendations.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            );
                          }

                          final recs = recSnapshot.data ?? const [];
                          if (recs.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                'No recommendations available.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            );
                          }

                          return SizedBox(
                            height: 220,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: recs.length,
                              itemBuilder: (context, index) =>
                                  AnimeCard(anime: recs[index]),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: widget.anime.episodes.isEmpty
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => WatchScreen(
                                        anime: widget.anime,
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
                      Row(
                        children: [
                          Expanded(
                            child: _SecondaryActionButton(
                              anime: widget.anime,
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
                              anime: widget.anime,
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
                      FutureBuilder<List<EpisodeModel>>(
                        future: _episodesFuture,
                        builder: (context, episodeSnapshot) {
                          if (episodeSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          if (episodeSnapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              child: Center(
                                child: Text(
                                  'Failed to load episodes.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            );
                          }

                          final episodes = episodeSnapshot.data ?? const [];
                          if (episodes.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                          itemCount: episodes.length,
                          separatorBuilder: (_, _) => Divider(
                            color: Colors.white.withValues(alpha: 0.06),
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final ep = episodes[index];
                            return ValueListenableBuilder<Map<String, Set<int>>>(
                              valueListenable: MockDataService.watchedEpisodesNotifier,
                              builder: (context, watchedMap, _) {
                                return ValueListenableBuilder<List<ContinueWatchingModel>>(
                                  valueListenable: MockDataService.continueWatchingNotifier,
                                  builder: (context, _, _) {
                                    final continueItem = MockDataService
                                        .getContinueWatchingByAnimeId(widget.anime.id);
                                    final isCurrentContinueEpisode =
                                        continueItem != null &&
                                        continueItem.episodeNumber == ep.number &&
                                        continueItem.watchProgress > 0 &&
                                        continueItem.watchProgress < 0.9;
                                    final isWatched = MockDataService.isEpisodeWatched(
                                      animeId: widget.anime.id,
                                      episodeNumber: ep.number,
                                    );

                                    String subtitleText = ep.duration;
                                    if (isCurrentContinueEpisode) {
                                      final pct =
                                          (continueItem.watchProgress * 100).round();
                                      subtitleText = 'Continue $pct%';
                                    } else if (isWatched) {
                                      subtitleText = 'Watched';
                                    } else if (ep.airedDate != null) {
                                      subtitleText = ep.airedDate!;
                                    }

                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          ep.thumbnailUrl,
                                          width: 80,
                                          height: 50,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
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
                                        subtitleText,
                                        style: TextStyle(
                                          color: isWatched
                                              ? const Color(0xFF33D17A)
                                              : Colors.white.withValues(alpha: 0.4),
                                          fontSize: 11,
                                          fontWeight: isWatched
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                      trailing: Icon(
                                        isWatched
                                            ? Icons.check_circle_rounded
                                            : Icons.play_circle_outline,
                                        color: isWatched
                                            ? const Color(0xFF33D17A)
                                            : AppTheme.sakuraPink,
                                      ),
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => WatchScreen(
                                              anime: AnimeModel(
                                                id: widget.anime.id,
                                                title: widget.anime.title,
                                                imageUrl: widget.anime.imageUrl,
                                                rating: widget.anime.rating,
                                                genre: widget.anime.genre,
                                                description: widget.anime.description,
                                                isTrending: widget.anime.isTrending,
                                                episodes: episodes,
                                              ),
                                              initialEpisodeIndex: index,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 32),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
            rating.toStringAsFixed(1),
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
      builder: (context, _, _) {
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
