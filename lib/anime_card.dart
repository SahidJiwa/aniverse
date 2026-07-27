// anime_card.dart
// ─────────────────────────────────────────────────────────────────────────────
// Reusable anime card widget.
// Dipakai di HomeScreen (horizontal list), MyListScreen (grid).
// Watchlist V1: tambah bookmark icon overlay di sudut kanan atas.
//   → Reaktif via ValueListenableBuilder(MockDataService.libraryNotifier)
//   → Tidak ada local state — toggle langsung ke MockDataService
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'anime_detail_screen.dart';
import 'anime_model.dart';
import 'mock_data_service.dart';
import 'app_theme.dart';
import 'proxied_network_image.dart';

class AnimeCard extends StatelessWidget {
  final AnimeModel anime;
  // Optional explicit width for callers that need a fixed card size (e.g.
  // a horizontal ListView row, where each card must claim its own width
  // rather than stretching to fill). Left null when the parent already
  // constrains width itself — a GridView tile, for instance — so this
  // card just fills whatever space it's given instead of fighting the
  // grid's own sizing with a hardcoded value.
  //
  // This param was added after a layout crash: the card used to hardcode
  // width: 130 unconditionally. That's correct for a horizontal list (each
  // item does need to claim its own width there), but broke when the same
  // card was reused inside explore_screen.dart's GridView — the grid
  // delegate hands each tile a specific bounded width per column count,
  // and forcing 130 regardless produced "Stack requires bounded
  // constraints" / "child.hasSize is not true" crashes whenever the grid's
  // actual tile width didn't match 130.
  final double? width;

  const AnimeCard({super.key, required this.anime, this.width});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AnimeDetailScreen(anime: anime),
          ),
        );
      },
      child: Container(
        width: width,
        margin: width != null ? const EdgeInsets.only(right: 12) : EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cover + bookmark overlay ─────────────────────────────────
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover image
                  Hero(
                    tag: 'anime-hero-${anime.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ProxiedNetworkImage.forUrl(
                        url: anime.imageUrl,
                        title: anime.title,
                        // PERF: card renders at 130px wide × ~175px tall.
                        // 2× for high-DPI = 260×350. Avoids decoding 600×800 source.
                        width: 260,
                        height: 350,
                        fit: BoxFit.cover,
                        fallback: Container(
                          color: AppTheme.surfaceDark,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: Colors.white24, size: 32),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Trending badge kiri atas
                  if (anime.isTrending)
                    Positioned(
                      top: 7,
                      left: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.sakuraPink,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'HOT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                  // ── Bookmark icon kanan atas ─────────────────────────────
                  // Reaktif: rebuild hanya bagian ini saat libraryNotifier berubah
                  Positioned(
                    top: 6,
                    right: 6,
                    child: ValueListenableBuilder<List<AnimeModel>>(
                      valueListenable: MockDataService.libraryNotifier,
                      builder: (context, list, _) {
                        final inList = list.any((a) => a.id == anime.id);
                        return GestureDetector(
                          onTap: () {
                            MockDataService.toggleWatchlist(anime);
                            debugPrint(
                              '[MyList] card toggle animeId="${anime.id}" '
                              '"${anime.title}" inList=${!inList}',
                            );
                          },
                          // HitTestBehavior.opaque agar tap tidak tembus ke card
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: inList
                                  ? AppTheme.sakuraPink
                                  : Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: inList
                                    ? AppTheme.sakuraPink
                                    : Colors.white.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              inList
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Rating badge bawah kiri
                  Positioned(
                    bottom: 7,
                    left: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Colors.amber, size: 11),
                          const SizedBox(width: 3),
                          Text(
                            anime.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Title & Genre ────────────────────────────────────────────
            const SizedBox(height: 7),
            Text(
              anime.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              anime.genre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    ), // GestureDetector
    ); // RepaintBoundary
  }
}
