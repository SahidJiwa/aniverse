// home_screen.dart â€” AniVerse Cinematic Universe Pass
// Prompt #8 â€” "damn" not "nice dashboard"

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'anime_api_service.dart';
import 'catalog_store.dart';
import 'mock_data_service.dart';
import 'anime_model.dart';
import 'proxied_network_image.dart';
import 'anime_detail_screen.dart';
import 'app_theme.dart';
import 'watch_screen.dart';
import 'recommendation_service.dart';
import 'continue_watching_model.dart';
import 'explore_screen.dart';
import 'premium_pass_screen.dart';
import 'jadwal_screen.dart';
import 'library_screen.dart';
import 'widgets/liquid_glass.dart';

const _kBg = AppTheme.background;
const _kPurple = AppTheme.highlight;

// ─── SAFE ASSET PNG ─────────────────────────────────────────────────────────
// Rectangular counterpart to _SafeAssetAvatar — for character art, item
// renders, and cover thumbnails that aren't circular avatars. Fails silently
// (renders nothing, not Flutter's broken-image icon) if the asset is missing,
// so a section can ship its PNG spec now and have the art dropped in later
// without breaking the build.
class _SafeAssetPng extends StatefulWidget {
  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  const _SafeAssetPng({
    required this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  });

  @override
  State<_SafeAssetPng> createState() => _SafeAssetPngState();
}

class _SafeAssetPngState extends State<_SafeAssetPng> {
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    return Image.asset(
      widget.assetPath,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
      errorBuilder: (context, error, stackTrace) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _failed = true);
        });
        return const SizedBox.shrink();
      },
    );
  }
}

// ─── SAFE ASSET AVATAR ──────────────────────────────────────────────────────
// Wraps an AssetImage in a circle, falling back to a gradient + icon if the
// asset fails to load (missing file, bad pubspec declaration, typo, etc.)
// instead of showing Flutter's default broken-image icon.
class _SafeAssetAvatar extends StatefulWidget {
  final String assetPath;
  final double size;
  final Color borderColor;
  final double borderWidth;
  const _SafeAssetAvatar({
    required this.assetPath,
    required this.size,
    this.borderColor = AppTheme.accent,
    this.borderWidth = 1.5,
  });

  @override
  State<_SafeAssetAvatar> createState() => _SafeAssetAvatarState();
}

class _SafeAssetAvatarState extends State<_SafeAssetAvatar> {
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.borderColor,
          width: widget.borderWidth,
        ),
        gradient: _failed
            ? const LinearGradient(colors: [AppTheme.accent, _kPurple])
            : null,
        image: _failed
            ? null
            : DecorationImage(
                image: AssetImage(widget.assetPath),
                fit: BoxFit.cover,
                onError: (error, stackTrace) {
                  // Defer setState to avoid calling it mid-build.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _failed = true);
                  });
                },
              ),
      ),
      child: _failed
          ? Icon(
              Icons.person_rounded,
              color: AppTheme.surfaceElevated,
              size: widget.size * 0.55,
            )
          : null,
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class HomeScreen extends StatefulWidget {
  /// Lets Home's compact summary cards (Komunitas/Toko ringkasan, etc.)
  /// switch MainWrapper's bottom-nav tab directly (e.g. jump to Community
  /// or Vault) instead of duplicating those screens' content here.
  final ValueChanged<int>? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<AnimeModel> _topAnimes = const [];
  List<AnimeModel> _seasonalAnimes = const [];
  // True until the first fetch (success or failure) resolves for each
  // source. The skeleton UI reads _isInitialLoading (both true) to decide
  // whether to render shimmer placeholders instead of real sections.
  bool _topLoading = true;
  bool _seasonalLoading = true;
  bool get _isInitialLoading => _topLoading && _seasonalLoading;

  int _currentPage = 0;
  Timer? _heroTimer;

  late AnimationController _zoomCtrl;
  late Animation<double> _zoomAnim;
  late AnimationController _particleCtrl;
  late ScrollController _scrollCtrl;

  // ── Tahap 3: overlay panel state ──
  bool _showSearch = false;
  bool _showNotifications = false;
  bool _showProfileMenu = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // ── Recent search history — persisted so it survives app restarts, same
  // pattern as aniverse_vault_gems/aniverse_vault_purchased_items. Most
  // recent first, capped at 8 so the empty-query state doesn't get noisy.
  static const _kRecentSearchesKey = 'aniverse_home_recent_searches';
  List<String> _recentSearches = [];

  // ── Auto-hide header on scroll ──
  bool _headerVisible = true;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _zoomCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
    _zoomAnim = Tween<double>(
      begin: 1.0,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _zoomCtrl, curve: Curves.easeInOut));
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _scrollCtrl = ScrollController();
    _scrollCtrl.addListener(_onScrollForHeader);
    // Hero auto-carousel — cycles through top-rated seasonal every 5s
    _heroTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() => _currentPage++);
    });
    _loadTopAnime();
    _loadSeasonalAnime();
    _loadRecentSearches();
    CatalogStore.instance.addListener(_onCatalogChanged);
    MockDataService.favoritesNotifier.addListener(_onUserDataChanged);
    MockDataService.recentlyWatchedNotifier.addListener(_onUserDataChanged);
    MockDataService.continueWatchingNotifier.addListener(_onUserDataChanged);
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _scrollCtrl.removeListener(_onScrollForHeader);
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _zoomCtrl.dispose();
    _particleCtrl.dispose();
    CatalogStore.instance.removeListener(_onCatalogChanged);
    MockDataService.favoritesNotifier.removeListener(_onUserDataChanged);
    MockDataService.recentlyWatchedNotifier.removeListener(_onUserDataChanged);
    MockDataService.continueWatchingNotifier.removeListener(_onUserDataChanged);
    super.dispose();
  }

  void _onCatalogChanged() {
    if (mounted) setState(() {});
  }

  void _onUserDataChanged() {
    if (_topAnimes.isNotEmpty) _computeRecommendations();
  }

  /// Hides the top header when scrolling down, reveals it when scrolling up
  /// or near the very top. Small threshold avoids flicker on tiny scrolls.
  void _onScrollForHeader() {
    if (!_scrollCtrl.hasClients) return;
    final offset = _scrollCtrl.offset;
    final delta = offset - _lastScrollOffset;

    if (offset <= 12) {
      if (!_headerVisible) setState(() => _headerVisible = true);
    } else if (delta > 6 && _headerVisible) {
      setState(() => _headerVisible = false);
    } else if (delta < -6 && !_headerVisible) {
      setState(() => _headerVisible = true);
    }
    _lastScrollOffset = offset;
  }

  // ── Recent search history ──────────────────────────────────────────────
  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_kRecentSearchesKey) ?? [];
      if (!mounted) return;
      setState(() => _recentSearches = saved);
    } catch (_) {
      // Non-fatal — search just opens with an empty recent list.
    }
  }

  Future<void> _saveRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kRecentSearchesKey, _recentSearches);
    } catch (_) {}
  }

  // Called when a search result is tapped (not on every keystroke) — mirrors
  // how most apps only commit a search to history once it leads somewhere.
  void _addRecentSearch(String term) {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _recentSearches.removeWhere(
        (s) => s.toLowerCase() == trimmed.toLowerCase(),
      );
      _recentSearches.insert(0, trimmed);
      if (_recentSearches.length > 8) {
        _recentSearches = _recentSearches.sublist(0, 8);
      }
    });
    _saveRecentSearches();
  }

  void _removeRecentSearch(String term) {
    setState(() => _recentSearches.remove(term));
    _saveRecentSearches();
  }

  void _clearRecentSearches() {
    setState(() => _recentSearches = []);
    _saveRecentSearches();
  }

  void _computeRecommendations() {
    final seen = <String>{};
    final pool = <AnimeModel>[];
    for (final a in [
      ..._topAnimes,
      ..._seasonalAnimes,
      ...MockDataService.recentlyWatchedNotifier.value,
      ...MockDataService.favoritesNotifier.value,
    ]) {
      if (seen.add(a.id)) pool.add(a);
    }
    RecommendationService.compute(
      candidates: pool,
      favorites: MockDataService.favoritesNotifier.value,
      recentlyViewed: MockDataService.recentlyWatchedNotifier.value,
      continueWatchingIds: MockDataService.continueWatchingNotifier.value
          .map((c) => c.animeId)
          .toList(),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadTopAnime() async {
    try {
      final a = await AnimeApiService.fetchTopAnime();
      if (!mounted) return;
      setState(() {
        _topAnimes = a;
        _topLoading = false;
      });
      _computeRecommendations();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _topAnimes = MockDataService.getMockAnimes();
        _topLoading = false;
      });
      _computeRecommendations();
    }
  }

  Future<void> _loadSeasonalAnime() async {
    try {
      final a = await AnimeApiService.fetchCurrentSeasonAnime();
      if (!mounted) return;
      setState(() {
        _seasonalAnimes = a;
        _seasonalLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _seasonalAnimes = const [];
        _seasonalLoading = false;
      });
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Selamat pagi';
    if (h < 17) return 'Selamat siang';
    if (h < 21) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context) {
    final src = CatalogStore.instance.getCustomCatalog();
    final heroList = src;
    final featured = heroList.isNotEmpty
        ? heroList[_currentPage % heroList.length]
        : null;

    final liveAnimes = CatalogStore.instance.getCustomCatalog();

    final mq = MediaQuery.of(context);
    final safeTop = mq.padding.top;

    final double kTopRailH = 56.0 + safeTop;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
          // L0 â€” UNIVERSE BACKGROUND
          // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _particleCtrl,
                builder: (_, __) => CustomPaint(
                  painter: _UniverseBackgroundPainter(_particleCtrl.value),
                ),
              ),
            ),
          ),

          // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
          // L1 â€” SAKURA PARTICLES
          // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([_particleCtrl, _scrollCtrl]),
                builder: (_, __) => CustomPaint(
                  painter: _SakuraPainter(
                    _particleCtrl.value,
                    parallax: _scrollCtrl.hasClients
                        ? _scrollCtrl.offset * 0.12
                        : 0,
                  ),
                ),
              ),
            ),
          ),

          // L2 — V5 HOME (scrollable, 8 sections)
          Positioned.fill(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(
                top: (_headerVisible ? kTopRailH : safeTop + 8) + 12,
                left: 16,
                right: 16,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                child: _isInitialLoading
                    ? const _HomeLobbySkeleton(key: ValueKey('skeleton'))
                    : _HomeLobbyV4(
                        key: const ValueKey('loaded'),
                        greeting: _greeting(),
                        featured: featured,
                        liveAnimes: liveAnimes,
                        scrollCtrl: _scrollCtrl,
                        onNavigateToTab: widget.onNavigateToTab,
                        onSearch: () => setState(() {
                          _showSearch = true;
                          _showNotifications = false;
                          _showProfileMenu = false;
                        }),
                        onWatch: featured == null
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => WatchScreen(
                                    anime: featured,
                                    initialEpisodeIndex: 0,
                                  ),
                                ),
                              ),
                        onDetail: featured == null
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AnimeDetailScreen(anime: featured),
                                ),
                              ),
                      ),
              ),
            ),
          ),

          // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
          // L8 â€” TOP RAIL (Floating Header)
          // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: kTopRailH,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              offset: _headerVisible ? Offset.zero : const Offset(0, -1),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _headerVisible ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_headerVisible,
                  child: _TopRail(
                    safeTop: safeTop,
                    notificationCount: 3,
                    onSearch: () => setState(() {
                      _showSearch = !_showSearch;
                      _showNotifications = false;
                      _showProfileMenu = false;
                    }),
                    onNotification: () => setState(() {
                      _showNotifications = !_showNotifications;
                      _showSearch = false;
                      _showProfileMenu = false;
                    }),
                    onAvatar: () => setState(() {
                      _showProfileMenu = !_showProfileMenu;
                      _showSearch = false;
                      _showNotifications = false;
                    }),
                  ),
                ),
              ),
            ),
          ),

          // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
          // L9 â€” SEARCH OVERLAY (Tahap 3)
          // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_showSearch,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.97, end: 1.0).animate(anim),
                    child: child,
                  ),
                ),
                child: _showSearch
                    ? _SearchOverlay(
                        key: const ValueKey('search-on'),
                        topInset: kTopRailH,
                        controller: _searchCtrl,
                        animeList: liveAnimes,
                        onQueryChanged: (q) => setState(() => _searchQuery = q),
                        query: _searchQuery,
                        recentSearches: _recentSearches,
                        onRecentTap: (term) {
                          _searchCtrl.text = term;
                          setState(() => _searchQuery = term);
                        },
                        onRemoveRecent: _removeRecentSearch,
                        onClearRecent: _clearRecentSearches,
                        onClose: () => setState(() {
                          _showSearch = false;
                          _searchCtrl.clear();
                          _searchQuery = '';
                        }),
                        onResultTap: (anime) {
                          _addRecentSearch(anime.title);
                          setState(() {
                            _showSearch = false;
                            _searchCtrl.clear();
                            _searchQuery = '';
                          });
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => AnimeDetailScreen(anime: anime),
                            ),
                          );
                        },
                      )
                    : const SizedBox.shrink(key: ValueKey('search-off')),
              ),
            ),
          ),

          // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
          // L9 â€” NOTIFICATION PANEL (Tahap 3)
          // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_showNotifications,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.97, end: 1.0).animate(anim),
                    child: child,
                  ),
                ),
                child: _showNotifications
                    ? _NotificationPanel(
                        key: const ValueKey('notif-on'),
                        topInset: kTopRailH,
                        onClose: () =>
                            setState(() => _showNotifications = false),
                      )
                    : const SizedBox.shrink(key: ValueKey('notif-off')),
              ),
            ),
          ),

          // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
          // L9 â€” PROFILE MENU (Tahap 3)
          // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_showProfileMenu,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.97, end: 1.0).animate(anim),
                    child: child,
                  ),
                ),
                child: _showProfileMenu
                    ? _ProfileMenu(
                        key: const ValueKey('profile-on'),
                        topInset: kTopRailH,
                        onClose: () => setState(() => _showProfileMenu = false),
                      )
                    : const SizedBox.shrink(key: ValueKey('profile-off')),
              ),
            ),
          ),

          // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
          // L10 â€” TOP EDGE BLOOM
          // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _particleCtrl,
                  builder: (_, __) {
                    final breath =
                        (math.sin(_particleCtrl.value * math.pi * 2) + 1) / 2;
                    return Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppTheme.accent.withValues(
                              alpha: 0.16 + breath * 0.10,
                            ),
                            _kPurple.withValues(alpha: 0.12 + breath * 0.07),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ PHASE_1_PRESERVED â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Widgets below are intentionally NOT rendered in Phase 1.
  // Phase 2 will pick them up zone by zone.
  // Do NOT delete. Do NOT modify.
  //
  // PRESERVED_RENDER_CALLS:
  //
  // ProtagonistZone (Phase 2):
  //   _CinematicHero(
  //     anime: featured,
  //     zoomAnim: _zoomAnim,
  //     scrollCtrl: _scrollCtrl,   // parallax to be removed in Phase 2
  //     pageIndex: _currentPage,
  //     total: heroList.length,
  //     onWatch: () => Navigator.of(context).push(MaterialPageRoute(
  //         builder: (_) => WatchScreen(anime: featured!, initialEpisodeIndex: 0))),
  //     onDetail: () => Navigator.of(context).push(MaterialPageRoute(
  //         builder: (_) => AnimeDetailScreen(anime: featured!))),
  //   )
  //
  // WorldPulse (Phase 2):
  //   const _AnimeWorldSection()    // data: _rooms, _friendEvents
  //
  // Community (removed per HOME_V4_FINAL â€” do not restore):
  //   const _CommunitySection()
  //
  // END PHASE_1_PRESERVED
}

// ─── Skeleton Loading State ──────────────────────────────────────────────────
// Shown in place of _HomeLobbyV4 while both the top-anime and seasonal-anime
// fetches are still in flight. Mirrors the real layout's section order and
// approximate sizes so there's no layout jump when the real content swaps in.

