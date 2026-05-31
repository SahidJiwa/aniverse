import 'package:flutter/foundation.dart';
import 'anime_model.dart';
import 'episode_model.dart';

List<EpisodeModel> _buildEpisodes(int count, String animeTag) {
  return List.generate(
    count,
    (i) => EpisodeModel(
      number: i + 1,
      title: 'Episode ${i + 1}',
      duration: '${22 + (i % 3)}m',
      thumbnailUrl:
          'https://placehold.co/320x180/png?text=$animeTag+Ep${i + 1}',
    ),
  );
}

class MockDataService {
  // ── Watchlist ─────────────────────────────────────────────────────────────
  static final ValueNotifier<List<AnimeModel>> libraryNotifier =
      ValueNotifier<List<AnimeModel>>([]);

  static bool isInWatchlist(String id) =>
      libraryNotifier.value.any((a) => a.id == id);

  static void toggleWatchlist(AnimeModel anime) {
    final list = List<AnimeModel>.from(libraryNotifier.value);
    final idx = list.indexWhere((a) => a.id == anime.id);
    if (idx >= 0) {
      list.removeAt(idx);
    } else {
      list.add(anime);
    }
    libraryNotifier.value = list;
  }

  // ── Favorites ─────────────────────────────────────────────────────────────
  static final ValueNotifier<List<AnimeModel>> favoritesNotifier =
      ValueNotifier<List<AnimeModel>>([]);

  static bool isFavorite(String id) =>
      favoritesNotifier.value.any((a) => a.id == id);

  static void toggleFavorite(AnimeModel anime) {
    final list = List<AnimeModel>.from(favoritesNotifier.value);
    final idx = list.indexWhere((a) => a.id == anime.id);
    if (idx >= 0) {
      list.removeAt(idx);
    } else {
      list.add(anime);
    }
    favoritesNotifier.value = list;
  }

  // ── Data ──────────────────────────────────────────────────────────────────
  static List<AnimeModel> getMockAnimes() {
    return [
      AnimeModel(
        id: '1',
        title: 'Cyberpunk Edgerunners',
        imageUrl: 'https://placehold.co/600x800/png?text=Cyberpunk',
        rating: 9.5,
        genre: 'Sci-Fi',
        description:
            'A street kid trying to survive in a technology and body modification-obsessed city of the future.',
        isTrending: true,
        episodes: _buildEpisodes(10, 'Cyberpunk'),
      ),
      AnimeModel(
        id: '2',
        title: 'Demon Slayer',
        imageUrl: 'https://placehold.co/600x800/png?text=Demon+Slayer',
        rating: 9.2,
        genre: 'Action',
        description:
            'A family is attacked by demons and only two members survive.',
        isTrending: true,
        episodes: _buildEpisodes(26, 'DemonSlayer'),
      ),
      AnimeModel(
        id: '3',
        title: 'Attack on Titan',
        imageUrl: 'https://placehold.co/600x800/png?text=AOT',
        rating: 9.8,
        genre: 'Drama',
        description:
            'Humans are nearly exterminated by giant creatures called Titans.',
        isTrending: false,
        episodes: _buildEpisodes(25, 'AOT'),
      ),
      AnimeModel(
        id: '4',
        title: 'Jujutsu Kaisen',
        imageUrl: 'https://placehold.co/600x800/png?text=JJK',
        rating: 9.0,
        genre: 'Fantasy',
        description:
            'A boy swallows a cursed object and becomes a vessel for a powerful curse.',
        isTrending: true,
        episodes: _buildEpisodes(24, 'JJK'),
      ),
      AnimeModel(
        id: '5',
        title: 'Spy x Family',
        imageUrl: 'https://placehold.co/600x800/png?text=SpyXFamily',
        rating: 8.9,
        genre: 'Comedy',
        description: 'A spy builds a fake family to execute a mission.',
        isTrending: false,
        episodes: _buildEpisodes(12, 'SpyFamily'),
      ),
    ];
  }

  static List<String> getGenres() =>
      ['Action', 'Adventure', 'Comedy', 'Drama', 'Sci-Fi', 'Fantasy', 'Horror'];
}
