// custom_anime_catalog.dart — AniVerse Custom Anime Catalog
// ─────────────────────────────────────────────────────────────────────────────
// SINGLE SOURCE OF TRUTH for manually-added anime.
//
// This is the ONE place to add, edit, or remove a custom anime entry.
// Every screen that lists anime (Home sections, Explore, Search, Jadwal,
// recommendations, etc.) merges this catalog together with live Jikan API
// results — so anything you add here shows up everywhere automatically,
// and anything you remove disappears everywhere too. No copy-pasting data
// into multiple files, no places that can fall out of sync.
//
// ── HOW TO ADD A NEW ANIME ──────────────────────────────────────────────────
// Copy this template into the list below and fill in the fields:
//
//   AnimeModel(
//     id: 'custom-my-anime-slug',        // unique, never reuse an existing id
//     title: 'My Anime Title',
//     imageUrl: 'https://.../cover.jpg', // real cover art if you have one
//     rating: 8.5,
//     genres: ['Action', 'Fantasy'],
//     description: 'A short synopsis...',
//     isTrending: false,                 // true pins it into "Trending Now"
//     episodes: buildCatalogEpisodes(12, 'MyAnime'),
//     releaseDay: 5,                     // 1=Senin..7=Minggu, or null if finished
//     nextEpisodeAt: null,               // see nextAiring() helper below if airing
//     addedAt: DateTime.now(),           // shows "NEW" badge for 14 days
//   ),
//
// ── HOW TO EDIT ──────────────────────────────────────────────────────────────
// Find the entry by its `id` or `title` below and change whatever field you
// need. The change appears everywhere the next time the app reloads.
//
// ── HOW TO REMOVE ────────────────────────────────────────────────────────────
// Delete the entire `AnimeModel(...)` block. It disappears from every
// screen at once — there is no second copy anywhere else to clean up.
// ─────────────────────────────────────────────────────────────────────────────

import 'anime_model.dart';
import 'voice_actor_model.dart';
import 'episode_model.dart';

// Single muted placeholder (not a rotating rainbow) — matches the rest of
// the Ghibli retheme's "one quiet neutral for filler content, save color
// for things that actually matter" direction. These are only shown until
// you have real per-episode thumbnails to hand instead.
const List<String> _kEpisodeThumbColors = ['242629', 'B8B8C0']; // AppTheme.surface / paperLight

/// Generates [count] placeholder episodes with a neutral placeholder
/// thumbnail, tagged with [animeTag] in the thumbnail text. Used by every
/// entry below unless you have real per-episode thumbnails to hand instead.
List<EpisodeModel> buildCatalogEpisodes(int count, String animeTag) {
  return List.generate(count, (i) {
    return EpisodeModel(
      number: i + 1,
      title: 'Episode ${i + 1}',
      duration: '${22 + (i % 3)}m',
      thumbnailUrl:
          'https://placehold.co/320x180/${_kEpisodeThumbColors[0]}/${_kEpisodeThumbColors[1]}/png?text=$animeTag+Ep${i + 1}',
    );
  });
}

class CustomAnimeCatalog {
  CustomAnimeCatalog._();

  /// Every manually-curated anime in the app. Merge this into any live
  /// (Jikan API) result list before rendering — see [mergeWithLive].
  static List<AnimeModel> get all => _build();

  /// Combines this catalog with a list of live API results, de-duplicated
  /// by id. Catalog entries are placed first so they're always present
  /// even if a live fetch is slow, empty, or fails — and so a catalog
  /// entry "wins" if it happens to share an id with a live result.
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
    // Helper: next occurrence of [weekday] (1=Mon..7=Sun) at [hour]:00 local time.
    DateTime nextAiring(int weekday, int hour) {
      var d = DateTime(now.year, now.month, now.day, hour);
      var diff = (weekday - now.weekday) % 7;
      if (diff < 0) diff += 7;
      d = d.add(Duration(days: diff));
      if (diff == 0 && d.isBefore(now)) d = d.add(const Duration(days: 7));
      return d;
    }

