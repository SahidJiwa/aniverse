import 'anime_model.dart';

// trailer_links.dart — AniVerse trailer link registry
//
// Simple, manually-maintained lookup: anime title -> trailer video URL
// (YouTube link, or any URL url_launcher can open).
//
// Keyed by TITLE (not id) on purpose — the app pulls anime from both a
// local mock dataset and the live Jikan API, and their id schemes don't
// match. Titles are stable and easy for you to recognize, so matching is
// done by title (case-insensitive, trimmed) instead.
//
// HOW TO ADD A TRAILER:
// 1. Copy the anime's title exactly as it appears in the app.
// 2. Add a line below: 'exact title here': 'https://youtube.com/watch?v=...',
//    (case doesn't matter — matching is case-insensitive)
//
// Anime with no entry here simply won't show a Trailer button — it's
// safe to leave anime out, nothing breaks.

const Map<String, String> trailerLinks = {
  // ─────────────────────────────────────────────────────────────────────────
  // TEMPLATE — copy the line below, paste it anywhere in this map, then
  // replace both the title and the URL. Keep entries alphabetized so it's
  // easy to check whether a title is already in here before adding a
  // duplicate.
  //
  // 'exact anime title here': 'https://youtube.com/watch?v=...',
  // ─────────────────────────────────────────────────────────────────────────
  'mushoku tensei: isekai ittara honki dasu': 'https://youtu.be/1TiBoHQUj3I',
  'mushoku tensei: jobless reincarnation': 'https://youtu.be/1TiBoHQUj3I',
  'sousou no frieren': 'https://www.youtube.com/watch?v=Iwr1aLEDpe4',
  'sousou no frieren season 2':
      'https://youtu.be/EOMVXqH9DSg?si=pPKCE0u5nFMcPuoA',
};

/// Returns the trailer URL for [animeTitle], or null if none is
/// registered. Matching is case-insensitive and ignores leading/trailing
/// whitespace, so small formatting differences between data sources
/// don't cause a miss. Accepts an optional [AnimeModel] to check for
/// custom user-defined trailer URLs first.
String? getTrailerUrl(String animeTitle, {AnimeModel? anime}) {
  if (anime != null && anime.trailerUrl != null && anime.trailerUrl!.trim().isNotEmpty) {
    return anime.trailerUrl!.trim();
  }
  return trailerLinks[animeTitle.trim().toLowerCase()];
}
