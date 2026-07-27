// search_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Dedicated Search Screen for AniVerse.
// • Debounce 500ms on user input
// • Calls AnimeApiService.searchAnime() — rate limit + retry already handled
// • Shows loading, empty, error, and result states
// • Tapping result opens AnimeDetailScreen (same as AnimeCard behaviour)
// • Reuses AnimeModel, AppTheme, MockDataService.toggleWatchlist
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';

import 'anime_api_service.dart';
import 'anime_model.dart';
import 'anime_detail_screen.dart';
import 'mock_data_service.dart';
import 'app_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  List<AnimeModel> _results = const [];
  bool _isLoading = false;
  bool _hasSearched = false;   // true setelah user pertama kali ketik
  String _errorMessage = '';
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    // Auto-fokus keyboard saat screen terbuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Debounced search ───────────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    _debounce?.cancel();

    final trimmed = query.trim();

    // Kalau query kosong, reset ke initial state
    if (trimmed.isEmpty) {
      setState(() {
        _results = const [];
        _hasSearched = false;
        _isLoading = false;
        _errorMessage = '';
        _lastQuery = '';
      });
      return;
    }

    // Jangan re-fetch jika query sama persis
    if (trimmed == _lastQuery) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = '';
    });

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(trimmed);
    });
  }

  Future<void> _performSearch(String query) async {
    _lastQuery = query;
    try {
      final results = await AnimeApiService.searchAnime(query);
      // Guard: widget mungkin sudah di-dispose saat request selesai
      if (!mounted) return;
      // Guard: user mungkin sudah ketik query baru
      if (_controller.text.trim() != query) return;

      setState(() {
        _results = results;
        _isLoading = false;
        _errorMessage = '';
      });
    } catch (e) {
      if (!mounted) return;
      if (_controller.text.trim() != query) return;

      setState(() {
        _results = const [];
        _isLoading = false;
        _errorMessage = 'Gagal memuat hasil. Cek koneksi internet kamu.';
      });
      debugPrint('[SearchScreen] error: $e');
    }
  }

  // ── Clear search ───────────────────────────────────────────────────────────

  void _clearSearch() {
    _controller.clear();
    _debounce?.cancel();
    setState(() {
      _results = const [];
      _hasSearched = false;
      _isLoading = false;
      _errorMessage = '';
      _lastQuery = '';
    });
    _focusNode.requestFocus();
  }

  // ── Navigate to detail ─────────────────────────────────────────────────────

  void _openDetail(AnimeModel anime) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AnimeDetailScreen(anime: anime)),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _SearchBar(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onSearchChanged,
          onClear: _clearSearch,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // ── Loading ──────────────────────────────────────────────────────────────
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.sakuraPink),
      );
    }

    // ── Error ────────────────────────────────────────────────────────────────
    if (_errorMessage.isNotEmpty) {
      return _EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Oops!',
        subtitle: _errorMessage,
      );
    }

    // ── Initial state (belum ketik apa-apa) ──────────────────────────────────
    if (!_hasSearched) {
      return _EmptyState(
        icon: Icons.search_rounded,
        title: 'Cari Anime',
        subtitle: 'Ketik judul anime yang ingin kamu temukan.',
      );
    }

    // ── No results ───────────────────────────────────────────────────────────
    if (_results.isEmpty) {
      return _EmptyState(
        icon: Icons.sentiment_dissatisfied_rounded,
        title: 'Tidak ditemukan',
        subtitle: 'Coba kata kunci lain atau periksa ejaan.',
      );
    }

    // ── Results ──────────────────────────────────────────────────────────────
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      itemBuilder: (context, index) => _SearchResultTile(
        anime: _results[index],
        onTap: () => _openDetail(_results[index]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SearchBar — TextField styled sesuai AniVerse theme
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        cursorColor: AppTheme.sakuraPink,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Cari anime...',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 15,
          ),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppTheme.sakuraPink, size: 20),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, _) {
              return value.text.isNotEmpty
                  ? GestureDetector(
                      onTap: onClear,
                      child: Icon(Icons.cancel_rounded,
                          color: Colors.white.withValues(alpha: 0.4), size: 18),
                    )
                  : const SizedBox.shrink();
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SearchResultTile — list-style item, lebih cocok dari AnimeCard (card = 130px wide)
// ─────────────────────────────────────────────────────────────────────────────

class _SearchResultTile extends StatelessWidget {
  final AnimeModel anime;
  final VoidCallback onTap;

  const _SearchResultTile({required this.anime, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: AppTheme.sakuraPink.withValues(alpha: 0.08),
      highlightColor: AppTheme.sakuraPink.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // ── Cover image ──────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                anime.imageUrl,
                width: 60,
                height: 85,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 60,
                  height: 85,
                  color: AppTheme.surfaceDark,
                  child: const Icon(Icons.broken_image_outlined,
                      color: Colors.white24, size: 24),
                ),
              ),
            ),

            const SizedBox(width: 14),

            // ── Info ─────────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    anime.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  // Genre
                  Text(
                    anime.genre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Rating
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Colors.amber, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        anime.rating > 0
                            ? anime.rating.toStringAsFixed(1)
                            : 'N/A',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Bookmark button ──────────────────────────────────────────
            ValueListenableBuilder<List<AnimeModel>>(
              valueListenable: MockDataService.libraryNotifier,
              builder: (context, list, _) {
                final inList = list.any((a) => a.id == anime.id);
                return GestureDetector(
                  onTap: () => MockDataService.toggleWatchlist(anime),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: inList
                            ? AppTheme.sakuraPink
                            : Colors.white.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: inList
                              ? AppTheme.sakuraPink
                              : Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Icon(
                        inList
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EmptyState — reusable untuk initial / no-result / error state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
