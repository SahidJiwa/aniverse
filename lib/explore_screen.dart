// explore_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Explore Search V2 — Premium streaming-service quality
//
// Features:
//  • Real-time search filtering (debounced 180ms)
//  • Recent search history (persisted in-memory, max 8)
//  • Clear search button
//  • Search suggestions (genre-based + title autocomplete)
//  • Empty state UI (per-type: no results vs no query)
//  • Smooth animations (staggered entry, fade, slide)
//  • AniVerse theme (sakuraPink, surfaceDark, backgroundDark)
//  • Mobile + Desktop responsive (2-col → 3-col → 4-col grid)
//
// PRESERVED from original Explore:
//  • Genre filter chips
//  • All anime cards (AnimeCard widget untouched)
//  • MockDataService.getGenres() + getMockAnimes()
//  • Navigation architecture (no changes)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'anime_model.dart';
import 'package:aniverse/theme/aniverse_theme.dart';
import 'mock_data_service.dart';
import 'anime_card.dart';
import 'proxied_network_image.dart';
import 'catalog_store.dart';
import 'widgets/liquid_glass.dart';

// ─── Multi-genre accessor (mirrors home_screen.dart's _genresOf) ──────────────
// AnimeModel.genres is the source of truth (List<String>, populated from
// Jikan's full genre list or mock data). The dynamic fallback to `.genre`
// remains only as defense against any non-AnimeModel caller.
List<String> _genresOf(dynamic a) {
  try { final v = a.genres; if (v is List) return v.map((e) => e.toString()).toList(); } catch (_) {}
  try { final v = a.genre; if (v is String && v.isNotEmpty) return [v]; } catch (_) {}
  return [];
}

enum _SortMode {
  relevant('Relevan'),
  rating('Rating ↓'),
  az('A–Z'),
  trending('Trending');

  final String label;
  const _SortMode(this.label);
}

class ExploreScreen extends StatefulWidget {
  final String? initialGenre;
  const ExploreScreen({super.key, this.initialGenre});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  String _query = '';
  String? _selectedGenre;
  bool _isFocused = false;
  bool _isLoading = true;

  List<AnimeModel> _allAnimes = const [];
  List<AnimeModel> _filtered = const [];
  List<String> _suggestions = const [];

  // Recent search history — persisted via SharedPreferences, max 8
  final List<String> _recentSearches = [];
  static const _kRecentKey = 'explore_recent_searches';

  // Sort & rating filter
  _SortMode _sortMode = _SortMode.relevant;
  double _minRating = 0.0; // 0 = no filter

  Timer? _debounce;

  // ── Animation controllers ──────────────────────────────────────────────────
  late AnimationController _searchBarAnim;
  late Animation<double> _searchBarExpand;

  late AnimationController _overlayAnim;
  late Animation<double> _overlayFade;

  late AnimationController _resultsAnim;
  late Animation<double> _resultsFade;
  late Animation<Offset> _resultsSlide;

