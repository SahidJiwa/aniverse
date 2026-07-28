// custom_anime_catalog.dart — AniVerse Custom Anime Catalog
// ─────────────────────────────────────────────────────────────────────────────
// SINGLE SOURCE OF TRUTH for manually-added anime.
// Curated list filtered strictly to Mushoku Tensei & Sousou no Frieren (S1 & S2).

import 'anime_model.dart';
import 'voice_actor_model.dart';
import 'episode_model.dart';

const List<String> _kEpisodeThumbColors = ['242629', 'B8B8C0'];

List<EpisodeModel> buildCatalogEpisodes(
  int count,
  String animeTag, {
  String? customStreamUrl,
}) {
  return List.generate(count, (i) {
    return EpisodeModel(
      number: i + 1,
      title: 'Episode ${i + 1}',
      duration: '${22 + (i % 3)}m',
      thumbnailUrl:
          'https://placehold.co/320x180/${_kEpisodeThumbColors[0]}/${_kEpisodeThumbColors[1]}/png?text=$animeTag+Ep${i + 1}',
      videoUrl: customStreamUrl,
    );
  });
}

class CustomAnimeCatalog {
  CustomAnimeCatalog._();

  static List<AnimeModel> get all => _build();

  static List<AnimeModel> mergeWithLive(List<AnimeModel> live) {
    final seen = <String>{};
    final merged = <AnimeModel>[];
    for (final a in [...all, ...live]) {
      if (seen.add(a.id)) merged.add(a);
    }
    return merged;
  }

