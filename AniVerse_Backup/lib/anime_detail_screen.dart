import 'package:flutter/material.dart';
import 'anime_model.dart';
import 'app_theme.dart';

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
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                      _buildChip("24 Episodes"), // Mock data for episode count
                      _buildChip("HD"),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    "Synopsis",
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
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.sakuraPink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.library_add_rounded),
                      label: const Text(
                        "Add to Library",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
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
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
          const SizedBox(width: 4),
          Text(
            rating.toString(),
            style: const TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, {bool isAccent = false}) {
    return Chip(
      label: Text(label),
      backgroundColor: isAccent ? AppTheme.sakuraPink.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
      side: BorderSide(
        color: isAccent ? AppTheme.sakuraPink.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1),
      ),
      labelStyle: TextStyle(
        color: isAccent ? AppTheme.sakuraPink : Colors.white.withValues(alpha: 0.7),
        fontSize: 12,
        fontWeight: isAccent ? FontWeight.bold : FontWeight.normal,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}