    return [
      AnimeModel(
        id: '1',
        title: 'Cyberpunk Edgerunners',
        imageUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx120377-ayZPoxiWt4Li.jpg',
        rating: 9.5,
        genres: ['Sci-Fi'],
        description:
            'A street kid trying to survive in a technology and body modification-obsessed city of the future.',
        isTrending: true,
        episodes: buildCatalogEpisodes(10, 'Cyberpunk'),
        releaseDay: 5,
        nextEpisodeAt: nextAiring(5, 20),
      ),
      AnimeModel(
        id: '2',
        title: 'Demon Slayer',
        imageUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx101922-WBsBl0ClmgYL.jpg',
        rating: 9.2,
        genres: ['Action'],
        description:
            'A family is attacked by demons and only two members survive.',
        isTrending: true,
        episodes: buildCatalogEpisodes(26, 'DemonSlayer'),
        releaseDay: 7,
        nextEpisodeAt: nextAiring(7, 17),
      ),
      AnimeModel(
        id: '3',
        title: 'Attack on Titan',
        imageUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx16498-buvcRTBx4NSm.jpg',
        rating: 9.8,
        genres: ['Drama'],
        description:
            'Humans are nearly exterminated by giant creatures called Titans.',
        isTrending: false,
        episodes: buildCatalogEpisodes(25, 'AOT'),
        releaseDay: 1,
        nextEpisodeAt: nextAiring(1, 19),
      ),
      AnimeModel(
        id: '4',
        title: 'Jujutsu Kaisen',
        imageUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx113415-LHBAeoZDIsnF.jpg',
        rating: 9.0,
        genres: ['Fantasy'],
        description:
            'A boy swallows a cursed object and becomes a vessel for a powerful curse.',
        isTrending: true,
        episodes: buildCatalogEpisodes(24, 'JJK'),
        releaseDay: 3,
        nextEpisodeAt: nextAiring(3, 23),
      ),
      AnimeModel(
        id: '5',
        title: 'Spy x Family',
        imageUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx140960-Kb6R5nYQfjmP.jpg',
        rating: 8.9,
        genres: ['Comedy'],
        description: 'A spy builds a fake family to execute a mission.',
        isTrending: false,
        episodes: buildCatalogEpisodes(12, 'SpyFamily'),
        releaseDay: 6,
        nextEpisodeAt: nextAiring(6, 18),
      ),
      AnimeModel(
        id: '6',
        title: 'One Piece',
        imageUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx21-ELSYx3yMPcKM.jpg',
        rating: 9.4,
        genres: ['Adventure'],
        description:
            'Monkey D. Luffy sails the Grand Line to find the legendary treasure One Piece and become the Pirate King.',
        isTrending: true,
        episodes: buildCatalogEpisodes(30, 'OnePiece'),
        releaseDay: 7,
        nextEpisodeAt: nextAiring(7, 9),
      ),
      AnimeModel(
        id: 'custom-frieren',
        title: 'Sousou no Frieren',
        imageUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx154587-qQTzQnEJJ3oB.jpg',
        rating: 9.26,
        genres: ['Adventure', 'Award Winning', 'Drama'],
        description:
            'During a decade-long quest to defeat the Demon King, the members of the hero party — including Himmel the priest Heiter the dwarf warrior Eisen and the elven mage Frieren — forge bonds through adventures and battles creating unforgettable memories.',
        isTrending: true,
        episodes: buildCatalogEpisodes(28, 'SousouFrieren'),
        releaseDay: null,
        nextEpisodeAt: null,
        voiceActors: const [
          VoiceActorModel(
            malId: 613,
            name: 'Junichi Suwabe',
            imageUrl: 'https://cdn.myanimelist.net/images/voiceactors/1/923.jpg',
            language: 'Japanese',
            characterName: 'Frieren',
            characterImageUrl: 'https://cdn.myanimelist.net/images/characters/4361605.jpg',
          ),
          VoiceActorModel(
            malId: 428,
            name: 'Kana Hanazawa',
            imageUrl: 'https://cdn.myanimelist.net/images/voiceactors/2/428.jpg',
            language: 'Japanese',
            characterName: 'Fern',
            characterImageUrl: 'https://cdn.myanimelist.net/images/characters/4361606.jpg',
          ),
          VoiceActorModel(
            malId: 30179,
            name: 'Reina Ueda',
            imageUrl: 'https://cdn.myanimelist.net/images/voiceactors/3/1136.jpg',
            language: 'Japanese',
            characterName: 'Stark',
            characterImageUrl: 'https://cdn.myanimelist.net/images/characters/4361607.jpg',
          ),
          VoiceActorModel(
            malId: 413,
            name: 'Youhei Tadano',
            imageUrl: 'https://cdn.myanimelist.net/images/voiceactors/1/413.jpg',
            language: 'Japanese',
            characterName: 'Sein',
            characterImageUrl: 'https://cdn.myanimelist.net/images/characters/4361608.jpg',
          ),
          VoiceActorModel(
            malId: 90,
            name: 'Koichi Yamadera',
            imageUrl: 'https://cdn.myanimelist.net/images/voiceactors/3/252.jpg',
            language: 'Japanese',
            characterName: 'Himmel',
            characterImageUrl: 'https://cdn.myanimelist.net/images/characters/4361609.jpg',
          ),
        ],
        relatedAnime: [
          _relatedAnime(
            id: 'rel-1',
            title: 'Made in Abyss',
            imageUrl: 'https://cdn.myanimelist.net/images/anime/6/86733l.jpg',
            rating: 9.3,
            genres: ['Adventure'],
            description: 'A young girl and her robot companion descend into a mysterious abyss.',
            episodes: [],
            voiceActors: const [],
            relatedAnime: [],
          ),
          _relatedAnime(
            id: 'rel-2',
            title: 'Mushishi',
            imageUrl: 'https://cdn.myanimelist.net/images/anime/3/26159l.jpg',
            rating: 9.1,
            genres: ['Drama'],
            description: 'A man travels the world investigating supernatural phenomena called Mushi.',
            episodes: [],
            voiceActors: const [],
            relatedAnime: [],
          ),
          _relatedAnime(
            id: 'rel-3',
            title: 'Violet Evergarden',
            imageUrl: 'https://cdn.myanimelist.net/images/anime/1795/95088l.jpg',
            rating: 9.0,
            genres: ['Drama'],
            description: 'A former soldier learns about emotions by becoming a letter writer.',
            episodes: [],
            voiceActors: const [],
            relatedAnime: [],
          ),
        ],
      ),
      AnimeModel(
        id: '8',
        title: 'Solo Leveling',
        imageUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx151807-it355ZgzquUd.png',
        rating: 9.1,
        genres: ['Action'],
        description:
            'The weakest hunter in the world gains the unique ability to level up infinitely after a near-death dungeon raid.',
        isTrending: true,
        episodes: buildCatalogEpisodes(13, 'SoloLeveling'),
        releaseDay: 6,
        nextEpisodeAt: nextAiring(6, 23),
      ),
      AnimeModel(
        id: '9',
        title: 'Chainsaw Man',
        imageUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx127230-DdP4vAdssLoz.png',
        rating: 8.8,
        genres: ['Horror'],
        description:
            'A young devil hunter merges with his pet chainsaw devil to become a powerful, chainsaw-headed hybrid.',
        isTrending: false,
        episodes: buildCatalogEpisodes(12, 'ChainsawMan'),
        releaseDay: 2,
        nextEpisodeAt: nextAiring(2, 23),
      ),
      AnimeModel(
        id: '10',
        title: 'Blue Lock',
        imageUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx137822-U8naszP96vzC.png',
        rating: 8.6,
        genres: ['Sci-Fi'],
        description:
            'Three hundred strikers are isolated and forced to compete in a brutal program to create Japan\'s best egoist striker.',
        isTrending: false,
        episodes: buildCatalogEpisodes(24, 'BlueLock'),
        releaseDay: 3,
        nextEpisodeAt: nextAiring(3, 22),
      ),
      AnimeModel(
        id: '11',
        // Title must match my_episode_links.dart's key EXACTLY (after
        // normalization) for the 11 real uploaded episodes to resolve.
        title: 'Mushoku Tensei: Isekai Ittara Honki Dasu',
        imageUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx108465-1ANspF1EWyFx.jpg',
        rating: 8.7,
        genres: ['Fantasy'],
        description:
            'A shut-in is reincarnated into a magical world as Rudeus Greyrat and resolves to live this new life without regrets.',
        isTrending: false,
        // Corrected from 23 to 11 — that's the real episode count
        // actually uploaded (Season 1 Part 1). The other 12 (Part 2)
        // are a separate cour/season, listed as their own entry below
        // rather than lumped into one 23-episode block.
        episodes: buildCatalogEpisodes(11, 'MushokuTensei'),
        releaseDay: 5,
        nextEpisodeAt: nextAiring(5, 0),
      ),
      AnimeModel(
        id: 'custom-mushoku-tensei-part-2',
        title: 'Mushoku Tensei: Isekai Ittara Honki Dasu Part 2',
        imageUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx146065-IjirxRK26O03.png',
        rating: 8.8,
        genres: ['Fantasy'],
        description:
            'The second cour of Rudeus\' journey continues as new challenges and revelations unfold.',
        isTrending: false,
        // Placeholder for now — no real video files uploaded yet for
        // Part 2. Add matching entries to my_episode_links.dart under
        // this exact title once episodes are ready.
        episodes: buildCatalogEpisodes(12, 'MushokuTenseiPart2'),
        releaseDay: 5,
        nextEpisodeAt: nextAiring(5, 0),
      ),
      AnimeModel(
        id: '12',
        title: 'Oshi no Ko',
        imageUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx150672-WqmmwZ4nMzAy.png',
        rating: 9.3,
        genres: ['Drama'],
        description:
            'Reincarnated as the children of their favorite idol, twins navigate the dark, glamorous world of Japanese show business.',
        isTrending: true,
        episodes: buildCatalogEpisodes(11, 'OshiNoKo'),
        releaseDay: 2,
        nextEpisodeAt: nextAiring(2, 0),
      ),
      AnimeModel(
        id: '13',
        title: 'Vinland Saga',
        imageUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx101348-2fhDFPCuMNiz.jpg',
        rating: 9.0,
        genres: ['Drama'],
        description:
            'A young Viking warrior seeks revenge against the man who killed his father, only to question the meaning of violence itself.',
        isTrending: false,
        episodes: buildCatalogEpisodes(24, 'VinlandSaga'),
        releaseDay: 1,
        nextEpisodeAt: nextAiring(1, 0),
      ),
      AnimeModel(
        id: '14',
        title: 'Dungeon Meshi',
        imageUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx153518-IVXPDY5ph3kO.jpg',
        rating: 8.9,
        genres: ['Adventure'],
        description:
            'A party of adventurers resorts to cooking and eating monsters to survive their dungeon-crawling quest to save a lost companion.',
        isTrending: false,
        episodes: buildCatalogEpisodes(24, 'DungeonMeshi'),
        releaseDay: 4,
        nextEpisodeAt: nextAiring(4, 17),
      ),
      AnimeModel(
        id: '15',
        title: 'Kaiju No. 8',
        imageUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx153288-25FBfFJzEQ5O.jpg',
        rating: 8.5,
        genres: ['Action'],
        description:
            'A man who dreamed of joining the Defense Force gains the power to transform into a kaiju himself.',
        isTrending: false,
        episodes: buildCatalogEpisodes(12, 'KaijuNo8'),
        releaseDay: 6,
        nextEpisodeAt: nextAiring(6, 23),
      ),
      AnimeModel(
        id: '16',
        title: 'Dandadan',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/1584/143719.jpg',
        rating: 8.45,
        genres: ['Action', 'Supernatural', 'Comedy'],
        description:
            'Setelah diputusin secara kejam, Momo Ayase yang sedang sedih bertemu dengan Takakura Ken yang dibully. '
            'Terselamatkan oleh kebaikan Ayase, Ken yang terobsesi dengan alien itu mencoba berbicara kepada Ayase '
            'tentang minat luar angkasa yang menurut Ken sama-sama mereka miliki. Menolak klaimnya, Ayase bilang '
            'bahwa dia justru lebih percaya pada hantu, yang memulai pertengkaran di antara keduanya tentang mana '
            'yang nyata. Dalam taruhan untuk menentukan siapa yang benar, keduanya memutuskan untuk masing-masing '
            'mengunjungi lokasi berlawanan yang terkait dengan kejadian luar angkasa dan supranatural, Ayase pergi '
            'ke tempat kejadian luar angkasa dan Ken ke tempat supranatural. Ketika keduanya sampai di tempat '
            'masing-masing, ternyata mereka menemukan kejadian yang tak terduga. Ini menandai dimulainya petualangan '
            'Ayase dan Ken.',
        isTrending: true, // sudah tamat, ditandai trending biar tetap menonjol
        episodes: buildCatalogEpisodes(24, 'Dandadan'),
        // Sudah tamat -> releaseDay & nextEpisodeAt sengaja tidak diisi (null),
        // jadi tidak akan muncul di "Tayang Hari Ini" / countdown Jadwal.
        addedAt: DateTime.now(), // badge "NEW" otomatis hilang setelah 14 hari
      ),

      // ── Add new custom anime below this line ──────────────────────────────
      // (see the template in the file header comment)
    ];
  }
}

AnimeModel _relatedAnime({
  required String id,
  required String title,
  required String imageUrl,
  required double rating,
  required List<String> genres,
  required String description,
  List<EpisodeModel> episodes = const [],
  List<VoiceActorModel> voiceActors = const [],
  List<AnimeModel> relatedAnime = const [],
}) {
  return AnimeModel(
    id: id,
    title: title,
    imageUrl: imageUrl,
    rating: rating,
    genres: genres,
    description: description,
    episodes: episodes,
    voiceActors: voiceActors,
    relatedAnime: relatedAnime,
  );
}
