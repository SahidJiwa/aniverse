import 'package:flutter/foundation.dart';
import 'anime_model.dart';

class MockDataService {
  static final ValueNotifier<List<AnimeModel>> libraryNotifier =
      ValueNotifier<List<AnimeModel>>([]);

  static List<AnimeModel> getMockAnimes() {
    return [
      AnimeModel(
        id: '1',
        title: 'Cyberpunk Edgerunners',
        imageUrl: 'https://placehold.co/600x800/png?text=Cyberpunk',
        rating: 9.5,
        genre: 'Sci-Fi',
        description: 'A street kid trying to survive in a technology and body modification-obsessed city of the future.',
        isTrending: true,
      ),
      AnimeModel(
        id: '2',
        title: 'Demon Slayer',
        imageUrl: 'https://placehold.co/600x800/png?text=Demon+Slayer',
        rating: 9.2,
        genre: 'Action',
        description: 'A family is attacked by demons and only two members survive.',
        isTrending: true,
      ),
      AnimeModel(
        id: '3',
        title: 'Attack on Titan',
        imageUrl: 'https://placehold.co/600x800/png?text=AOT',
        rating: 9.8,
        genre: 'Drama',
        description: 'Humans are nearly exterminated by giant creatures called Titans.',
        isTrending: false,
      ),
      AnimeModel(
        id: '4',
        title: 'Jujutsu Kaisen',
        imageUrl: 'https://placehold.co/600x800/png?text=JJK',
        rating: 9.0,
        genre: 'Fantasy',
        description: 'A boy swallows a cursed object and becomes a vessel for a powerful curse.',
        isTrending: true,
      ),
      AnimeModel(
        id: '5',
        title: 'Spy x Family',
        imageUrl: 'https://placehold.co/600x800/png?text=SpyXFamily',
        rating: 8.9,
        genre: 'Comedy',
        description: 'A spy builds a fake family to execute a mission.',
        isTrending: false,
      ),
    ];
  }

  static List<String> getGenres() => ['Action', 'Adventure', 'Comedy', 'Drama', 'Sci-Fi', 'Fantasy', 'Horror'];
}