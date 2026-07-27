// library_screen.dart — AniVerse Premium Release: Koleksi Saya

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'anime_card.dart';
import 'anime_detail_screen.dart';
import 'anime_model.dart';
import 'app_theme.dart';
import 'continue_watching_model.dart';
import 'mock_data_service.dart';
import 'theme/aniverse_theme.dart';
import 'watch_screen.dart';
import 'widgets/dashboard_sections.dart';
import 'widgets/liquid_glass.dart';


class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

enum _SortMode { recentlyAdded, az, za, rating }

class _LibraryScreenState extends State<LibraryScreen> {
  bool _myListGridMode = false;
  _SortMode _sortMode = _SortMode.recentlyAdded;
  bool _isRefreshing = false;

  AnimeModel? _resolveAnimeById(String id) {
    for (final anime in MockDataService.getMockAnimes()) {
      if (anime.id == id) return anime;
    }
    for (final anime in MockDataService.recentlyWatchedNotifier.value) {
      if (anime.id == id) return anime;
    }
    for (final anime in MockDataService.libraryNotifier.value) {
      if (anime.id == id) return anime;
    }
    for (final anime in MockDataService.favoritesNotifier.value) {
      if (anime.id == id) return anime;
    }
    return null;
  }

  List<AnimeModel> _sortedList(List<AnimeModel> list) {
    final sorted = List<AnimeModel>.from(list);
    switch (_sortMode) {
      case _SortMode.recentlyAdded:
        break; // keep original order (most recent first from notifier)
      case _SortMode.az:
        sorted.sort((a, b) => a.title.compareTo(b.title));
      case _SortMode.za:
        sorted.sort((a, b) => b.title.compareTo(a.title));
      case _SortMode.rating:
        sorted.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return sorted;
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    // MockDataService doesn't need actual network — just simulate delay
    // then trigger a notifier ping so ValueListenableBuilders rebuild.
    await Future.delayed(const Duration(milliseconds: 900));
    // Re-assign same value to trigger rebuild
    MockDataService.libraryNotifier.value =
        List.from(MockDataService.libraryNotifier.value);
    MockDataService.favoritesNotifier.value =
        List.from(MockDataService.favoritesNotifier.value);
    MockDataService.recentlyWatchedNotifier.value =
        List.from(MockDataService.recentlyWatchedNotifier.value);
    if (mounted) setState(() => _isRefreshing = false);
  }

  String get _sortLabel {
    switch (_sortMode) {
      case _SortMode.recentlyAdded: return 'Terbaru';
      case _SortMode.az: return 'A–Z';
      case _SortMode.za: return 'Z–A';
      case _SortMode.rating: return 'Rating';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ValueListenableBuilder<List<AnimeModel>>(
        valueListenable: MockDataService.libraryNotifier,
        builder: (context, watchlist, _) {
          return ValueListenableBuilder<List<ContinueWatchingModel>>(
            valueListenable: MockDataService.continueWatchingNotifier,
            builder: (context, continueList, _) {
              return ValueListenableBuilder<List<AnimeModel>>(
                valueListenable: MockDataService.favoritesNotifier,
                builder: (context, favorites, _) {
                  return ValueListenableBuilder<List<AnimeModel>>(
                    valueListenable: MockDataService.recentlyWatchedNotifier,
                    builder: (context, recent, _) {
                      return ValueListenableBuilder<Map<String, Set<int>>>(
                        valueListenable: MockDataService.watchedEpisodesNotifier,
                        builder: (context, watchedEpisodesMap, _) {
                      final completedCount = continueList
                          .where((e) => e.watchProgress >= 0.9)
                          .length;
                      final avgProgress = continueList.isEmpty
                          ? 0
                          : ((continueList
                                        .map((e) => e.watchProgress)
                                        .reduce((a, b) => a + b) /
                                    continueList.length) *
                                  100)
                              .round();
                      final episodesWatched = watchedEpisodesMap.values
                          .fold<int>(0, (sum, set) => sum + set.length);

                      final safeTop = MediaQuery.of(context).padding.top;
                      final sortedWatchlist = _sortedList(watchlist);

                      return Stack(
                        children: [
                          const _LibraryAtmosphere(),
                          RefreshIndicator(
                            onRefresh: _onRefresh,
                            color: AppTheme.sakuraPink,
                            backgroundColor: AppTheme.surfaceElevated,
                            displacement: safeTop + 16,
                            child: CustomScrollView(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            slivers: [
                              SliverToBoxAdapter(
                                child: SizedBox(height: safeTop + 12),
                              ),
                              SliverToBoxAdapter(
                                child: _LibraryHeader(
                                  totalItems: watchlist.length +
                                      favorites.length +
                                      recent.length,
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  20,
                                  16,
                                  100,
                                ),
                                sliver: SliverList(
                                  delegate: SliverChildListDelegate([
                                    FadeSlideIn(
                                      child: _SectionTitle(
                                        icon: Icons.insights_rounded,
                                        title: 'Statistik Nonton',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    FadeSlideIn(
                                      delay: const Duration(milliseconds: 40),
                                      child: _StatsGrid(
                                        episodesWatched: episodesWatched,
                                        favoritesCount: favorites.length,
                                        completedCount: completedCount,
                                        avgProgress: avgProgress,
                                      ),
                                    ),
                                    const SizedBox(height: 26),
                                    FadeSlideIn(
                                      delay: const Duration(milliseconds: 80),
                                      child: _SectionTitle(
                                        icon: Icons.play_circle_rounded,
                                        title: 'Lanjut Nonton',
                                        count: continueList.length,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    FadeSlideIn(
                                      delay: const Duration(milliseconds: 120),
                                      child: _ContinueHero(
                                        list: continueList,
                                        resolver: _resolveAnimeById,
                                      ),
                                    ),
                                    const SizedBox(height: 26),
                                    FadeSlideIn(
                                      delay: const Duration(milliseconds: 160),
                                      child: _SectionTitle(
                                        icon: Icons.favorite_rounded,
                                        title: 'Favorit',
                                        count: favorites.length,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    FadeSlideIn(
                                      delay: const Duration(milliseconds: 200),
                                      child: _FavoritesCarousel(
                                        list: favorites,
                                        continueList: continueList,
                                      ),
                                    ),
                                    const SizedBox(height: 26),
                                    FadeSlideIn(
                                      delay: const Duration(milliseconds: 240),
                                      child: _SectionTitle(
                                        icon: Icons.history_rounded,
                                        title: 'Baru Dilihat',
                                        count: recent.length,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    FadeSlideIn(
                                      delay: const Duration(milliseconds: 280),
                                      child: _RecentlyTimeline(
                                        list: recent,
                                        continueList: continueList,
                                      ),
                                    ),
                                    const SizedBox(height: 26),
                                    // ── Daftar Saya header + controls ──────
                                    FadeSlideIn(
                                      delay: const Duration(milliseconds: 320),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: _SectionTitle(
                                              icon: Icons.bookmark_rounded,
                                              title: 'Daftar Saya',
                                              count: watchlist.length,
                                            ),
                                          ),
                                          // Sort dropdown
                                          if (watchlist.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () => _showSortSheet(context),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.surfaceElevated,
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: AppTheme.textSecondary.withOpacity(0.2)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.sort_rounded, size: 13, color: AppTheme.accent),
                                                    const SizedBox(width: 4),
                                                    Text(_sortLabel, style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w700)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            // Grid/list toggle
                                            GestureDetector(
                                              onTap: () => setState(() => _myListGridMode = !_myListGridMode),
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 200),
                                                padding: const EdgeInsets.all(7),
                                                decoration: BoxDecoration(
                                                  color: _myListGridMode ? AppTheme.accent.withOpacity(0.15) : AppTheme.surfaceElevated,
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: _myListGridMode ? AppTheme.accent.withOpacity(0.4) : AppTheme.textSecondary.withOpacity(0.2),
                                                  ),
                                                ),
                                                child: AnimatedSwitcher(
                                                  duration: const Duration(milliseconds: 180),
                                                  child: Icon(
                                                    _myListGridMode ? Icons.view_list_rounded : Icons.grid_view_rounded,
                                                    key: ValueKey(_myListGridMode),
                                                    color: _myListGridMode ? AppTheme.accent : AppTheme.textSecondary,
                                                    size: 15,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    FadeSlideIn(
                                      delay: const Duration(milliseconds: 360),
                                      child: _MyListSection(
                                        watchlist: sortedWatchlist,
                                        gridMode: _myListGridMode,
                                        continueList: continueList,
                                      ),
                                    ),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                          ),
                        ],
                      );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Urutkan Daftar', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            ..._SortMode.values.map((mode) {
              final labels = {
                _SortMode.recentlyAdded: ('Terbaru Ditambahkan', Icons.access_time_rounded),
                _SortMode.az: ('Judul A–Z', Icons.sort_by_alpha_rounded),
                _SortMode.za: ('Judul Z–A', Icons.sort_by_alpha_rounded),
                _SortMode.rating: ('Rating Tertinggi', Icons.star_rounded),
              };
              final (label, icon) = labels[mode]!;
              final isActive = _sortMode == mode;
              return GestureDetector(
                onTap: () {
                  setState(() => _sortMode = mode);
                  Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.accent.withOpacity(0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive ? AppTheme.accent.withOpacity(0.4) : AppTheme.textSecondary.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: isActive ? AppTheme.accent : AppTheme.textSecondary, size: 18),
                      const SizedBox(width: 12),
                      Expanded(child: Text(label, style: TextStyle(color: isActive ? AppTheme.accent : AppTheme.textPrimary, fontSize: 14, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500))),
                      if (isActive) Icon(Icons.check_rounded, color: AppTheme.accent, size: 18),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Atmosphere ────────────────────────────────────────────────────────────────

class _LibraryAtmosphere extends StatelessWidget {
  const _LibraryAtmosphere();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -60,
            left: -50,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFD4A657).withValues(alpha: 0.12),
                    const Color(0xFFD4A657).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 120,
            right: -70,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accent.withValues(alpha: 0.12),
                    AppTheme.accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.glow.withValues(alpha: 0.08),
                    AppTheme.glow.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _LibraryHeader extends StatelessWidget {
  final int totalItems;
  const _LibraryHeader({required this.totalItems});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LiquidGlassPill(
        borderRadius: AniVerseTheme.radiusXl,
        padding: EdgeInsets.zero,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AniVerseTheme.radiusXl),
            // Gold accent border/shadow kept as an overlay on top of the
            // shared glass base — this is what makes the Library header
            // read as distinct from other liquid-glass panels app-wide.
            border: Border.all(
              color: const Color(0xFFD4A657).withValues(alpha: 0.22),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4A657).withValues(alpha: 0.10),
                blurRadius: 24,
                spreadRadius: -6,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppTheme.accent, AppTheme.highlight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.40),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.collections_bookmark_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Koleksi Saya',
                        style: TextStyle(
                          color: AppTheme.textPrimary, // Ganti _kInk
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Anime favoritmu di satu tempat',
                        style: TextStyle(
                          color: AppTheme.textSecondary.withValues(alpha: 0.95), // Ganti _kMuted
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.08), // Ganti _kPurple
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppTheme.accent.withValues(alpha: 0.16), // Ganti _kPurple
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.folder_special_rounded,
                              size: 12,
                              color: AppTheme.accent.withValues(alpha: 0.85), // Ganti _kPurple
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '$totalItems item tersimpan',
                              style: TextStyle(
                                color: AppTheme.accent.withValues(alpha: 0.92), // Ganti _kPurple
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.sakuraPink.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppTheme.sakuraPink.withValues(alpha: 0.24),
                    ),
                  ),
                  child: const Text(
                    'PERSONAL',
                    style: TextStyle(
                      color: AppTheme.sakuraPink,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }
}

// ── Section Title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final int? count;

  const _SectionTitle({
    required this.icon,
    required this.title,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.accent.withValues(alpha: 0.14), // Ganti _kPurple
                AppTheme.sakuraPink.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.14)), // Ganti _kPurple
          ),
          child: Icon(icon, color: AppTheme.accent, size: 16), // Ganti _kPurple
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary, // Ganti _kInk
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (count != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.80), // Ganti Colors.white
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.surface), // Ganti Colors.white
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.95), // Ganti _kMuted
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Stats Grid ────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final int episodesWatched;
  final int favoritesCount;
  final int completedCount;
  final int avgProgress;

  const _StatsGrid({
    required this.episodesWatched,
    required this.favoritesCount,
    required this.completedCount,
    required this.avgProgress,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.65,
      children: [
        _statCard(
          'Episode',
          '$episodesWatched',
          Icons.movie_filter_rounded,
          AppTheme.accent, // Ganti _kPurple
        ),
        _statCard(
          'Favorit',
          '$favoritesCount',
          Icons.favorite_rounded,
          AppTheme.sakuraPink,
        ),
        _statCard(
          'Selesai',
          '$completedCount',
          Icons.check_circle_rounded,
          AppTheme.success, // Ganti Color(0xFF10B981)
        ),
        _statCard(
          'Progress',
          '$avgProgress%',
          Icons.trending_up_rounded,
          AppTheme.warning, // Ganti Color(0xFFF59E0B)
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.13),
            AppTheme.surfaceElevated.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.28), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 22,
            spreadRadius: -6,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.90),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Continue Hero ─────────────────────────────────────────────────────────────

class _ContinueHero extends StatelessWidget {
  final List<ContinueWatchingModel> list;
  final AnimeModel? Function(String id) resolver;

  const _ContinueHero({required this.list, required this.resolver});

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) {
      return const _EmptyState(
        icon: Icons.play_circle_outline_rounded,
        title: 'Belum ada yang ditonton',
        subtitle:
            'Mulai episode anime dan kartu lanjut nonton akan muncul di sini.',
      );
    }

    final item = list.first;
    final active =
        MockDataService.getContinueWatchingByAnimeId(item.animeId) ?? item;
    final anime =
        resolver(active.animeId) ?? MockDataService.getMockAnimes().first;
    final progress = active.watchProgress.clamp(0.0, 1.0);
    final episodeIndex = anime.episodes.isEmpty
        ? 0
        : (active.episodeNumber - 1).clamp(0, anime.episodes.length - 1);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
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
        height: 196,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.22)), // Ganti _kPurple
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.20), // Ganti _kPurple
              blurRadius: 24,
              spreadRadius: -4,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                active.thumbnailUrl.isNotEmpty
                    ? active.thumbnailUrl
                    : anime.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Container(color: AppTheme.background),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.08),
                      Colors.black.withValues(alpha: 0.82),
                    ],
                    stops: const [0.25, 1.0],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                    colors: [
                      AppTheme.accent.withValues(alpha: 0.30), // Ganti _kPurple
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.sakuraPink.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.sakuraPink.withValues(alpha: 0.45),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 11,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'LANJUT NONTON',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      active.animeTitle.isNotEmpty
                          ? active.animeTitle
                          : anime.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Episode ${active.episodeNumber}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        valueColor: const AlwaysStoppedAnimation(
                          AppTheme.sakuraPink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(progress * 100).round()}% ditonton',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.68),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.accent, AppTheme.glow], // Ganti _kPurple, _kAccent
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accent.withValues(alpha: 0.35), // Ganti _kPurple
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Lanjutkan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Favorites Carousel ────────────────────────────────────────────────────────

class _FavoritesCarousel extends StatelessWidget {
  final List<AnimeModel> list;
  final List<ContinueWatchingModel> continueList;
  const _FavoritesCarousel({required this.list, required this.continueList});

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) {
      return const _EmptyState(
        icon: Icons.favorite_outline_rounded,
        title: 'Belum ada favorit',
        subtitle:
            'Tap ikon hati di halaman detail anime untuk menyimpannya.',
      );
    }
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        itemBuilder: (context, index) {
          final anime = list[index];
          ContinueWatchingModel? cw;
          for (final item in continueList) {
            if (item.animeId == anime.id) { cw = item; break; }
          }
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _FavoriteCard(anime: anime, cw: cw),
          );
        },
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final AnimeModel anime;
  final ContinueWatchingModel? cw;
  const _FavoriteCard({required this.anime, this.cw});

  @override
  Widget build(BuildContext context) {
    final progress = cw?.watchProgress ?? 0.0;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AnimeDetailScreen(anime: anime)),
      ),
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover with progress bar overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    anime.imageUrl,
                    width: 130,
                    height: 175,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 130, height: 175,
                      color: AppTheme.surfaceElevated,
                      child: Icon(Icons.movie_rounded, color: AppTheme.textSecondary, size: 32),
                    ),
                  ),
                ),
                // Progress bar at bottom of image
                if (progress > 0.01)
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      ),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: Colors.white.withOpacity(0.15),
                        valueColor: const AlwaysStoppedAnimation(AppTheme.sakuraPink),
                      ),
                    ),
                  ),
                // Rating pill top-right
                Positioned(
                  top: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFD4AF37), size: 10),
                        const SizedBox(width: 3),
                        Text(
                          anime.rating.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              anime.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600, height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recently Watched ──────────────────────────────────────────────────────────

class _RecentlyTimeline extends StatelessWidget {
  final List<AnimeModel> list;
  final List<ContinueWatchingModel> continueList;

  const _RecentlyTimeline({required this.list, required this.continueList});

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) {
      return const _EmptyState(
        icon: Icons.history_rounded,
        title: 'Belum ada aktivitas',
        subtitle:
            'Buka detail anime dan riwayat tontonanmu akan muncul di sini.',
      );
    }

    return Column(
      children: List.generate(list.length.clamp(0, 8), (index) {
        final anime = list[index];
        ContinueWatchingModel? cw;
        for (final item in continueList) {
          if (item.animeId == anime.id) {
            cw = item;
            break;
          }
        }

        final subtitle = cw != null
            ? 'Episode ${cw.episodeNumber} · ${(cw.watchProgress * 100).round()}%'
            : 'Dikunjungi';
        final time = cw != null ? _timeAgo(cw.lastWatched) : 'Baru saja';
        final progress = cw?.watchProgress ?? 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AnimeDetailScreen(anime: anime),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated.withValues(alpha: 0.92), // Ganti _kCard
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppTheme.textPrimary.withValues(alpha: 0.95), // Ganti Colors.white
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.07), // Ganti _kPurple
                    blurRadius: 22,
                    spreadRadius: -8,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 14,
                    bottom: 14,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.accent.withValues(alpha: 0.9), // Ganti _kPurple
                            AppTheme.sakuraPink.withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 46,
                            height: 62,
                            child: Image.network(
                              anime.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: AppTheme.accent.withValues(alpha: 0.12), // Ganti _kPurple
                                child: Icon(
                                  Icons.movie_rounded,
                                  color: AppTheme.accent, // Ganti _kPurple
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                anime.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary, // Ganti _kInk
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: AppTheme.textSecondary.withValues(alpha: 0.95), // Ganti _kMuted
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (progress > 0) ...[
                                const SizedBox(height: 7),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 4,
                                    backgroundColor:
                                        AppTheme.accent.withValues(alpha: 0.10), // Ganti _kPurple
                                    valueColor: const AlwaysStoppedAnimation(
                                      AppTheme.sakuraPink,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              time,
                              style: TextStyle(
                                color: AppTheme.textSecondary.withValues(alpha: 0.90), // Ganti _kMuted
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.textSecondary.withValues(alpha: 0.50), // Ganti _kMuted
                              size: 18,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    return '${diff.inDays}h lalu';
  }
}

// ── My List ───────────────────────────────────────────────────────────────────

class _MyListSection extends StatelessWidget {
  final List<AnimeModel> watchlist;
  final bool gridMode;
  final List<ContinueWatchingModel> continueList;

  const _MyListSection({
    required this.watchlist,
    required this.gridMode,
    required this.continueList,
  });

  @override
  Widget build(BuildContext context) {
    if (watchlist.isEmpty) {
      return const _EmptyState(
        icon: Icons.bookmark_outline_rounded,
        title: 'Daftar masih kosong',
        subtitle:
            'Buka anime dan tap "Tambah ke Daftar" untuk melacak watchlist-mu.',
      );
    }

    return ValueListenableBuilder<Map<String, AnimeStatus>>(
      valueListenable: MockDataService.myListNotifier,
      builder: (context, myList, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: gridMode
              ? _myListGrid(context, myList)
              : _myListHorizontal(context, myList),
        );
      },
    );
  }

  Widget _myListHorizontal(BuildContext context, Map<String, AnimeStatus> myList) {
    return SizedBox(
      key: const ValueKey('horiz'),
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: watchlist.length,
        itemBuilder: (context, index) {
          final anime = watchlist[index];
          final status = myList[anime.id];
          ContinueWatchingModel? cw;
          for (final item in continueList) {
            if (item.animeId == anime.id) { cw = item; break; }
          }
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _MyListCard(anime: anime, status: status, cw: cw),
          );
        },
      ),
    );
  }

  Widget _myListGrid(BuildContext context, Map<String, AnimeStatus> myList) {
    return GridView.builder(
      key: const ValueKey('grid'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.62,
      ),
      itemCount: watchlist.length,
      itemBuilder: (context, index) {
        final anime = watchlist[index];
        final status = myList[anime.id];
        ContinueWatchingModel? cw;
        for (final item in continueList) {
          if (item.animeId == anime.id) { cw = item; break; }
        }
        return _MyListCard(anime: anime, status: status, cw: cw, compact: true);
      },
    );
  }
}

class _MyListCard extends StatelessWidget {
  final AnimeModel anime;
  final AnimeStatus? status;
  final ContinueWatchingModel? cw;
  final bool compact;

  const _MyListCard({
    required this.anime,
    this.status,
    this.cw,
    this.compact = false,
  });

  Color _statusColor(AnimeStatus s) {
    switch (s) {
      case AnimeStatus.watching: return AppTheme.sakuraPink;
      case AnimeStatus.completed: return AppTheme.success;
      case AnimeStatus.planToWatch: return AppTheme.accent;
      case AnimeStatus.dropped: return AppTheme.textSecondary;
    }
  }

  String _statusLabel(AnimeStatus s) {
    switch (s) {
      case AnimeStatus.watching: return 'Nonton';
      case AnimeStatus.completed: return 'Selesai';
      case AnimeStatus.planToWatch: return 'Plan';
      case AnimeStatus.dropped: return 'Drop';
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = cw?.watchProgress ?? 0.0;
    final cardW = compact ? double.infinity : 130.0;
    final imgH = compact ? 140.0 : 175.0;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AnimeDetailScreen(anime: anime)),
      ),
      child: SizedBox(
        width: compact ? null : cardW,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(compact ? 12 : 14),
                  child: Image.network(
                    anime.imageUrl,
                    width: cardW,
                    height: imgH,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: cardW, height: imgH,
                      color: AppTheme.surfaceElevated,
                      child: Icon(Icons.movie_rounded, color: AppTheme.textSecondary, size: 28),
                    ),
                  ),
                ),
                // Progress bar
                if (progress > 0.01)
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(compact ? 12 : 14),
                        bottomRight: Radius.circular(compact ? 12 : 14),
                      ),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: Colors.white.withOpacity(0.15),
                        valueColor: const AlwaysStoppedAnimation(AppTheme.sakuraPink),
                      ),
                    ),
                  ),
                // Status badge top-left
                if (status != null)
                  Positioned(
                    top: 5, left: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusColor(status!).withOpacity(0.88),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _statusLabel(status!),
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.2),
                      ),
                    ),
                  ),
                // Rating pill top-right
                Positioned(
                  top: 5, right: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFD4AF37), size: 9),
                        const SizedBox(width: 2),
                        Text(anime.rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              anime.title,
              maxLines: compact ? 2 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: compact ? 10 : 12,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

// ── Empty state illustrations ─────────────────────────────────────────────────
// One warm palette, four scenes. Each _EmptyState variant gets its own
// CustomPainter that tells a small visual story matching the empty context.
// Colors: gold (dominant) + soft cream + muted brown line work only.

enum _EmptyKind { play, favorite, history, bookmark }

class _EmptyState extends StatelessWidget {
  final IconData icon;   // kept for fallback but no longer rendered
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  _EmptyKind get _kind {
    if (icon == Icons.favorite_outline_rounded) return _EmptyKind.favorite;
    if (icon == Icons.history_rounded) return _EmptyKind.history;
    if (icon == Icons.bookmark_outline_rounded) return _EmptyKind.bookmark;
    return _EmptyKind.play;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD4A657).withValues(alpha: 0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4A657).withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: -8,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Mini illustration (56×56)
          SizedBox(
            width: 56,
            height: 56,
            child: CustomPaint(painter: _EmptyPainter(_kind)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.95),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPainter extends CustomPainter {
  final _EmptyKind kind;
  const _EmptyPainter(this.kind);

  // Warm Ghibli palette — one family only
  static const _gold     = Color(0xFFD4A657);
  static const _goldSoft = Color(0xFFEEDCB0);
  static const _brown    = Color(0xFF5A4632);
  static const _cream    = Color(0xFFF3E6C9);

  @override
  void paint(Canvas canvas, Size s) {
    switch (kind) {
      case _EmptyKind.play:     _paintPlay(canvas, s);
      case _EmptyKind.favorite: _paintFavorite(canvas, s);
      case _EmptyKind.history:  _paintHistory(canvas, s);
      case _EmptyKind.bookmark: _paintBookmark(canvas, s);
    }
  }

  // ── Play: a tiny film reel + one star spark ──────────────────────────────
  void _paintPlay(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;

    // Outer reel ring
    canvas.drawCircle(Offset(cx, cy), s.width * 0.42,
        Paint()..color = _gold.withValues(alpha: 0.22)..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(cx, cy), s.width * 0.42,
        Paint()..color = _gold.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Centre hub
    canvas.drawCircle(Offset(cx, cy), s.width * 0.12,
        Paint()..color = _gold);

    // 4 sprocket holes around the ring
    for (int i = 0; i < 4; i++) {
      final angle = (i / 4) * 2 * 3.1416;
      final hx = cx + s.width * 0.30 * math.cos(angle);
      final hy = cy + s.width * 0.30 * math.sin(angle);
      canvas.drawCircle(Offset(hx, hy), s.width * 0.06,
          Paint()..color = _goldSoft);
    }

    // Play triangle centred in hub
    final tri = Path()
      ..moveTo(cx - 3, cy - 5)
      ..lineTo(cx - 3, cy + 5)
      ..lineTo(cx + 5, cy)
      ..close();
    canvas.drawPath(tri, Paint()..color = const Color(0xFF070B14));
  }

  // ── Favorite: a softly glowing heart ────────────────────────────────────
  void _paintFavorite(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2 + 2;

    // Glow
    canvas.drawCircle(Offset(cx, cy), s.width * 0.38,
        Paint()..color = _gold.withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));

    // Heart drawn as two bezier halves
    final heart = Path();
    final w = s.width * 0.42;
    heart.moveTo(cx, cy + w * 0.55);
    heart.cubicTo(cx - w, cy - w * 0.20, cx - w, cy - w * 0.85, cx, cy - w * 0.20);
    heart.cubicTo(cx + w, cy - w * 0.85, cx + w, cy - w * 0.20, cx, cy + w * 0.55);
    heart.close();
    canvas.drawPath(heart, Paint()..color = _gold);
    canvas.drawPath(heart, Paint()..color = _brown.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke..strokeWidth = 1.2);

    // Tiny specular highlight
    canvas.drawCircle(Offset(cx - w * 0.25, cy - w * 0.10), 2.5,
        Paint()..color = _cream.withValues(alpha: 0.7));
  }

  // ── History: a pocket watch / clock face ─────────────────────────────────
  void _paintHistory(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2 + 2;
    final r = s.width * 0.40;

    // Case & face
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = _gold.withValues(alpha: 0.20));
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = _gold..style = PaintingStyle.stroke..strokeWidth = 1.8);
    canvas.drawCircle(Offset(cx, cy), r * 0.80,
        Paint()..color = _cream.withValues(alpha: 0.10));

    // Hour ticks
    for (int i = 0; i < 12; i++) {
      final a = (i / 12) * 2 * math.pi - math.pi / 2;
      final tickR = i % 3 == 0 ? r * 0.68 : r * 0.73;
      canvas.drawLine(
        Offset(cx + tickR * math.cos(a), cy + tickR * math.sin(a)),
        Offset(cx + r * 0.82 * math.cos(a), cy + r * 0.82 * math.sin(a)),
        Paint()..color = _gold.withValues(alpha: 0.8)..strokeWidth = i % 3 == 0 ? 1.4 : 0.8,
      );
    }

    // Hands — pointing to ~10:10 (classic watch ad pose)
    final hourAngle  = (-60 * math.pi / 180);
    final minAngle   = (60 * math.pi / 180);
    canvas.drawLine(Offset(cx, cy),
        Offset(cx + r * 0.45 * math.cos(hourAngle), cy + r * 0.45 * math.sin(hourAngle)),
        Paint()..color = _gold..strokeWidth = 2..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(cx, cy),
        Offset(cx + r * 0.60 * math.cos(minAngle), cy + r * 0.60 * math.sin(minAngle)),
        Paint()..color = _goldSoft..strokeWidth = 1.5..strokeCap = StrokeCap.round);

    // Centre pin
    canvas.drawCircle(Offset(cx, cy), 2.5, Paint()..color = _gold);

    // Crown at top
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy - r - 4), width: 8, height: 5), const Radius.circular(2)),
      Paint()..color = _gold,
    );
  }

  // ── Bookmark: an open book with a ribbon ─────────────────────────────────
  void _paintBookmark(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final by = s.height * 0.78;
    const hw = 20.0;
    const ph = 14.0;

    final fill  = Paint()..color = _cream.withValues(alpha: 0.90);
    final line  = Paint()..color = _gold..style = PaintingStyle.stroke..strokeWidth = 1.4;
    final text  = Paint()..color = _brown.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke..strokeWidth = 0.9;

    // Left page
    final left = Path()
      ..moveTo(cx, by - ph)
      ..quadraticBezierTo(cx - hw * 0.55, by - ph - 8, cx - hw, by - 3)
      ..lineTo(cx - hw, by + 5)
      ..quadraticBezierTo(cx - hw * 0.55, by - 1, cx, by + ph * 0.5)
      ..close();
    canvas.drawPath(left, fill);
    canvas.drawPath(left, line);

    // Right page
    final right = Path()
      ..moveTo(cx, by - ph)
      ..quadraticBezierTo(cx + hw * 0.55, by - ph - 8, cx + hw, by - 3)
      ..lineTo(cx + hw, by + 5)
      ..quadraticBezierTo(cx + hw * 0.55, by - 1, cx, by + ph * 0.5)
      ..close();
    canvas.drawPath(right, fill);
    canvas.drawPath(right, line);

    // Spine
    canvas.drawLine(Offset(cx, by - ph), Offset(cx, by + ph * 0.5),
        Paint()..color = _brown.withValues(alpha: 0.35)..strokeWidth = 1.2);

    // Text lines
    for (int i = 0; i < 2; i++) {
      final ly = by - ph + 7 + i * 5;
      canvas.drawLine(Offset(cx - hw + 7, ly), Offset(cx - 5, ly), text);
      canvas.drawLine(Offset(cx + 5, ly), Offset(cx + hw - 7, ly), text);
    }

    // Ribbon bookmark dangling from top-right corner
    final ribbon = Path()
      ..moveTo(cx + hw - 8, s.height * 0.08)
      ..lineTo(cx + hw - 1, s.height * 0.08)
      ..lineTo(cx + hw - 1, by - ph + 4)
      ..lineTo(cx + hw - 4.5, by - ph - 1)
      ..lineTo(cx + hw - 8, by - ph + 4)
      ..close();
    canvas.drawPath(ribbon, Paint()..color = _gold.withValues(alpha: 0.85));
  }

  @override
  bool shouldRepaint(covariant _EmptyPainter old) => old.kind != kind;
}