  @override
  void initState() {
    super.initState();

    _searchBarAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _searchBarExpand = CurvedAnimation(
      parent: _searchBarAnim,
      curve: Curves.easeOutCubic,
    );

    _overlayAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _overlayFade = CurvedAnimation(parent: _overlayAnim, curve: Curves.easeOut);

    _resultsAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _resultsFade = CurvedAnimation(parent: _resultsAnim, curve: Curves.easeOut);
    _resultsSlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _resultsAnim, curve: Curves.easeOutCubic));

    _searchFocus.addListener(_onFocusChange);
    _searchController.addListener(_onSearchChanged);

    _selectedGenre = widget.initialGenre;

    _loadRecentSearches();
    _loadAnimes();
    CatalogStore.instance.addListener(_onCatalogChanged);
  }

  @override
  void dispose() {
    CatalogStore.instance.removeListener(_onCatalogChanged);
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.removeListener(_onFocusChange);
    _searchFocus.dispose();
    _scrollController.dispose();
    _searchBarAnim.dispose();
    _overlayAnim.dispose();
    _resultsAnim.dispose();
    super.dispose();
  }

  void _onCatalogChanged() {
    _loadAnimes(); // Reload and merge custom catalog anime
  }

  // ── Universe Signal Strip taps ────────────────────────────────────────────
  // Mood Radar / Fan Pulse / Drop Map belum punya layar fungsional sendiri,
  // tapi sekarang punya destination screen "Coming Soon" yang niat (bukan
  // snackbar) — swap isi _ComingSoonScreen ke fitur asli begitu siap.
  void _onUniverseSignalTap(String id) {
    final data = {
      'mood_radar': (
        icon: Icons.radar_rounded,
        title: 'Mood Radar',
        tagline: 'Match vibe',
        colors: [AniVerseTheme.accent, AniVerseTheme.glow],
        description:
            'Pilih mood kamu sekarang — santai, tegang, mellow, atau adrenalin — '
            'dan biar AniVerse cocokin rekomendasi anime yang paling pas sama '
            'vibe kamu saat ini.',
      ),
      'fan_pulse': (
        icon: Icons.groups_rounded,
        title: 'Fan Pulse',
        tagline: 'Hot rooms',
        colors: [AniVerseTheme.primary, AniVerseTheme.success],
        description:
            'Lihat room diskusi paling rame secara real-time, gabung obrolan '
            'fans lain soal episode terbaru, teori, dan momen paling hype '
            'minggu ini.',
      ),
      'drop_map': (
        icon: Icons.diamond_rounded,
        title: 'Drop Map',
        tagline: 'Rewards',
        colors: [AniVerseTheme.highlight, AniVerseTheme.accent],
        description:
            'Peta reward interaktif — kumpulin gem, buka drop eksklusif, dan '
            'lacak progres event musiman langsung dari satu layar.',
      ),
    }[id];

    if (data == null) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        pageBuilder: (_, __, ___) => _ComingSoonScreen(
          icon: data.icon,
          title: data.title,
          tagline: data.tagline,
          description: data.description,
          gradientColors: data.colors,
        ),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  // ── SharedPreferences ──────────────────────────────────────────────────────

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_kRecentKey) ?? [];
      if (!mounted) return;
      setState(() {
        _recentSearches.clear();
        _recentSearches.addAll(saved);
      });
    } catch (_) {}
  }

  Future<void> _saveRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kRecentKey, _recentSearches.take(8).toList());
    } catch (_) {}
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadAnimes() async {
    if (!mounted) return;
    setState(() {
      _allAnimes = CatalogStore.instance.getCustomCatalog();
      _isLoading = false;
    });
    _applyFilter();
  }

  // ── Event handlers ─────────────────────────────────────────────────────────

  void _onFocusChange() {
    setState(() => _isFocused = _searchFocus.hasFocus);
    if (_searchFocus.hasFocus) {
      _searchBarAnim.forward();
      _overlayAnim.forward();
    } else {
      _searchBarAnim.reverse();
      _overlayAnim.reverse();
    }
  }

  void _onSearchChanged() {
    final raw = _searchController.text;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() {
        _query = raw.trim();
        _suggestions = _buildSuggestions(_query);
      });
      _applyFilter();
    });
  }

  // ── Trending ranking ────────────────────────────────────────────────────
  // AnimeModel doesn't expose numeric popularity/member counts (only rating
  // and the explicit isTrending flag), so a real trending signal has to lean
  // on isTrending first, then rating as tie-breaker within each group. This
  // replaces the old "rating >= 8.0" filter, which wasn't measuring trending
  // at all — just quality. Swap in real view-count/activity metrics here
  // once the API/model exposes them.
  int _trendingCompare(AnimeModel a, AnimeModel b) {
    if (a.isTrending != b.isTrending) {
      return a.isTrending ? -1 : 1;
    }
    return b.rating.compareTo(a.rating);
  }

  List<AnimeModel> _trendingNow({int limit = 8}) {
    final sorted = List<AnimeModel>.from(_allAnimes)..sort(_trendingCompare);
    return sorted.take(limit).toList();
  }

  void _applyFilter() {
    final q = _query.toLowerCase();
    List<AnimeModel> result = _allAnimes;

    if (_selectedGenre != null) {
      result = result.where((a) => _genresOf(a).contains(_selectedGenre)).toList();
    }

    if (q.isNotEmpty) {
      result = result.where((a) {
        return a.title.toLowerCase().contains(q) ||
            _genresOf(a).any((g) => g.toLowerCase().contains(q)) ||
            a.description.toLowerCase().contains(q);
      }).toList();
    }

    // Rating filter
    if (_minRating > 0) {
      result = result.where((a) => (a.rating ?? 0.0) >= _minRating).toList();
    }

    // Sort
    switch (_sortMode) {
      case _SortMode.rating:
        result = List.from(result)..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      case _SortMode.az:
        result = List.from(result)..sort((a, b) => a.title.compareTo(b.title));
      case _SortMode.trending:
        result = List.from(result)..sort(_trendingCompare);
      case _SortMode.relevant:
        break; // keep API order
    }

    _resultsAnim.reset();
    setState(() => _filtered = result);
    _resultsAnim.forward();
  }

  List<String> _buildSuggestions(String q) {
    if (q.isEmpty) return const [];
    final lower = q.toLowerCase();
    final Set<String> seen = {};
    final List<String> out = [];

    // Title suggestions
    for (final a in _allAnimes) {
      if (a.title.toLowerCase().contains(lower) && seen.add(a.title)) {
        out.add(a.title);
        if (out.length >= 5) break;
      }
    }

    // Genre suggestions
    for (final g in MockDataService.getGenres()) {
      if (g.toLowerCase().contains(lower) && seen.add(g)) {
        out.add(g);
        if (out.length >= 6) break;
      }
    }

    return out.take(6).toList();
  }

  void _submitSearch(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    _searchController.text = trimmed;
    setState(() {
      _query = trimmed;
      _suggestions = const [];
    });
    _applyFilter();
    _addToRecent(trimmed);
    _searchFocus.unfocus();
  }

  void _selectSuggestion(String suggestion) {
    _searchController.text = suggestion;
    _submitSearch(suggestion);
  }

  void _addToRecent(String term) {
    if (term.isEmpty) return;
    setState(() {
      _recentSearches.remove(term);
      _recentSearches.insert(0, term);
      if (_recentSearches.length > 8) _recentSearches.removeLast();
    });
    _saveRecentSearches();
  }

  void _clearAllRecent() {
    setState(() => _recentSearches.clear());
    _saveRecentSearches();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _query = '';
      _suggestions = const [];
    });
    _applyFilter();
  }

  void _selectGenre(String? genre) {
    HapticFeedback.selectionClick();
    setState(() => _selectedGenre = genre == _selectedGenre ? null : genre);
    _applyFilter();
  }

  // Genre selected from the "Browse by Genre" grid card (idle state) rather
  // than a chip. The grid feels like a doorway into a category, so unlike a
  // chip tap (already near the top), this auto-scrolls back to the top after
  // filtering so the transition into the results grid feels intentional
  // instead of a jump-cut to wherever the scroll position happened to be.
  void _selectGenreFromGrid(String genre) {
    _selectGenre(genre);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _dismissOverlay() {
    _searchFocus.unfocus();
    setState(() => _suggestions = const []);
  }

  void _setSortMode(_SortMode mode) {
    if (_sortMode == mode) return;
    HapticFeedback.selectionClick();
    setState(() => _sortMode = mode);
    _applyFilter();
  }

  void _showFilterSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RatingFilterSheet(
        currentMin: _minRating,
        onApply: (val) {
          setState(() => _minRating = val);
          _applyFilter();
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AniVerseTheme.background, // Menggunakan tema Ghibli
      body: GestureDetector(
        onTap: _dismissOverlay,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // ── Ambient glow backdrop ────────────────────────────────────
            // Fixed (non-scrolling) soft color blobs behind everything else.
            // Without this, the liquid-glass panels above (search bar,
            // chips, cards) have nothing but flat solid background to
            // blur, so the frosted effect is technically active but
            // invisible — glass only reads as glass when there's something
            // with color/texture behind it to refract.
            Positioned.fill(
              child: IgnorePointer(
                child: Stack(
                  children: [
                    Positioned(
                      top: -60,
                      left: -40,
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AniVerseTheme.primary.withOpacity(0.20),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 120,
                      right: -60,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AniVerseTheme.accent.withOpacity(0.16),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -80,
                      left: 40,
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AniVerseTheme.glow.withOpacity(0.14),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Main content ────────────────────────────────────────────
            _buildMainContent(),

            // ── Suggestions overlay ─────────────────────────────────────
            if (_suggestions.isNotEmpty && _isFocused)
              _buildSuggestionsOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── App bar + search bar ───────────────────────────────────────
        SliverAppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          pinned: true,
          toolbarHeight: 0,
          expandedHeight: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: _buildSearchBar(),
          ),
        ),

        // ── Genre chips ────────────────────────────────────────────────
        SliverToBoxAdapter(child: _buildGenreChips()),

        // ── Body: state-driven content ─────────────────────────────────
        if (_isLoading)
          const SliverFillRemaining(
            child: _LoadingShimmer(),
          )
        else if (_query.isEmpty && _selectedGenre == null)
          SliverToBoxAdapter(child: _buildIdleState())
        else if (_filtered.isEmpty)
          SliverFillRemaining(
            child: _buildEmptyState(),
          )
        else ...[
          SliverToBoxAdapter(child: _buildSortBar()),
          _buildResultsGrid(),
        ],

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Stack(
      children: [
        // ── Cinematic nebula background ──
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AniVerseTheme.surfaceElevated,
                  AniVerseTheme.surface,
                  AniVerseTheme.background,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        // ── Purple glow top-left ──
        Positioned(
          top: -20, left: -30,
          child: Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AniVerseTheme.primary.withOpacity(0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // ── Pink glow top-right ──
        Positioned(
          top: 0, right: -20,
          child: Container(
            width: 150, height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AniVerseTheme.accent.withOpacity(0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // ── Content ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // EXPLORE label small
                    Text(
                      'すべてのアニメを探索',
                      style: TextStyle(
                        color: AniVerseTheme.accent.withOpacity(0.70),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ShaderMask(
                      shaderCallback: (r) => LinearGradient(
                        colors: [AniVerseTheme.textPrimary, AniVerseTheme.accent],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(r),
                      child: Text(
                        'UNIVERSE',
                        style: TextStyle(
                          color: AniVerseTheme.textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 5,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_allAnimes.length} titles available',
                      style: TextStyle(
                        color: AniVerseTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Filter badge
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_query.isNotEmpty || _selectedGenre != null)
                    _AnimatedPill(
                      label: _filtered.isEmpty
                          ? 'No results'
                          : '${_filtered.length} result${_filtered.length == 1 ? '' : 's'}',
                      color: _filtered.isEmpty ? AniVerseTheme.warning : AniVerseTheme.accent,
                    ),
                  const SizedBox(height: 4),
                  // Decorative star icon
                  GestureDetector(
                    onTap: _showFilterSheet,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _minRating > 0
                            ? AniVerseTheme.accent.withOpacity(0.20)
                            : AniVerseTheme.surfaceElevated,
                        border: Border.all(
                          color: _minRating > 0
                              ? AniVerseTheme.accent
                              : AniVerseTheme.accent.withOpacity(0.30),
                        ),
                        boxShadow: [BoxShadow(color: AniVerseTheme.glow, blurRadius: 12)],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.tune_rounded, color: AniVerseTheme.accent, size: 16),
                          if (_minRating > 0)
                            Positioned(
                              top: 4, right: 4,
                              child: Container(
                                width: 7, height: 7,
                                decoration: BoxDecoration(
                                  color: AniVerseTheme.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // ── Bottom fade ──
        Positioned(
          bottom: 0, left: 0, right: 0,
          height: 24,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, AniVerseTheme.background],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return AnimatedBuilder(
      animation: _searchBarExpand,
      builder: (context, child) {
        return Container(
          height: 64,
          color: Colors.transparent,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: LiquidGlassPill(
            borderRadius: AniVerseTheme.radiusLg,
            padding: EdgeInsets.zero,
            height: 48,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AniVerseTheme.radiusLg),
                border: Border.all(
                  color: _isFocused
                      ? AniVerseTheme.accent.withOpacity(0.55)
                      : Colors.transparent,
                  width: _isFocused ? 1.4 : 1.0,
                ),
                boxShadow: _isFocused
                    ? AniVerseTheme.glowShadow(AniVerseTheme.accent, 0.22)
                    : null,
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(
                    Icons.search_rounded,
                  color: _isFocused
                      ? AniVerseTheme.highlight
                      : AniVerseTheme.textSecondary.withOpacity(0.6),
                  size: 21,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    style: TextStyle(
                      color: AniVerseTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search anime, genre, studio…',
                      hintStyle: TextStyle(
                        color: AniVerseTheme.textSecondary.withOpacity(0.55),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: _submitSearch,
                  ),
                ),
                // ── Clear button ────────────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim,
                    child: child,
                  ),
                  child: _query.isNotEmpty
                      ? GestureDetector(
                          key: const ValueKey('clear'),
                          onTap: _clearSearch,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: AniVerseTheme.accent.withOpacity(0.18),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AniVerseTheme.accent.withOpacity(0.4),
                              ),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              color: AniVerseTheme.highlight,
                              size: 14,
                            ),
                          ),
                        )
                      : const SizedBox(key: ValueKey('empty'), width: 12),
                ),
              ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Suggestions overlay ────────────────────────────────────────────────────

  Widget _buildSuggestionsOverlay() {
    // Pinned below the app bar (header 120 + search bar 64 = 184)
    return Positioned(
      top: 184 + MediaQuery.of(context).padding.top,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _overlayFade,
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 320),
            decoration: BoxDecoration(
              color: AniVerseTheme.surfaceElevated.withOpacity(0.95),
              borderRadius: BorderRadius.circular(AniVerseTheme.radiusLg),
              border: Border.all(color: AniVerseTheme.accent.withOpacity(0.3)),
              boxShadow: AniVerseTheme.glowShadow(AniVerseTheme.accent, 0.25),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AniVerseTheme.radiusLg),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: AniVerseTheme.surface.withOpacity(AniVerseTheme.opacityMedium), // Ganti surfaceSubtle
                  indent: 46,
                ),
                itemBuilder: (context, i) {
                  final s = _suggestions[i];
                  final isGenre = MockDataService.getGenres().contains(s);
                  return _SuggestionTile(
                    label: s,
                    query: _query,
                    icon: isGenre
                        ? Icons.local_movies_rounded
                        : Icons.search_rounded,
                    onTap: () => _selectSuggestion(s),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Genre chips ────────────────────────────────────────────────────────────

  Widget _buildGenreChips() {
    // MockDataService.getGenres() is confirmed to return 7 unique genres
    // (checked directly — no duplicates at the source). This de-dup stays
    // as cheap defensive insurance in case the list ever changes, but it
    // isn't compensating for a real bug.
    final seen = <String>{};
    final genres = MockDataService.getGenres().where((g) {
      final key = g.trim().toLowerCase();
      if (key.isEmpty || seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();

    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: genres.length + 1, // +1 for "All"
        itemBuilder: (context, i) {
          if (i == 0) {
            return _GenreChip(
              label: 'All',
              selected: _selectedGenre == null,
              onTap: () => _selectGenre(null),
            );
          }
          final g = genres[i - 1];
          return _GenreChip(
            label: g,
            selected: _selectedGenre == g,
            onTap: () => _selectGenre(g),
          );
        },
      ),
    );
  }

  // ── Idle state (no query, no genre) ───────────────────────────────────────

  Widget _buildIdleState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UniverseSignalStrip(onSignalTap: _onUniverseSignalTap),
          const SizedBox(height: 18),

          // Trending Now strip
          if (_allAnimes.isNotEmpty) ...[
            _SectionLabel(
              label: 'Trending Sekarang 🔥',
              trailing: TextButton(
                onPressed: () => _setSortMode(_SortMode.trending),
                style: TextButton.styleFrom(
                  foregroundColor: AniVerseTheme.accent,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Lihat semua', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(height: 10),
            _TrendingStrip(
              animes: _trendingNow(limit: 8),
              onTap: (a) {
                _searchController.text = a.title;
                _submitSearch(a.title);
              },
            ),
            const SizedBox(height: 18),
          ],

          // Recent searches
          if (_recentSearches.isNotEmpty) ...[
            _SectionLabel(
              label: 'Recent Searches',
              trailing: TextButton(
                onPressed: _clearAllRecent,
                style: TextButton.styleFrom(
                  foregroundColor: AniVerseTheme.textSecondary.withOpacity(0.7),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Clear all', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches.map((term) {
                return _RecentChip(
                  label: term,
                  onTap: () => _selectSuggestion(term),
                  onDelete: () => setState(() => _recentSearches.remove(term)),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Popular genres header
          const _SectionLabel(label: 'Browse by Genre'),
          const SizedBox(height: 12),
          _buildGenreGrid(),
          const SizedBox(height: 24),

          // All titles preview
          const _SectionLabel(label: 'All Titles'),
          const SizedBox(height: 12),
          _buildAnimeGridInline(_allAnimes),
        ],
      ),
    );
  }

  Widget _buildGenreGrid() {
    // Same defensive de-duplication as _buildGenreChips — keeps this grid
    // in sync with the chip row above and prevents a repeated genre from
    // rendering twice with mismatched accent/icon pairing.
    final seenGrid = <String>{};
    final genres = MockDataService.getGenres().where((g) {
      final key = g.trim().toLowerCase();
      if (key.isEmpty || seenGrid.contains(key)) return false;
      seenGrid.add(key);
      return true;
    }).toList();
    // Mengganti warna hardcode dengan warna Ghibli yang lebih lembut
    const accents = [
      AniVerseTheme.highlight, // Action (or another vibrant Ghibli color)
      AniVerseTheme.primary,    // Adventure
      AniVerseTheme.success,    // Comedy
      AniVerseTheme.accent,     // Drama
      AniVerseTheme.primary,    // Sci-Fi (tetap primary, atau bisa juga teal/biru yang diredam)
      AniVerseTheme.glow,       // Fantasy
      AniVerseTheme.surfaceElevated, // Horror (lebih menonjol dari background)
    ];
    const icons = [
      Icons.local_fire_department_rounded, // Action
      Icons.explore_rounded,               // Adventure
      Icons.sentiment_very_satisfied_rounded, // Comedy
      Icons.theater_comedy_rounded,        // Drama
      Icons.rocket_launch_rounded,         // Sci-Fi
      Icons.auto_fix_high_rounded,         // Fantasy
      Icons.nightlight_round,              // Horror
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.6,
      ),
      itemCount: genres.length,
      itemBuilder: (context, i) {
        final accent = accents[i % accents.length];
        final icon = icons[i % icons.length];
        return _GenreGridCard(
          label: genres[i],
          accent: accent,
          icon: icon,
          onTap: () => _selectGenreFromGrid(genres[i]),
        );
      },
    );
  }

  Widget _buildAnimeGridInline(List<AnimeModel> animes) {
    // Responsive: 2 / 3 / 4 columns
    final width = MediaQuery.of(context).size.width;
    final cols = width < 480 ? 2 : width < 800 ? 3 : 4;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.62,
      ),
      itemCount: animes.length,
      itemBuilder: (context, i) => _StaggeredAnimeCard(
        anime: animes[i],
        index: i,
      ),
    );
  }

  // ── Sort bar ───────────────────────────────────────────────────────────────

  Widget _buildSortBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Row(
        children: [
          // Result count
          Text(
            '${_filtered.length} hasil',
            style: TextStyle(
              color: AniVerseTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_minRating > 0) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                setState(() => _minRating = 0.0);
                _applyFilter();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AniVerseTheme.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AniVerseTheme.accent.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, color: AniVerseTheme.accent, size: 11),
                    const SizedBox(width: 3),
                    Text(
                      '≥${_minRating.toStringAsFixed(1)} ✕',
                      style: TextStyle(
                        color: AniVerseTheme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Spacer(),
          // Sort chips
          ..._SortMode.values.map((mode) => Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _SortChip(
              label: mode.label,
              selected: _sortMode == mode,
              onTap: () => _setSortMode(mode),
            ),
          )),
        ],
      ),
    );
  }

  // ── Results grid (SliverGrid) ──────────────────────────────────────────────

  Widget _buildResultsGrid() {
    final width = MediaQuery.of(context).size.width;
    final cols = width < 480 ? 2 : width < 800 ? 3 : 4;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.62,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => SlideTransition(
            position: _resultsSlide,
            child: FadeTransition(
              opacity: _resultsFade,
              child: _StaggeredAnimeCard(
                anime: _filtered[i],
                index: i,
              ),
            ),
          ),
          childCount: _filtered.length,
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return _EmptyState(
      query: _query,
      genre: _selectedGenre,
      onClearSearch: _clearSearch,
      onClearGenre: () => _selectGenre(null),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ═══════════════════════════════════════════════════════════════════════════════

// ── Suggestion tile ───────────────────────────────────────────────────────────

class _UniversePassport extends StatelessWidget {
  final int totalTitles;
  final ValueChanged<String?> onMoodTap;

  const _UniversePassport({
    required this.totalTitles,
    required this.onMoodTap,
  });

  @override
  Widget build(BuildContext context) {
    final portals = [
      (label: 'Battle Gate', genre: 'Action', icon: Icons.flash_on_rounded),
      (label: 'Soft Escape', genre: 'Drama', icon: Icons.local_florist_rounded),
      (label: 'Magic Route', genre: 'Fantasy', icon: Icons.auto_fix_high_rounded),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AniVerseTheme.surface, AniVerseTheme.background, AniVerseTheme.surfaceElevated],
        ),
        border: Border.all(color: AniVerseTheme.surfaceElevated.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: AniVerseTheme.accent.withOpacity(0.14),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AniVerseTheme.accent, AniVerseTheme.primary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AniVerseTheme.accent.withOpacity(0.25),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Icon(Icons.public_rounded,
                    color: AniVerseTheme.textPrimary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Universe Passport',
                      style: TextStyle(
                        color: AniVerseTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$totalTitles title • mood portal • curated anime lanes',
                      style: TextStyle(
                        color: AniVerseTheme.textSecondary.withOpacity(0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AniVerseTheme.accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AniVerseTheme.accent.withOpacity(0.18)),
                ),
                child: Text(
                  'LIVE',
                  style: TextStyle(
                    color: AniVerseTheme.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: portals.map((portal) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => onMoodTap(portal.genre),
                    borderRadius: BorderRadius.circular(18),
                    child: Ink(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AniVerseTheme.surface.withOpacity(0.72),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AniVerseTheme.surfaceElevated.withOpacity(0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(portal.icon, color: AniVerseTheme.accent, size: 18),
                          const SizedBox(height: 8),
                          Text(
                            portal.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AniVerseTheme.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            portal.genre,
                            style: TextStyle(
                              color: AniVerseTheme.textSecondary.withOpacity(0.7),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _UniverseSignalStrip extends StatelessWidget {
  final ValueChanged<String>? onSignalTap;

  const _UniverseSignalStrip({this.onSignalTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        id: 'mood_radar',
        icon: Icons.radar_rounded,
        title: 'Mood Radar',
        sub: 'Match vibe',
        colors: [AniVerseTheme.accent, AniVerseTheme.glow],
      ),
      (
        id: 'fan_pulse',
        icon: Icons.groups_rounded,
        title: 'Fan Pulse',
        sub: 'Hot rooms',
        colors: [AniVerseTheme.primary, AniVerseTheme.success],
      ),
      (
        id: 'drop_map',
        icon: Icons.diamond_rounded,
        title: 'Drop Map',
        sub: 'Rewards',
        colors: [AniVerseTheme.highlight, AniVerseTheme.accent],
      ),
    ];

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return _SignalCard(
            icon: item.icon,
            title: item.title,
            sub: item.sub,
            gradientColors: item.colors,
            onTap: () {
              HapticFeedback.selectionClick();
              onSignalTap?.call(item.id);
            },
          );
        },
      ),
    );
  }
}

class _SignalCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String sub;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _SignalCard({
    required this.icon,
    required this.title,
    required this.sub,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  State<_SignalCard> createState() => _SignalCardState();
}

class _SignalCardState extends State<_SignalCard> {
  bool _pressed = false;

  void _setPressed(bool v) => setState(() => _pressed = v);

  @override
  Widget build(BuildContext context) {
    final accent = widget.gradientColors.first;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: LiquidGlassPill(
          borderRadius: 22,
          padding: EdgeInsets.zero,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 152,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _pressed ? accent.withOpacity(0.55) : Colors.transparent,
                width: _pressed ? 1.4 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(_pressed ? 0.28 : 0.14),
                  blurRadius: _pressed ? 22 : 18,
                  spreadRadius: _pressed ? 0 : -2,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.gradientColors,
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, color: AniVerseTheme.background, size: 18),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AniVerseTheme.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AniVerseTheme.textSecondary.withOpacity(0.75),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final String label;
  final String query;
  final IconData icon;
  final VoidCallback onTap;

  const _SuggestionTile({
    required this.label,
    required this.query,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Highlight the matching portion
    final lower = label.toLowerCase();
    final qLower = query.toLowerCase();
    final matchStart = lower.indexOf(qLower);

    return InkWell(
      onTap: onTap,
      splashColor: AniVerseTheme.accent.withOpacity(0.1),
      highlightColor: AniVerseTheme.accent.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AniVerseTheme.accent),
            const SizedBox(width: 12),
            Expanded(
              child: matchStart >= 0
                  ? RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: label.substring(0, matchStart),
                            style: TextStyle(
                                color: AniVerseTheme.textSecondary, fontSize: 14),
                          ),
                          TextSpan(
                            text: label.substring(
                                matchStart, matchStart + query.length),
                            style: TextStyle(
                              color: AniVerseTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: label.substring(matchStart + query.length),
                            style: TextStyle(
                                color: AniVerseTheme.textSecondary, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : Text(label,
                      style: TextStyle(color: AniVerseTheme.textSecondary, fontSize: 14)),
            ),
            Icon(Icons.north_west_rounded, size: 14, color: AniVerseTheme.textSecondary.withOpacity(AniVerseTheme.opacityHigh)),
          ],
        ),
      ),
    );
  }
}

// ── Genre chip ────────────────────────────────────────────────────────────────

class _GenreChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GenreChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_GenreChip> createState() => _GenreChipState();
}

class _GenreChipState extends State<_GenreChip> {
  double _scale = 1.0;

  void _setPressed(bool pressed) {
    setState(() => _scale = pressed ? 0.93 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
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
          margin: const EdgeInsets.only(right: 10),
          child: selected
              ? AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AniVerseTheme.accent, AniVerseTheme.highlight],
                    ),
                    borderRadius: BorderRadius.circular(AniVerseTheme.radiusPill),
                    boxShadow: AniVerseTheme.glowShadow(AniVerseTheme.accent, 0.30),
                  ),
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: AniVerseTheme.background,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                )
              : LiquidGlassPill(
                  borderRadius: AniVerseTheme.radiusPill,
                  compact: true,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: AniVerseTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Recent search chip ────────────────────────────────────────────────────────

class _RecentChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RecentChip({
    required this.label,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LiquidGlassPill(
        borderRadius: 20,
        compact: true,
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 13, color: AniVerseTheme.textSecondary.withOpacity(0.7)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: AniVerseTheme.textPrimary, fontSize: 13),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, size: 12, color: AniVerseTheme.textSecondary.withOpacity(0.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Genre grid card ───────────────────────────────────────────────────────────

class _GenreGridCard extends StatefulWidget {
  final String label;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  const _GenreGridCard({
    required this.label,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_GenreGridCard> createState() => _GenreGridCardState();
}

class _GenreGridCardState extends State<_GenreGridCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: LiquidGlassPill(
          borderRadius: AniVerseTheme.radiusLg,
          padding: EdgeInsets.zero,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AniVerseTheme.radiusLg),
              border: Border.all(
                color: widget.accent.withOpacity(_pressed ? 0.55 : 0.0),
                width: _pressed ? 1.3 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withOpacity(_pressed ? 0.24 : AniVerseTheme.opacityLow),
                  blurRadius: _pressed ? 18 : 12,
                  spreadRadius: _pressed ? 0 : -2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  // Icon container — gradient, not flat
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.accent.withOpacity(0.30),
                          widget.accent.withOpacity(0.10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AniVerseTheme.radiusSm),
                      border: Border.all(color: widget.accent.withOpacity(0.35), width: 0.8),
                      boxShadow: _pressed
                          ? [BoxShadow(color: widget.accent.withOpacity(0.35), blurRadius: 8)]
                          : null,
                    ),
                    child: Center(
                      child: Icon(widget.icon, color: widget.accent, size: 17),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: AniVerseTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  AnimatedSlide(
                    offset: _pressed ? const Offset(0.3, 0) : Offset.zero,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: widget.accent.withOpacity(_pressed ? 0.9 : 0.50),
                      size: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Staggered anime card wrapper ──────────────────────────────────────────────

class _StaggeredAnimeCard extends StatefulWidget {
  final AnimeModel anime;
  final int index;

  const _StaggeredAnimeCard({required this.anime, required this.index});

  @override
  State<_StaggeredAnimeCard> createState() => _StaggeredAnimeCardState();
}

class _StaggeredAnimeCardState extends State<_StaggeredAnimeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );

    // Stagger based on index (max 400ms total offset)
    final delay = Duration(milliseconds: (widget.index * 40).clamp(0, 400));
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: AnimeCard(anime: widget.anime),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatefulWidget {
  final String query;
  final String? genre;
  final VoidCallback onClearSearch;
  final VoidCallback onClearGenre;

  const _EmptyState({
    required this.query,
    required this.genre,
    required this.onClearSearch,
    required this.onClearGenre,
  });

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AniVerseTheme.accent.withOpacity(AniVerseTheme.opacityLow),
                    border: Border.all(color: AniVerseTheme.accent.withOpacity(AniVerseTheme.opacityMedium)),
                    boxShadow: [
                      BoxShadow(color: AniVerseTheme.glow, blurRadius: 28),
                    ],
                  ),
                  child: Icon(
                    Icons.search_off_rounded,
                    color: AniVerseTheme.accent,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  'No results found',
                  style: TextStyle(
                    color: AniVerseTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                // Subtitle
                Text(
                  widget.query.isNotEmpty && widget.genre != null
                      ? 'No "${widget.query}" in ${widget.genre}'
                      : widget.query.isNotEmpty
                          ? '"${widget.query}" didn\'t match anything'
                          : 'No anime in the ${widget.genre} genre',
                  style: TextStyle(color: AniVerseTheme.textSecondary, fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Actions
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    if (widget.query.isNotEmpty)
                      _EmptyActionButton(
                        icon: Icons.close_rounded,
                        label: 'Clear search',
                        onTap: widget.onClearSearch,
                        primary: true,
                      ),
                    if (widget.genre != null)
                      _EmptyActionButton(
                        icon: Icons.filter_alt_off_rounded,
                        label: 'Clear genre',
                        onTap: widget.onClearGenre,
                        primary: widget.query.isEmpty,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _EmptyActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          color: primary ? AniVerseTheme.accent : AniVerseTheme.surfaceElevated.withOpacity(0.06),
          borderRadius: BorderRadius.circular(AniVerseTheme.radiusXl),
          border: Border.all(
            color: primary ? AniVerseTheme.accent : AniVerseTheme.surfaceElevated.withOpacity(0.1),
          ),
          boxShadow: primary
              ? [BoxShadow(color: AniVerseTheme.glow, blurRadius: 12)]
              : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AniVerseTheme.textPrimary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: AniVerseTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loading shimmer ───────────────────────────────────────────────────────────

class _LoadingShimmer extends StatefulWidget {
  const _LoadingShimmer();

  @override
  State<_LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<_LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.62,
            ),
            itemCount: 6,
            itemBuilder: (context, i) {
              final delay = (i * 0.15) % 1.0;
              final shimmerValue = ((_anim.value - delay + 1.0) % 1.0);
              final opacity = 0.04 + 0.06 * shimmerValue;
              return Container(
                decoration: BoxDecoration(
                  color: AniVerseTheme.surface.withOpacity(opacity),
                  borderRadius: BorderRadius.circular(AniVerseTheme.radiusMd),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Animated result-count pill ────────────────────────────────────────────────

class _AnimatedPill extends StatelessWidget {
  final String label;
  final Color color;

  const _AnimatedPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AniVerseTheme.radiusMd),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Trending strip ────────────────────────────────────────────────────────────

class _TrendingStrip extends StatelessWidget {
  final List<AnimeModel> animes;
  final ValueChanged<AnimeModel> onTap;

  const _TrendingStrip({required this.animes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (animes.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 178,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(right: 4),
        itemCount: animes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          return _TrendingCard(
            anime: animes[i],
            rank: i + 1,
            onTap: () => onTap(animes[i]),
          );
        },
      ),
    );
  }
}

class _TrendingCard extends StatefulWidget {
  final AnimeModel anime;
  final int rank;
  final VoidCallback onTap;

  const _TrendingCard({required this.anime, required this.rank, required this.onTap});

  @override
  State<_TrendingCard> createState() => _TrendingCardState();
}

class _TrendingCardState extends State<_TrendingCard> {
  bool _pressed = false;

  void _setPressed(bool v) => setState(() => _pressed = v);

  // Top-3 dapat gradient badge emas/perak/perunggu; sisanya gradient accent standar.
  List<Color> get _rankColors {
    switch (widget.rank) {
      case 1:
        return [const Color(0xFFFFD76A), AniVerseTheme.accent];
      case 2:
        return [const Color(0xFFE3E8E8), AniVerseTheme.primary];
      case 3:
        return [const Color(0xFFE0A667), AniVerseTheme.glow];
      default:
        return [AniVerseTheme.accent, AniVerseTheme.glow];
    }
  }

  @override
  Widget build(BuildContext context) {
    final anime = widget.anime;
    final rankColors = _rankColors;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox(
          width: 118,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 118,
                height: 142,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _pressed
                        ? rankColors.first.withOpacity(0.7)
                        : Colors.transparent,
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: rankColors.first.withOpacity(_pressed ? 0.32 : 0.16),
                      blurRadius: _pressed ? 20 : 14,
                      spreadRadius: -2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      anime.imageUrl.isNotEmpty
                          ? ProxiedNetworkImage.forUrl(
                              url: anime.imageUrl,
                              title: anime.title,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              fallback: _TrendingPlaceholder(title: anime.title),
                            )
                          : _TrendingPlaceholder(title: anime.title),

                      // Bottom scrim — keeps rating pill readable over bright posters
                      Positioned(
                        left: 0, right: 0, bottom: 0,
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                AniVerseTheme.background.withOpacity(0.85),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Rank badge — gradient, top-3 gets a distinct glow color
                      Positioned(
                        top: 7, left: 7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: rankColors),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(color: rankColors.first.withOpacity(0.55), blurRadius: 10),
                            ],
                          ),
                          child: Text(
                            '#${widget.rank}',
                            style: TextStyle(
                              color: AniVerseTheme.background,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),

                      // Rating pill
                      if (anime.rating != null)
                        Positioned(
                          bottom: 7, right: 7,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: AniVerseTheme.background.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AniVerseTheme.highlight.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded, color: AniVerseTheme.highlight, size: 11),
                                const SizedBox(width: 2),
                                Text(
                                  anime.rating!.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: AniVerseTheme.textPrimary,
                                    fontSize: 10.5,
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
              const SizedBox(height: 6),
              Text(
                anime.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AniVerseTheme.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendingShimmer extends StatefulWidget {
  final String title;
  const _TrendingShimmer({required this.title});

  @override
  State<_TrendingShimmer> createState() => _TrendingShimmerState();
}

class _TrendingShimmerState extends State<_TrendingShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, -1),
              end: Alignment(1 + 2 * t, 1),
              colors: [
                AniVerseTheme.surface,
                AniVerseTheme.surfaceElevated,
                AniVerseTheme.surface,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TrendingPlaceholder extends StatelessWidget {
  final String title;
  const _TrendingPlaceholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AniVerseTheme.surfaceElevated, AniVerseTheme.surface],
        ),
      ),
      child: Center(
        child: Text(
          title.isNotEmpty ? title[0] : '?',
          style: TextStyle(
            color: AniVerseTheme.accent,
            fontSize: 32,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

// ── Rating filter bottom sheet ─────────────────────────────────────────────────

class _RatingFilterSheet extends StatefulWidget {
  final double currentMin;
  final ValueChanged<double> onApply;

  const _RatingFilterSheet({required this.currentMin, required this.onApply});

  @override
  State<_RatingFilterSheet> createState() => _RatingFilterSheetState();
}

class _RatingFilterSheetState extends State<_RatingFilterSheet> {
  late double _value;

  static const _presets = [0.0, 7.0, 7.5, 8.0, 8.5, 9.0];

  @override
  void initState() {
    super.initState();
    _value = widget.currentMin;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AniVerseTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AniVerseTheme.surfaceElevated.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: AniVerseTheme.glow.withOpacity(0.3), blurRadius: 32, offset: const Offset(0, -8)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AniVerseTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Row(
            children: [
              Icon(Icons.tune_rounded, color: AniVerseTheme.accent, size: 20),
              const SizedBox(width: 10),
              Text(
                'Filter Rating',
                style: TextStyle(
                  color: AniVerseTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (_value > 0)
                GestureDetector(
                  onTap: () => setState(() => _value = 0.0),
                  child: Text(
                    'Reset',
                    style: TextStyle(
                      color: AniVerseTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Current value display
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _value > 0
                    ? AniVerseTheme.accent.withOpacity(0.15)
                    : AniVerseTheme.surfaceElevated.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _value > 0
                      ? AniVerseTheme.accent.withOpacity(0.5)
                      : AniVerseTheme.surfaceElevated.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded,
                      color: _value > 0 ? AniVerseTheme.accent : AniVerseTheme.textSecondary,
                      size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _value > 0 ? '≥ ${_value.toStringAsFixed(1)}' : 'Semua rating',
                    style: TextStyle(
                      color: _value > 0 ? AniVerseTheme.accent : AniVerseTheme.textSecondary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AniVerseTheme.accent,
              inactiveTrackColor: AniVerseTheme.surfaceElevated,
              thumbColor: AniVerseTheme.accent,
              overlayColor: AniVerseTheme.accent.withOpacity(0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              trackHeight: 4,
            ),
            child: Slider(
              value: _value,
              min: 0,
              max: 9.5,
              divisions: 19,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _value = v < 0.3 ? 0.0 : v);
              },
            ),
          ),

          // Preset chips
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _presets.map((p) {
              final selected = (_value - p).abs() < 0.01;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _value = p);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected
                        ? AniVerseTheme.accent.withOpacity(0.18)
                        : AniVerseTheme.surfaceElevated.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? AniVerseTheme.accent
                          : AniVerseTheme.surfaceElevated.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    p == 0.0 ? 'Semua' : '≥ ${p.toStringAsFixed(1)}',
                    style: TextStyle(
                      color: selected ? AniVerseTheme.accent : AniVerseTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Apply button
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () {
                widget.onApply(_value);
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AniVerseTheme.accent, AniVerseTheme.primary],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: AniVerseTheme.glow, blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: Center(
                  child: Text(
                    'Terapkan Filter',
                    style: TextStyle(
                      color: AniVerseTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sort chip ──────────────────────────────────────────────────────────────

class _SortChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({required this.label, required this.selected, required this.onTap});

  @override
  State<_SortChip> createState() => _SortChipState();
}

class _SortChipState extends State<_SortChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: selected
            ? AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AniVerseTheme.accent, AniVerseTheme.glow]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: AniVerseTheme.accent.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: AniVerseTheme.background,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : LiquidGlassPill(
                borderRadius: 20,
                compact: true,
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: AniVerseTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final Widget? trailing;

  const _SectionLabel({required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AniVerseTheme.accent,
            borderRadius: BorderRadius.circular(AniVerseTheme.radiusSm),
            boxShadow: [BoxShadow(color: AniVerseTheme.glow, blurRadius: 6)],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: AniVerseTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _CustomCatalogCard extends StatelessWidget {
  final VoidCallback onTap;

  const _CustomCatalogCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LiquidGlassPill(
      borderRadius: 24,
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AniVerseTheme.accent.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AniVerseTheme.accent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.video_collection_rounded,
                      color: AniVerseTheme.accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Katalog Anime Kustom',
                          style: TextStyle(
                            color: AniVerseTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kelola anime buatanmu sendiri & tonton dengan link streaming kustom!',
                          style: TextStyle(
                            color: AniVerseTheme.textSecondary.withOpacity(0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AniVerseTheme.accent,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Coming Soon destination screen ────────────────────────────────────────
// Landing screen for Universe Signal features (Mood Radar / Fan Pulse /
// Drop Map) that don't have real functionality yet. Presented as a proper
// screen instead of a snackbar so the tap feels like it leads somewhere —
// glowing icon badge, gradient matching the source card, notify-me action,
// and a close button. Swap the body out for the real feature when ready.
class _ComingSoonScreen extends StatefulWidget {
  final IconData icon;
  final String title;
  final String tagline;
  final String description;
  final List<Color> gradientColors;

  const _ComingSoonScreen({
    required this.icon,
    required this.title,
    required this.tagline,
    required this.description,
    required this.gradientColors,
  });

  @override
  State<_ComingSoonScreen> createState() => _ComingSoonScreenState();
}

class _ComingSoonScreenState extends State<_ComingSoonScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  bool _notifyMe = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _toggleNotify() {
    HapticFeedback.selectionClick();
    setState(() => _notifyMe = !_notifyMe);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _notifyMe
              ? 'Oke, kamu bakal dikabarin pas ${widget.title} rilis!'
              : 'Dibatalkan — nggak apa, kamu bisa balik kapan aja.',
        ),
        backgroundColor: AniVerseTheme.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Backdrop ──────────────────────────────────────────────────
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AniVerseTheme.surfaceElevated,
                      AniVerseTheme.background,
                    ],
                  ),
                ),
              ),
            ),

            // ── Close button ──────────────────────────────────────────────
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                color: AniVerseTheme.textSecondary,
                style: IconButton.styleFrom(
                  backgroundColor: AniVerseTheme.surface.withOpacity(0.6),
                  shape: const CircleBorder(),
                ),
              ),
            ),

            // ── Content ───────────────────────────────────────────────────
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pulsing icon badge
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (context, child) {
                        final t = _pulseCtrl.value;
                        return Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: widget.gradientColors,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: widget.gradientColors.first
                                    .withOpacity(0.25 + t * 0.25),
                                blurRadius: 24 + t * 20,
                                spreadRadius: 2 + t * 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.icon,
                            color: Colors.white,
                            size: 48,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 28),

                    // Badge label
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: widget.gradientColors.first.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: widget.gradientColors.first.withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        'SEGERA HADIR',
                        style: TextStyle(
                          color: widget.gradientColors.first,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AniVerseTheme.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.tagline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: widget.gradientColors.first,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      widget.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AniVerseTheme.textSecondary.withOpacity(0.85),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Notify-me toggle button
                    GestureDetector(
                      onTap: _toggleNotify,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: _notifyMe
                              ? null
                              : LinearGradient(colors: widget.gradientColors),
                          color: _notifyMe
                              ? AniVerseTheme.surface
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          border: _notifyMe
                              ? Border.all(
                                  color: widget.gradientColors.first
                                      .withOpacity(0.5),
                                )
                              : null,
                          boxShadow: _notifyMe
                              ? []
                              : [
                                  BoxShadow(
                                    color: widget.gradientColors.first
                                        .withOpacity(0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _notifyMe
                                  ? Icons.notifications_active_rounded
                                  : Icons.notifications_none_rounded,
                              color: _notifyMe
                                  ? widget.gradientColors.first
                                  : Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _notifyMe ? 'Bakal dikabarin' : 'Kabari aku',
                              style: TextStyle(
                                color: _notifyMe
                                    ? widget.gradientColors.first
                                    : Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Balik ke Explore',
                        style: TextStyle(
                          color: AniVerseTheme.textSecondary.withOpacity(0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
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
