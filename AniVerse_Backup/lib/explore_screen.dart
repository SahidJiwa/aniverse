import 'dart:async';

import 'package:flutter/material.dart';
import 'anime_api_service.dart';
import 'anime_card.dart';
import 'anime_model.dart';
import 'app_theme.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _selectedGenre;

  bool _isLoading = true;
  bool _isSearching = false;
  String? _errorMessage;
  List<AnimeModel> _animes = const [];
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadTopAnime();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTopAnime() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await AnimeApiService.fetchTopAnime();
      if (!mounted) return;
      setState(() {
        _animes = result;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load anime. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _query = value;
    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;

      final q = _query.trim();
      if (q.isEmpty) {
        await _loadTopAnime();
        return;
      }

      setState(() {
        _isSearching = true;
        _errorMessage = null;
      });

      try {
        final result = await AnimeApiService.searchAnime(q);
        if (!mounted) return;
        if (_query.trim() != q) return;
        setState(() {
          _animes = result;
          _isSearching = false;
        });
      } catch (_) {
        if (!mounted) return;
        if (_query.trim() != q) return;
        setState(() {
          _errorMessage = 'Search failed. Please try again.';
          _animes = const [];
          _isSearching = false;
        });
      }
    });

    setState(() {});
  }

  List<AnimeModel> _filterAnimes(List<AnimeModel> animes) {
    final trimmedQuery = _query.trim().toLowerCase();

    return animes.where((anime) {
      final matchesQuery = trimmedQuery.isEmpty
          ? true
          : anime.title.toLowerCase().contains(trimmedQuery) ||
              anime.genre.toLowerCase().contains(trimmedQuery);
      final matchesGenre =
          _selectedGenre == null ? true : anime.genre == _selectedGenre;
      return matchesQuery && matchesGenre;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final genres = _animes.map((a) => a.genre).toSet().toList()..sort();
    final filteredAnimes = _filterAnimes(_animes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SearchBar(
              hintText: 'Search anime...',
              controller: _searchController,
              onChanged: _onSearchChanged,
              leading: const Icon(Icons.search, color: Colors.white70),
              trailing: _query.trim().isNotEmpty
                  ? [
                      IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      ),
                    ]
                  : null,
              hintStyle: WidgetStateProperty.all(
                const TextStyle(color: Colors.white54),
              ),
              textStyle: WidgetStateProperty.all(
                const TextStyle(color: Colors.white),
              ),
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 16),
              ),
              backgroundColor: WidgetStateProperty.all(AppTheme.surfaceDark),
              side: WidgetStateProperty.all(
                BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              elevation: WidgetStateProperty.all(0),
            ),
          ),
        ),
      ),
      body: _buildBody(genres, filteredAnimes),
    );
  }

  Widget _buildBody(List<String> genres, List<AnimeModel> filteredAnimes) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 42),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _query.trim().isEmpty
                    ? _loadTopAnime
                    : () => _onSearchChanged(_query),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 50,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: genres.length,
            itemBuilder: (context, index) {
              final genre = genres[index];
              final isSelected = _selectedGenre == genre;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(genre),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedGenre = isSelected ? null : genre;
                    });
                  },
                  selectedColor: AppTheme.sakuraPink.withValues(alpha: 0.3),
                  checkmarkColor: AppTheme.sakuraPink,
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.sakuraPink : Colors.white70,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppTheme.sakuraPink.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.14),
                  ),
                  backgroundColor: AppTheme.surfaceDark,
                  showCheckmark: false,
                ),
              );
            },
          ),
        ),
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            if (filteredAnimes.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: const Icon(
                          Icons.search_off_rounded,
                          color: Colors.white54,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No anime found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try a different title or genre keyword.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            int crossAxisCount = constraints.maxWidth ~/ 150;
            if (crossAxisCount < 2) crossAxisCount = 2;

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.65,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: filteredAnimes.length,
              itemBuilder: (context, index) => AnimeCard(
                anime: filteredAnimes[index],
                width: double.infinity,
              ),
            );
          }),
        ),
      ],
    );
  }
}