  static List<AnimeModel> _build() {
    final now = DateTime.now();

    DateTime nextAiring(int weekday, int hour) {
      var d = DateTime(now.year, now.month, now.day, hour);
      var diff = (weekday - now.weekday) % 7;
      if (diff < 0) diff += 7;
      d = d.add(Duration(days: diff));
      if (diff == 0 && d.isBefore(now)) d = d.add(const Duration(days: 7));
      return d;
    }

    return [
      // 1. Sousou no Frieren (Season 1)
      AnimeModel(
        id: 'custom-frieren',
        title: 'Sousou no Frieren',
        imageUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx154587-qQTzQnEJJ3oB.jpg',
        rating: 9.26,
        genres: ['Adventure', 'Award Winning', 'Drama', 'Fantasy'],
        description:
            'During a decade-long quest to defeat the Demon King, the members of the hero party — including Himmel the priest Heiter the dwarf warrior Eisen and the elven mage Frieren — forge bonds through adventures and battles creating unforgettable memories.',
        isTrending: true,
        episodes: buildCatalogEpisodes(28, 'SousouFrieren'),
        releaseDay: null,
        nextEpisodeAt: null,
        voiceActors: const [
          VoiceActorModel(
            malId: 613,
            name: 'Atsumi Tanezaki',
            imageUrl: 'https://cdn.myanimelist.net/images/voiceactors/3/68641.jpg',
            language: 'Japanese',
            characterName: 'Frieren',
            characterImageUrl: 'https://cdn.myanimelist.net/images/characters/4/521703.jpg',
          ),
          VoiceActorModel(
            malId: 428,
            name: 'Kana Ichinose',
            imageUrl: 'https://cdn.myanimelist.net/images/voiceactors/1/56885.jpg',
            language: 'Japanese',
            characterName: 'Fern',
            characterImageUrl: 'https://cdn.myanimelist.net/images/characters/2/521704.jpg',
          ),
          VoiceActorModel(
            malId: 30179,
            name: 'Chiaki Kobayashi',
            imageUrl: 'https://cdn.myanimelist.net/images/voiceactors/2/56574.jpg',
            language: 'Japanese',
            characterName: 'Stark',
            characterImageUrl: 'https://cdn.myanimelist.net/images/characters/3/521705.jpg',
          ),
          VoiceActorModel(
            malId: 413,
            name: 'Nobuhiko Okamoto',
            imageUrl: 'https://cdn.myanimelist.net/images/voiceactors/2/63060.jpg',
            language: 'Japanese',
            characterName: 'Himmel',
            characterImageUrl: 'https://cdn.myanimelist.net/images/characters/5/521706.jpg',
          ),
          VoiceActorModel(
            malId: 90,
            name: 'Hiroki Touchi',
            imageUrl: 'https://cdn.myanimelist.net/images/voiceactors/3/174.jpg',
            language: 'Japanese',
            characterName: 'Heiter',
            characterImageUrl: 'https://cdn.myanimelist.net/images/characters/2/521707.jpg',
          ),
          VoiceActorModel(
            malId: 91,
            name: 'Yoji Ueda',
            imageUrl: 'https://cdn.myanimelist.net/images/voiceactors/2/5555.jpg',
            language: 'Japanese',
            characterName: 'Eisen',
            characterImageUrl: 'https://cdn.myanimelist.net/images/characters/4/521708.jpg',
          ),
        ],
      ),

      // 2. Sousou no Frieren Season 2
      AnimeModel(
        id: 'custom-frieren-s2',
        title: 'Sousou no Frieren Season 2',
        imageUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx154587-qQTzQnEJJ3oB.jpg',
        rating: 9.35,
        genres: ['Adventure', 'Fantasy', 'Drama'],
        description:
            'Petualangan Frieren, Fern, dan Stark berlanjut ke wilayah utara Benua Ende tempat bersemayamnya jiwa para pahlawan dan misteri sihir kuno.',
        isTrending: true,
        episodes: buildCatalogEpisodes(12, 'FrierenS2'),
        releaseDay: 5, // Jumat
        nextEpisodeAt: nextAiring(5, 23),
        voiceActors: const [
          VoiceActorModel(
            malId: 613,
            name: 'Atsumi Tanezaki',
            imageUrl: 'https://cdn.myanimelist.net/images/voiceactors/3/68641.jpg',
            language: 'Japanese',
            characterName: 'Frieren',
            characterImageUrl: 'https://cdn.myanimelist.net/images/characters/4/521703.jpg',
          ),
          VoiceActorModel(
            malId: 428,
            name: 'Kana Ichinose',
            imageUrl: 'https://cdn.myanimelist.net/images/voiceactors/1/56885.jpg',
            language: 'Japanese',
            characterName: 'Fern',
            characterImageUrl: 'https://cdn.myanimelist.net/images/characters/2/521704.jpg',
          ),
          VoiceActorModel(
            malId: 30179,
            name: 'Chiaki Kobayashi',
            imageUrl: 'https://cdn.myanimelist.net/images/voiceactors/2/56574.jpg',
            language: 'Japanese',
            characterName: 'Stark',
            characterImageUrl: 'https://cdn.myanimelist.net/images/characters/3/521705.jpg',
          ),
        ],
      ),

      // 3. Mushoku Tensei: Isekai Ittara Honki Dasu (Season 1)
      AnimeModel(
        id: '11',
        title: 'Mushoku Tensei: Isekai Ittara Honki Dasu',
        imageUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx108465-1ANspF1EWyFx.jpg',
        rating: 8.7,
        genres: ['Fantasy', 'Isekai', 'Adventure'],
        description:
            'A shut-in is reincarnated into a magical world as Rudeus Greyrat and resolves to live this new life without regrets.',
        isTrending: true,
        episodes: buildCatalogEpisodes(11, 'MushokuTensei'),
        releaseDay: 5,
        nextEpisodeAt: nextAiring(5, 0),
        voiceActors: const [
          VoiceActorModel(
            malId: 1001,
            name: 'Yumi Uchiyama',
            imageUrl: 'https://cdn.myanimelist.net/images/voiceactors/3/54868.jpg',
            language: 'Japanese',
            characterName: 'Rudeus Greyrat',
            characterImageUrl: 'https://cdn.myanimelist.net/images/characters/3/426027.jpg',
          ),
          VoiceActorModel(
            malId: 1002,
            name: 'Ai Kakuma',
            imageUrl: 'https://cdn.myanimelist.net/images/voiceactors/2/62464.jpg',
            language: 'Japanese',
            characterName: 'Eris Boreas Greyrat',
            characterImageUrl: 'https://cdn.myanimelist.net/images/characters/5/426028.jpg',
          ),
          VoiceActorModel(
            malId: 1003,
            name: 'Konomi Kohara',
            imageUrl: 'https://cdn.myanimelist.net/images/voiceactors/1/54603.jpg',
            language: 'Japanese',
            characterName: 'Roxy Migurdia',
            characterImageUrl: 'https://cdn.myanimelist.net/images/characters/2/426029.jpg',
          ),
          VoiceActorModel(
            malId: 1004,
            name: 'Hisako Kanemoto',
            imageUrl: 'https://cdn.myanimelist.net/images/voiceactors/1/11691.jpg',
            language: 'Japanese',
            characterName: 'Zenith Greyrat',
            characterImageUrl: 'https://cdn.myanimelist.net/images/characters/4/426030.jpg',
          ),
          VoiceActorModel(
            malId: 1005,
            name: 'Toshiyuki Morikawa',
            imageUrl: 'https://cdn.myanimelist.net/images/voiceactors/1/54506.jpg',
            language: 'Japanese',
            characterName: 'Paul Greyrat',
            characterImageUrl: 'https://cdn.myanimelist.net/images/characters/2/426031.jpg',
          ),
        ],
      ),

      // 4. Mushoku Tensei: Isekai Ittara Honki Dasu Part 2 / Season 2
      AnimeModel(
        id: 'custom-mushoku-tensei-part-2',
        title: 'Mushoku Tensei: Isekai Ittara Honki Dasu Part 2',
        imageUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx146065-IjirxRK26O03.png',
        rating: 8.8,
        genres: ['Fantasy', 'Isekai', 'Adventure'],
        description:
            'The second cour of Rudeus\' journey continues as new challenges and revelations unfold in the Demon Continent.',
        isTrending: true,
        episodes: buildCatalogEpisodes(12, 'MushokuTenseiPart2'),
        releaseDay: 5,
        nextEpisodeAt: nextAiring(5, 0),
        voiceActors: const [
          VoiceActorModel(
            malId: 1001,
            name: 'Yumi Uchiyama',
            imageUrl: 'https://cdn.myanimelist.net/images/voiceactors/3/54868.jpg',
            language: 'Japanese',
            characterName: 'Rudeus Greyrat',
            characterImageUrl: 'https://cdn.myanimelist.net/images/characters/3/426027.jpg',
          ),
          VoiceActorModel(
            malId: 1002,
            name: 'Ai Kakuma',
            imageUrl: 'https://cdn.myanimelist.net/images/voiceactors/2/62464.jpg',
            language: 'Japanese',
            characterName: 'Eris Boreas Greyrat',
            characterImageUrl: 'https://cdn.myanimelist.net/images/characters/5/426028.jpg',
          ),
          VoiceActorModel(
            malId: 1003,
            name: 'Konomi Kohara',
            imageUrl: 'https://cdn.myanimelist.net/images/voiceactors/1/54603.jpg',
            language: 'Japanese',
            characterName: 'Roxy Migurdia',
            characterImageUrl: 'https://cdn.myanimelist.net/images/characters/2/426029.jpg',
          ),
          VoiceActorModel(
            malId: 1006,
            name: 'Daisuke Namikawa',
            imageUrl: 'https://cdn.myanimelist.net/images/voiceactors/1/54867.jpg',
            language: 'Japanese',
            characterName: 'Ruijerd Superdia',
            characterImageUrl: 'https://cdn.myanimelist.net/images/characters/4/426032.jpg',
          ),
        ],
      ),
    ];
  }
}
