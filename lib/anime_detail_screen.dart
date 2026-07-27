import 'package:flutter/material.dart';
import 'anime_api_service.dart';
import 'anime_model.dart';
import 'app_theme.dart';
import 'continue_watching_model.dart';
import 'episode_model.dart';
import 'mock_data_service.dart';
import 'trailer_links.dart';
import 'trailer_player.dart';
import 'voice_actor_model.dart';
import 'voice_actors_section.dart';
import 'widgets/liquid_glass.dart';
import 'watch_screen.dart';

class AnimeDetailScreen extends StatefulWidget {
  final AnimeModel anime;

  const AnimeDetailScreen({super.key, required this.anime});

  @override
  State<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends State<AnimeDetailScreen>
    with TickerProviderStateMixin {
  bool _recentlyWatchedQueued = false;
  late Future<JikanAnimeDetail> _detailFuture;
  late Future<List<EpisodeModel>> _episodesFuture;
  late Future<List<AnimeModel>> _recommendationsFuture;
  late Future<List<VoiceActorModel>> _voiceActorsFuture;

  bool _episodesExpanded = false;
  final TextEditingController _episodeSearchCtrl = TextEditingController();
  int? _episodeSearchQuery;

  // Synopsis read-more/less — collapsed by default so the page stays
  // compact, expands with a smooth size+fade animation on tap.
  bool _synopsisExpanded = false;

  // Ken Burns effect — slow continuous zoom on the hero image, purely
  // decorative (no user interaction), long duration so it reads as a
  // gentle drift rather than an obvious animation.
  late final AnimationController _heroZoomController;
  late final Animation<double> _heroZoomAnimation;

  // ── Poster-to-trailer cross-fade ──────────────────────────────────────
  // After the Hero flight lands (full-size banner), the poster cross-
  // fades into a full-cover trailer — only when this anime actually has a
  // registered trailer (see trailer_links.dart); otherwise the poster
  // just stays full-size with its existing Ken Burns drift, unchanged
  // from before. (Previously the poster shrank into a corner thumbnail
  // instead of fading out fully, but even scaled down it kept covering
  // part of the video, so this is a straight cross-fade now.)
  late final AnimationController _posterShrinkController;
  late final Animation<double> _trailerOpacity;

  @override
  void dispose() {
    _episodeSearchCtrl.dispose();
    _heroZoomController.dispose();
    _posterShrinkController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _heroZoomController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
    _heroZoomAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _heroZoomController, curve: Curves.easeInOut),
    );

    _posterShrinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _trailerOpacity = CurvedAnimation(
      parent: _posterShrinkController,
      // Trailer fades in a little after the cross-fade starts, rather
      // than instantly snapping, so it reads as a deliberate reveal.
      curve: const Interval(0.35, 1.0, curve: Curves.easeIn),
    );

    // .timeout() ensures a hanging/offline network call fails fast instead
    // of leaving the FutureBuilder stuck on ConnectionState.waiting forever
    // (which is what caused the perpetual spinner under Recommendations).
    _detailFuture = AnimeApiService.fetchAnimeDetail(widget.anime.id)
        .timeout(const Duration(seconds: 45));
    _episodesFuture = AnimeApiService.fetchAnimeEpisodes(widget.anime.id)
        .timeout(const Duration(seconds: 45));
    _recommendationsFuture =
        AnimeApiService.fetchAnimeRecommendations(widget.anime.id, title: widget.anime.title)
            .timeout(const Duration(seconds: 45));
    _voiceActorsFuture =
        AnimeApiService.fetchAnimeVoiceActors(widget.anime.id, title: widget.anime.title)
            .timeout(const Duration(seconds: 45));

    // Only run the shrink/reveal sequence if this anime actually has a
    // trailer registered — otherwise there'd be nothing behind the poster
    // and it would just shrink into empty space for no reason.
    if (getTrailerUrl(widget.anime.title, anime: widget.anime) != null) {
      // Delayed start: let the Hero flight itself finish landing first
      // (MaterialPageRoute's default transition duration is 300ms) before
      // the poster starts shrinking, so the two animations read as
      // sequential ("it arrives, THEN it shrinks") rather than overlapping
      // and looking like one confused motion.
      Future.delayed(const Duration(milliseconds: 420), () {
        if (mounted) _posterShrinkController.forward();
      });
    }
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