/// Base shimmer building block: a rounded box that sweeps a soft
/// light-to-dark gradient left-to-right on a loop.
class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        // Sweeps from -1.5..1.5 so the highlight fully enters/exits the box
        // on each loop instead of popping in at the edge.
        final t = _ctrl.value * 3.0 - 1.5;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(t - 0.3, 0),
              end: Alignment(t + 0.3, 0),
              colors: [
                Colors.white.withValues(alpha: 0.05),
                Colors.white.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A skeleton section label — mimics _SectionLabel's icon+text silhouette.
class _SkeletonSectionLabel extends StatelessWidget {
  const _SkeletonSectionLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ShimmerBox(
          width: 20,
          height: 20,
          borderRadius: BorderRadius.circular(6),
        ),
        const SizedBox(width: 8),
        _ShimmerBox(
          width: 140,
          height: 14,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

/// A horizontal row of skeleton cards, used for Today Airing / Trending /
/// Baru Ditambahkan style sections.
class _SkeletonCardRow extends StatelessWidget {
  final double cardWidth;
  final double cardHeight;
  final int count;

  const _SkeletonCardRow({
    this.cardWidth = 130,
    this.cardHeight = 190,
    this.count = 4,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _ShimmerBox(
          width: cardWidth,
          height: cardHeight,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _HomeLobbySkeleton extends StatelessWidget {
  const _HomeLobbySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // ── Hero banner ──
        _ShimmerBox(
          width: double.infinity,
          height: 360,
          borderRadius: BorderRadius.circular(24),
        ),
        const SizedBox(height: 18),

        // ── Premium Pass ──
        _ShimmerBox(
          width: double.infinity,
          height: 84,
          borderRadius: BorderRadius.circular(20),
        ),
        const SizedBox(height: 18),

        // ── Continue Watching ──
        const _SkeletonSectionLabel(),
        const SizedBox(height: 10),
        _ShimmerBox(
          width: double.infinity,
          height: 160,
          borderRadius: BorderRadius.circular(18),
        ),
        const SizedBox(height: 18),

        // ── Tayang Hari Ini ──
        const _SkeletonSectionLabel(),
        const SizedBox(height: 10),
        const _SkeletonCardRow(),
        const SizedBox(height: 18),

        // ── Trending ──
        const _SkeletonSectionLabel(),
        const SizedBox(height: 10),
        const _SkeletonCardRow(count: 5),
        const SizedBox(height: 18),

        // ── Baru Ditambahkan ──
        const _SkeletonSectionLabel(),
        const SizedBox(height: 10),
        const _SkeletonCardRow(),
        const SizedBox(height: 18),

        // ── Dunia AniVerse ──
        const _SkeletonSectionLabel(),
        const SizedBox(height: 10),
        _ShimmerBox(
          width: double.infinity,
          height: 100,
          borderRadius: BorderRadius.circular(18),
        ),
        const SizedBox(height: 18),

        // ── Aktivitas & Misi ──
        const _SkeletonSectionLabel(),
        const SizedBox(height: 10),
        _ShimmerBox(
          width: double.infinity,
          height: 140,
          borderRadius: BorderRadius.circular(18),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

// ─── V4 Home Lobby ───────────────────────────────────────────────────────────

class _HomeLobbyV4 extends StatelessWidget {
  final String greeting;
  final AnimeModel? featured;
  final List<AnimeModel> liveAnimes;
  final VoidCallback onSearch;
  final VoidCallback? onWatch;
  final VoidCallback? onDetail;
  final ScrollController scrollCtrl;
  final ValueChanged<int>? onNavigateToTab;

  const _HomeLobbyV4({
    super.key,
    required this.greeting,
    required this.featured,
    required this.liveAnimes,
    required this.onSearch,
    required this.scrollCtrl,
    this.onWatch,
    this.onDetail,
    this.onNavigateToTab,
  });

  AnimeModel? _resolveAnime(String id) {
    for (final a in liveAnimes) {
      if (a.id == id) return a;
    }
    for (final a in MockDataService.getMockAnimes()) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final allAnimes = liveAnimes.isNotEmpty
        ? liveAnimes
        : MockDataService.getMockAnimes();

    return ValueListenableBuilder<List<ContinueWatchingModel>>(
      valueListenable: MockDataService.continueWatchingNotifier,
      builder: (context, cwList, _) {
        final cw = cwList.isNotEmpty ? cwList.first : null;
        final hasCw =
            cw != null && cw.watchProgress > 0 && cw.watchProgress < 0.95;
        // Sourced from getMockAnimes() sorted by index (newest first)
        // addedAt field may not exist in all AnimeModel versions, so we
        // fallback to the catalog order.
        final recentlyAdded = MockDataService.getMockAnimes().take(10).toList();

        // ── Section list (same order/content as before) ──
        // Built once per rebuild, then handed to ListView.builder below so
        // each section is lazily built/disposed as it scrolls in and out of
        // view, instead of every section (and every one of their animation
        // controllers) running simultaneously from the moment the screen
        // opens. This is the single biggest scroll-jank fix in this file.
        final sections = <Widget>[
          // ── 1. HERO BANNER ──
          SizedBox(
            height: 360,
            child: _ProtagonistZone(
              greeting: greeting,
              featured: featured,
              onDetail: onDetail,
              onWatch: onWatch,
              scrollCtrl: scrollCtrl,
            ),
          ),
          const SizedBox(height: 18),

          // ── 2. PREMIUM PASS HIGHLIGHT ──
          const _PremiumPassHighlight(),
          const SizedBox(height: 18),

          // ═══ ANIME CONTENT FIRST — moved up so the lobby's actual anime
          // library is visible before gamification/social/shop noise ═══

          // ── 3. CONTINUE WATCHING ──
          if (hasCw) ...[
            _SectionLabel(label: 'LANJUTKAN MENONTON', icon: Icons.play_circle_fill_rounded),
            const SizedBox(height: 10),
            _ContinueWatchingCard(item: cw, resolveAnime: _resolveAnime),
            const SizedBox(height: 18),
          ],

          // ── 4. TAYANG HARI INI ──
          _SectionLabel(label: 'TAYANG HARI INI', icon: Icons.today_rounded),
          const SizedBox(height: 10),
          RepaintBoundary(child: _TodayAiringRow(animes: allAnimes)),
          const SizedBox(height: 18),

          // ── 5. BARU DITAMBAHKAN — always from mock data, so it never
          // depends on the live API being up (see `recentlyAdded` above).
          if (recentlyAdded.isNotEmpty) ...[
            _SectionLabel(label: 'BARU DITAMBAHKAN', icon: Icons.fiber_new_rounded),
            const SizedBox(height: 10),
            RepaintBoundary(child: _RecentlyAddedRow(animes: recentlyAdded)),
            const SizedBox(height: 18),
          ],

          // ── 6. TRENDING NOW ──
          _SectionLabel(label: 'TRENDING NOW', icon: Icons.trending_up_rounded),
          const SizedBox(height: 10),
          RepaintBoundary(
            child: _TrendingRow(
              animes: () {
                final trending = allAnimes
                    .where((a) => a.isTrending)
                    .toList();
                if (trending.isNotEmpty) return trending;
                // Fallback: no anime flagged trending (e.g. small dataset) —
                // show top-rated instead so the section is never empty.
                final byRating = List<AnimeModel>.from(allAnimes)
                  ..sort((a, b) => b.rating.compareTo(a.rating));
                return byRating.take(10).toList();
              }(),
            ),
          ),
          SizedBox(height: 28),

          // ═══ GAMIFICATION / SOCIAL / SHOP — bento grid with themed
          // illustrations (Dunia AniVerse, Aktivitas & Misi, Komunitas,
          // Toko). Flash Sale was dropped — it's just a preview of what's
          // already in Vault, so it was pure duplication once Toko already
          // tap-throughs there. Vault (cosmetics/shop) and Community
          // (social/live rooms) already exist as their own tabs; these are
          // just inviting previews. Full widgets (_LiveActivityPulse,
          // _FlashSaleBanner, _ActivityMissionCard, _KomunitasSection,
          // _TokoSection) are kept below, unused, in case any of this needs
          // to be reverted or expanded later — do not delete them. ═══
          _SectionLabel(label: 'LAINNYA', icon: Icons.widgets_rounded),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
              children: [
              _BentoSummaryCard(
                illustration: 'asset/images/home screen/dunia_aniverse.png',
                gradientColors: const [Color(0xFF163A2C), Color(0xFF0F2419)],
                glowColor: const Color(0xFFF0D08A),
                title: 'Dunia AniVerse',
                statValue: '12.4K',
                statLabel: 'member online',
                entranceDelay: const Duration(milliseconds: 0),
                onTap: () => onNavigateToTab?.call(6), // Community
              ),
              _BentoSummaryCard(
                illustration: 'asset/images/home screen/aktivitas_misi.png',
                gradientColors: const [Color(0xFF4A2416), Color(0xFF250F09)],
                glowColor: const Color(0xFFBF7A4E),
                title: 'Aktivitas & Misi',
                statValue: '7',
                statLabel: 'hari streak',
                entranceDelay: const Duration(milliseconds: 60),
                onTap: () => onNavigateToTab?.call(5), // Profile (missions live there)
              ),
              _BentoSummaryCard(
                illustration: 'asset/images/home screen/komunitas.png',
                gradientColors: const [Color(0xFF3D2233), Color(0xFF1F111C)],
                glowColor: const Color(0xFFD99066),
                title: 'Komunitas',
                statValue: '24',
                statLabel: 'nonton bareng',
                entranceDelay: const Duration(milliseconds: 120),
                // Two side-by-side characters read wider than the other
                // cards' single-object illustrations (globe/torch/chest) —
                // pulled in from the edge so neither head gets cropped.
                illustrationRightOffset: -4,
                illustrationBottomOffset: -12,
                onTap: () => onNavigateToTab?.call(6), // Community
              ),
              _BentoSummaryCard(
                illustration: 'asset/images/home screen/toko.png',
                gradientColors: const [Color(0xFF433310), Color(0xFF241B08)],
                glowColor: const Color(0xFFF0D08A),
                title: 'Toko',
                statValue: 'Baru',
                statLabel: 'Golden Dragon Ring',
                entranceDelay: const Duration(milliseconds: 180),
                onTap: () => onNavigateToTab?.call(4), // Vault
              ),
            ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Footer — closes the scroll so it doesn't feel like it
          // "belum selesai load" after Trending Now.
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: _kPurple.withValues(alpha: 0.25),
                  size: 18,
                ),
                SizedBox(height: 8),
                Text(
                  'Kamu sudah menjelajahi semua~',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.55),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Sampai jumpa di episode berikutnya 🌸',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.35),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ];

        return ListView.builder(
          controller: scrollCtrl,
          physics: const BouncingScrollPhysics(),
          // Keeps ~1 extra screen worth of content built above/below the
          // viewport so scrolling feels seamless, without forcing every
          // section in the whole page to exist (and animate) at once like
          // the old SingleChildScrollView + Column did.
          cacheExtent: 800,
          itemCount: sections.length,
          itemBuilder: (context, index) {
            // RepaintBoundary isolates each section's own repaints (shimmer,
            // pulse, countdown, painters) so they don't force neighboring
            // sections to repaint every frame too.
            return RepaintBoundary(child: sections[index]);
          },
        );
      },
    );
  }
}

// ─── Section Label (premium eyebrow header, reused across every section) ────
class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, this.icon = Icons.auto_awesome_rounded});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.highlight, AppTheme.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(7),
            boxShadow: [
              BoxShadow(
                color: AppTheme.highlight.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, size: 11.5, color: AppTheme.surfaceElevated),
        ),
        const SizedBox(width: 9),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(width: 10),
        // Fading trailing divider — separates this module from the next
        // without a hard rule, and reads as a deliberate editorial device
        // rather than the plain solid bar this used to be.
        Expanded(
          child: Container(
            height: 1.4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.highlight.withValues(alpha: 0.22),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Compact one-line summary card ───────────────────────────────────────────
// Used to represent Dunia AniVerse / Flash Sale / Aktivitas & Misi / Komunitas
// / Toko on Home without duplicating their full sections — those already
// live on the Community and Vault tabs. Tapping jumps straight to the
// relevant tab via onNavigateToTab (passed down from MainWrapper).
class _HomeSummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _HomeSummaryCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: iconColor.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.75),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppTheme.textSecondary.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ─── Bento Summary Card — illustrated 2x2 grid tile ───────────────────────────
// Replaces the flat _HomeSummaryCard rows for Dunia AniVerse/Aktivitas &
// Misi/Komunitas/Toko: themed gradient background, a big stat number as the
// focal point, and a custom illustration (from asset/images/home screen/)
// anchored bottom-right as a decorative accent, per the Ghibli Forest Night
// palette. Falls back to a plain gradient card (errorBuilder) if an asset is
// missing, so a missing PNG never crashes the Home screen.
class _BentoSummaryCard extends StatefulWidget {
  final String illustration;
  final List<Color> gradientColors;
  final Color glowColor;
  final String title;
  final String statValue;
  final String statLabel;
  final Duration entranceDelay;
  final VoidCallback? onTap;
  // Fine-tune per-illustration positioning — some compositions (e.g. two
  // side-by-side characters) are wider than others (a single globe/torch/
  // chest) and need a bit more room pushed further into the corner so they
  // don't read as cropped. Defaults match the original single-object spec.
  final double illustrationRightOffset;
  final double illustrationBottomOffset;

  const _BentoSummaryCard({
    required this.illustration,
    required this.gradientColors,
    required this.glowColor,
    required this.title,
    required this.statValue,
    required this.statLabel,
    this.entranceDelay = Duration.zero,
    this.onTap,
    this.illustrationRightOffset = -18,
    this.illustrationBottomOffset = -18,
  });

  @override
  State<_BentoSummaryCard> createState() => _BentoSummaryCardState();
}

class _BentoSummaryCardState extends State<_BentoSummaryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final Animation<double> _fade;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _fade = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slide = Tween<double>(begin: 18, end: 0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic),
    );
    Future.delayed(widget.entranceDelay, () {
      if (mounted) _entranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entranceCtrl,
      builder: (context, child) => Opacity(
        opacity: _fade.value,
        child: Transform.translate(
          offset: Offset(0, _slide.value),
          child: child,
        ),
      ),
      child: _PressableScale(
        onTap: widget.onTap,
        child: Container(
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.gradientColors,
            ),
            border: Border.all(
              color: widget.glowColor.withValues(alpha: 0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Illustration — anchored bottom-right, per the asset spec
              // (objects are already composed leaning toward that corner).
              Positioned(
                right: widget.illustrationRightOffset,
                bottom: widget.illustrationBottomOffset,
                width: 128,
                height: 128,
                child: Opacity(
                  opacity: 0.92,
                  child: Image.asset(
                    widget.illustration,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
              // Soft glow wash behind the illustration for extra depth.
              Positioned(
                right: -30,
                bottom: -30,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        widget.glowColor.withValues(alpha: 0.18),
                        widget.glowColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Text content — top-left, per the composition spec.
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      widget.statValue,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.statLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.7),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Chevron affordance, top-right, small — keeps the "tap to
              // go deeper" cue without competing with the illustration.
              Positioned(
                top: 12,
                right: 12,
                child: Icon(
                  Icons.arrow_outward_rounded,
                  size: 15,
                  color: AppTheme.textSecondary.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ─── Member card silhouette: 3 rounded corners + 1 diagonal-cut corner ─────
class _MemberCardClipper extends CustomClipper<Path> {
  final double corner;
  final double notch;
  const _MemberCardClipper({this.corner = 20, this.notch = 26});

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(corner, 0)
      ..lineTo(w - notch, 0)
      ..lineTo(w, notch) // diagonal die-cut corner, top-right
      ..lineTo(w, h - corner)
      ..quadraticBezierTo(w, h, w - corner, h)
      ..lineTo(corner, h)
      ..quadraticBezierTo(0, h, 0, h - corner)
      ..lineTo(0, corner)
      ..quadraticBezierTo(0, 0, corner, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ─── Foil/holographic stroke traced along the member card silhouette ──────
class _MemberCardBorderPainter extends CustomPainter {
  final double corner;
  final double notch;
  final double t; // shimmer animation phase, 0..1
  const _MemberCardBorderPainter({
    this.corner = 20,
    this.notch = 26,
    required this.t,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _MemberCardClipper(corner: corner, notch: notch).getClip(size);
    final rect = Offset.zero & size;
    final shift = (t * 2) - 0.5;
    final gradient = LinearGradient(
      begin: Alignment(-1 + shift, -1),
      end: Alignment(1 + shift, 1),
      colors: const [
        Color(0x00FFFFFF),
        Color(0xE6FFFFFF),
        Color(0x33FFE9B0),
        Color(0xE6FFFFFF),
        Color(0x00FFFFFF),
      ],
      stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
    );
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MemberCardBorderPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _PremiumPassHighlight extends StatefulWidget {
  const _PremiumPassHighlight();

  @override
  State<_PremiumPassHighlight> createState() => _PremiumPassHighlightState();
}

class _PremiumPassHighlightState extends State<_PremiumPassHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const xp = 340;
    const target = 500;
    final progress = (xp / target).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const PremiumPassScreen())),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final t = _ctrl.value;
          // Pulse oscillates 0→1→0 once per cycle for the glow & icon ring
          final pulse = (math.sin(t * math.pi * 2) + 1) / 2;
          return Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Color(
                    0xFFFFAA00,
                  ).withValues(alpha: 0.14 + pulse * 0.06),
                  blurRadius: 16 + pulse * 4,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipPath(
              clipper: const _MemberCardClipper(),
              child: Stack(
                children: [
                  // ── Background artwork replaces the flat gold gradient —
                  // gives the glass badges below real art to blend with,
                  // same pattern that worked for the hero banner. ──
                  Positioned.fill(
                    child: Image.asset(
                      'asset/Premium Pass banner.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFF3D98A),
                              Color(0xFFE3A94E),
                              Color(0xFFCB7F35),
                              Color(0xFF9A5A26),
                            ],
                            stops: [0.0, 0.35, 0.70, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Warm darken so white text/glass stay legible over the
                  // new artwork regardless of its brightness.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.black.withValues(alpha: 0.30),
                            const Color(0xFF6B3410).withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: child,
                  ),
                  // ── Single shimmer sweep — VIP watermark, hologram chip,
                  // and the secondary shimmer sweep were removed here: they
                  // added visual weight without adding information, and made
                  // this card compete with the anime content around it.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipPath(
                        clipper: _MemberCardClipper(),
                        child: Transform.translate(
                          offset: Offset((t * 2 - 0.6) * 340, 0),
                          child: Transform.rotate(
                            angle: -0.4,
                            child: Container(
                              width: 70,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(alpha: 0.16),
                                    Colors.white.withValues(alpha: 0.24),
                                    Colors.white.withValues(alpha: 0.16),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                  stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // ── Foil border traced along the member card silhouette ──
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _MemberCardBorderPainter(t: t),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        child: Row(
          children: [
            SizedBox(
              // Fixed footprint (max pulse size) so the ring's animated
              // width/height below never changes this card's layout size —
              // that was leaking into the ListView and bouncing every item
              // beneath Premium Pass each pulse cycle.
              width: 54,
              height: 54,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _ctrl,
                    builder: (_, __) {
                      final pulse =
                          (math.sin(_ctrl.value * math.pi * 2) + 1) / 2;
                      return Container(
                        width: 48 + pulse * 6,
                        height: 48 + pulse * 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: 0.25 - pulse * 0.15,
                            ),
                            width: 1.5,
                          ),
                        ),
                      );
                    },
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [Color(0xFFFFE566), Color(0xFFFFAA00)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.60),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.30),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                  ),
                  child: const Icon(
                    Icons.diamond_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
              ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Flexible(
                        child: Text(
                          'Premium Pass',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
                      LiquidGlassPill(
                        borderRadius: 6,
                        compact: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: const Text(
                          'Lv 12',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      backgroundColor: Colors.white.withValues(alpha: 0.20),
                      valueColor: AlwaysStoppedAnimation(
                        Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '$xp / $target XP — Reward berikutnya menanti',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            LiquidGlassPill(
              borderRadius: 12,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 10),
                  SizedBox(width: 4),
                  Text(
                    'Upgrade',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
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

// ─── 4. Continue Watching Card ────────────────────────────────────────────────
class _ContinueWatchingCard extends StatefulWidget {
  final ContinueWatchingModel? item;
  final AnimeModel? Function(String id) resolveAnime;

  const _ContinueWatchingCard({required this.item, required this.resolveAnime});

  @override
  State<_ContinueWatchingCard> createState() => _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends State<_ContinueWatchingCard> {
  bool _pressed = false;
  // Live-fetched poster, used when the stored thumbnailUrl/anime.imageUrl
  // turns out to be a placehold.co placeholder (leftover from mock seed
  // data) instead of a real poster. Null until resolved; stays null forever
  // if the title isn't a placeholder or the live lookup fails — in both
  // cases the original thumb is used as-is or the plain surface fallback
  // kicks in, so this can never make things worse than before.
  String? _resolvedThumb;
  String? _resolvingForTitle;

  static bool _isPlaceholder(String url) => url.contains('placehold.co');

  @override
  void initState() {
    super.initState();
    _maybeResolveLivePoster();
  }

  @override
  void didUpdateWidget(covariant _ContinueWatchingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-resolve if the underlying item changed (e.g. user switched to
    // continuing a different anime) rather than keeping the old poster.
    if (oldWidget.item?.animeId != widget.item?.animeId) {
      _resolvedThumb = null;
      _maybeResolveLivePoster();
    }
  }

  void _maybeResolveLivePoster() {
    final item = widget.item;
    if (item == null) return;
    final anime = widget.resolveAnime(item.animeId);
    final title = item.animeTitle.isNotEmpty
        ? item.animeTitle
        : (anime?.title ?? '');
    final storedThumb = item.thumbnailUrl.isNotEmpty
        ? item.thumbnailUrl
        : (anime?.imageUrl ?? '');
    if (title.isEmpty || !_isPlaceholder(storedThumb)) return;

    _resolvingForTitle = title;
    AnimeApiService.searchAnime(title).then((results) {
      if (!mounted || _resolvingForTitle != title) return;
      if (results.isEmpty) return;
      final realUrl = results.first.imageUrl;
      if (realUrl.isEmpty || _isPlaceholder(realUrl)) return;
      setState(() => _resolvedThumb = realUrl);
    }).catchError((_) {
      // Live lookup failed (network/rate-limit) — silently keep the
      // existing placeholder-or-empty thumb; the UI already handles that.
    });
  }

  String _remaining(double progress) {
    // Rough estimate assuming a ~24min episode, just to give the user a
    // sense of "how much is left" without needing real duration data.
    final remainingMin = ((1 - progress.clamp(0.0, 1.0)) * 24).round();
    if (remainingMin <= 0) return 'Hampir selesai';
    return '$remainingMin menit tersisa';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    if (item == null) return const SizedBox.shrink();
    final anime = widget.resolveAnime(item.animeId);
    final title = item.animeTitle.isNotEmpty
        ? item.animeTitle
        : (anime?.title ?? 'Unknown');
    final storedThumb = item.thumbnailUrl.isNotEmpty
        ? item.thumbnailUrl
        : (anime?.imageUrl ?? '');
    // Prefer the live-resolved poster over a known placeholder; otherwise
    // use whatever was stored (a real URL, most of the time).
    final thumb = (_resolvedThumb != null && _resolvedThumb!.isNotEmpty)
        ? _resolvedThumb!
        : (_isPlaceholder(storedThumb) ? '' : storedThumb);
    final progress = item.watchProgress.clamp(0.0, 1.0);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        final playable =
            anime ?? MockDataService.getPlayableAnimeForContinue(item);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WatchScreen(
              anime: playable,
              initialEpisodeIndex: (item.episodeNumber - 1).clamp(0, 99),
              initialWatchProgress: item.watchProgress,
            ),
          ),
        );
      },
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 130,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Full-bleed poster background — this is what makes the
                // glass panel below actually read as "glass", the same way
                // the hero banner's cover art does. ──
                thumb.isNotEmpty
                    ? ProxiedNetworkImage.forUrl(
                        // Explicit key stops this widget's loading state
                        // (which candidate succeeded, in-flight AniList
                        // fallback, etc.) from being silently reset every
                        // time an unrelated ancestor rebuilds (e.g. the
                        // Home hero's 5s auto-carousel timer, which
                        // setState()s the whole HomeScreen). Without a key,
                        // Flutter's widget diffing can decide this is a
                        // "new" widget purely from tree position, discard
                        // the old State (and everything it had already
                        // loaded), and start the whole candidate chain over
                        // from scratch — which looked like "the image loads
                        // then vanishes again a few seconds later".
                        key: ValueKey('img_$thumb'),
                        url: thumb,
                        title: title,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        fallback: Container(color: AppTheme.surfaceElevated),
                      )
                    : Container(color: AppTheme.surfaceElevated),
                // Darken gradient so text/glass panel stays legible over
                // bright or busy artwork.
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: 0.78),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
                // "Lanjutkan" badge — glass now, since it sits over artwork.
                Positioned(
                  top: 8,
                  left: 8,
                  child: LiquidGlassPill(
                    borderRadius: 7,
                    compact: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    child: const Text(
                      'LANJUTKAN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 6.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                // Progress % badge, top-right — glass, sits on artwork.
                Positioned(
                  top: 8,
                  right: 8,
                  child: LiquidGlassPill(
                    borderRadius: 999,
                    compact: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 11,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${(progress * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Bottom glass panel: title, episode info, progress bar,
                // play button — the main info surface, floating over the
                // poster like the hero banner's content column. ──
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  shadows: [
                                    Shadow(color: Colors.black45, blurRadius: 4),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Episode ${item.episodeNumber} • ${_remaining(progress)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: SizedBox(
                                  height: 5,
                                  child: Stack(
                                    children: [
                                      Container(
                                        color: Colors.white.withValues(
                                          alpha: 0.18,
                                        ),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: progress == 0
                                            ? 0.02
                                            : progress,
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                AppTheme.accent,
                                                AppTheme.primary,
                                              ],
                                            ),
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
                        const SizedBox(width: 10),
                        // Play button — glass ring over the poster, replaces
                        // the old solid gradient circle.
                        AnimatedScale(
                          scale: _pressed ? 1.08 : 1.0,
                          duration: const Duration(milliseconds: 120),
                          curve: Curves.easeOutCubic,
                          child: LiquidGlassPill(
                            borderRadius: 999,
                            height: 40,
                            padding: EdgeInsets.zero,
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
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
        ),
      ),
    );
  }
}

// ─── 5. Today Airing Row ──────────────────────────────────────────────────────
class _TodayAiringRow extends StatelessWidget {
  final List<AnimeModel> animes;
  const _TodayAiringRow({required this.animes});

  String _countdown(AnimeModel a) {
    if (a.nextEpisodeAt == null) return '';
    final diff = a.nextEpisodeAt!.difference(DateTime.now());
    if (diff.isNegative) return 'Tayang sekarang';
    if (diff.inDays > 0) return '${diff.inDays}h ${diff.inHours % 24}j lagi';
    if (diff.inHours > 0)
      return '${diff.inHours}j ${diff.inMinutes % 60}m lagi';
    return '${diff.inMinutes}m lagi';
  }

  bool _isLive(AnimeModel a) {
    if (a.nextEpisodeAt == null) return false;
    return a.nextEpisodeAt!.difference(DateTime.now()).isNegative;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday;
    final todayAnimes = animes.where((a) => a.releaseDay == today).toList();

    if (todayAnimes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.surfaceElevated, AppTheme.surfaceElevated],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.surfaceElevated),
          boxShadow: [
            BoxShadow(
              color: _kPurple.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _kPurple.withValues(alpha: 0.14),
                    AppTheme.accent.withValues(alpha: 0.14),
                  ],
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                Icons.event_busy_rounded,
                color: _kPurple.withValues(alpha: 0.55),
                size: 17,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Tidak ada rilis terjadwal hari ini',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: todayAnimes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final a = todayAnimes[i];
          return _TodayAiringCard(
            key: ValueKey(a.id),
            anime: a,
            countdown: _countdown(a),
            isLive: _isLive(a),
          );
        },
      ),
    );
  }
}

class _TodayAiringCard extends StatelessWidget {
  final AnimeModel anime;
  final String countdown;
  final bool isLive;
  const _TodayAiringCard({
    super.key,
    required this.anime,
    required this.countdown,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    final a = anime;
    final accent = isLive ? const Color(0xFF22C55E) : AppTheme.accent;

    return _PressableScale(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => AnimeDetailScreen(anime: a))),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 254,
            height: 118,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Full-bleed poster crop as the card's own background —
                // gives the glass badges below real artwork to blend with,
                // instead of a flat surfaceElevated panel. ──
                ProxiedNetworkImage.forUrl(
                  key: ValueKey('img_${a.imageUrl}'),
                  url: a.imageUrl,
                  title: a.title,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  fallback: Container(color: AppTheme.surfaceElevated),
                ),
                // Left-to-right darken so the title column stays legible
                // over bright/busy art, mirroring the hero banner treatment.
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.80),
                        Colors.black.withValues(alpha: 0.55),
                        Colors.black.withValues(alpha: 0.15),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
                // Bottom fade for extra contrast under the airing badge.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // "LIVE" / "HARI INI" ribbon — glass, top-right corner over art.
                Positioned(
                  top: 8,
                  right: 8,
                  child: LiquidGlassPill(
                    borderRadius: 999,
                    compact: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLive) ...[
                          const _PulsingDot(color: Color(0xFF22C55E), size: 6),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          isLive ? 'LIVE' : 'HARI INI',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Rating badge — glass, top-left over art.
                Positioned(
                  top: 8,
                  left: 8,
                  child: LiquidGlassPill(
                    borderRadius: 8,
                    compact: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFBBF24),
                          size: 9,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          a.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Bottom-left content column: title, episode count,
                // airing-time pill — floats over the poster like the hero
                // banner's own text column. ──
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        a.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          height: 1.22,
                          letterSpacing: -0.1,
                          shadows: [
                            Shadow(color: Colors.black45, blurRadius: 4),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_episodesOf(a)} Episode',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Airing-time glass pill — the unique info for "today"
                      // cards, now floating over the poster.
                      LiquidGlassPill(
                        borderRadius: 8,
                        compact: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isLive)
                              const _PulsingDot(
                                color: Color(0xFF22C55E),
                                size: 6,
                              )
                            else
                              Icon(Icons.timer_rounded, size: 10, color: accent),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                countdown,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
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

// ─── 3aa. Recently Added — always sourced from mock data (see comment at
// the `recentlyAdded` computation), so it's unaffected by live API status ──
class _RecentlyAddedRow extends StatelessWidget {
  final List<AnimeModel> animes;
  const _RecentlyAddedRow({required this.animes});

  String _addedCaption(AnimeModel a) {
    // addedAt may not exist on all AnimeModel versions — access defensively
    DateTime? addedAt;
    try {
      addedAt = (a as dynamic).addedAt as DateTime?;
    } catch (_) {}
    if (addedAt == null) return '';
    final days = DateTime.now().difference(addedAt).inDays;
    if (days <= 0) return 'Baru hari ini';
    if (days == 1) return 'Baru kemarin';
    return 'Baru $days hari lalu';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: animes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final a = animes[i];
          return _RecentlyAddedCard(key: ValueKey(a.id), anime: a, addedCaption: _addedCaption(a));
        },
      ),
    );
  }
}

class _RecentlyAddedCard extends StatelessWidget {
  final AnimeModel anime;
  final String addedCaption;
  const _RecentlyAddedCard({super.key, required this.anime, required this.addedCaption});

  @override
  Widget build(BuildContext context) {
    final a = anime;
    const accent = Color(0xFF10B981); // fresh emerald — distinct from
    // LIVE-green and Premium-gold, reads as "new/fresh" rather than
    // reusing an accent that already means something else elsewhere.

    return _PressableScale(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => AnimeDetailScreen(anime: a))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 254,
            height: 118,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Full-bleed poster crop as the card's own background —
                // same successful pattern as TodayAiringCard: gives the
                // glass badges real artwork to blend with. ──
                ProxiedNetworkImage.forUrl(
                  key: ValueKey('img_${a.imageUrl}'),
                  url: a.imageUrl,
                  title: a.title,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  fallback: Container(color: AppTheme.surfaceElevated),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.80),
                        Colors.black.withValues(alpha: 0.55),
                        Colors.black.withValues(alpha: 0.15),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // "BARU" ribbon — glass, top-right over art.
                Positioned(
                  top: 8,
                  right: 8,
                  child: LiquidGlassPill(
                    borderRadius: 999,
                    compact: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_new_rounded, color: accent, size: 11),
                        const SizedBox(width: 3),
                        const Text(
                          'BARU',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Rating badge — glass, top-left over art.
                Positioned(
                  top: 8,
                  left: 8,
                  child: LiquidGlassPill(
                    borderRadius: 8,
                    compact: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFBBF24),
                          size: 9,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          a.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Bottom-left content column: title, episode count,
                // "added recently" pill — floats over the poster. ──
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        a.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          height: 1.22,
                          letterSpacing: -0.1,
                          shadows: [
                            Shadow(color: Colors.black45, blurRadius: 4),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_episodesOf(a)} Episode',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      LiquidGlassPill(
                        borderRadius: 8,
                        compact: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 10,
                              color: accent,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                addedCaption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
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

// ─── 6. Cosmetic Showcase ──────────────────────────────────────────────────────
// ─── TOKO SECTION (Tahap 4 merge) ───────────────────────────────────────────
// Combines Cosmetic Spotlight + Kosmetik Shop into one card with a chip
// switcher, same pattern as _KomunitasSection. Flash Sale intentionally
// stays outside this merge (see sections-list comment) since it's a
// countdown-driven urgency banner, not a browsing surface.
class _TokoSection extends StatefulWidget {
  const _TokoSection();
  @override
  State<_TokoSection> createState() => _TokoSectionState();
}

class _TokoSectionState extends State<_TokoSection> {
  int _tab = 0; // 0 = Cosmetic Spotlight, 1 = Kosmetik Shop

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _KomunitasChip(
                label: 'Cosmetic Spotlight',
                icon: Icons.diamond_rounded,
                selected: _tab == 0,
                onTap: () => setState(() => _tab = 0),
              ),
              const SizedBox(width: 8),
              _KomunitasChip(
                label: 'Kosmetik Shop',
                icon: Icons.storefront_rounded,
                selected: _tab == 1,
                onTap: () => setState(() => _tab = 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _tab == 0
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _CosmeticShowcaseCard(),
              )
            : const _ShopCarousel(),
      ],
    );
  }
}

class _CosmeticShowcaseCard extends StatefulWidget {
  const _CosmeticShowcaseCard();

  @override
  State<_CosmeticShowcaseCard> createState() => _CosmeticShowcaseCardState();
}

class _CosmeticShowcaseCardState extends State<_CosmeticShowcaseCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    // Same 3200ms cadence as Premium Pass so the two glow pulses on the
    // home feed feel like one consistent "premium" motion language
    // rather than two unrelated animation speeds.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Membuka Vault...'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      },
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.accent.withValues(alpha: 0.12),
                AppTheme.surfaceElevated,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.accent.withValues(alpha: 0.26),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.20),
                blurRadius: 26,
                spreadRadius: -4,
                offset: Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Fixed footprint (max pulse size) so the ring's animated
              // width/height never changes this Row's layout — same fix
              // pattern used for Premium Pass to avoid the layout-shift
              // bug where sibling content bounced each pulse cycle.
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // ── Pulsing glow ring behind the icon ──
                    AnimatedBuilder(
                      animation: _ctrl,
                      builder: (_, __) {
                        final pulse =
                            (math.sin(_ctrl.value * math.pi * 2) + 1) / 2;
                        return Container(
                          width: 56 + pulse * 8,
                          height: 56 + pulse * 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Color(
                                0xFFFFD700,
                              ).withValues(alpha: 0.35 - pulse * 0.20),
                              width: 1.5,
                            ),
                          ),
                        );
                      },
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFFD700), AppTheme.accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accent.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppTheme.surfaceElevated,
                        size: 26,
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: Color(
                                0xFFFFD700,
                              ).withValues(alpha: 0.50),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Text(
                          'EXCLUSIVE',
                          style: TextStyle(
                            color: AppTheme.surfaceElevated,
                            fontSize: 6.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Golden Dragon Ring',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Cosmetic populer minggu ini — belum kamu miliki',
                      maxLines: 2,
                      style: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.9),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.accent, AppTheme.primary],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Vault',
                      style: TextStyle(
                        color: AppTheme.surfaceElevated,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.surfaceElevated,
                      size: 13,
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

// ─── 7. Trending Row ──────────────────────────────────────────────────────────
class _TrendingRow extends StatelessWidget {
  final List<AnimeModel> animes;
  const _TrendingRow({required this.animes});

  @override
  Widget build(BuildContext context) {
    if (animes.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: animes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _TrendingCard(key: ValueKey(animes[i].id), anime: animes[i], rank: i + 1),
      ),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  final AnimeModel anime;
  final int rank;
  const _TrendingCard({super.key, required this.anime, required this.rank});

  @override
  Widget build(BuildContext context) {
    final a = anime;
    return _PressableScale(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => AnimeDetailScreen(anime: a))),
      child: SizedBox(
          width: 124,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    SizedBox(
                      width: 124,
                      height: 164,
                      child: ProxiedNetworkImage.forUrl(
                        key: ValueKey('img_${a.imageUrl}'),
                        url: a.imageUrl,
                        title: a.title,
                        width: 124,
                        height: 164,
                        fit: BoxFit.cover,
                        fallback: Container(color: AppTheme.surfaceElevated),
                      ),
                    ),
                    // Bottom fade so the rating badge & edges feel integrated
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.45),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (a.rating > 0)
                      Positioned(
                        top: 7,
                        left: 7,
                        child: LiquidGlassPill(
                          borderRadius: 8,
                          compact: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFFBBF24),
                                size: 11,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                a.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (rank <= 3)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: switch (rank) {
                                1 => const [Color(0xFFFFD700), Color(0xFFFFA000)],
                                2 => const [Color(0xFFE0E0E0), Color(0xFFB0B0B0)],
                                _ => const [Color(0xFFD08A56), Color(0xFF9C6234)],
                              },
                            ),
                            border: Border.all(
                              color: AppTheme.surfaceElevated.withValues(alpha: 0.85),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: switch (rank) {
                                  1 => const Color(0xFFFFD700),
                                  2 => const Color(0xFFE0E0E0),
                                  _ => Color(0xFFD08A56),
                                }.withValues(alpha: 0.55),
                                blurRadius: 8,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${rank}',
                            style: const TextStyle(
                              color: AppTheme.surfaceElevated,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(
                                  color: Colors.black38,
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  if (a.isTrending)
                    Container(
                      margin: const EdgeInsets.only(right: 5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'HOT',
                        style: TextStyle(
                          color: AppTheme.surfaceElevated,
                          fontSize: 6.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      a.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
    );
  }
}

// ─── 8. Genre Grid ────────────────────────────────────────────────────────────
class _GenreGrid extends StatelessWidget {
  final List<AnimeModel> animes;
  const _GenreGrid({required this.animes});

  @override
  Widget build(BuildContext context) {
    final genres = MockDataService.getGenres();
    const genreIcons = {
      'Action': Icons.bolt_rounded,
      'Adventure': Icons.terrain_rounded,
      'Comedy': Icons.mood_rounded,
      'Drama': Icons.theater_comedy_rounded,
      'Sci-Fi': Icons.rocket_launch_rounded,
      'Fantasy': Icons.auto_fix_high_rounded,
      'Horror': Icons.dark_mode_rounded,
    };
    const genreColors = {
      'Action': Color(0xFFEF4444),
      'Adventure': Color(0xFF22C55E),
      'Comedy': Color(0xFFF59E0B),
      'Drama': AppTheme.accent,
      'Sci-Fi': Color(0xFF06B6D4),
      'Fantasy': AppTheme.accent,
      'Horror': Color(0xFF6B7280),
    };

    return GridView.builder(
      itemCount: genres.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.6,
      ),
      itemBuilder: (_, i) {
        final genre = genres[i];
        final color = genreColors[genre] ?? _kPurple;
        final icon = genreIcons[genre] ?? Icons.category_rounded;
        final count = animes.where((a) => a.genre == genre).length;
        // Genre character art — 120×120 PNG, flat anime silhouette in the
        // genre's accent color, drops in silently once the asset exists at
        // this path (see asset spec: fade-left, transparent bg).
        final artAsset =
            'asset/images/home screen/genre_${genre.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]"), "_")}.png';
        return _GenreCard(
          genre: genre,
          color: color,
          icon: icon,
          count: count,
          artAsset: artAsset,
        );
      },
    );
  }
}

class _GenreCard extends StatefulWidget {
  final String genre;
  final Color color;
  final IconData icon;
  final int count;
  final String artAsset;
  const _GenreCard({
    required this.genre,
    required this.color,
    required this.icon,
    required this.count,
    required this.artAsset,
  });

  @override
  State<_GenreCard> createState() => _GenreCardState();
}

class _GenreCardState extends State<_GenreCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Menjelajahi genre ${widget.genre}...'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _pressed
                  ? color.withValues(alpha: 0.45)
                  : Colors.transparent,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: _pressed ? 0.16 : 0.07),
                blurRadius: _pressed ? 16 : 10,
                spreadRadius: -2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: LiquidGlassPill(
            borderRadius: 14,
            padding: EdgeInsets.zero,
            child: SizedBox(
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerRight,
                children: [
                  // Character art — fades into the card from the right edge.
                  // Renders nothing until the PNG at widget.artAsset exists.
                  Positioned(
                    right: -8,
                    top: 0,
                    bottom: 0,
                    child: ShaderMask(
                      shaderCallback: (rect) => LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Colors.transparent, color.withValues(alpha: 0.9)],
                        stops: const [0.0, 0.45],
                      ).createShader(rect),
                      blendMode: BlendMode.dstIn,
                      child: _SafeAssetPng(
                        assetPath: widget.artAsset,
                        width: 78,
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                color.withValues(alpha: 0.20),
                                color.withValues(alpha: 0.10),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(widget.icon, color: color, size: 14.5),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.genre,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (widget.count > 0)
                                Text(
                                  '${widget.count} anime',
                                  style: TextStyle(
                                    color: const Color(
                                      0xFF7C7299,
                                    ).withValues(alpha: 0.85),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: color.withValues(alpha: 0.45),
                          size: 14.5,
                        ),
                      ],
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

// ─── Pressable scale wrapper ─────────────────────────────────────────────────
// Wraps a child in scale-down-on-press feedback plus a light haptic tick,
// used for the hero CTA buttons (Tonton Sekarang / Detail) so they feel
// tactile instead of a flat GestureDetector tap.
class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _PressableScale({required this.child, this.onTap});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _ProtagonistZone extends StatefulWidget {
  final String greeting;
  final AnimeModel? featured;
  final VoidCallback? onDetail;
  final VoidCallback? onWatch;
  final ScrollController? scrollCtrl;

  const _ProtagonistZone({
    required this.greeting,
    required this.featured,
    this.onDetail,
    this.onWatch,
    this.scrollCtrl,
  });

  @override
  State<_ProtagonistZone> createState() => _ProtagonistZoneState();
}

class _ProtagonistZoneState extends State<_ProtagonistZone> {
  double _parallaxOffset = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollCtrl?.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _ProtagonistZone oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollCtrl != widget.scrollCtrl) {
      oldWidget.scrollCtrl?.removeListener(_onScroll);
      widget.scrollCtrl?.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollCtrl?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final ctrl = widget.scrollCtrl;
    if (ctrl == null || !ctrl.hasClients) return;
    // The hero only occupies the very top of the scroll range, so only a
    // small window of offset (0..120) ever visually applies to it. Clamp
    // hard so the cover image can't drift far enough to reveal empty space
    // at the bottom of its Stack once the user scrolls past the hero.
    final offset = ctrl.offset.clamp(0.0, 120.0) * 0.25;
    if ((offset - _parallaxOffset).abs() > 0.1) {
      setState(() => _parallaxOffset = offset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final greeting = widget.greeting;
    final featured = widget.featured;
    final onDetail = widget.onDetail;
    final onWatch = widget.onWatch;
    final title = featured?.title ?? 'AniVerse Universe';
    final rating = featured?.rating ?? 0.0;
    final cover = _bannerOf(featured) ?? featured?.imageUrl ?? '';
    final genres = featured != null
        ? _genresOf(featured).take(2).toList()
        : <String>[];
    final episodes = featured != null ? _episodesOf(featured) : '?';

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.surfaceElevated.withValues(alpha: 0.90)),
          boxShadow: [
            BoxShadow(
              color: _kPurple.withValues(alpha: 0.18),
              blurRadius: 32,
              spreadRadius: -4,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cover.isNotEmpty)
              Positioned(
                // Oversized + shifted up by the same margin so the parallax
                // translate below always has image to show — it can never
                // scroll past the top edge into blank space.
                top: -16,
                left: 0,
                right: 0,
                bottom: -16,
                child: Transform.translate(
                  offset: Offset(0, -_parallaxOffset),
                  child: ProxiedNetworkImage.forUrl(
                    key: ValueKey('img_$cover'),
                    url: cover,
                    title: featured?.title,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    fallback: const SizedBox.shrink(),
                  ),
                ),
              ),

            // Stronger, more dimensional gradient — readable text, deeper mood
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.20),
                    Colors.black.withValues(alpha: 0.62),
                    AppTheme.background.withValues(alpha: 0.94),
                  ],
                  stops: const [0.0, 0.35, 0.68, 1.0],
                ),
              ),
            ),
            // Left-side darken so badges/title pop even on bright covers
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.20),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.6],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting + episode count row
                  Row(
                    children: [
                      LiquidGlassPill(
                        child: Text(
                          '$greeting, Penjelajah',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(color: Colors.black38, blurRadius: 3),
                            ],
                          ),
                        ),
                      ),
                      Spacer(),
                      if (featured != null && episodes != '?')
                        LiquidGlassPill(
                          borderRadius: 999,
                          compact: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.play_circle_outline_rounded,
                                color: AppTheme.surfaceElevated,
                                size: 11,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$episodes EP',
                                style: const TextStyle(
                                  color: AppTheme.surfaceElevated,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  Spacer(),

                  if (featured != null) ...[
                    LiquidGlassPill(
                      borderRadius: 999,
                      compact: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      child: Text(
                        'PILIHAN UNIVERSE',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      height: 1.08,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 3, offset: Offset(0, 1)),
                        Shadow(color: Colors.black, blurRadius: 3, offset: Offset(0, -1)),
                        Shadow(color: Colors.black, blurRadius: 3, offset: Offset(1, 0)),
                        Shadow(color: Colors.black, blurRadius: 3, offset: Offset(-1, 0)),
                        Shadow(color: Colors.black, blurRadius: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Rating + genre tags row
                  if (rating > 0 || genres.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (rating > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFFBBF24),
                                  size: 14.5,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: AppTheme.surfaceElevated.withValues(alpha: 0.92),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          for (final g in genres)
                            LiquidGlassPill(
                              borderRadius: 999,
                              compact: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              child: Text(
                                g,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  // Primary + secondary CTA row
                  Row(
                    children: [
                      if (onWatch != null)
                        Expanded(
                          child: _PressableScale(
                            onTap: onWatch,
                            child: Container(
                              height: 46,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.accent,
                                    AppTheme.primary,
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.accent.withValues(
                                      alpha: 0.40,
                                    ),
                                    blurRadius: 16,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.play_arrow_rounded,
                                    color: AppTheme.surfaceElevated,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Tonton Sekarang',
                                    style: TextStyle(
                                      color: AppTheme.surfaceElevated,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (onWatch != null && onDetail != null)
                        SizedBox(width: 10),
                      if (onDetail != null)
                        _PressableScale(
                          onTap: onDetail,
                          child: LiquidGlassPill(
                            borderRadius: 14,
                            height: 46,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            alignment: Alignment.center,
                            child: Text(
                              'Detail',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                              ),
                            ),
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
    );
  }
}

class _LobbyProgressRail extends StatelessWidget {
  _LobbyProgressRail();

  @override
  Widget build(BuildContext context) {
    const xp = 340;
    const target = 500;
    final progress = (xp / target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceElevated),
        boxShadow: [
          BoxShadow(
            color: _kPurple.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: _kPurple.withValues(alpha: 0.85),
                size: 13,
              ),
              const SizedBox(width: 6),
              const Text(
                'Level 12 · Otaku',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Spacer(),
              Text(
                '$xp / $target XP',
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.95),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: _kPurple.withValues(alpha: 0.10),
              valueColor: const AlwaysStoppedAnimation(_kPurple),
            ),
          ),
        ],
      ),
    );
  }
}

class _LobbyPrimaryAction extends StatelessWidget {
  final bool hasContinue;
  final ContinueWatchingModel? continueItem;
  final AnimeModel? featured;
  final AnimeModel? Function(String id) resolveAnime;
  final VoidCallback? onWatchFeatured;

  const _LobbyPrimaryAction({
    required this.hasContinue,
    required this.continueItem,
    required this.featured,
    required this.resolveAnime,
    this.onWatchFeatured,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            if (hasContinue && continueItem != null) {
              final anime = resolveAnime(continueItem!.animeId) ?? featured;
              if (anime == null) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WatchScreen(
                    anime: anime,
                    initialEpisodeIndex: (continueItem!.episodeNumber - 1)
                        .clamp(0, 99),
                    initialWatchProgress: continueItem!.watchProgress,
                  ),
                ),
              );
            } else {
              onWatchFeatured?.call();
            }
          },
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasContinue
                    ? [AppTheme.accent, AppTheme.highlight]
                    : [_kPurple, AppTheme.accent],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: (hasContinue ? AppTheme.accent : _kPurple)
                      .withValues(alpha: 0.30),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  hasContinue
                      ? Icons.play_circle_filled_rounded
                      : Icons.play_arrow_rounded,
                  color: AppTheme.surfaceElevated,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  hasContinue ? 'Lanjut Nonton' : 'Mulai Petualangan',
                  style: const TextStyle(
                    color: AppTheme.surfaceElevated,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _LobbySecondaryButton(
                icon: Icons.groups_rounded,
                label: 'Gabung Room',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Room segera hadir!'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _LobbySecondaryButton(
                icon: Icons.public_rounded,
                label: 'Masuk Universe',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExploreScreen()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LobbySecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  _LobbySecondaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.surfaceElevated),
          boxShadow: [
            BoxShadow(
              color: _kPurple.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _kPurple, size: 14.5),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LobbyDock extends StatelessWidget {
  final VoidCallback onSearch;

  const _LobbyDock({required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DockTile(
            icon: Icons.calendar_month_rounded,
            label: 'Jadwal',
            color: _kPurple,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const JadwalScreen())),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DockTile(
            icon: Icons.collections_bookmark_rounded,
            label: 'Koleksi',
            color: AppTheme.accent,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const LibraryScreen())),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DockTile(
            icon: Icons.search_rounded,
            label: 'Cari',
            color: AppTheme.accent,
            onTap: onSearch,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DockTile(
            icon: Icons.diamond_rounded,
            label: 'Premium',
            color: const Color(0xFFF59E0B),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PremiumPassScreen()),
            ),
          ),
        ),
      ],
    );
  }
}

class _DockTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _DockTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.surfaceElevated),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 14.5),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Live Activity Pulse — "AniVerse is a living world" ───────────────────────
// Replaces the old Quick Actions row (which just duplicated nav items).
// One big focal card with a rotating live-activity ticker, plus two small
// live stats beside it (members online, active rooms).
class _LiveActivityEvent {
  final String text;
  final IconData icon;
  final Color color;
  const _LiveActivityEvent(this.text, this.icon, this.color);
}

class _LiveActivityPulse extends StatefulWidget {
  const _LiveActivityPulse();

  @override
  State<_LiveActivityPulse> createState() => _LiveActivityPulseState();
}

class _LiveActivityPulseState extends State<_LiveActivityPulse> {
  static const _events = [
    _LiveActivityEvent(
      'Aiko Chan baru saja menonton Mushoku Tensei S2',
      Icons.play_circle_fill_rounded,
      AppTheme.accent,
    ),
    _LiveActivityEvent(
      'Kirito_01 bergabung di Sword Art Online Room',
      Icons.group_rounded,
      Color(0xFF22D3EE),
    ),
    _LiveActivityEvent(
      '128 orang sedang live di Solo Leveling Room',
      Icons.local_fire_department_rounded,
      Color(0xFFF59E0B),
    ),
    _LiveActivityEvent(
      'Rei menyelesaikan Demon Slayer S3 Episode 12',
      Icons.celebration_rounded,
      Color(0xFF4ADE80),
    ),
    _LiveActivityEvent(
      'Hana mendapat badge 🌸 Sakura Collector',
      Icons.workspace_premium_rounded,
      Color(0xFFFBBF24),
    ),
  ];

  int _index = 0;
  double _opacity = 1.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;
      // Two-phase crossfade using a SINGLE Text widget: fade the current
      // text out, swap its content while invisible, then fade the new
      // text in. Because there is only ever one Text in the tree (never
      // two AnimatedSwitcher children stacked mid-transition), it is
      // structurally impossible for two different event strings to
      // render overlapping/garbled on top of each other.
      setState(() => _opacity = 0.0);
      await Future.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;
      setState(() {
        _index = (_index + 1) % _events.length;
        _opacity = 1.0;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _events[_index];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kPurple.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: _kPurple.withValues(alpha: 0.10),
            blurRadius: 22,
            spreadRadius: -4,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // ── Background artwork replaces the flat purple-tint gradient
            // — gives the "LIVE SEKARANG" glass badge below real art to
            // blend with, same pattern that worked for the hero banner. ──
            Positioned.fill(
              child: Image.asset(
                'asset/Dunia AniVerse card.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _kPurple.withValues(alpha: 0.10),
                        AppTheme.surfaceElevated,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Darken so white text/glass stay legible over the artwork.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.72),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Live ticker — rotates through recent world activity
                  Row(
                    children: [
                      const _LiveDot(),
                      const SizedBox(width: 8),
                      LiquidGlassPill(
                        borderRadius: 999,
                        compact: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        child: const Text(
                          'LIVE SEKARANG',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Fixed height avoids layout jump between short/long event
                  // texts. AnimatedOpacity on a single Row (content swapped via
                  // the two-phase timer above) guarantees only one event's text
                  // is ever in the tree at once — no stacked-widget overlap.
                  SizedBox(
                    height: 42,
                    child: AnimatedOpacity(
                      opacity: _opacity,
                      duration: Duration(milliseconds: 260),
                      curve: Curves.easeInOut,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: current.color.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              current.icon,
                              color: current.color,
                              size: 13.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                current.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 14),
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  SizedBox(height: 12),
                  // Small live stats beside the main ticker
                  Row(
                    children: [
                      Expanded(
                        child: _LivePulseStat(
                          icon: Icons.people_alt_rounded,
                          value: '12.4K',
                          label: 'Member Online',
                          color: _kPurple,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      Expanded(
                        child: _LivePulseStat(
                          icon: Icons.meeting_room_rounded,
                          value: '342',
                          label: 'Room Aktif',
                          color: AppTheme.accent,
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
    );
  }
}

class _LivePulseStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _LivePulseStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 14.5),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// â”€â”€â”€ Section Label â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

// â”€â”€â”€ Universe Background Painter â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Background depth layer: always-present ambient nebula glows

class _UniverseBackgroundPainter extends CustomPainter {
  final double t;
  _UniverseBackgroundPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.surface, // Sky blue
          AppTheme.surface, // Lavender
          AppTheme.surface, // Pastel pink
        ],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    final breath = (math.sin(t * math.pi * 2) + 1) / 2;

    final nebula1 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppTheme.surface.withValues(alpha: 0.32 + breath * 0.08),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.1, size.height * 0.2),
              radius: size.width * 0.6,
            ),
          );
    canvas.drawRect(rect, nebula1);

    final nebula2 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppTheme.surface.withValues(alpha: 0.28 + breath * 0.06),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.9, size.height * 0.4),
              radius: size.width * 0.5,
            ),
          );
    canvas.drawRect(rect, nebula2);
  }

  @override
  bool shouldRepaint(_UniverseBackgroundPainter o) => o.t != t;
}

// â”€â”€â”€ Sakura Particle Painter â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SakuraPainter extends CustomPainter {
  final double t;
  final double parallax;
  static final _rng = math.Random(42);
  static final _px = List.generate(22, (_) => _rng.nextDouble());
  static final _py = List.generate(22, (_) => _rng.nextDouble());
  static final _ps = List.generate(
    22,
    (_) => 0.003 + _rng.nextDouble() * 0.007,
  );
  static final _pr = List.generate(22, (_) => 1.0 + _rng.nextDouble() * 3.2);
  static final _pa = List.generate(22, (_) => _rng.nextDouble() * math.pi * 2);
  static final _po = List.generate(22, (_) => 0.03 + _rng.nextDouble() * 0.09);

  _SakuraPainter(this.t, {this.parallax = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 22; i++) {
      final y = (_py[i] + _ps[i] * t * 5 + parallax / size.height) % 1.0;
      final x =
          (_px[i] +
              (_ps[i] * 0.14) * t * 5 +
              math.sin(t * math.pi * 2 + _pa[i]) * 0.005) %
          1.0;
      final opacity = (_po[i] + 0.025 * math.sin(t * math.pi * 2 + _pa[i]))
          .clamp(0.02, 0.12);
      final center = Offset(x * size.width, y * size.height);
      if (i % 4 == 0) {
        paint.color = AppTheme.surfaceElevated.withValues(alpha: opacity * 0.6);
        canvas.drawCircle(center, _pr[i] * 0.4, paint);
      } else {
        paint.color = AppTheme.accent.withValues(alpha: opacity);
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(_pa[i] + t * 0.7);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: _pr[i] * 1.6,
            height: _pr[i] * 0.85,
          ),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_SakuraPainter o) =>
      o.t != t || o.parallax != parallax;
}

// â”€â”€â”€ Global Activity Overlay â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _GlobalActivityOverlay extends StatefulWidget {
  const _GlobalActivityOverlay();
  @override
  State<_GlobalActivityOverlay> createState() => _GlobalActivityOverlayState();
}

class _GlobalActivityOverlayState extends State<_GlobalActivityOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  static const _events = [
    '🌸 Aiko membuka Sakura Collector',
    '⚔ Kirito mencapai Episode 24',
    '🔥 Room Solo Leveling capai 1000 member',
    '🎤 Voice Chat ramai di Anime Room',
    '🏯 Room baru: Demon Slayer Indonesia',
  ];
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Phase 2: Align removed. Parent Positioned controls placement.
    // Widget returns pill content only.
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final index = (_c.value * _events.length).floor().clamp(
          0,
          _events.length - 1,
        );
        final local = (_c.value * _events.length) % 1;
        final opacity = local < 0.22
            ? local / 0.22
            : (local > 0.70 ? (1 - local) / 0.30 : 1.0);
        return Opacity(
          opacity: opacity.clamp(0.0, 0.86),
          child: Transform.translate(
            offset: Offset(0, 12 - (local * 18)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.08),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _LiveDot(),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _events[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// â”€â”€â”€ Top Rail â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Phase 3: single-line transparent rail. Logo left Â· icons right.
// No tagline. safeTop passed from parent so internal padding is device-correct.

class _TopRail extends StatelessWidget {
  final double safeTop;
  final int notificationCount;
  final VoidCallback onSearch;
  final VoidCallback onNotification;
  final VoidCallback onAvatar;

  const _TopRail({
    required this.safeTop,
    required this.notificationCount,
    required this.onSearch,
    required this.onNotification,
    required this.onAvatar,
  });

  @override
  Widget build(BuildContext context) {
    const pink = AppTheme.accent;
    const purple = AppTheme.accent;

    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.surfaceElevated.withValues(alpha: 0.84),
                AppTheme.surfaceElevated.withValues(alpha: 0.55),
                AppTheme.surfaceElevated.withValues(alpha: 0.22),
                AppTheme.surfaceElevated.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.55, 0.85, 1.0],
            ),
          ),
          padding: EdgeInsets.only(top: safeTop + 8, left: 16, right: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Logo with warm gold halo glow (matches AniVerse gold-A mark) ──
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC9A24A).withValues(alpha: 0.28),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Image.asset(
                  'asset/logo aniverse.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'AniVerse',
                    style: TextStyle(
                      fontFamily: 'serif',
                      color: const Color(0xFFF0E6CC),
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 8.5,
                        color: const Color(0xFFC9A24A).withValues(alpha: 0.75),
                      ),
                      SizedBox(width: 3),
                      Text(
                        'Masuk ke duniamu',
                        style: TextStyle(
                          color: AppTheme.textSecondary.withValues(alpha: 0.8),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              _GlassIconButton(
                icon: Icons.search_rounded,
                glowColor: purple,
                onPressed: onSearch,
              ),
              SizedBox(width: 14),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _GlassIconButton(
                    icon: Icons.notifications_none_rounded,
                    glowColor: pink,
                    onPressed: onNotification,
                  ),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 15,
                      height: 15,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: pink.withValues(alpha: 0.20),
                      ),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.surfaceElevated, width: 1.5),
                          gradient: LinearGradient(
                            colors: [pink, AppTheme.accent],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: pink.withValues(alpha: 0.55),
                              blurRadius: 6,
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: onAvatar,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Gradient "story ring" with a soft gap before the avatar
                    Container(
                      width: 44,
                      height: 44,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [pink, purple],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: pink.withValues(alpha: 0.30),
                            blurRadius: 12,
                            spreadRadius: 0.5,
                          ),
                          BoxShadow(
                            color: purple.withValues(alpha: 0.20),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.surfaceElevated,
                        ),
                        child: _SafeAssetAvatar(
                          assetPath: 'asset/Hitaku_Avatar_Face.png',
                          size: 37,
                          borderWidth: 0,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -3,
                      right: -3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [pink, purple],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.surfaceElevated, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: pink.withValues(alpha: 0.45),
                              blurRadius: 6,
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                        child: const Text(
                          '28',
                          style: TextStyle(
                            color: AppTheme.surfaceElevated,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
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

// ─── Glassmorphic icon button used in the header (search / notification) ──
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final Color glowColor;
  final VoidCallback onPressed;

  _GlassIconButton({
    required this.icon,
    required this.glowColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 39,
      height: 39,
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            glowColor.withValues(alpha: 0.45),
            AppTheme.surfaceElevated.withValues(alpha: 0.10),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.16),
            blurRadius: 10,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.surfaceElevated.withValues(alpha: 0.78),
              AppTheme.surfaceElevated.withValues(alpha: 0.55),
            ],
          ),
        ),
        child: Center(
          child: _PressableScale(
            onTap: onPressed,
            child: SizedBox(
              width: 39,
              height: 39,
              child: Center(
                child: Icon(icon, color: AppTheme.textPrimary, size: 19),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// â”€â”€â”€ Hero Atmosphere Painter â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _HeroAtmospherePainter extends CustomPainter {
  final double pulse;
  final double drift;
  final double scroll;
  _HeroAtmospherePainter({
    required this.pulse,
    required this.drift,
    required this.scroll,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final breath = 0.5 + pulse * 0.5;
    final parallax = scroll * 0.04;

    // 1. Large background nebula glow
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppTheme.accent.withValues(alpha: 0.08 + breath * 0.04),
              AppTheme.primary.withValues(alpha: 0.03),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(
                size.width * (0.3 + drift * 0.05),
                size.height * 0.5 + parallax,
              ),
              radius: size.width * 0.7,
            ),
          );
    canvas.drawRect(Offset.zero & size, glowPaint);

    // 2. Foreground light particles
    final particlePaint = Paint()..style = PaintingStyle.fill;
    final numParticles = 14;
    for (int i = 0; i < numParticles; i++) {
      final speedX = 0.03 + (i % 3) * 0.02;
      final speedY = 0.06 + (i % 2) * 0.03;

      final x = size.width * ((0.1 + (i * 0.07) + drift * speedX) % 1.0);
      final y =
          size.height * ((0.15 + (i * 0.08) - drift * speedY) % 1.0) + parallax;

      final sizeRadius = 1.0 + (i % 3) * 0.8 + math.sin(drift * 4 + i) * 0.4;
      final opacity = 0.12 + 0.15 * math.sin(drift * 3 + i);

      particlePaint.color = AppTheme.highlight.withValues(
        alpha: opacity.clamp(0.0, 1.0),
      );
      canvas.drawCircle(Offset(x, y), sizeRadius, particlePaint);
    }

    // 3. Falling/Drifting Sakura Petals
    final petalPaint = Paint()..style = PaintingStyle.fill;
    final numPetals = 8;
    for (int i = 0; i < numPetals; i++) {
      final speedX = 0.06 + (i % 2) * 0.02;
      final speedY = 0.10 + (i % 3) * 0.03;

      final x = size.width * ((0.15 + (i * 0.12) + drift * speedX) % 1.0);
      final y =
          size.height * ((0.1 + (i * 0.10) + drift * speedY) % 1.0) + parallax;

      final angle = (drift * 1.5 + i * 0.4) % (math.pi * 2);
      final petalW = 4.5 + (i % 3) * 1.5;
      final petalH = 7.0 + (i % 3) * 2.0;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);

      petalPaint.color = AppTheme.accent.withValues(
        alpha: (0.30 + 0.15 * math.sin(drift + i)).clamp(0.0, 1.0),
      );

      final path = Path();
      path.moveTo(0, -petalH / 2);
      path.quadraticBezierTo(petalW / 2, -petalH / 4, 0, petalH / 2);
      path.quadraticBezierTo(-petalW / 2, -petalH / 4, 0, -petalH / 2);
      canvas.drawPath(path, petalPaint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _HeroAtmospherePainter o) =>
      o.pulse != pulse || o.drift != drift || o.scroll != scroll;
}

// â”€â”€â”€ CINEMATIC HERO â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// TRUE full-bleed â€” no card border, no margin, no radius clip on outer wrapper.
// Artwork bleeds all 4 edges. Multiple gradient planes create depth.
// User is PROTAGONIST. Anime is the world they inhabit.

// DEFENSIVE ANIME FIELD ACCESSORS (top-level)
String _titleOf(dynamic a) {
  try {
    final t = a.title;
    if (t is String && t.isNotEmpty) return t;
  } catch (_) {}
  try {
    final t = a.name;
    if (t is String && t.isNotEmpty) return t;
  } catch (_) {}
  return '';
}

double _ratingOf(dynamic a) {
  try {
    final r = a.rating;
    if (r is num) return r.toDouble();
  } catch (_) {}
  return 0.0;
}

String? _coverOf(dynamic a) {
  for (final getter in [
    'coverUrl',
    'imageUrl',
    'coverImage',
    'image',
    'posterUrl',
  ]) {
    try {
      final dynamic d = a;
      dynamic v;
      switch (getter) {
        case 'coverUrl':
          v = d.coverUrl;
          break;
        case 'imageUrl':
          v = d.imageUrl;
          break;
        case 'coverImage':
          v = d.coverImage;
          break;
        case 'image':
          v = d.image;
          break;
        case 'posterUrl':
          v = d.posterUrl;
          break;
      }
      if (v is String && v.isNotEmpty) return v;
    } catch (_) {}
  }
  return null;
}

String? _bannerOf(dynamic a) {
  try {
    final v = a.bannerImage;
    if (v is String && v.isNotEmpty) return v;
  } catch (_) {}
  try {
    final v = a.banner;
    if (v is String && v.isNotEmpty) return v;
  } catch (_) {}
  try {
    final v = a.bannerUrl;
    if (v is String && v.isNotEmpty) return v;
  } catch (_) {}
  return null;
}

List<String> _genresOf(dynamic a) {
  try {
    final v = a.genres;
    if (v is List) return v.map((e) => e.toString()).toList();
  } catch (_) {}
  try {
    final v = a.genreList;
    if (v is List) return v.map((e) => e.toString()).toList();
  } catch (_) {}
  try {
    final v = a.genre;
    if (v is String && v.isNotEmpty) return [v];
  } catch (_) {}
  return [];
}

String _episodesOf(dynamic a) {
  try {
    final v = a.episodes;
    if (v is num) return v.toInt().toString();
    if (v is String && v.length <= 4) return v;
  } catch (_) {}
  try {
    final v = a.episodeCount;
    if (v is num) return v.toInt().toString();
    if (v is String && v.length <= 4) return v;
  } catch (_) {}
  return '?';
}

class _CinematicHero extends StatefulWidget {
  final AnimeModel anime;
  final Animation<double> zoomAnim;
  final ScrollController? scrollCtrl;
  final int pageIndex, total;
  final VoidCallback onWatch, onDetail;
  final String greeting;

  const _CinematicHero({
    required this.anime,
    required this.zoomAnim,
    this.scrollCtrl,
    required this.pageIndex,
    required this.total,
    required this.onWatch,
    required this.onDetail,
    this.greeting = 'Good Evening,',
  });

  @override
  State<_CinematicHero> createState() => _CinematicHeroState();
}

class _CinematicHeroState extends State<_CinematicHero>
    with TickerProviderStateMixin {
  late AnimationController _driftCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _driftCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _driftCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final anime = widget.anime;
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(32),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // LAYER 1: Anime Banner - full bleed zoomed
              AnimatedBuilder(
                animation: widget.zoomAnim,
                builder: (_, __) => Transform.scale(
                  scale: widget.zoomAnim.value,
                  child: ProxiedNetworkImage(
                    key: ValueKey('hero_img_${anime.id}'),
                    candidates: [
                      ...corsProxyCandidates(
                        _bannerOf(anime) ??
                            _coverOf(anime) ??
                            'https://s4.anilist.co/file/anilistcdn/media/anime/banner/166240-FLKBxUEKtxXl.jpg',
                      ),
                      ...corsProxyCandidates(
                        _coverOf(anime) ??
                            'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx166240-yFnHGAFR9DKI.jpg',
                      ),
                    ],
                    title: anime.title,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    fallback: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.surfaceElevated,
                            AppTheme.accent.withValues(alpha: 0.35),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // LAYER 2: Bottom-heavy gradient scrim
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.20),
                        Colors.black.withValues(alpha: 0.14),
                        Colors.black.withValues(alpha: 0.62),
                        AppTheme.background,
                      ],
                      stops: const [0.0, 0.30, 0.72, 1.0],
                    ),
                  ),
                ),
              ),

              // LAYER 3: Left scrim for text readability
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.28),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.60],
                    ),
                  ),
                ),
              ),

              // LAYER 4: Sakura atmosphere particles
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_pulseAnim, _driftCtrl]),
                  builder: (_, __) => CustomPaint(
                    painter: _HeroAtmospherePainter(
                      pulse: _pulseAnim.value,
                      drift: _driftCtrl.value,
                      scroll: widget.scrollCtrl?.hasClients == true
                          ? widget.scrollCtrl!.offset.clamp(0.0, 500.0)
                          : 0.0,
                    ),
                  ),
                ),
              ),

              // LAYER 5: TOP BAR - greeting + rank
              Positioned(
                top: 18,
                left: 20,
                right: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.greeting,
                            style: TextStyle(
                              color: AppTheme.textPrimary.withValues(alpha: 0.80),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Text(
                            'HITAKU',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              height: 1.0,
                              shadows: [
                                Shadow(color: Colors.black45, blurRadius: 10),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Rank pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.textPrimary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.textPrimary.withValues(alpha: 0.40),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'asset/Sakura Emperor Badge.png',
                            width: 14,
                            height: 14,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.star_rounded,
                              color: AppTheme.highlight,
                              size: 13,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Sakura Emperor',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // LAYER 6: BOTTOM - anime info + buttons + daily missions
              Positioned(
                left: 20,
                right: 16,
                bottom: 28,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Left: anime info + actions
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Genre tags
                          if (_genresOf(anime).isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: _genresOf(anime)
                                  .take(3)
                                  .map(
                                    (g) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.textPrimary.withValues(
                                          alpha: 0.18,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppTheme.textPrimary.withValues(
                                            alpha: 0.40,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        g,
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          const SizedBox(height: 8),

                          // Anime title - BIG
                          Text(
                            _titleOf(anime),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                              letterSpacing: 0.2,
                              shadows: [
                                // Tight, high-opacity contact shadow right
                                // behind the glyphs — this is what actually
                                // separates text from busy/bright artwork,
                                // the soft blur alone wasn't enough.
                                Shadow(color: Colors.black, blurRadius: 3, offset: Offset(0, 1)),
                                Shadow(color: Colors.black, blurRadius: 3, offset: Offset(0, -1)),
                                Shadow(color: Colors.black, blurRadius: 3, offset: Offset(1, 0)),
                                Shadow(color: Colors.black, blurRadius: 3, offset: Offset(-1, 0)),
                                // Wider ambient glow for extra separation on
                                // very bright backdrops.
                                Shadow(color: Colors.black, blurRadius: 20),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Rating + episodes row
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: AppTheme.highlight,
                                size: 13,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _ratingOf(anime).toStringAsFixed(1),
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 10),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: AppTheme.textPrimary.withValues(alpha: 0.50),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  '${_episodesOf(anime)} EP',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppTheme.textPrimary.withValues(alpha: 0.80),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Action buttons
                          Row(
                            children: [
                              // TONTON
                              GestureDetector(
                                onTap: widget.onWatch,
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.highlight,
                                        AppTheme.highlight,
                                        AppTheme.accent,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(22),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.highlight.withValues(
                                          alpha: 0.55,
                                        ),
                                        blurRadius: 20,
                                        offset: const Offset(0, 6),
                                        spreadRadius: -4,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.play_arrow_rounded,
                                        color: AppTheme.background,
                                        size: 18,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Tonton',
                                        style: TextStyle(
                                          color: AppTheme.background,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(width: 10),

                              // DETAIL
                              GestureDetector(
                                onTap: widget.onDetail,
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.textPrimary.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: AppTheme.textPrimary.withValues(
                                        alpha: 0.55,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Detail',
                                      textAlign: TextAlign.center,
                                      strutStyle: StrutStyle(
                                        fontSize: 13,
                                        height: 1.0,
                                        forceStrutHeight: true,
                                      ),
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        height: 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Right: Daily Mission glass card
                    SizedBox(width: 196, child: _DailyMissionCard()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── ACTIVITY & MISSION CARD (Tahap 3 merge) ────────────────────────────────
// Combines Daily Login streak + Daily Mission + Weekly Challenge into one
// collapsed summary row (3 compact stats) with a "Lihat Semua" tap-to-expand
// that reveals the original 3 cards below, fully intact — no functionality
// removed, just hidden behind a toggle so the collapsed state is light.
class _ActivityMissionCard extends StatefulWidget {
  const _ActivityMissionCard();
  @override
  State<_ActivityMissionCard> createState() => _ActivityMissionCardState();
}

class _ActivityMissionCardState extends State<_ActivityMissionCard> {
  bool _expanded = false;

  // Summary numbers — mirrors the data inside _DailyLoginStreakCard,
  // _DailyMissionCard, and _WeeklyChallengeCard (kept in sync manually
  // since those widgets manage their own internal state/animations).
  static const int _loginStreak = 7;
  static const int _missionDone = 2;
  static const int _missionTotal = 3;
  static const double _challengeProg = 17 / 28; // 7+3+1+6 of 10+5+3+10

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.22),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // ── Background artwork — trophy/achievement theme, with the
              // left side kept dark/empty by design so the stat row and
              // "Lihat Semua" toggle stay legible without extra darkening
              // there. Falls back to the old gold gradient if the asset is
              // ever missing.
              Positioned.fill(
                child: Image.asset(
                  'asset/images/home screen/Aktivitas & Misi.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color.lerp(AppTheme.surface, const Color(0xFF3D2A0F), 0.55)!,
                          Color.lerp(AppTheme.surfaceElevated, const Color(0xFFFFD700), 0.10)!,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              ),
              // Warm darken so text/glass stay legible over the artwork,
              // heavier on the right where the trophy illustration is busiest.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: 0.15),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Collapsed summary row ──
              Row(
                children: [
                  Expanded(
                    child: _ActivitySummaryStat(
                      icon: Icons.local_fire_department_rounded,
                      iconColor: AppTheme.accent,
                      value: '$_loginStreak Hari',
                      label: 'Login Streak',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: AppTheme.textSecondary.withValues(alpha: 0.15),
                  ),
                  Expanded(
                    child: _ActivitySummaryStat(
                      icon: Icons.task_alt_rounded,
                      iconColor: AppTheme.primary,
                      value: '$_missionDone/$_missionTotal',
                      label: 'Daily Mission',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: AppTheme.textSecondary.withValues(alpha: 0.15),
                  ),
                  Expanded(
                    child: _ActivitySummaryStat(
                      icon: Icons.emoji_events_rounded,
                      iconColor: const Color(0xFFFFD700),
                      value: '${(_challengeProg * 100).round()}%',
                      label: 'Weekly Challenge',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // ── Lihat Semua / Sembunyikan toggle ──
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _expanded ? 'Sembunyikan' : 'Lihat Semua',
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.accent,
                          size: 15,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // ── Expanded detail (original widgets, untouched) ──
              if (_expanded) ...[
                const SizedBox(height: 14),
                const _DailyLoginStreakCard(),
                const SizedBox(height: 14),
                _DailyMissionCard(),
                const SizedBox(height: 14),
                const _WeeklyChallengeCard(),
              ],
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

// Small stat block used in the collapsed _ActivityMissionCard summary row.
class _ActivitySummaryStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  const _ActivitySummaryStat({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary.withValues(alpha: 0.7),
            fontSize: 8,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// â”€â”€â”€ DAILY MISSION CARD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _DailyMissionCard extends StatelessWidget {
  _DailyMissionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: -4,
            offset: Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              // Alpha lowered from 0.60 — this card sits inside
              // _ActivityMissionCard which now has real background artwork;
              // a lighter tint lets it show through as true glass instead
              // of being fully covered.
              color: AppTheme.surfaceElevated.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primary.withValues(alpha: 0.14),
                          ),
                          child: const Icon(
                            Icons.assignment_turned_in_rounded,
                            color: AppTheme.primary,
                            size: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'DAILY MISSION',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    RichText(
                      text: const TextSpan(
                        text: '2',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                        children: [
                          TextSpan(
                            text: '/3',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildMissionItem(
                  icon: Icons.play_circle_fill_rounded,
                  title: 'Tonton 2 Episode',
                  progressText: '1/2',
                  progress: 0.5,
                  xp: '+30 XP',
                ),
                const SizedBox(height: 8),
                _buildMissionItem(
                  icon: Icons.favorite_rounded,
                  title: 'Like 3 Post',
                  progressText: '1/3',
                  progress: 0.33,
                  xp: '+30 XP',
                ),
                const SizedBox(height: 8),
                _buildMissionItem(
                  icon: Icons.chat_bubble_rounded,
                  title: 'Gabung di 1 Room',
                  progressText: '0/1',
                  progress: 0.0,
                  xp: '+20 XP',
                ),
                const SizedBox(height: 12),
                // Klaim All button
                Container(
                  width: double.infinity,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.highlight, AppTheme.accent],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.highlight.withValues(alpha: 0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.card_giftcard_rounded,
                                  color: AppTheme.background,
                                  size: 13,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Klaim All',
                                  style: TextStyle(
                                    color: AppTheme.background,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              '80 XP',
                              style: TextStyle(
                                color: AppTheme.background,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMissionItem({
    required IconData icon,
    required String title,
    required String progressText,
    required double progress,
    required String xp,
  }) {
    final done = progress >= 1.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 26,
          height: 26,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 2.4,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    done ? const Color(0xFF22C55E) : AppTheme.primary,
                  ),
                ),
              ),
              Icon(
                done ? Icons.check_rounded : icon,
                color: done ? const Color(0xFF22C55E) : AppTheme.primary,
                size: 11,
              ),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    progressText,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    xp,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Friends Activity Section — social proof, keeps the lobby feeling alive ──
// ─── PULSING DOT ──────────────────────────────────────────────────────────────
// A small breathing dot used for "online" / "live" status indicators.
// Parametrized (unlike _LiveDot above, which is hardcoded red) so it can be
// reused for green online dots, white dots on colored backgrounds, etc.
class _PulsingDot extends StatefulWidget {
  final Color color;
  final double size;
  const _PulsingDot({this.color = const Color(0xFF22C55E), this.size = 6});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.65 + 0.35 * _c.value),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.35 * _c.value),
              blurRadius: 5,
              spreadRadius: _c.value * 1.6,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── LIVE WAVEFORM ────────────────────────────────────────────────────────────
// Tiny 4-bar equalizer that oscillates continuously — used in place of a
// static mic icon to sell "this room has live audio happening right now".
class _LiveWaveform extends StatefulWidget {
  final Color color;
  final double barWidth;
  final double maxHeight;
  const _LiveWaveform({
    this.color = AppTheme.surfaceElevated,
    this.barWidth = 2.6,
    this.maxHeight = 14,
  });

  @override
  State<_LiveWaveform> createState() => _LiveWaveformState();
}

class _LiveWaveformState extends State<_LiveWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * 2 * math.pi;
        final phases = [0.0, 1.4, 2.6, 4.0];
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: phases.map((p) {
            final h = widget.maxHeight *
                (0.25 + 0.75 * (0.5 + 0.5 * math.sin(t + p)));
            return Container(
              width: widget.barWidth,
              height: h,
              margin: EdgeInsets.symmetric(horizontal: widget.barWidth * 0.4),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(widget.barWidth),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─── KOMUNITAS SECTION (Tahap 4 merge) ──────────────────────────────────────
// Combines Friends Activity + Live Rooms into one card with a chip switcher,
// instead of 2 separate full-width sections. Both original widgets are
// reused as-is inside — no logic duplicated, just wrapped in a tab shell.
class _KomunitasSection extends StatefulWidget {
  const _KomunitasSection();
  @override
  State<_KomunitasSection> createState() => _KomunitasSectionState();
}

class _KomunitasSectionState extends State<_KomunitasSection> {
  int _tab = 0; // 0 = Aktivitas Teman, 1 = Live Rooms

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _KomunitasChip(
                label: 'Aktivitas Teman',
                icon: Icons.people_alt_rounded,
                selected: _tab == 0,
                onTap: () => setState(() => _tab = 0),
              ),
              const SizedBox(width: 8),
              _KomunitasChip(
                label: 'Live Rooms',
                icon: Icons.podcasts_rounded,
                selected: _tab == 1,
                onTap: () => setState(() => _tab = 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _tab == 0 ? 16 : 0),
          child: _tab == 0
              ? const _FriendsActivitySection()
              : const _LiveRoomsSection(),
        ),
      ],
    );
  }
}

class _KomunitasChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _KomunitasChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.accent.withValues(alpha: 0.20)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppTheme.accent.withValues(alpha: 0.55)
                  : AppTheme.textSecondary.withValues(alpha: 0.20),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 12,
                color: selected ? AppTheme.accent : AppTheme.textSecondary.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppTheme.accent : AppTheme.textSecondary.withValues(alpha: 0.55),
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendsActivitySection extends StatelessWidget {
  const _FriendsActivitySection();

  static const _activities = [
    _FriendActivity(
      'Aiko',
      '🌸',
      'menyelesaikan',
      'Mushoku Tensei S2',
      '2m lalu',
      AppTheme.accent,
    ),
    _FriendActivity(
      'Kirito',
      '⚔',
      'mencapai Episode 24 di',
      'Sword Art Online',
      '12m lalu',
      AppTheme.accent,
    ),
    _FriendActivity(
      'Rei',
      '🔥',
      'bergabung di Room',
      'Solo Leveling Indonesia',
      '28m lalu',
      Color(0xFFEF4444),
    ),
    _FriendActivity(
      'Hana',
      '🎤',
      'memulai Voice Chat di',
      'Demon Slayer Room',
      '1j lalu',
      Color(0xFF06B6D4),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.10),
            blurRadius: 22,
            spreadRadius: -4,
            offset: Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF22C55E).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // ── Background artwork — connected silhouettes with an
            // orange→teal network-line gradient, echoing this card's own
            // accent-to-online-green glass tint. Falls back to a plain
            // surfaceElevated fill if the asset is ever missing.
            Positioned.fill(
              child: Image.asset(
                'asset/images/home screen/Komunitas (Teman Aktif).png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: AppTheme.surfaceElevated,
                ),
              ),
            ),
            BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              // Now that there's real artwork behind this glass layer, the
              // tint is lighter than before (alpha lowered) so the
              // silhouettes/network-lines actually show through instead of
              // being smothered by an opaque-ish gradient fill.
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(AppTheme.surfaceElevated, AppTheme.accent, 0.16)!
                      .withValues(alpha: 0.38),
                  Color.lerp(AppTheme.surfaceElevated, const Color(0xFF22C55E), 0.10)!
                      .withValues(alpha: 0.32),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.accent.withValues(alpha: 0.18),
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row — online friend count gives the social signal
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accent.withValues(alpha: 0.10),
                      ),
                      child: const Icon(
                        Icons.people_alt_rounded,
                        color: AppTheme.accent,
                        size: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'TEMAN AKTIF',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${_activities.length} online',
                      style: const TextStyle(
                        color: Color(0xFF22C55E),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14),
                // Overlapping avatar stack — quick "who's online" glance
                // before diving into the detailed rows below.
                SizedBox(
                  height: 34,
                  child: Stack(
                    children: List.generate(_activities.length, (i) {
                      final a = _activities[i];
                      return Positioned(
                        left: i * 22.0,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [a.color, a.color.withValues(alpha: 0.55)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: AppTheme.surfaceElevated, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: a.color.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            a.emoji,
                            style: const TextStyle(fontSize: 13.5),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 16),
                for (int i = 0; i < _activities.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _FriendActivityRow(activity: _activities[i]),
                ],
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

class _FriendActivity {
  final String name;
  final String emoji;
  final String action;
  final String target;
  final String time;
  final Color color;
  const _FriendActivity(
    this.name,
    this.emoji,
    this.action,
    this.target,
    this.time,
    this.color,
  );
}

class _FriendActivityRow extends StatefulWidget {
  final _FriendActivity activity;
  const _FriendActivityRow({required this.activity});

  @override
  State<_FriendActivityRow> createState() => _FriendActivityRowState();
}

class _FriendActivityRowState extends State<_FriendActivityRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {},
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: _pressed
                ? activity.color.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          activity.color,
                          activity.color.withValues(alpha: 0.55),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      activity.emoji,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: const BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        shape: BoxShape.circle,
                      ),
                      child: const _PulsingDot(size: 7.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: AppTheme.textSecondary,
                    ),
                    children: [
                      TextSpan(
                        text: activity.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(text: ' ${activity.action} '),
                      TextSpan(
                        text: activity.target,
                        style: TextStyle(
                          color: activity.color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 6),
              Text(
                activity.time,
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── TODAY PROGRESS INDICATOR ─────────────────────────────────────────────────
class _TodayProgressIndicator extends StatefulWidget {
  final double progress;
  const _TodayProgressIndicator({required this.progress});

  @override
  State<_TodayProgressIndicator> createState() =>
      _TodayProgressIndicatorState();
}

class _TodayProgressIndicatorState extends State<_TodayProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    Future.delayed(const Duration(milliseconds: 200), () {
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
    final int filledBlocks = (widget.progress * 10).round().clamp(0, 10);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final activeIndex = (_ctrl.value * filledBlocks).floor();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(10, (index) {
            final isFilled = index < filledBlocks && index <= activeIndex;
            final isJustLit = index == activeIndex && index < filledBlocks;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 6,
              height: isJustLit ? 18 : 16,
              margin: const EdgeInsets.only(right: 3.5),
              decoration: BoxDecoration(
                color: isFilled
                    ? AppTheme.accent
                    : AppTheme.textSecondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2.0),
                boxShadow: isJustLit
                    ? [
                        BoxShadow(
                          color: AppTheme.accent.withValues(alpha: 0.7),
                          blurRadius: 4,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        );
      },
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: Duration(seconds: 1))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Color(0xFFEF4444).withValues(alpha: 0.6 + 0.4 * _c.value),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0xFFEF4444).withValues(alpha: 0.4 * _c.value),
            blurRadius: 6,
            spreadRadius: _c.value * 2,
          ),
        ],
      ),
    ),
  );
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// TAHAP 3 â€” SEARCH OVERLAY
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _SearchOverlay extends StatelessWidget {
  final double topInset;
  final TextEditingController controller;
  final List<AnimeModel> animeList;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClose;
  final ValueChanged<AnimeModel> onResultTap;
  final List<String> recentSearches;
  final ValueChanged<String> onRecentTap;
  final ValueChanged<String> onRemoveRecent;
  final VoidCallback onClearRecent;

  const _SearchOverlay({
    super.key,
    required this.topInset,
    required this.controller,
    required this.animeList,
    required this.query,
    required this.onQueryChanged,
    required this.onClose,
    required this.onResultTap,
    this.recentSearches = const [],
    required this.onRecentTap,
    required this.onRemoveRecent,
    required this.onClearRecent,
  });

  // Defensive title getter â€” AnimeModel field name may vary across versions.
  String _titleOf(AnimeModel a) {
    try {
      final dynamic d = a;
      final t = d.title;
      if (t is String && t.isNotEmpty) return t;
    } catch (_) {}
    try {
      final dynamic d = a;
      final t = d.name;
      if (t is String && t.isNotEmpty) return t;
    } catch (_) {}
    return a.toString();
  }

  double _ratingOf(AnimeModel a) {
    try {
      final dynamic d = a;
      final r = d.rating;
      if (r is num) return r.toDouble();
    } catch (_) {}
    return 0;
  }

  String? _coverOf(AnimeModel a) {
    final dynamic d = a;
    try {
      final v = d.coverUrl;
      if (v is String && v.isNotEmpty) return v;
    } catch (_) {}
    try {
      final v = d.imageUrl;
      if (v is String && v.isNotEmpty) return v;
    } catch (_) {}
    try {
      final v = d.coverImage;
      if (v is String && v.isNotEmpty) return v;
    } catch (_) {}
    try {
      final v = d.image;
      if (v is String && v.isNotEmpty) return v;
    } catch (_) {}
    try {
      final v = d.posterUrl;
      if (v is String && v.isNotEmpty) return v;
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = query.trim().isEmpty
        ? <AnimeModel>[]
        : animeList
              .where(
                (a) => _titleOf(a).toLowerCase().contains(query.toLowerCase()),
              )
              .take(12)
              .toList();

    return GestureDetector(
      onTap: onClose,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: AppTheme.textPrimary.withValues(alpha: 0.15),
        child: GestureDetector(
          onTap: () {}, // absorb taps on the panel itself
          child: Padding(
            padding: EdgeInsets.only(top: topInset + 4, left: 16, right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // â”€â”€ Search input bar â”€â”€
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.accent.withValues(alpha: 0.22),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.12),
                        blurRadius: 22,
                        spreadRadius: -2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        color: AppTheme.textSecondary,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          autofocus: true,
                          onChanged: onQueryChanged,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          cursorColor: AppTheme.accent,
                          decoration: const InputDecoration(
                            hintText: 'Cari anime, room, atau komunitas...',
                            hintStyle: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                            border: InputBorder.none,
                            isCollapsed: true,
                          ),
                        ),
                      ),
                      if (query.isNotEmpty)
                        _PressableScale(
                          onTap: () {
                            controller.clear();
                            onQueryChanged('');
                          },
                          child: const Icon(
                            Icons.close_rounded,
                            color: AppTheme.textSecondary,
                            size: 16,
                          ),
                        ),
                      const SizedBox(width: 10),
                      _PressableScale(
                        onTap: onClose,
                        child: const Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: AppTheme.textSecondary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Results ──
                if (query.trim().isEmpty)
                  recentSearches.isNotEmpty
                      ? Flexible(
                          child: ListView(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'PENCARIAN TERAKHIR',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const Spacer(),
                                  _PressableScale(
                                    onTap: onClearRecent,
                                    child: const Text(
                                      'Hapus semua',
                                      style: TextStyle(
                                        color: AppTheme.accent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ...recentSearches.map(
                                (term) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => onRecentTap(term),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 10,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.history_rounded,
                                              size: 16,
                                              color: AppTheme.textSecondary
                                                  .withValues(alpha: 0.6),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                term,
                                                style: const TextStyle(
                                                  color: AppTheme.textPrimary,
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            _PressableScale(
                                              onTap: () =>
                                                  onRemoveRecent(term),
                                              child: Icon(
                                                Icons.close_rounded,
                                                size: 15,
                                                color: AppTheme.textSecondary
                                                    .withValues(alpha: 0.45),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.travel_explore_rounded,
                                  color: AppTheme.textSecondary.withValues(
                                    alpha: 0.35,
                                  ),
                                  size: 40,
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Mulai ketik untuk mencari anime favoritmu',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                else if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            color: AppTheme.textSecondary.withValues(alpha: 0.35),
                            size: 40,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Tidak ada hasil untuk "$query"',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final a = filtered[i];
                        return _SearchResultTile(
                          // Stagger index drives the entry fade/slide below —
                          // capped so a long result list doesn't leave the
                          // last few items waiting on a visibly long delay.
                          index: i.clamp(0, 8),
                          title: _titleOf(a),
                          rating: _ratingOf(a),
                          cover: _coverOf(a),
                          onTap: () => onResultTap(a),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatefulWidget {
  final int index;
  final String title;
  final double rating;
  final String? cover;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.index,
    required this.title,
    required this.rating,
    required this.cover,
    required this.onTap,
  });

  @override
  State<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<_SearchResultTile>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _entryCtrl;
  late final Animation<double> _entryAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _entryAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic);
    // Small per-item delay so results cascade in instead of popping in
    // simultaneously — capped via widget.index (see call site) so this
    // stays a quick ripple, not a slow chain, on long result lists.
    Future.delayed(Duration(milliseconds: 25 * widget.index), () {
      if (mounted) _entryCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entryAnim,
      builder: (context, child) => Opacity(
        opacity: _entryAnim.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _entryAnim.value) * 12),
          child: child,
        ),
      ),
      child: GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _pressed
                  ? AppTheme.accent.withValues(alpha: 0.30)
                  : AppTheme.accent.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(
                  0xFF8B5CF6,
                ).withValues(alpha: _pressed ? 0.10 : 0.04),
                blurRadius: _pressed ? 16 : 10,
                spreadRadius: -2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    SizedBox(
                      width: 42,
                      height: 56,
                      child: widget.cover != null
                          ? ProxiedNetworkImage.forUrl(
                              key: ValueKey('img_${widget.cover}'),
                              url: widget.cover,
                              title: widget.title,
                              width: 42,
                              height: 56,
                              fit: BoxFit.cover,
                              fallback: Container(
                                color: AppTheme.background,
                                child: const Icon(
                                  Icons.movie_outlined,
                                  color: AppTheme.textSecondary,
                                  size: 16,
                                ),
                              ),
                            )
                          : Container(
                              color: AppTheme.background,
                              child: const Icon(
                                Icons.movie_outlined,
                                color: AppTheme.textSecondary,
                                size: 16,
                              ),
                            ),
                    ),
                    // Subtle bottom fade so the rating chip below feels consistent
                    // with the rest of the premium card language in this file.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.35),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFFFBBF24).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFBBF24),
                            size: 10,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            widget.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Color(0xFF92660F),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: _pressed ? 0.04 : 0,
                duration: const Duration(milliseconds: 120),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// TAHAP 3 â€” NOTIFICATION PANEL
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _NotificationItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;
  final bool unread;
  const _NotificationItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
    this.unread = false,
  });
}

class _NotificationPanel extends StatelessWidget {
  final double topInset;
  final VoidCallback onClose;

  const _NotificationPanel({
    super.key,
    required this.topInset,
    required this.onClose,
  });

  static const _items = [
    _NotificationItem(
      icon: Icons.celebration_rounded,
      color: AppTheme.accent,
      title: 'Daily Mission selesai!',
      subtitle: 'Kamu mendapat 50 XP dari "Tonton 2 Episode"',
      time: '2m lalu',
      unread: true,
    ),
    _NotificationItem(
      icon: Icons.favorite_rounded,
      color: AppTheme.primary,
      title: 'Aiko Chan menyukai komentarmu',
      subtitle: 'di Solo Leveling Room',
      time: '14m lalu',
      unread: true,
    ),
    _NotificationItem(
      icon: Icons.live_tv_rounded,
      color: Color(0xFF22D3EE),
      title: 'Episode baru tayang',
      subtitle: 'Demon Slayer S3 Episode 12 sudah rilis',
      time: '1j lalu',
      unread: true,
    ),
    _NotificationItem(
      icon: Icons.group_rounded,
      color: Color(0xFF4ADE80),
      title: 'Kirito_01 bergabung di Room kamu',
      subtitle: 'Sword Art Online Room',
      time: '3j lalu',
    ),
    _NotificationItem(
      icon: Icons.workspace_premium_rounded,
      color: Color(0xFFFBBF24),
      title: 'Badge baru terbuka',
      subtitle: '🌸 Sakura Collector — koleksi 50 figure',
      time: 'Kemarin',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: AppTheme.textPrimary.withValues(alpha: 0.15),
        child: Align(
          alignment: Alignment.topRight,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: EdgeInsets.only(top: topInset + 4, right: 16),
              width: 300,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated.withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.18),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.12),
                    blurRadius: 26,
                    spreadRadius: -2,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      children: [
                        const Text(
                          'Notifikasi',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Color(
                              0xFFFF4FA3,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '3 baru',
                            style: TextStyle(
                              color: AppTheme.accent,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: onClose,
                          child: Icon(
                            Icons.close_rounded,
                            color: AppTheme.textSecondary,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 1,
                    color: AppTheme.accent.withValues(alpha: 0.08),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(10),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (ctx, i) =>
                          _NotificationTile(item: _items[i]),
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

class _NotificationTile extends StatefulWidget {
  final _NotificationItem item;
  const _NotificationTile({required this.item});

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: it.unread
                ? Color(
                    0xFF8B5CF6,
                  ).withValues(alpha: _pressed ? 0.09 : 0.05)
                : (_pressed
                      ? AppTheme.accent.withValues(alpha: 0.04)
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: it.color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: it.color.withValues(alpha: 0.18),
                      blurRadius: 8,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Icon(it.icon, color: it.color, size: 14.5),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      it.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      it.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      it.time,
                      style: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.60),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (it.unread)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.45),
                        blurRadius: 5,
                        spreadRadius: 0.5,
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

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// TAHAP 3 â€” PROFILE MENU
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _ProfileMenu extends StatelessWidget {
  final double topInset;
  final VoidCallback onClose;

  const _ProfileMenu({
    super.key,
    required this.topInset,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_ProfileMenuItem>[
      _ProfileMenuItem(
        Icons.person_rounded,
        'Lihat Profile',
        AppTheme.textPrimary,
      ),
      _ProfileMenuItem(
        Icons.video_library_rounded,
        'Library Saya',
        AppTheme.textPrimary,
      ),
      _ProfileMenuItem(
        Icons.emoji_events_rounded,
        'Achievement & Badge',
        AppTheme.textPrimary,
      ),
      _ProfileMenuItem(
        Icons.settings_rounded,
        'Pengaturan',
        AppTheme.textPrimary,
      ),
      _ProfileMenuItem(
        Icons.help_outline_rounded,
        'Bantuan',
        AppTheme.textPrimary,
      ),
      _ProfileMenuItem(Icons.logout_rounded, 'Keluar', Color(0xFFF87171)),
    ];

    return GestureDetector(
      onTap: onClose,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: AppTheme.textPrimary.withValues(alpha: 0.15),
        child: Align(
          alignment: Alignment.topRight,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: EdgeInsets.only(top: topInset + 4, right: 16),
              width: 230,
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.20),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.08),
                    blurRadius: 22,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Profile header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                    child: Row(
                      children: [
                        _SafeAssetAvatar(
                          assetPath: 'asset/Hitaku_Avatar_Face.png',
                          size: 36,
                          borderColor: Color(
                            0xFF8B5CF6,
                          ).withValues(alpha: 0.40),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'HITAKU',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Sakura Emperor',
                                style: TextStyle(
                                  color: Color(
                                    0xFFFF4FA3,
                                  ).withValues(alpha: 0.85),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 1,
                    color: AppTheme.accent.withValues(alpha: 0.08),
                  ),
                  const SizedBox(height: 6),
                  ...items.map((item) {
                    final isDefault = item.color == AppTheme.textPrimary;
                    return InkWell(
                      onTap: onClose,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.icon,
                              color: isDefault
                                  ? AppTheme.textSecondary
                                  : item.color,
                              size: 15.5,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              item.label,
                              style: TextStyle(
                                color: item.color,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileMenuItem {
  final IconData icon;
  final String label;
  final Color color;
  const _ProfileMenuItem(this.icon, this.label, this.color);
}

// ─── WEEKLY CHALLENGE CARD ───────────────────────────────────────────────────
class _WeeklyChallengeCard extends StatefulWidget {
  const _WeeklyChallengeCard();
  @override
  State<_WeeklyChallengeCard> createState() => _WeeklyChallengeCardState();
}

class _WeeklyChallengeCardState extends State<_WeeklyChallengeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmer;

  final _challenges = <_Challenge>[
    _Challenge(
      'Tonton 10 Episode',
      7,
      10,
      120,
      Icons.play_circle_rounded,
      AppTheme.accent,
    ),
    _Challenge(
      'Kumpulkan 5 Badge',
      3,
      5,
      80,
      Icons.workspace_premium_rounded,
      AppTheme.accent,
    ),
    _Challenge(
      'Ikut 3 Voice Chat',
      1,
      3,
      100,
      Icons.mic_rounded,
      const Color(0xFF06B6D4),
    ),
    _Challenge(
      'Like 10 Post',
      6,
      10,
      60,
      Icons.favorite_rounded,
      const Color(0xFF22C55E),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalXp = _challenges.fold(0, (s, c) => s + c.xp);
    final earnedXp = _challenges.fold(
      0,
      (s, c) => s + (c.progress / c.total * c.xp).round(),
    );
    final overallProg =
        _challenges.fold<int>(0, (s, c) => s + c.progress) /
        _challenges.fold<int>(0, (s, c) => s + c.total);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.accent.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.20),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            // Was a solid dark-brown→background gradient fill that fully
            // covered the parent card's background artwork. Liquid glass
            // treatment (blur + low-alpha tint) lets it show through,
            // matching _DailyLoginStreakCard and _DailyMissionCard above.
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.06),
                    AppTheme.primary.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.accent, AppTheme.primary],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.emoji_events_rounded,
                          color: AppTheme.surfaceElevated,
                          size: 10,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'MINGGU INI',
                          style: TextStyle(
                            color: AppTheme.surfaceElevated,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(overallProg * 100).round()}%',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFD700).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$earnedXp/$totalXp XP',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              // Overall progress
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: overallProg.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: AppTheme.surfaceElevated.withValues(alpha: 0.10),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.accent,
                  ),
                ),
              ),
              SizedBox(height: 14),
              // Challenge list
              ...List.generate(_challenges.length, (i) {
                final c = _challenges[i];
                final done = c.progress >= c.total;
                final prog = (c.progress / c.total).clamp(0.0, 1.0);
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: i == _challenges.length - 1 ? 0 : 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: done
                              ? Color(0xFFFFD700).withValues(alpha: 0.15)
                              : c.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: done
                                ? Color(0xFFFFD700).withValues(alpha: 0.4)
                                : c.color.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Icon(
                          c.icon,
                          color: done ? const Color(0xFFFFD700) : c.color,
                          size: 14.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.title,
                              style: TextStyle(
                                color: done
                                    ? const Color(0xFFFFD700)
                                    : AppTheme.surfaceElevated,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: prog,
                                      minHeight: 4,
                                      backgroundColor: AppTheme.surfaceElevated.withValues(
                                        alpha: 0.08,
                                      ),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        done
                                            ? const Color(0xFFFFD700)
                                            : c.color,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '${c.progress}/${c.total}',
                                  style: TextStyle(
                                    color: AppTheme.surfaceElevated.withValues(alpha: 0.5),
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: done
                              ? Color(0xFFFFD700).withValues(alpha: 0.12)
                              : c.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          done ? '✓' : '+${c.xp}',
                          style: TextStyle(
                            color: done ? const Color(0xFFFFD700) : c.color,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              // Reward preview
              SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Color(0xFFFFD700).withValues(alpha: 0.15),
                  ),
                  color: Color(0xFFFFD700).withValues(alpha: 0.04),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFF8800)],
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppTheme.surfaceElevated,
                        size: 13,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Selesaikan semua tantangan untuk mendapatkan **Void Border** eksklusif!',
                        style: TextStyle(
                          color: AppTheme.surfaceElevated.withValues(alpha: 0.70),
                          fontSize: 9,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Challenge {
  final String title;
  final int progress;
  final int total;
  final int xp;
  final IconData icon;
  final Color color;
  const _Challenge(
    this.title,
    this.progress,
    this.total,
    this.xp,
    this.icon,
    this.color,
  );
}

// ─── QUICK PREMIUM ROW ───────────────────────────────────────────────────────
class _LiveRoomsSection extends StatelessWidget {
  const _LiveRoomsSection();

  static const _rooms = [
    _LiveRoom('Solo Leveling Room', '1.2k', true, AppTheme.accent, 24),
    _LiveRoom('Demon Slayer Chat', '856', true, Color(0xFFEF4444), 15),
    _LiveRoom('Nostalgia Corner', '432', false, Color(0xFF06B6D4), 8),
    _LiveRoom('Music Japan', '231', false, Color(0xFF22C55E), 5),
  ];

  @override
  Widget build(BuildContext context) {
    final featured = _rooms.first;
    final rest = _rooms.skip(1).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _FeaturedLiveRoomCard(room: featured),
          const SizedBox(height: 10),
          ...List.generate(rest.length, (i) {
            final room = rest[i];
            return Padding(
              padding: EdgeInsets.only(bottom: i == rest.length - 1 ? 0 : 8),
              child: _LiveRoomTile(room: room),
            );
          }),
        ],
      ),
    );
  }
}

// ─── FEATURED LIVE ROOM CARD ──────────────────────────────────────────────────
// The busiest room gets a wide, colored, standalone card instead of blending
// into the plain tile list below — same "not every card looks the same"
// principle applied to Premium Pass / Flash Sale.
class _FeaturedLiveRoomCard extends StatelessWidget {
  final _LiveRoom room;
  _FeaturedLiveRoomCard({required this.room});

  static const _memberEmojis = ['🌸', '⚔', '🔥', '🎧'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [room.color, room.color.withValues(alpha: 0.72)],
        ),
        boxShadow: [
          BoxShadow(
            color: room.color.withValues(alpha: 0.30),
            blurRadius: 20,
            spreadRadius: -2,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulsingDot(color: AppTheme.surfaceElevated, size: 6),
                    SizedBox(width: 5),
                    Text(
                      'LIVE SEKARANG',
                      style: TextStyle(
                        color: AppTheme.surfaceElevated,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Spacer(),
              _LiveWaveform(color: AppTheme.surfaceElevated.withValues(alpha: 0.9)),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.surfaceElevated.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.mic_rounded,
                    color: AppTheme.surfaceElevated,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.surfaceElevated,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '${room.members} members • ${room.onlineNow} online',
                      style: TextStyle(
                        color: AppTheme.surfaceElevated.withValues(alpha: 0.85),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              // Overlapping avatar stack — the "people already here" cue
              SizedBox(
                width: 66,
                height: 28,
                child: Stack(
                  children: List.generate(_memberEmojis.length, (i) {
                    return Positioned(
                      left: i * 16.0,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.surfaceElevated.withValues(alpha: 0.95),
                          border: Border.all(color: room.color, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _memberEmojis[i],
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.headset_mic_rounded,
                      color: room.color,
                      size: 13,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Gabung',
                      style: TextStyle(
                        color: room.color,
                        fontSize: 11,
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
    );
  }
}

class _LiveRoom {
  final String name;
  final String members;
  final bool isLive;
  final Color color;
  final int onlineNow;
  const _LiveRoom(
    this.name,
    this.members,
    this.isLive,
    this.color,
    this.onlineNow,
  );
}

class _LiveRoomTile extends StatefulWidget {
  final _LiveRoom room;
  const _LiveRoomTile({required this.room});
  @override
  State<_LiveRoomTile> createState() => _LiveRoomTileState();
}

class _LiveRoomTileState extends State<_LiveRoomTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.room;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {},
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: AppTheme.surfaceElevated.withValues(alpha: 0.80),
            border: Border.all(
              color: r.isLive
                  ? r.color.withValues(alpha: 0.25)
                  : AppTheme.surfaceElevated.withValues(alpha: 0.4),
              width: r.isLive ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: r.color.withValues(alpha: r.isLive ? 0.10 : 0.03),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Room avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [r.color, r.color.withValues(alpha: 0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: r.isLive
                      ? const _LiveWaveform(
                          color: AppTheme.surfaceElevated,
                          barWidth: 2.2,
                          maxHeight: 15,
                        )
                      : const Icon(
                          Icons.chat_rounded,
                          color: AppTheme.surfaceElevated,
                          size: 14.5,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            r.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (r.isLive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Color(
                                0xFFEF4444,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 6.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.people_rounded,
                          size: 10,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${r.members} members',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        r.isLive
                            ? const _PulsingDot(size: 6)
                            : Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: Color(
                                    0xFF7C7299,
                                  ).withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                              ),
                        const SizedBox(width: 3),
                        Text(
                          '${r.onlineNow} online',
                          style: TextStyle(
                            color: r.isLive
                                ? const Color(0xFF22C55E)
                                : Color(
                                    0xFF7C7299,
                                  ).withValues(alpha: 0.6),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── COSMETICS SHOP CAROUSEL ─────────────────────────────────────────────────
class _ShopCarousel extends StatefulWidget {
  const _ShopCarousel();
  @override
  State<_ShopCarousel> createState() => _ShopCarouselState();
}

class _ShopCarouselState extends State<_ShopCarousel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;

  static const _items = [
    _ShopItem(
      'Sakura Emperor Border',
      'Border',
      Icons.hexagon_rounded,
      AppTheme.accent,
      '120 Gems',
      rarity: _Rarity.legendary,
      tag: 'HOT',
      originalPrice: '200 Gems',
    ),
    _ShopItem(
      'Void Effect',
      'Profile FX',
      Icons.auto_awesome,
      AppTheme.accent,
      '150 Gems',
      rarity: _Rarity.epic,
      tag: 'NEW',
    ),
    _ShopItem(
      'Night Sky',
      'Profile BG',
      Icons.wallpaper_rounded,
      Color(0xFF06B6D4),
      '100 Gems',
      rarity: _Rarity.rare,
    ),
    _ShopItem(
      'Kawaii Bubble',
      'Chat Bubble',
      Icons.chat_rounded,
      Color(0xFF22C55E),
      '80 Gems',
      rarity: _Rarity.common,
    ),
    _ShopItem(
      'Golden Crown',
      'Border',
      Icons.workspace_premium_rounded,
      Color(0xFFFFD700),
      '200 Gems',
      rarity: _Rarity.legendary,
      tag: 'LIMITED',
      originalPrice: '320 Gems',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 262,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: _items.length,
        itemBuilder: (ctx, i) =>
            _ShopItemCard(item: _items[i], glowAnim: _glowCtrl),
      ),
    );
  }
}

// ── Decorative facet pattern for cosmetic shop item preview tiles.
// Draws a few translucent diagonal facets/lines so the tile reads as
// a faceted gem/item card rather than a flat solid-color box.
class _ItemFacetPainter extends CustomPainter {
  final Color color;
  final double glow;
  _ItemFacetPainter({required this.color, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.surfaceElevated.withValues(alpha: 0.08 + glow * 0.05)
      ..style = PaintingStyle.fill;

    // Top-right facet triangle
    final path1 = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.55)
      ..lineTo(size.width * 0.55, 0)
      ..close();
    canvas.drawPath(path1, paint);

    // Bottom-left facet triangle, slightly dimmer
    paint.color = color.withValues(alpha: 0.10);
    final path2 = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.45)
      ..lineTo(size.width * 0.40, size.height)
      ..close();
    canvas.drawPath(path2, paint);

    // Thin diagonal accent line
    final linePaint = Paint()
      ..color = AppTheme.surfaceElevated.withValues(alpha: 0.14)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.15, size.height),
      Offset(size.width * 0.55, 0),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_ItemFacetPainter old) =>
      old.glow != glow || old.color != color;
}

// ─── COSMETIC PREVIEW ART ─────────────────────────────────────────────────────
// Renders what each cosmetic actually looks like when equipped — a real ring
// around a mock avatar for borders, a mock avatar with a particle aura for
// profile FX, a mini profile-card mockup for backgrounds, and an actual
// speech-bubble shape for chat bubbles — instead of a generic icon sitting on
// a plain colored circle. Falls back to the old icon badge for anything that
// doesn't match a known category.
// ─── COSMETIC PREVIEW ART ─────────────────────────────────────────────────────
// Full-bleed preview art — the decoration fills the ENTIRE tile like an actual
// scene/atmosphere (scattered dust, nebula blobs, orbiting sparkles), with a
// mock avatar sitting inside it. This is what makes a cosmetic preview read as
// premium instead of "a small icon floating in an empty gradient box".
enum _CosmeticKind { border, profileFx, profileBg, chatBubble, generic }

_CosmeticKind _kindOfType(String type) {
  final t = type.toLowerCase();
  if (t.contains('border')) return _CosmeticKind.border;
  if (t.contains('fx') || t.contains('effect')) return _CosmeticKind.profileFx;
  if (t.contains('bg') || t.contains('background')) return _CosmeticKind.profileBg;
  if (t.contains('bubble')) return _CosmeticKind.chatBubble;
  return _CosmeticKind.generic;
}

class _CosmeticPreviewContent extends StatelessWidget {
  final _ShopItem item;
  final double glow;
  const _CosmeticPreviewContent({required this.item, required this.glow});

  @override
  Widget build(BuildContext context) {
    switch (_kindOfType(item.type)) {
      case _CosmeticKind.border:
        return _BorderPreview(color: item.color, rarity: item.rarity, glow: glow);
      case _CosmeticKind.profileFx:
        return _ProfileFxPreview(color: item.color, glow: glow);
      case _CosmeticKind.profileBg:
        return _ProfileBgPreview(color: item.color, name: item.name);
      case _CosmeticKind.chatBubble:
        return _ChatBubblePreview(color: item.color, glow: glow);
      case _CosmeticKind.generic:
        return Center(
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surfaceElevated.withValues(alpha: 0.92),
              boxShadow: [
                BoxShadow(
                  color: item.color.withValues(alpha: 0.30),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
        );
    }
  }
}

// Small placeholder avatar so borders/FX previews have something real to
// sit around instead of floating in empty space.
class _MockAvatar extends StatelessWidget {
  final double size;
  const _MockAvatar({this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFCBD5F5), Color(0xFF94A3D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.person_rounded,
        color: AppTheme.surfaceElevated.withValues(alpha: 0.85),
        size: size * 0.55,
      ),
    );
  }
}

// ── BORDER: fills the whole tile with a swirling nebula-style aura (dust +
// soft cloud blobs + a bright defined rim), scaled up so it reads as an
// actual "scene" wrapped around the avatar — not a thin ring in empty space.
class _BorderPreview extends StatelessWidget {
  final Color color;
  final _Rarity rarity;
  final double glow;
  const _BorderPreview({
    required this.color,
    required this.rarity,
    required this.glow,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        final avatarSize = side * 0.32;
        return Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(side, side),
              painter: _BorderRingPainter(
                color: color,
                rarity: rarity,
                glow: glow,
              ),
            ),
            _MockAvatar(size: avatarSize),
          ],
        );
      },
    );
  }
}

// Paints an organic, asymmetric surround instead of a perfect geometric
// ring — irregular soft haze blobs plus scattered petals/shards at varied
// sizes, rotations and distances, the way a real illustrated decoration
// (falling petals, drifting embers) looks rather than a "radar ring".
class _BorderRingPainter extends CustomPainter {
  final Color color;
  final _Rarity rarity;
  final double glow;
  const _BorderRingPainter({
    required this.color,
    required this.rarity,
    required this.glow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final side = size.width;
    final isPremium = rarity != _Rarity.common;
    // Seed mixes color + rarity so the scatter is stable across rebuilds but
    // distinct per item.
    final rnd = math.Random(color.toARGB32() ^ (rarity.index * 7919));

    // Fine dust across the whole tile for atmosphere.
    final dustCount = isPremium ? 22 : 8;
    for (int i = 0; i < dustCount; i++) {
      final dx = rnd.nextDouble() * side;
      final dy = rnd.nextDouble() * side;
      final r = 0.6 + rnd.nextDouble() * 1.5;
      final useWhite = rnd.nextBool();
      canvas.drawCircle(
        Offset(dx, dy),
        r,
        Paint()
          ..color = (useWhite ? AppTheme.surfaceElevated : color).withValues(
            alpha: (0.22 + rnd.nextDouble() * 0.3) * (0.6 + glow * 0.4),
          ),
      );
    }

    if (!isPremium) {
      // Common: just a soft, slightly uneven halo — deliberately plain.
      canvas.drawCircle(
        center,
        side * 0.30,
        Paint()
          ..color = color.withValues(alpha: 0.18 + glow * 0.08)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, side * 0.09),
      );
      return;
    }

    // Irregular haze — 4 overlapping soft blobs placed off-center at
    // uneven distances/sizes so the aura silhouette isn't a perfect
    // circle. This alone is what breaks the "radar ring" look.
    final hazeCount = rarity == _Rarity.legendary ? 5 : rarity == _Rarity.epic ? 4 : 3;
    for (int i = 0; i < hazeCount; i++) {
      final angle = rnd.nextDouble() * 2 * math.pi;
      final dist = side * (0.16 + rnd.nextDouble() * 0.14);
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * dist;
      final r = side * (0.20 + rnd.nextDouble() * 0.14);
      canvas.drawCircle(
        pos,
        r,
        Paint()
          ..color = color.withValues(alpha: (0.16 + glow * 0.12))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.75),
      );
    }
    // One brighter, tighter bloom right behind the avatar so it still
    // reads as glowing at the core.
    canvas.drawCircle(
      center,
      side * 0.22,
      Paint()
        ..color = color.withValues(alpha: 0.22 + glow * 0.16)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, side * 0.10),
    );

    if (rarity == _Rarity.legendary) {
      // Scattered sakura petals at random size/rotation/distance — like
      // petals drifting around the avatar, not a uniform ring of clones.
      const petalCount = 16;
      for (int i = 0; i < petalCount; i++) {
        final angle = rnd.nextDouble() * 2 * math.pi;
        final dist = side * (0.22 + rnd.nextDouble() * 0.30);
        final pos = center + Offset(math.cos(angle), math.sin(angle)) * dist;
        final petalScale = side * (0.05 + rnd.nextDouble() * 0.05);
        final rotation = rnd.nextDouble() * 2 * math.pi;
        final alpha = 0.55 + rnd.nextDouble() * 0.4;
        _drawPetal(canvas, pos, rotation, color, petalScale, alpha);
      }
      // A signature focal bloom (small rosette) off-center, replacing a
      // generic crown — a distinct illustrated detail rather than a UI
      // ornament.
      _drawBloom(
        canvas,
        center + Offset(side * 0.24, -side * 0.30),
        side * 0.075,
        color,
        glow,
      );
      // A second, smaller bloom on the opposite side for balance.
      _drawBloom(
        canvas,
        center + Offset(-side * 0.28, side * 0.24),
        side * 0.05,
        color,
        glow,
      );
    } else if (rarity == _Rarity.epic) {
      // Scattered angular shards for a "void/crystal" feel — irregular
      // placement, not an even ring of identical gems.
      const shardCount = 8;
      for (int i = 0; i < shardCount; i++) {
        final angle = rnd.nextDouble() * 2 * math.pi;
        final dist = side * (0.24 + rnd.nextDouble() * 0.24);
        final pos = center + Offset(math.cos(angle), math.sin(angle)) * dist;
        final r = side * (0.025 + rnd.nextDouble() * 0.03);
        _drawGem(canvas, pos, color, r);
      }
    } else if (rarity == _Rarity.rare) {
      const shardCount = 5;
      for (int i = 0; i < shardCount; i++) {
        final angle = rnd.nextDouble() * 2 * math.pi;
        final dist = side * (0.22 + rnd.nextDouble() * 0.18);
        final pos = center + Offset(math.cos(angle), math.sin(angle)) * dist;
        final r = side * (0.018 + rnd.nextDouble() * 0.02);
        _drawGem(canvas, pos, color, r);
      }
    }
  }

  void _drawPetal(
    Canvas canvas,
    Offset pos,
    double rotation,
    Color color,
    double scale,
    double alpha,
  ) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(rotation);
    final len = scale;
    final w = scale * 0.6;
    final path = Path()
      ..moveTo(0, -len)
      ..quadraticBezierTo(w, -len * 0.25, 0, len * 0.75)
      ..quadraticBezierTo(-w, -len * 0.25, 0, -len)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [AppTheme.surfaceElevated, color],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(-w, -len, w * 2, len * 1.8))
        ..color = color.withValues(alpha: alpha),
    );
    canvas.restore();
  }

  // A tiny 5-petal rosette used as a one-off focal accent rather than a
  // ring of identical repeated shapes.
  void _drawBloom(Canvas canvas, Offset pos, double scale, Color color, double glow) {
    for (int i = 0; i < 5; i++) {
      final angle = (2 * math.pi / 5) * i;
      final petalPos = pos + Offset(math.cos(angle), math.sin(angle)) * scale * 0.5;
      _drawPetal(canvas, petalPos, angle + math.pi / 2, color, scale, 0.75 + glow * 0.2);
    }
    canvas.drawCircle(
      pos,
      scale * 0.32,
      Paint()..color = AppTheme.surfaceElevated.withValues(alpha: 0.85 + glow * 0.15),
    );
  }

  void _drawGem(Canvas canvas, Offset pos, Color color, double r) {
    final path = Path()
      ..moveTo(pos.dx, pos.dy - r)
      ..lineTo(pos.dx + r, pos.dy)
      ..lineTo(pos.dx, pos.dy + r)
      ..lineTo(pos.dx - r, pos.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = AppTheme.surfaceElevated.withValues(alpha: 0.92));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.22,
    );
  }

  @override
  bool shouldRepaint(covariant _BorderRingPainter old) =>
      old.glow != glow || old.color != color || old.rarity != rarity;
}

// ── PROFILE FX: a full-bleed colored aura with dust and orbiting sparkle
// glyphs spread across the whole tile, wrapped around a mock avatar — reads
// as "an effect applied to your whole profile", not a bare icon.
class _ProfileFxPreview extends StatelessWidget {
  final Color color;
  final double glow;
  const _ProfileFxPreview({required this.color, required this.glow});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        final avatarSize = side * 0.40;
        return Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(side, side),
              painter: _AuraFieldPainter(color: color, glow: glow),
            ),
            _MockAvatar(size: avatarSize),
          ],
        );
      },
    );
  }
}

class _AuraFieldPainter extends CustomPainter {
  final Color color;
  final double glow;
  _AuraFieldPainter({required this.color, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final side = size.width;

    // Soft radial aura filling most of the tile.
    canvas.drawCircle(
      center,
      side * 0.46,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.32 * glow + 0.10),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: side * 0.46)),
    );

    // Dust spread across the whole tile.
    final rnd = math.Random(color.toARGB32());
    for (int i = 0; i < 20; i++) {
      final dx = rnd.nextDouble() * side;
      final dy = rnd.nextDouble() * side;
      final r = 0.6 + rnd.nextDouble() * 1.6;
      canvas.drawCircle(
        Offset(dx, dy),
        r,
        Paint()
          ..color = AppTheme.surfaceElevated.withValues(
            alpha: (0.25 + rnd.nextDouble() * 0.4) * (0.5 + glow * 0.5),
          ),
      );
    }

    // Bigger orbiting sparkle glyphs (drawn as tiny 4-point stars) circling
    // the avatar so the effect reads as active/moving.
    for (int i = 0; i < 4; i++) {
      final angle = (math.pi / 2) * i + glow * 2 * math.pi;
      final r = side * 0.34;
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * r;
      _drawStar(canvas, pos, side * 0.035, AppTheme.surfaceElevated.withValues(alpha: 0.7 + glow * 0.3));
    }
  }

  void _drawStar(Canvas canvas, Offset pos, double r, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = r * 0.35;
    canvas.drawLine(pos.translate(-r, 0), pos.translate(r, 0), paint);
    canvas.drawLine(pos.translate(0, -r), pos.translate(0, r), paint);
  }

  @override
  bool shouldRepaint(covariant _AuraFieldPainter old) =>
      old.glow != glow || old.color != color;
}

// ── PROFILE BACKGROUND: fills the entire tile with the actual backdrop
// scene (starfield for night/space themes, soft bokeh wash otherwise), with
// a small avatar tucked in the corner — exactly how it will actually look
// applied to a profile, not an abstract color swatch.
class _ProfileBgPreview extends StatelessWidget {
  final Color color;
  final String name;
  const _ProfileBgPreview({required this.color, required this.name});

  @override
  Widget build(BuildContext context) {
    final n = name.toLowerCase();
    final isNight = n.contains('night') ||
        n.contains('sky') ||
        n.contains('galaxy') ||
        n.contains('void') ||
        n.contains('space');
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isNight
                        ? [Color(0xFF0B1023), color.withValues(alpha: 0.6)]
                        : [color.withValues(alpha: 0.55), color.withValues(alpha: 0.15)],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: isNight
                    ? _MiniStarsPainter(color: AppTheme.surfaceElevated)
                    : _BgBokehPainter(color: color),
              ),
            ),
            Positioned(
              left: side * 0.08,
              bottom: side * 0.08,
              child: _MockAvatar(size: side * 0.24),
            ),
          ],
        );
      },
    );
  }
}

class _MiniStarsPainter extends CustomPainter {
  final Color color;
  _MiniStarsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Fixed seed so the star field is stable across rebuilds instead of
    // jumping around every time this repaints.
    final rnd = math.Random(7);
    final paint = Paint();
    for (int i = 0; i < 26; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height * 0.85;
      final r = 0.6 + rnd.nextDouble() * 1.4;
      paint.color = color.withValues(alpha: 0.4 + rnd.nextDouble() * 0.5);
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniStarsPainter old) => false;
}

class _BgBokehPainter extends CustomPainter {
  final Color color;
  _BgBokehPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(color.toARGB32());
    for (int i = 0; i < 8; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      final r = size.width * (0.08 + rnd.nextDouble() * 0.10);
      canvas.drawCircle(
        Offset(dx, dy),
        r,
        Paint()
          ..color = AppTheme.surfaceElevated.withValues(alpha: 0.14 + rnd.nextDouble() * 0.12)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BgBokehPainter old) => false;
}

// ── CHAT BUBBLE: full-bleed dust field around a mock avatar with a real
// speech-bubble shape (rounded rect + tail) tucked at the corner, so it
// reads as a chat cosmetic that fills the whole tile like the others.
class _ChatBubblePreview extends StatelessWidget {
  final Color color;
  final double glow;
  const _ChatBubblePreview({required this.color, required this.glow});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        final avatarSize = side * 0.34;
        return Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(side, side),
              painter: _ChatDustPainter(color: color, glow: glow),
            ),
            _MockAvatar(size: avatarSize),
            Positioned(
              right: side * 0.10,
              top: side * 0.08,
              child: _MiniBubble(color: color, size: side * 0.34),
            ),
          ],
        );
      },
    );
  }
}

class _MiniBubble extends StatelessWidget {
  final Color color;
  final double size;
  const _MiniBubble({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.72,
      child: CustomPaint(
        painter: _ChatBubbleShapePainter(color: color),
        child: Center(
          child: Text('👋', style: TextStyle(fontSize: size * 0.32)),
        ),
      ),
    );
  }
}

class _ChatDustPainter extends CustomPainter {
  final Color color;
  final double glow;
  _ChatDustPainter({required this.color, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(color.toARGB32());
    for (int i = 0; i < 12; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      final r = 1.0 + rnd.nextDouble() * 2.0;
      canvas.drawCircle(
        Offset(dx, dy),
        r,
        Paint()..color = color.withValues(alpha: (0.25 + rnd.nextDouble() * 0.3) * (0.6 + glow * 0.4)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChatDustPainter old) => old.glow != glow;
}

class _ChatBubbleShapePainter extends CustomPainter {
  final Color color;
  const _ChatBubbleShapePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final bubbleHeight = size.height - 8;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, bubbleHeight),
      const Radius.circular(12),
    );
    final path = Path()
      ..addRRect(rrect)
      ..moveTo(14, bubbleHeight)
      ..lineTo(8, size.height)
      ..lineTo(22, bubbleHeight)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ChatBubbleShapePainter old) =>
      old.color != color;
}

enum _Rarity { common, rare, epic, legendary }

extension _RarityStyle on _Rarity {
  String get label {
    switch (this) {
      case _Rarity.common:
        return 'Common';
      case _Rarity.rare:
        return 'Rare';
      case _Rarity.epic:
        return 'Epic';
      case _Rarity.legendary:
        return 'Legendary';
    }
  }

  Color get color {
    switch (this) {
      case _Rarity.common:
        return AppTheme.textSecondary;
      case _Rarity.rare:
        return const Color(0xFF06B6D4);
      case _Rarity.epic:
        return AppTheme.accent;
      case _Rarity.legendary:
        return const Color(0xFFFFD700);
    }
  }
}

class _ShopItem {
  final String name;
  final String type;
  final IconData icon;
  final Color color;
  final String price;
  final _Rarity rarity;
  final String? tag;
  final String? originalPrice;
  const _ShopItem(
    this.name,
    this.type,
    this.icon,
    this.color,
    this.price, {
    this.rarity = _Rarity.common,
    this.tag,
    this.originalPrice,
  });
}

class _ShopItemCard extends StatefulWidget {
  final _ShopItem item;
  final Animation<double> glowAnim;
  const _ShopItemCard({required this.item, required this.glowAnim});
  @override
  State<_ShopItemCard> createState() => _ShopItemCardState();
}

class _ShopItemCardState extends State<_ShopItemCard> {
  bool _pressed = false;

  static const _tagColors = {
    'HOT': Color(0xFFFF4757),
    'NEW': Color(0xFF22C55E),
    'LIMITED': AppTheme.accent,
    'SALE': Color(0xFFF59E0B),
  };

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final tagColor = it.tag != null ? (_tagColors[it.tag] ?? it.color) : null;
    final hasDiscount = it.originalPrice != null;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Membuka detail ${it.name}...'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedBuilder(
          animation: widget.glowAnim,
          builder: (context, child) {
            final glow = 0.5 + widget.glowAnim.value * 0.5;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        width: 190,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.surfaceElevated,
                              it.rarity.color.withValues(alpha: 0.06),
                            ],
                          ),
                          border: Border.all(
                            color: _pressed
                                ? it.color.withValues(alpha: 0.6)
                                : it.rarity.color.withValues(
                                    alpha: 0.30 + glow * 0.15,
                                  ),
                            width: _pressed ? 2.0 : 1.3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: it.color.withValues(
                                alpha: _pressed ? 0.24 : 0.10 + glow * 0.06,
                              ),
                              blurRadius: _pressed ? 18 : 14,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Item preview: layered pattern + icon so it
                            // reads as an actual cosmetic item, not a flat
                            // placeholder icon on a plain gradient box.
                            AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    it.color.withValues(alpha: 0.28),
                                    it.color.withValues(alpha: 0.08),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: it.color.withValues(alpha: 0.28),
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Decorative facet pattern — gives the tile
                                  // texture/depth instead of a flat fill.
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _ItemFacetPainter(
                                        color: it.color,
                                        glow: glow,
                                      ),
                                    ),
                                  ),
                                  // Diagonal shine sweep, animates with glowAnim
                                  Positioned.fill(
                                    child: Align(
                                      alignment: Alignment(-1 + glow * 2.4, -1),
                                      child: Transform.rotate(
                                        angle: -0.5,
                                        child: Container(
                                          width: 30,
                                          height: 220,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                AppTheme.surfaceElevated.withValues(alpha: 0.0),
                                                AppTheme.surfaceElevated.withValues(
                                                  alpha: 0.22 * glow,
                                                ),
                                                AppTheme.surfaceElevated.withValues(alpha: 0.0),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Real, full-bleed preview of what the cosmetic
                                  // actually looks like when equipped — fills the
                                  // whole square like an actual scene/atmosphere,
                                  // not a small icon floating in empty space.
                                  Positioned.fill(
                                    child: _CosmeticPreviewContent(item: it, glow: glow),
                                  ),
                                  // Rarity sparkle accents for epic/legendary only
                                  if (it.rarity == _Rarity.legendary ||
                                      it.rarity == _Rarity.epic) ...[
                                    Positioned(
                                      top: 8,
                                      right: 12,
                                      child: Icon(
                                        Icons.auto_awesome_rounded,
                                        color: AppTheme.surfaceElevated.withValues(
                                          alpha: 0.5 + glow * 0.4,
                                        ),
                                        size: 11,
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 10,
                                      left: 10,
                                      child: Icon(
                                        Icons.auto_awesome_rounded,
                                        color: AppTheme.surfaceElevated.withValues(
                                          alpha: 0.3 + (1 - glow) * 0.3,
                                        ),
                                        size: 8,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              ),
                            ),
                            SizedBox(height: 8),
                            // ── Rarity + type row ──
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: it.rarity.color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    it.rarity.label,
                                    style: TextStyle(
                                      color: it.rarity.color,
                                      fontSize: 6.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    it.type.toUpperCase(),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: it.color.withValues(alpha: 0.7),
                                      fontSize: 6.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            // Name
                            Text(
                              it.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Spacer(),
                            // ── Price row (with strikethrough if discounted) ──
                            if (hasDiscount)
                              Text(
                                it.originalPrice!,
                                style: TextStyle(
                                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.diamond_rounded,
                                      color: it.color,
                                      size: 9,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      it.price,
                                      style: TextStyle(
                                        color: it.color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        it.color.withValues(alpha: 0.85),
                                        it.color,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(7),
                                    boxShadow: [
                                      BoxShadow(
                                        color: it.color.withValues(alpha: 0.30),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'Beli',
                                    style: TextStyle(
                                      color: AppTheme.surfaceElevated,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // ── Legendary-only shimmer sweeping the FULL card ──
                      // Reuses widget.glowAnim (no new AnimationController)
                      // per the plan: legendary items get a diagonal shine
                      // that sweeps the whole card, not just the preview
                      // tile, so they visibly read as rarer than epic/rare.
                      if (it.rarity == _Rarity.legendary)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Align(
                              alignment: Alignment(-1.6 + glow * 3.2, -1),
                              child: Transform.rotate(
                                angle: -0.5,
                                child: Container(
                                  width: 34,
                                  height: 260,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        AppTheme.surfaceElevated.withValues(alpha: 0.0),
                                        Color(
                                          0xFFFFD700,
                                        ).withValues(alpha: 0.28 * glow),
                                        AppTheme.surfaceElevated.withValues(
                                          alpha: 0.38 * glow,
                                        ),
                                        Color(
                                          0xFFFFD700,
                                        ).withValues(alpha: 0.28 * glow),
                                        AppTheme.surfaceElevated.withValues(alpha: 0.0),
                                      ],
                                      stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // ── Corner ribbon tag (HOT / NEW / LIMITED / SALE) ──
                // Stays OUTSIDE the ClipRRect (sibling in the outer,
                // unclipped Stack) so its negative top offset can still
                // poke above the card instead of being clipped off.
                if (it.tag != null)
                  Positioned(
                    top: -6,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: tagColor,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: tagColor!.withValues(alpha: 0.45),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        it.tag!,
                        style: const TextStyle(
                          color: AppTheme.surfaceElevated,
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── TICKET CLIPPER ───────────────────────────────────────────────────────────
// Cuts a movie-ticket-stub silhouette: rounded rect with a small semicircular
// notch bitten out of the left AND right edge at the same height, so a
// dashed divider can sit exactly where the "tear" would be. Used to give the
// Flash Sale banner a shape that's genuinely different from the plain
// rounded cards used everywhere else (Premium Pass, Daily Login, etc).
class TicketClipper extends CustomClipper<Path> {
  final double notchY;
  final double notchRadius;
  final double cornerRadius;

  const TicketClipper({
    required this.notchY,
    this.notchRadius = 11,
    this.cornerRadius = 20,
  });

  // Exposed separately from getClip so the background painter can build the
  // exact same outline for its fill/border/glow.
  Path buildPath(Size size) {
    final w = size.width;
    final h = size.height;
    final r = cornerRadius;
    return Path()
      ..moveTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, notchY - notchRadius)
      ..arcToPoint(
        Offset(w, notchY + notchRadius),
        radius: Radius.circular(notchRadius),
        clockwise: false,
      )
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h)
      ..lineTo(r, h)
      ..quadraticBezierTo(0, h, 0, h - r)
      ..lineTo(0, notchY + notchRadius)
      ..arcToPoint(
        Offset(0, notchY - notchRadius),
        radius: Radius.circular(notchRadius),
        clockwise: false,
      )
      ..close();
  }

  @override
  Path getClip(Size size) => buildPath(size);

  @override
  bool shouldReclip(covariant TicketClipper oldClipper) {
    return oldClipper.notchY != notchY ||
        oldClipper.notchRadius != notchRadius ||
        oldClipper.cornerRadius != cornerRadius;
  }
}

// ─── DASHED DIVIDER ───────────────────────────────────────────────────────────
// A horizontal row of short dashes, sized to fill whatever width it's given.
// Sits at the ticket's notch line to sell the "tear here" illusion.
class DashedDivider extends StatelessWidget {
  final double height;
  final Color color;
  final double dashWidth;
  final double dashGap;

  const DashedDivider({
    super.key,
    this.height = 1.2,
    this.color = const Color(0x33FFFFFF),
    this.dashWidth = 5,
    this.dashGap = 4,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        final dashCount = totalWidth <= 0
            ? 0
            : (totalWidth / (dashWidth + dashGap)).floor().clamp(1, 999);
        return SizedBox(
          height: height,
          width: totalWidth,
          child: Row(
            children: List.generate(dashCount, (_) {
              return Padding(
                padding: EdgeInsets.only(right: dashGap),
                child: Container(width: dashWidth, height: height, color: color),
              );
            }),
          ),
        );
      },
    );
  }
}

// ─── TICKET SHAPE PAINTER ─────────────────────────────────────────────────────
// Paints the fill gradient + stroke border + a soft glow along the exact
// ticket silhouette (including the notches), since a plain BoxDecoration
// border can't follow a custom Path — only CustomPaint can.
class _TicketShapePainter extends CustomPainter {
  final double notchY;
  final double notchRadius;
  final double cornerRadius;
  final Gradient fillGradient;
  final Color borderColor;
  final double borderWidth;
  final double glowAlpha;
  final double glowBlur;

  _TicketShapePainter({
    required this.notchY,
    required this.fillGradient,
    required this.borderColor,
    this.notchRadius = 11,
    this.cornerRadius = 20,
    this.borderWidth = 1.5,
    this.glowAlpha = 0.08,
    this.glowBlur = 20,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = TicketClipper(
      notchY: notchY,
      notchRadius: notchRadius,
      cornerRadius: cornerRadius,
    ).buildPath(size);

    // Soft glow echoing the card's old BoxShadow, following the real shape
    final glowPaint = Paint()
      ..color = Color(0xFFFFD700).withValues(alpha: glowAlpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowBlur / 2);
    canvas.drawPath(path.shift(const Offset(0, 6)), glowPaint);

    // Fill
    canvas.drawPath(
      path,
      Paint()..shader = fillGradient.createShader(Offset.zero & size),
    );

    // Border (drawn last so it sits crisp on top of the fill, notches included)
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _TicketShapePainter old) {
    return old.notchY != notchY ||
        old.borderColor != borderColor ||
        old.glowAlpha != glowAlpha ||
        old.glowBlur != glowBlur ||
        old.fillGradient != fillGradient;
  }
}

// ─── FLASH SALE BANNER ───────────────────────────────────────────────────────
class _FlashSaleBanner extends StatefulWidget {
  const _FlashSaleBanner();
  @override
  State<_FlashSaleBanner> createState() => _FlashSaleBannerState();
}

class _FlashSaleBannerState extends State<_FlashSaleBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  Timer? _timer;
  int _secondsLeft = 2 * 3600 + 45 * 60 + 30; // 2h 45m 30s

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          // Sale "restocks" with a fresh countdown instead of freezing at
          // 00:00:00 forever — keeps the urgency banner honest if someone
          // leaves the app open past the deadline.
          _secondsLeft = 2 * 3600 + 45 * 60 + 30;
        }
      });
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // Vertical position (from the card's top) where the ticket notches + the
  // dashed "tear" divider sit — right under the FLASH SALE header row.
  static const double _notchY = 45;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (_, __) {
          final pulse = _pulseCtrl.value;
          final fillGradient = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(
                const Color(0xFF3A1B2E),
                AppTheme.accent.withValues(alpha: 0.45),
                pulse,
              )!,
              Color.lerp(
                const Color(0xFF1F1030),
                AppTheme.highlight.withValues(alpha: 0.30),
                pulse,
              )!,
            ],
            stops: const [0.0, 1.0],
          );
          final borderColor = AppTheme.highlight.withValues(
            alpha: 0.35 + pulse * 0.20,
          );

          return Stack(
            children: [
              // ── Ticket-stub fill + border + notches (replaces the old
              // plain rounded Container so this card actually reads as a
              // different shape from Premium Pass / Daily Login next to it) ──
              Positioned.fill(
                child: CustomPaint(
                  painter: _TicketShapePainter(
                    notchY: _notchY,
                    fillGradient: fillGradient,
                    borderColor: borderColor,
                    glowAlpha: 0.06 + pulse * 0.05,
                    glowBlur: 18 + pulse * 8,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header: FLASH SALE + live dot + timer ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.accent, AppTheme.highlight],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              color: AppTheme.background,
                              size: 10,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'FLASH SALE',
                              style: TextStyle(
                                color: AppTheme.background,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Live pulsing dot
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Color(
                            0xFFEF4444,
                          ).withValues(alpha: 0.6 + 0.4 * pulse),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(
                                0xFFEF4444,
                              ).withValues(alpha: 0.4 * pulse),
                              blurRadius: 6,
                              spreadRadius: pulse * 2,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 6),
                      // Countdown timer
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.surfaceElevated.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.timer_rounded,
                              color: AppTheme.highlight,
                              size: 9,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatTime(_secondsLeft),
                              style: const TextStyle(
                                color: AppTheme.highlight,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  ),
                  // ── Dashed "tear" divider, sitting exactly at the notch ──
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: DashedDivider(
                      color: AppTheme.highlight.withValues(
                        alpha: 0.16 + pulse * 0.10,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  // ── Sale item showcase ──
                  Row(
                    children: [
                      // Item preview
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: const RadialGradient(
                            colors: [
                              Color(0xFFFFE566),
                              Color(0xFFFF8800),
                              Color(0xFFCC4400),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Color(
                              0xFFFFD700,
                            ).withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(
                                0xFFFFD700,
                              ).withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.auto_awesome,
                            color: AppTheme.textPrimary,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Item details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sakura Emperor Border',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accent.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'LIMITED',
                                    style: TextStyle(
                                      color: AppTheme.accent,
                                      fontSize: 6.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.highlight.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '-40%',
                                    style: TextStyle(
                                      color: AppTheme.highlight,
                                      fontSize: 6.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  '150 Gems',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary.withValues(alpha: 0.6),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  '90 Gems',
                                  style: TextStyle(
                                    color: AppTheme.highlight,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // ── CTA Button ──
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color.lerp(
                              AppTheme.accent,
                              AppTheme.highlight,
                              pulse,
                            )!,
                            Color.lerp(
                              AppTheme.highlight,
                              AppTheme.accent,
                              pulse,
                            )!,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.highlight.withValues(
                              alpha: 0.30 + pulse * 0.15,
                            ),
                            blurRadius: 12 + pulse * 6,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {},
                          borderRadius: BorderRadius.circular(12),
                          child: const Center(
                            child: Text(
                              'Beli Sekarang',
                              style: TextStyle(
                                color: AppTheme.background,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── SAKURA PETAL DATA ───────────────────────────────────────────────────────
class _SakuraPetal {
  double x, y;
  double size;
  double speedX, speedY;
  double rotation, rotationSpeed;
  double opacity;
  double swayPhase;

  _SakuraPetal({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.rotation,
    required this.rotationSpeed,
    required this.opacity,
    required this.swayPhase,
  });
}

// ─── SAKURA PETAL PAINTER ────────────────────────────────────────────────────
class _SakuraPetalPainter extends CustomPainter {
  final List<_SakuraPetal> petals;

  _SakuraPetalPainter(this.petals);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in petals) {
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);

      final paint = Paint()
        ..color = AppTheme.accent.withValues(alpha: 0.4).withValues(alpha: p.opacity * 0.6)
        ..style = PaintingStyle.fill;

      // Draw sakura petal shape (5-petal simplified as overlapping ellipses)
      final petalPath = Path();
      const petalCount = 5;
      for (int i = 0; i < petalCount; i++) {
        final angle = (i * 2 * math.pi / petalCount) - math.pi / 2;
        petalPath.addOval(
          Rect.fromCenter(
            center: Offset(
              math.cos(angle) * p.size * 0.35,
              math.sin(angle) * p.size * 0.35,
            ),
            width: p.size * 0.5,
            height: p.size * 0.7,
          ),
        );
      }
      // Center dot
      petalPath.addOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size * 0.2,
          height: p.size * 0.2,
        ),
      );

      canvas.drawPath(petalPath, paint);

      // Subtle inner glow
      final glowPaint = Paint()
        ..color = AppTheme.accent.withValues(alpha: p.opacity * 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawPath(petalPath, glowPaint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SakuraPetalPainter old) => true;
}

// ─── SAKURA BACKGROUND ───────────────────────────────────────────────────────
class _SakuraBackground extends StatefulWidget {
  const _SakuraBackground();
  @override
  State<_SakuraBackground> createState() => _SakuraBackgroundState();
}

class _SakuraBackgroundState extends State<_SakuraBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_SakuraPetal> _petals;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _initPetals();
  }

  void _initPetals() {
    final rand = math.Random(42);
    _petals = List.generate(20, (_) {
      return _SakuraPetal(
        x: rand.nextDouble() * 500,
        y: rand.nextDouble() * 900,
        size: 6 + rand.nextDouble() * 10,
        speedX: -0.15 + rand.nextDouble() * 0.3,
        speedY: 0.2 + rand.nextDouble() * 0.4,
        rotation: rand.nextDouble() * math.pi * 2,
        rotationSpeed: -0.02 + rand.nextDouble() * 0.04,
        opacity: 0.15 + rand.nextDouble() * 0.35,
        swayPhase: rand.nextDouble() * math.pi * 2,
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final screenW = MediaQuery.of(context).size.width;
        final screenH = MediaQuery.of(context).size.height;
        final t = _ctrl.value;

        for (int i = 0; i < _petals.length; i++) {
          final p = _petals[i];
          // Gentle swaying
          final sway = math.sin(t * math.pi * 2 + p.swayPhase) * 0.15;
          p.x += p.speedX + sway;
          p.y += p.speedY;
          p.rotation += p.rotationSpeed;
          // Loop when off screen
          if (p.y > screenH + 20) {
            p.y = -20;
            p.x = math.Random(i + 1).nextDouble() * screenW;
          }
          if (p.x < -30) p.x = screenW + 10;
          if (p.x > screenW + 30) p.x = -10;
        }

        return Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _SakuraPetalPainter(_petals),
              size: Size(screenW, screenH),
            ),
          ),
        );
      },
    );
  }
}

// ─── DAILY LOGIN STREAK CARD ─────────────────────────────────────────────────
class _DailyLoginStreakCard extends StatefulWidget {
  const _DailyLoginStreakCard();
  @override
  State<_DailyLoginStreakCard> createState() => _DailyLoginStreakCardState();
}

class _DailyLoginStreakCardState extends State<_DailyLoginStreakCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  final int _currentStreak = 7;
  final int _maxStreak = 30;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 7-day streak preview
    // NOTE: streak is 1-indexed within the week (Day 1..Day 7), so mapping
    // must land in [1, 7]. A plain `% 7` sends any multiple of 7 (7, 14, 21…)
    // to 0, which matches nothing in `days` and silently kills the
    // "today"/"checked" highlight — that's why the row looked all-grey at
    // streak 7 before this fix.
    final days = List.generate(7, (i) => i + 1);
    final currentDay = ((_currentStreak - 1) % 7) + 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.accent.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            // True liquid glass: was a solid surface→surfaceElevated fill
            // that fully covered the parent card's background artwork.
            // A blurred, low-alpha tint lets that artwork show through
            // instead, consistent with _LiquidGlassPill elsewhere.
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.07),
                    AppTheme.accent.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.accent, AppTheme.highlight],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      color: AppTheme.background,
                      size: 13,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'DAILY LOGIN',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _ctrl,
                          builder: (_, __) => Icon(
                            Icons.local_fire_department_rounded,
                            color: AppTheme.accent.withValues(
                              alpha: 0.6 + 0.4 * _ctrl.value,
                            ),
                            size: 11,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$_currentStreak Hari',
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 6),
                  // Compact reward chip — replaces the old full-width
                  // "Hadiah Day 30" strip that used to sit below the day
                  // row; same info, sejajar dengan badge streak di header.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.highlight.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.highlight.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.card_giftcard_rounded,
                          color: AppTheme.highlight,
                          size: 10,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${_maxStreak - _currentStreak}h',
                          style: const TextStyle(
                            color: AppTheme.highlight,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Responsive day row — sizes itself from the available width
              // instead of a hardcoded 7 × 38px (266px), which overflowed
              // on narrower screens ("OVERFLOWED BY 44 PIXELS").
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 6.0;
                  final itemWidth =
                      ((constraints.maxWidth - gap * 6) / 7).clamp(30.0, 42.0);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (i) {
                      final day = days[i];
                      final checked = day < currentDay;
                      final today = day == currentDay;

                      return GestureDetector(
                    onTap: () {},
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: itemWidth,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        gradient: today
                            ? const LinearGradient(
                                colors: [AppTheme.accent, AppTheme.highlight],
                              )
                            : (checked
                                  ? LinearGradient(
                                      colors: [
                                        AppTheme.primary,
                                        AppTheme.primary.withValues(alpha: 0.75),
                                      ],
                                    )
                                  : null),
                        color: today || checked
                            ? null
                            : AppTheme.surface.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: today
                            ? Border.all(
                                color: AppTheme.textPrimary.withValues(alpha: 0.55),
                                width: 1.5,
                              )
                            : null,
                        boxShadow: today
                            ? [
                                BoxShadow(
                                  color: AppTheme.accent.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Day $day',
                            style: TextStyle(
                              color: today || checked
                                  ? AppTheme.background
                                  : AppTheme.textSecondary,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Icon(
                            checked
                                ? Icons.check_circle_rounded
                                : (today
                                      ? Icons.circle_rounded
                                      : Icons.radio_button_unchecked_rounded),
                            size: 13,
                            color: today || checked
                                ? AppTheme.background
                                : AppTheme.textSecondary.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 3),
                          if (i == 0 || i == 2 || i == 6)
                            Icon(
                              i == 0
                                  ? Icons.card_giftcard_rounded
                                  : (i == 2
                                        ? Icons.diamond_rounded
                                        : Icons.workspace_premium_rounded),
                              size: 7.5,
                              color: today || checked
                                  ? AppTheme.background.withValues(alpha: 0.7)
                                  : AppTheme.textSecondary.withValues(alpha: 0.3),
                            )
                          else
                            const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  );
                    }),
                  );
                },
              ),
            ],
          ),
        ),
            ),
          ),
        ),
      ),
    );
  }
}
