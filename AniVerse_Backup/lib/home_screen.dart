import 'package:flutter/material.dart';
import 'anime_api_service.dart';
import 'mock_data_service.dart';
import 'anime_card.dart';
import 'anime_model.dart';
import 'continue_watching_model.dart';
import 'section_title.dart';
import 'app_theme.dart';
import 'watch_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoadingTopAnime = true;
  List<AnimeModel> _topAnimes = const [];
  List<AnimeModel> _seasonalAnimes = const [];

  @override
  void initState() {
    super.initState();
    _loadTopAnime();
    _loadSeasonalAnime();
  }

  Future<void> _loadTopAnime() async {
    try {
      final animes = await AnimeApiService.fetchTopAnime();
      if (!mounted) return;
      setState(() {
        _topAnimes = animes;
        _isLoadingTopAnime = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _topAnimes = MockDataService.getMockAnimes();
        _isLoadingTopAnime = false;
      });
    }
  }

  Future<void> _loadSeasonalAnime() async {
    try {
      final animes = await AnimeApiService.fetchCurrentSeasonAnime();
      if (!mounted) return;
      setState(() {
        _seasonalAnimes = animes;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _seasonalAnimes = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final animes = _topAnimes.isEmpty
        ? MockDataService.getMockAnimes()
        : _topAnimes;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(animes[0].imageUrl, fit: BoxFit.cover),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppTheme.backgroundDark.withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isLoadingTopAnime)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        Text(
                          animes[0].title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.play_arrow),
                          label: const Text("Watch Now"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.sakuraPink,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                ValueListenableBuilder<List<AnimeModel>>(
                  valueListenable: MockDataService.recentlyWatchedNotifier,
                  builder: (context, recentlyWatched, _) {
                    if (recentlyWatched.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      children: [
                        const SectionTitle(title: 'Recently Watched'),
                        SizedBox(
                          height: 220,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            scrollDirection: Axis.horizontal,
                            itemCount: recentlyWatched.length,
                            itemBuilder: (context, index) =>
                                AnimeCard(anime: recentlyWatched[index]),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                ValueListenableBuilder<List<ContinueWatchingModel>>(
                  valueListenable: MockDataService.continueWatchingNotifier,
                  builder: (context, continueWatchingList, _) {
                    if (continueWatchingList.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      children: [
                        const SectionTitle(title: "Continue Watching"),
                        SizedBox(
                          height: 190,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            scrollDirection: Axis.horizontal,
                            itemCount: continueWatchingList.length,
                            itemBuilder: (context, index) {
                              final item = continueWatchingList[index];
                              final anime = animes.firstWhere(
                                (a) => a.id == item.animeId,
                                orElse: () {
                                  debugPrint(
                                    '[HomeScreen] continue watching anime not found id=${item.animeId}',
                                  );
                                  return animes.first;
                                },
                              );
                              debugPrint(
                                '[HomeScreen] found anime=${anime.title} '
                                'episodes=${anime.episodes.length} '
                                'cwEpisode=${item.episodeNumber}',
                              );
                              return _ContinueWatchingCard(
                                anime: anime,
                                continueWatching: item,
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SectionTitle(title: "Trending Now"),
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: animes.length,
                    itemBuilder: (context, index) =>
                        AnimeCard(anime: animes[index]),
                  ),
                ),
                const SectionTitle(title: "New Episodes"),
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: animes.reversed.length,
                    itemBuilder: (context, index) =>
                        AnimeCard(anime: animes.reversed.toList()[index]),
                  ),
                ),
                if (_seasonalAnimes.isNotEmpty) ...[
                  const SectionTitle(title: "Seasonal Anime"),
                  SizedBox(
                    height: 220,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: _seasonalAnimes.length,
                      itemBuilder: (context, index) =>
                          AnimeCard(anime: _seasonalAnimes[index]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueWatchingCard extends StatelessWidget {
  final AnimeModel anime;
  final ContinueWatchingModel continueWatching;

  const _ContinueWatchingCard({
    required this.anime,
    required this.continueWatching,
  });

  @override
  Widget build(BuildContext context) {
    final episodeIndex = (continueWatching.episodeNumber - 1).clamp(
      0,
      anime.episodes.isEmpty ? 0 : anime.episodes.length - 1,
    );
    final progress = continueWatching.watchProgress.clamp(0.0, 1.0);
    final percentage = (progress * 100).round();

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WatchScreen(
              anime: anime,
              initialEpisodeIndex: episodeIndex,
              initialWatchProgress: progress,
            ),
          ),
        );
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(12),
              ),
              child: Image.network(
                anime.imageUrl,
                width: 100,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      anime.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Episode ${continueWatching.episodeNumber}",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.sakuraPink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "$percentage%",
                      style: const TextStyle(
                        color: AppTheme.sakuraPink,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