        // ── API failed — build fallback from mock data ──────────────────
        final JikanAnimeDetail detail;
        final bool isOffline;
        if (snapshot.hasError || !snapshot.hasData) {
          detail = JikanAnimeDetail(
            title: widget.anime.title,
            synopsis: widget.anime.description,
            score: widget.anime.rating,
            rank: null,
            episodes: widget.anime.episodes.isEmpty ? null : widget.anime.episodes.length,
            status: 'N/A',
            genres: widget.anime.genres,
            studios: const [],
            largeImageUrl: widget.anime.imageUrl,
            trailerYoutubeId: null,
            relations: const [],
          );
          isOffline = !widget.anime.id.startsWith('custom-');
        } else {
          detail = snapshot.data!;
          isOffline = false;
        }

        final displayGenre =
            detail.genres.isEmpty ? widget.anime.genre : detail.genres.first;
        final displayEpisodes = detail.episodes ?? widget.anime.episodes.length;

        // Banner height is exactly 16:9 for the screen width (not an
        // arbitrary fixed 450) so the trailer's BoxFit.contain has zero
        // letterboxing — the video frame and the banner frame are now the
        // same aspect ratio, so "contain" and "cover" produce the same
        // result and nothing gets cropped or padded with black bars.
        final bannerHeight = MediaQuery.of(context).size.width * 9 / 16;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: bannerHeight,
                pinned: true,
                stretch: true,
                backgroundColor: AppTheme.background,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: LiquidGlassPill(
                    borderRadius: 24,
                    compact: true,
                    padding: EdgeInsets.zero,
                    alignment: Alignment.center,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                actions: [
                  _FavoriteButton(anime: widget.anime),
                  _WatchlistButton(anime: widget.anime),
                  const SizedBox(width: 4),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Hero(
                    tag: 'anime-hero-${widget.anime.id}',
                    // flightShuttleBuilder must match the one in AnimeCard
                    // (see anime_card.dart) — both sides need to agree on
                    // how the corner radius interpolates during flight, or
                    // Flutter's default (picking one endpoint's subtree)
                    // produces a visible radius "pop" partway through.
                    flightShuttleBuilder: (
                      flightContext,
                      animation,
                      flightDirection,
                      fromHeroContext,
                      toHeroContext,
                    ) {
                      final radiusTween = Tween<double>(begin: 10, end: 0);
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(
                              radiusTween.evaluate(animation),
                            ),
                            child: child,
                          );
                        },
                        child: toHeroContext.widget,
                      );
                    },
                    child: Builder(
                      builder: (context) {
                        final trailerUrl = getTrailerUrl(widget.anime.title, anime: widget.anime);

                        Widget buildPosterLayer() {
                          return ShaderMask(
                            shaderCallback: (rect) {
                              return LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: const [
                                  Colors.white,
                                  Colors.white,
                                  Colors.white,
                                  Color(0xD9FFFFFF),
                                  Color(0x73FFFFFF),
                                  Color(0x26FFFFFF),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.45, 0.55, 0.68, 0.82, 0.93, 1.0],
                              ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
                            },
                            blendMode: BlendMode.dstIn,
                            child: AnimatedBuilder(
                              animation: _heroZoomAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _heroZoomAnimation.value,
                                  child: child,
                                );
                              },
                              child: Image.network(
                                detail.largeImageUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        }

                        // No trailer registered for this title — keep the
                        // exact original behavior (full-size poster, Ken
                        // Burns drift, nothing extra).
                        if (trailerUrl == null) return buildPosterLayer();

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            // Poster stays full-size and fades OUT as the
                            // trailer fades in — no more shrink-to-corner
                            // thumbnail, since even scaled down it kept
                            // covering part of the video. Simple cross-fade
                            // instead.
                            FadeTransition(
                              opacity: ReverseAnimation(_trailerOpacity),
                              child: buildPosterLayer(),
                            ),
                            FadeTransition(
                              opacity: _trailerOpacity,
                              child: TrailerPlayer(
                                trailerUrl: trailerUrl,
                                fallback: buildPosterLayer(),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              // ── Offline banner ─────────────────────────────────────────
              if (isOffline)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.warning.withOpacity(0.35)),
                      boxShadow: AppTheme.glowShadow(AppTheme.warning, 0.08),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.wifi_off_rounded, color: AppTheme.warning, size: 15),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Offline — menampilkan data lokal.',
                            style: TextStyle(
                              color: AppTheme.warning,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            AnimeApiService.clearAnimeCache(widget.anime.id);
                            setState(() {
                              _detailFuture = AnimeApiService
                                  .fetchAnimeDetail(widget.anime.id)
                                  .timeout(const Duration(seconds: 45));
                              _episodesFuture = AnimeApiService
                                  .fetchAnimeEpisodes(widget.anime.id)
                                  .timeout(const Duration(seconds: 45));
                              _recommendationsFuture = AnimeApiService
                                  .fetchAnimeRecommendations(widget.anime.id, title: widget.anime.title)
                                  .timeout(const Duration(seconds: 45));
                              _voiceActorsFuture = AnimeApiService
                                  .fetchAnimeVoiceActors(widget.anime.id, title: widget.anime.title)
                                  .timeout(const Duration(seconds: 45));
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                              border: Border.all(color: AppTheme.warning.withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh_rounded, color: AppTheme.warning, size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  'Retry',
                                  style: TextStyle(
                                    color: AppTheme.warning,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.background.withOpacity(0.0),
                        AppTheme.background,
                      ],
                      stops: const [0.0, 0.35],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 36, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              detail.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                    shadows: [
                                      Shadow(
                                        color: AppTheme.background.withValues(alpha: 0.8),
                                        blurRadius: 12,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _buildRatingBadge(detail.score),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _InfoGrid(
                        studio: detail.studios.isNotEmpty
                            ? detail.studios.join(', ')
                            : null,
                        episodes: displayEpisodes,
                        status: detail.status,
                        rank: detail.rank,
                      ),
                      const SizedBox(height: 16),
                      if (detail.genres.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildChip(displayGenre, isAccent: true),
                            ...detail.genres
                                .where((g) => g != displayGenre)
                                .map((g) => _buildChip(g)),
                          ],
                        ),
                      const SizedBox(height: 32),
                      _SynopsisSection(
                        text: detail.synopsis,
                        expanded: _synopsisExpanded,
                        onToggle: () => setState(
                          () => _synopsisExpanded = !_synopsisExpanded,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Container(
                            width: 3,
                            height: 22,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [AppTheme.accent, AppTheme.highlight],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Recommendations',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      FutureBuilder<List<AnimeModel>>(
                        future: _recommendationsFuture,
                        builder: (context, recSnapshot) {
                          if (recSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return SizedBox(
                              height: 236,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: 4,
                                itemBuilder: (context, index) =>
                                    const _RecommendationCardSkeleton(),
                              ),
                            );
                          }

                          if (recSnapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                'Rekomendasi tidak tersedia saat offline.',
                                style: TextStyle(
                                  color: AppTheme.textSecondary.withOpacity(0.7),
                                  fontSize: 13,
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
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                            );
                          }

                          return SizedBox(
                            height: 236,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: recs.length,
                              itemBuilder: (context, index) => _RecommendationCard(
                                anime: recs[index],
                                rank: index + 1,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AnimeDetailScreen(
                                        anime: recs[index],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      FutureBuilder<List<VoiceActorModel>>(
                        future: _voiceActorsFuture,
                        builder: (context, vaSnapshot) {
                          return VoiceActorsSection(
                            voiceActors: vaSnapshot.data ?? const [],
                            isLoading: vaSnapshot.connectionState ==
                                ConnectionState.waiting,
                            error: vaSnapshot.hasError
                                ? 'Voice actor data tidak tersedia saat offline.'
                                : null,
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      _WatchNowButton(
                        enabled: widget.anime.episodes.isNotEmpty,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => WatchScreen(
                                anime: widget.anime,
                                initialEpisodeIndex: 0,
                              ),
                            ),
                          );
                        },
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

                          // Fall back to the anime's local episode list when
                          // the API call fails or returns nothing — mirrors
                          // the fallback already used for `detail` above so
                          // the section doesn't stay stuck or blank offline.
                          final episodes = (episodeSnapshot.hasError ||
                                  !episodeSnapshot.hasData ||
                                  episodeSnapshot.data!.isEmpty)
                              ? widget.anime.episodes
                              : episodeSnapshot.data!;

                          if (episodes.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          final displayedEpisodes = _episodeSearchQuery == null
                              ? episodes
                              : episodes
                                  .where((e) => e.number == _episodeSearchQuery)
                                  .toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _episodesExpanded = !_episodesExpanded;
                              if (!_episodesExpanded) {
                                _episodeSearchCtrl.clear();
                                _episodeSearchQuery = null;
                              }
                            });
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 3,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [AppTheme.accent, AppTheme.highlight],
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Episodes (${episodes.length})',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ],
                              ),
                              AnimatedRotation(
                                duration: const Duration(milliseconds: 250),
                                turns: _episodesExpanded ? 0.5 : 0,
                                curve: Curves.easeOutCubic,
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: AppTheme.highlight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!_episodesExpanded) ...[
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 13),
                            child: Text(
                              'Tap to show episodes',
                              style: TextStyle(
                                color: AppTheme.textSecondary.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_episodesExpanded) ...[
                          const SizedBox(height: 14),
                          if (episodes.length > 20)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: TextField(
                                controller: _episodeSearchCtrl,
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Cari nomor episode...',
                                  hintStyle: TextStyle(
                                    color: AppTheme.textSecondary.withOpacity(0.5),
                                    fontSize: 13,
                                  ),
                                  prefixIcon: Icon(Icons.search_rounded,
                                      color: AppTheme.textSecondary.withOpacity(0.5), size: 20),
                                  suffixIcon: _episodeSearchQuery != null
                                      ? IconButton(
                                          icon: Icon(Icons.close_rounded,
                                              color: AppTheme.textSecondary, size: 18),
                                          onPressed: () {
                                            setState(() {
                                              _episodeSearchCtrl.clear();
                                              _episodeSearchQuery = null;
                                            });
                                          },
                                        )
                                      : null,
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  filled: true,
                                  fillColor: AppTheme.surfaceElevated.withOpacity(0.6),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                    borderSide: BorderSide(
                                      color: AppTheme.accent.withOpacity(0.2),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                    borderSide: BorderSide(
                                      color: AppTheme.accent.withOpacity(0.2),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                    borderSide: BorderSide(
                                      color: AppTheme.highlight.withOpacity(0.6),
                                    ),
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _episodeSearchQuery = int.tryParse(value.trim());
                                  });
                                },
                              ),
                            ),
                          if (displayedEpisodes.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  'Episode tidak ditemukan',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary.withOpacity(0.6),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: displayedEpisodes.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final ep = displayedEpisodes[index];
                                return ValueListenableBuilder<Map<String, Set<int>>>(
                                  valueListenable: MockDataService.watchedEpisodesNotifier,
                                  builder: (context, watchedMap, _) {
                                    return ValueListenableBuilder<List<ContinueWatchingModel>>(
                                      valueListenable: MockDataService.continueWatchingNotifier,
                                      builder: (context, _, __) {
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

                                        return _EpisodeTile(
                                          episode: ep,
                                          isWatched: isWatched,
                                          continueProgress: isCurrentContinueEpisode
                                              ? continueItem.watchProgress
                                              : null,
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => WatchScreen(
                                                  anime: AnimeModel(
                                                    id: widget.anime.id,
                                                    title: widget.anime.title,
                                                    imageUrl: widget.anime.imageUrl,
                                                    rating: widget.anime.rating,
                                                    genres: [widget.anime.genre],
                                                    description: widget.anime.description,
                                                    isTrending: widget.anime.isTrending,
                                                    episodes: episodes,
                                                  ),
                                                  initialEpisodeIndex:
                                                      episodes.indexOf(ep),
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
                        ],
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
    return LiquidGlassPill(
      borderRadius: AppTheme.radiusMd,
      compact: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: AppTheme.highlight, size: 17),
          const SizedBox(width: 5),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
                color: AppTheme.highlight,
                fontWeight: FontWeight.w800,
                fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, {bool isAccent = false}) {
    return LiquidGlassPill(
      borderRadius: AppTheme.radiusPill,
      compact: true,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: isAccent ? AppTheme.accent : AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: isAccent ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _InfoGrid — Mirainime-inspired 2-column metadata panel (Studio/Episodes
// left, Status/Rank right), rendered as one liquid-glass pane instead of
// scattered chips. Only surfaces fields JikanAnimeDetail actually has —
// no season/duration, since anime_api_service.dart doesn't fetch those.
class _InfoGrid extends StatelessWidget {
  const _InfoGrid({
    required this.studio,
    required this.episodes,
    required this.status,
    required this.rank,
  });

  final String? studio;
  final int episodes;
  final String status;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassPill(
      borderRadius: AppTheme.radiusLg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoField(label: 'Studio', value: studio ?? '—'),
                const SizedBox(height: 14),
                _InfoField(label: 'Total Episodes', value: '$episodes'),
              ],
            ),
          ),
          SizedBox(
            height: 66,
            child: VerticalDivider(
              color: Colors.white.withValues(alpha: 0.12),
              width: 24,
              thickness: 1,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoField(label: 'Status', value: status),
                const SizedBox(height: 14),
                _InfoField(
                  label: 'Rank',
                  value: rank != null ? '#$rank' : 'N/A',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  const _InfoField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textSecondary.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Synopsis — bold redesign: glass card with a soft glow border, an oversized
// quote-mark watermark, a drop-cap first letter, and an animated
// read-more/less toggle (AnimatedSize + AnimatedCrossFade for the fade).
// ─────────────────────────────────────────────────────────────────────────
class _SynopsisSection extends StatelessWidget {
  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  const _SynopsisSection({
    required this.text,
    required this.expanded,
    required this.onToggle,
  });

  static const int _collapsedMaxLines = 4;

  @override
  Widget build(BuildContext context) {
    final trimmed = text.trim();
    final firstLetter = trimmed.isNotEmpty ? trimmed[0] : '';
    final rest = trimmed.isNotEmpty ? trimmed.substring(1) : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 22,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppTheme.accent, AppTheme.highlight],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Synopsis',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Extra accent-tinted glow behind the pill — LiquidGlassPill's own
        // shadow is neutral black, so this adds the synopsis card's accent
        // colored glow as a separate layer underneath rather than forcing
        // pill's shared recipe to support a per-instance shadow color.
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: AppTheme.glowShadow(AppTheme.accent, 0.10),
          ),
          child: LiquidGlassPill(
            borderRadius: AppTheme.radiusLg,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            alignment: Alignment.topLeft,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Oversized quote-mark watermark in the corner
                Positioned(
                  top: -38,
                  right: -16,
                  child: Text(
                    '\u201D',
                    style: TextStyle(
                      fontFamily: 'ShipporiMinchoB1',
                      fontSize: 110,
                      height: 1,
                      color: AppTheme.accent.withOpacity(0.08),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: AnimatedCrossFade(
                        duration: const Duration(milliseconds: 220),
                        crossFadeState: expanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: _buildRichText(
                          firstLetter,
                          rest,
                          maxLines: _collapsedMaxLines,
                          overflow: TextOverflow.fade,
                        ),
                        secondChild: _buildRichText(firstLetter, rest),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: onToggle,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            expanded ? 'Show less' : 'Read more',
                            style: TextStyle(
                              color: AppTheme.highlight,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          AnimatedRotation(
                            duration: const Duration(milliseconds: 250),
                            turns: expanded ? 0.5 : 0,
                            curve: Curves.easeOutCubic,
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: AppTheme.highlight,
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
        ),
      ],
    );
  }

  Widget _buildRichText(
    String firstLetter,
    String rest, {
    int? maxLines,
    TextOverflow? overflow,
  }) {
    return RichText(
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      text: TextSpan(
        children: [
          if (firstLetter.isNotEmpty)
            TextSpan(
              text: firstLetter,
              style: TextStyle(
                fontFamily: 'ShipporiMinchoB1',
                color: AppTheme.highlight,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          TextSpan(
            text: rest,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Recommendations — bold redesign: poster card with rank badge, gradient
// scrim, rating pill, press-scale feedback, and a shimmer skeleton while
// loading instead of a plain spinner.
// ─────────────────────────────────────────────────────────────────────────
class _RecommendationCard extends StatefulWidget {
  final AnimeModel anime;
  final int rank;
  final VoidCallback onTap;

  const _RecommendationCard({
    required this.anime,
    required this.rank,
    required this.onTap,
  });

  @override
  State<_RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<_RecommendationCard> {
  double _scale = 1.0;

  void _setPressed(bool pressed) {
    setState(() => _scale = pressed ? 0.96 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: 140,
          margin: const EdgeInsets.only(right: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          boxShadow: AppTheme.glowShadow(AppTheme.accent, 0.08),
                        ),
                        child: widget.anime.imageUrl.isNotEmpty
                            ? Image.network(
                                widget.anime.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppTheme.surfaceElevated,
                                  child: Icon(
                                    Icons.movie_creation_outlined,
                                    color: AppTheme.textSecondary.withOpacity(0.4),
                                    size: 32,
                                  ),
                                ),
                              )
                            : Container(
                                color: AppTheme.surfaceElevated,
                                child: Icon(
                                  Icons.movie_creation_outlined,
                                  color: AppTheme.textSecondary.withOpacity(0.4),
                                  size: 32,
                                ),
                              ),
                      ),
                      // Bottom gradient scrim for legibility
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 64,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.75),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Rank badge — ticket-stub style, top-left
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                            border: Border.all(
                              color: AppTheme.highlight.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '#${widget.rank}',
                            style: TextStyle(
                              color: AppTheme.highlight,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      // Rating pill, top-right
                      if (widget.anime.rating > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded,
                                    color: AppTheme.highlight, size: 12),
                                const SizedBox(width: 2),
                                Text(
                                  widget.anime.rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Genre chip over the scrim, bottom
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: Text(
                          widget.anime.genre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.anime.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shimmer-style placeholder shown in the horizontal list while
/// recommendations are loading — reads as "content incoming" rather
/// than a blocking centered spinner.
class _RecommendationCardSkeleton extends StatefulWidget {
  const _RecommendationCardSkeleton();

  @override
  State<_RecommendationCardSkeleton> createState() =>
      _RecommendationCardSkeletonState();
}

class _RecommendationCardSkeletonState
    extends State<_RecommendationCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: Container(
                    color: Color.lerp(
                      AppTheme.surfaceElevated,
                      AppTheme.surface,
                      _ctrl.value,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 10,
            width: 100,
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
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
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: LiquidGlassPill(
            borderRadius: 24,
            compact: true,
            padding: EdgeInsets.zero,
            alignment: Alignment.center,
            child: IconButton(
              tooltip: active ? 'Remove from Favorites' : 'Add to Favorites',
              icon: Icon(
                active ? Icons.favorite : Icons.favorite_outline,
                color: active ? AppTheme.highlight : Colors.white,
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
            ),
          ),
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
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: LiquidGlassPill(
            borderRadius: 24,
            compact: true,
            padding: EdgeInsets.zero,
            alignment: Alignment.center,
            child: IconButton(
              tooltip: active ? 'Remove from Watchlist' : 'Add to Watchlist',
              icon: Icon(
                active ? Icons.bookmark : Icons.bookmark_outline,
                color: active ? AppTheme.highlight : Colors.white,
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
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Watch Now — bold redesign: gradient-filled pill with a soft outer glow
// and press-scale feedback, replacing the flat solid-color button. Falls
// back to a muted disabled look when there are no episodes to play.
// ─────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────
// Episode list — bold redesign: card row with a wide thumbnail, a
// gradient scrim + centered play glyph on hover/press, a watched
// checkmark badge, and an inline progress bar for continue-watching
// episodes, replacing the plain ListTile + divider layout.
// ─────────────────────────────────────────────────────────────────────────
class _EpisodeTile extends StatefulWidget {
  final EpisodeModel episode;
  final bool isWatched;
  final double? continueProgress;
  final VoidCallback onTap;

  const _EpisodeTile({
    required this.episode,
    required this.isWatched,
    required this.continueProgress,
    required this.onTap,
  });

  @override
  State<_EpisodeTile> createState() => _EpisodeTileState();
}

class _EpisodeTileState extends State<_EpisodeTile> {
  double _scale = 1.0;

  void _setPressed(bool pressed) {
    setState(() => _scale = pressed ? 0.98 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final ep = widget.episode;
    final isWatched = widget.isWatched;
    final progress = widget.continueProgress;

    String subtitleText = ep.duration;
    if (progress != null) {
      subtitleText = 'Continue ${(progress * 100).round()}%';
    } else if (isWatched) {
      subtitleText = 'Watched';
    } else if (ep.airedDate != null) {
      subtitleText = ep.airedDate!;
    }

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.045),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: isWatched
                  ? AppTheme.success.withOpacity(0.28)
                  : Colors.white.withOpacity(0.12),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Thumbnail with scrim + play glyph + progress bar ──────
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.network(
                      ep.thumbnailUrl,
                      width: 96,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 96,
                        height: 60,
                        color: AppTheme.surface,
                        child: Icon(Icons.movie_outlined,
                            color: AppTheme.textSecondary.withOpacity(0.3), size: 20),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.35),
                          ],
                        ),
                      ),
                      child: const SizedBox(width: 96, height: 60),
                    ),
                    Icon(
                      isWatched
                          ? Icons.check_circle_rounded
                          : Icons.play_circle_fill_rounded,
                      color: isWatched
                          ? AppTheme.success
                          : Colors.white.withOpacity(0.92),
                      size: 26,
                    ),
                    if (progress != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(6),
                            bottomRight: Radius.circular(6),
                          ),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 3,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation(AppTheme.highlight),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // ── Title + subtitle ─────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        ep.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (isWatched)
                            Icon(Icons.check_circle_rounded,
                                size: 12, color: AppTheme.success)
                          else if (progress != null)
                            Icon(Icons.play_circle_outline_rounded,
                                size: 12, color: AppTheme.highlight),
                          if (isWatched || progress != null)
                            const SizedBox(width: 4),
                          Text(
                            subtitleText,
                            style: TextStyle(
                              color: isWatched
                                  ? AppTheme.success
                                  : progress != null
                                      ? AppTheme.highlight
                                      : AppTheme.textSecondary.withOpacity(0.6),
                              fontSize: 11,
                              fontWeight: (isWatched || progress != null)
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _WatchNowButton extends StatefulWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _WatchNowButton({required this.enabled, required this.onPressed});

  @override
  State<_WatchNowButton> createState() => _WatchNowButtonState();
}

class _WatchNowButtonState extends State<_WatchNowButton> {
  double _scale = 1.0;

  void _setPressed(bool pressed) {
    if (!widget.enabled) return;
    setState(() => _scale = pressed ? 0.97 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return GestureDetector(
      onTap: enabled ? widget.onPressed : null,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            gradient: enabled
                ? LinearGradient(
                    colors: [AppTheme.accent, AppTheme.highlight],
                  )
                : null,
            color: enabled ? null : AppTheme.surfaceElevated,
            boxShadow: enabled
                ? AppTheme.glowShadow(AppTheme.accent, 0.35)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.play_arrow_rounded,
                size: 28,
                color: enabled
                    ? AppTheme.background
                    : AppTheme.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(width: 6),
              Text(
                'Watch Now',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: enabled
                      ? AppTheme.background
                      : AppTheme.textSecondary.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
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
      builder: (context, _, __) {
        final active = isActiveCheck(anime.id);
        return _MorphToggleButton(
          active: active,
          icon: active ? activeIcon : inactiveIcon,
          label: label,
          onTap: () => onToggle(anime),
        );
      },
    );
  }
}

/// Animated toggle button used for Watchlist/Favorite — morphs its fill,
/// border, and icon color over ~220ms and gives a quick scale "pop" the
/// moment it becomes active, instead of an instant flat color swap.
class _MorphToggleButton extends StatefulWidget {
  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MorphToggleButton({
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_MorphToggleButton> createState() => _MorphToggleButtonState();
}

class _MorphToggleButtonState extends State<_MorphToggleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _popCtrl;
  late final Animation<double> _popScale;

  @override
  void initState() {
    super.initState();
    _popCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _popScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.14)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.14, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_popCtrl);
  }

  @override
  void didUpdateWidget(covariant _MorphToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _popCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _popCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    // LiquidGlassPill's own recipe is white-only (no per-instance active
    // tint), so the active/inactive color morph is layered ON TOP as a
    // separate AnimatedContainer instead of being pushed into the shared
    // pill. Both branches use the same fixed height (52) explicitly, per
    // the anti-bug checklist in ANIVERSE_LIQUID_GLASS_SPEC.md §4 — this is
    // exactly the "two visual states must size identically" case it warns
    // about, so it's not left to intrinsic Row/Text sizing.
    const buttonHeight = 52.0;
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          LiquidGlassPill(
            borderRadius: AppTheme.radiusMd,
            compact: true,
            height: buttonHeight,
            padding: EdgeInsets.zero,
            alignment: Alignment.center,
            child: const SizedBox.shrink(),
          ),
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.highlight.withOpacity(0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: active
                      ? AppTheme.highlight.withOpacity(0.55)
                      : Colors.transparent,
                  width: 1,
                ),
                boxShadow: active
                    ? AppTheme.glowShadow(AppTheme.highlight, 0.12)
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _popScale,
                    child: Icon(
                      widget.icon,
                      size: 18,
                      color: active ? AppTheme.highlight : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: active ? AppTheme.highlight : AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
