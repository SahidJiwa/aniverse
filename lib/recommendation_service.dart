import 'anime_model.dart';

// =============================================================================
// RecommendationService
// =============================================================================
// Pure Dart — no Flutter imports, no network calls, no SharedPreferences.
// All scoring is synchronous and deterministic so it can be unit-tested
// independently of the UI.
//
// SCORING FORMULA (per candidate anime)
// ──────────────────────────────────────
//   finalScore = (genreScore * 0.70) + (similarityScore * 0.30)
//
//   genreScore      – [0.0 … 1.0] normalised sum of genre weights
//   similarityScore – [0.0 … 1.0] max Jaccard overlap between the
//                     candidate's semantic tag-set and the union of
//                     tag-sets from all seed anime
//
// TIE-BREAKING
// ────────────
//   1. finalScore descending
//   2. rating >= 8.0 preferred (boolean bucket)
//   3. rating descending
// =============================================================================

class RecommendationService {
  // ---------------------------------------------------------------------------
  // Public entry point
  // ---------------------------------------------------------------------------

  /// Computes a personalised recommendation list.
  ///
  /// [candidates]          – full anime pool to score (top + seasonal API results)
  /// [favorites]           – user's favourite anime          (weight 3)
  /// [recentlyViewed]      – recently visited detail screens  (weight 2)
  /// [continueWatchingIds] – anime IDs currently in-progress  (weight 1)
  /// [maxResults]          – hard cap on returned list
  ///
  /// Returns empty list when there are no user signals (cold-start) so the
  /// HomeScreen section stays hidden.
  static List<AnimeModel> compute({
    required List<AnimeModel> candidates,
    required List<AnimeModel> favorites,
    required List<AnimeModel> recentlyViewed,
    required List<String> continueWatchingIds,
    int maxResults = 15,
  }) {
    // ── 1. Short-circuit: nothing to base recommendations on ─────────────────
    final hasSignal = favorites.isNotEmpty ||
        recentlyViewed.isNotEmpty ||
        continueWatchingIds.isNotEmpty;
    if (!hasSignal) return const [];

    // ── 2. Build exclusion set (IDs the user already knows about) ────────────
    final excludedIds = <String>{
      for (final a in favorites) a.id,
      for (final a in recentlyViewed) a.id,
      ...continueWatchingIds,
    };

    // ── 3. Resolve continue-watching IDs → AnimeModel (needed for tags) ──────
    final cwAnimeById = <String, AnimeModel>{
      for (final c in candidates)
        if (continueWatchingIds.contains(c.id)) c.id: c,
    };
    final continueWatchingAnime = continueWatchingIds
        .map((id) => cwAnimeById[id])
        .whereType<AnimeModel>()
        .toList();

    // ── 4. Build genre-weight map from all three signal sources ───────────────
    //   favorites      → weight 3
    //   recentlyViewed → weight 2
    //   continueWatching → weight 1
    final genreWeights = <String, double>{};
    void addGenreWeight(AnimeModel a, double w) {
      final g = a.genre.trim().toLowerCase();
      if (g.isNotEmpty) genreWeights[g] = (genreWeights[g] ?? 0.0) + w;
    }

    for (final a in favorites) {
      addGenreWeight(a, 3.0);
    }
    for (final a in recentlyViewed) {
      addGenreWeight(a, 2.0);
    }
    for (final a in continueWatchingAnime) {
      addGenreWeight(a, 1.0);
    }

    final maxGenreWeight =
        genreWeights.values.fold(0.0, (prev, v) => v > prev ? v : prev);

    // ── 5. Build union of semantic tags from all seed anime ───────────────────
    final allSeedAnime = [
      ...favorites,
      ...recentlyViewed,
      ...continueWatchingAnime,
    ];
    final seedTagUnion = <String>{};
    for (final a in allSeedAnime) {
      seedTagUnion.addAll(_tagsFor(a));
    }

    // ── 6. Score every non-excluded candidate ─────────────────────────────────
    final scored = <_ScoredAnime>[];

    for (final candidate in candidates) {
      if (excludedIds.contains(candidate.id)) continue;

      // Genre score [0..1]
      final genreKey = candidate.genre.trim().toLowerCase();
      final rawGenre = genreWeights[genreKey] ?? 0.0;
      final genreScore =
          maxGenreWeight > 0 ? (rawGenre / maxGenreWeight) : 0.0;

      // Similarity score [0..1] — Jaccard between candidate tags and seed union
      final candidateTags = _tagsFor(candidate);
      final similarityScore = _jaccardSimilarity(candidateTags, seedTagUnion);

      final finalScore = (genreScore * 0.70) + (similarityScore * 0.30);

      // Only include candidates with at least a faint signal
      if (finalScore > 0.0) {
        scored.add(_ScoredAnime(anime: candidate, score: finalScore));
      }
    }

    // ── 7. Sort: score ↓, rating≥8 bucket ↓, rating ↓ ───────────────────────
    scored.sort((a, b) {
      final scoreCmp = b.score.compareTo(a.score);
      if (scoreCmp != 0) return scoreCmp;

      final aHighRated = a.anime.rating >= 8.0 ? 1 : 0;
      final bHighRated = b.anime.rating >= 8.0 ? 1 : 0;
      final ratingBucketCmp = bHighRated.compareTo(aHighRated);
      if (ratingBucketCmp != 0) return ratingBucketCmp;

      return b.anime.rating.compareTo(a.anime.rating);
    });

    // ── 8. Deduplicate by ID (candidates pool may have dupes across API calls)
    final seen = <String>{};
    final result = <AnimeModel>[];
    for (final s in scored) {
      if (seen.add(s.anime.id)) {
        result.add(s.anime);
        if (result.length >= maxResults) break;
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Semantic tag table
  // ---------------------------------------------------------------------------
  // Maps known anime titles (and their genre strings) to a set of descriptive
  // semantic tags. This bridges the gap when genre strings alone are too coarse
  // to capture the "Frieren → Mushishi" relationship.
  //
  // TAG DESIGN NOTES
  // • Tags are deliberately broad (e.g. "journey", "war", "supernatural") so
  //   that even titles not in the table still get partial overlap via their
  //   genre-derived fallback tags.
  // • Every genre string also maps to its own tags so even unknown titles
  //   benefit from the table via their genre field.
  // ---------------------------------------------------------------------------

  static const Map<String, List<String>> _titleTagTable = {
    // ── Slice-of-life / iyashikei ────────────────────────────────────────────
    'frieren: beyond journey\'s end': [
      'fantasy', 'journey', 'iyashikei', 'magic', 'adventure',
      'slow-paced', 'introspective', 'elves', 'post-quest',
    ],
    'frieren':                        ['fantasy', 'journey', 'iyashikei', 'magic', 'adventure', 'slow-paced', 'introspective'],
    'mushishi':                       ['supernatural', 'iyashikei', 'nature', 'episodic', 'slow-paced', 'mystery', 'journey'],
    'natsume yuujinchou':             ['supernatural', 'iyashikei', 'slice-of-life', 'spirits', 'slow-paced', 'heartwarming'],
    'natsume\'s book of friends':     ['supernatural', 'iyashikei', 'slice-of-life', 'spirits', 'slow-paced', 'heartwarming'],
    'kino\'s journey':                ['journey', 'iyashikei', 'philosophical', 'episodic', 'adventure', 'introspective'],
    'kino no tabi':                   ['journey', 'iyashikei', 'philosophical', 'episodic', 'adventure', 'introspective'],
    'violet evergarden':              ['drama', 'iyashikei', 'introspective', 'war', 'emotional', 'slow-paced', 'fantasy'],
    'a silent voice':                 ['drama', 'iyashikei', 'emotional', 'slice-of-life', 'school'],
    'your lie in april':              ['drama', 'emotional', 'music', 'slice-of-life', 'romance'],
    'spirited away':                  ['fantasy', 'adventure', 'magic', 'iyashikei', 'coming-of-age'],
    'princess mononoke':              ['fantasy', 'adventure', 'nature', 'war', 'action'],
    'made in abyss':                  ['fantasy', 'adventure', 'journey', 'dark', 'mystery'],
    'the ancient magus bride':        ['fantasy', 'magic', 'iyashikei', 'romance', 'supernatural'],

    // ── Action / dark fantasy ─────────────────────────────────────────────────
    'attack on titan':                ['dark', 'war', 'survival', 'military', 'action', 'mystery', 'historical', 'drama'],
    'vinland saga':                   ['historical', 'war', 'action', 'dark', 'drama', 'vikings', 'journey'],
    'kingdom':                        ['historical', 'war', 'action', 'military', 'strategy', 'dark'],
    'golden kamuy':                   ['historical', 'action', 'adventure', 'survival', 'dark', 'comedy'],
    '86':                             ['war', 'military', 'sci-fi', 'dark', 'mecha', 'drama'],
    'fullmetal alchemist: brotherhood':['action', 'fantasy', 'adventure', 'military', 'dark', 'magic', 'drama'],
    'fullmetal alchemist':            ['action', 'fantasy', 'adventure', 'military', 'dark', 'magic', 'drama'],
    'demon slayer':                   ['action', 'dark', 'supernatural', 'historical', 'fantasy', 'adventure'],
    'kimetsu no yaiba':               ['action', 'dark', 'supernatural', 'historical', 'fantasy', 'adventure'],
    'jujutsu kaisen':                 ['action', 'supernatural', 'dark', 'school', 'fantasy', 'horror'],
    'berserk':                        ['dark', 'fantasy', 'action', 'war', 'psychological', 'historical'],
    'claymore':                       ['dark', 'fantasy', 'action', 'supernatural', 'historical'],
    'dororo':                         ['dark', 'historical', 'action', 'supernatural', 'adventure', 'drama'],
    'goblin slayer':                  ['dark', 'fantasy', 'action', 'adventure', 'survival'],

    // ── Sci-fi ────────────────────────────────────────────────────────────────
    'cyberpunk edgerunners':          ['sci-fi', 'action', 'dark', 'cyberpunk', 'drama', 'urban'],
    'cowboy bebop':                   ['sci-fi', 'action', 'adventure', 'space', 'episodic', 'noir'],
    'trigun':                         ['sci-fi', 'action', 'adventure', 'western', 'comedy'],
    'steins;gate':                    ['sci-fi', 'thriller', 'time-travel', 'drama', 'mystery'],
    'neon genesis evangelion':        ['sci-fi', 'mecha', 'psychological', 'dark', 'action', 'drama'],
    'gurren lagann':                  ['sci-fi', 'mecha', 'action', 'adventure', 'comedy', 'drama'],
    'ghost in the shell':             ['sci-fi', 'cyberpunk', 'action', 'philosophical', 'thriller'],
    'psycho-pass':                    ['sci-fi', 'thriller', 'dark', 'psychological', 'action', 'mystery'],
    'serial experiments lain':        ['sci-fi', 'psychological', 'mystery', 'dark', 'introspective'],
    'ergo proxy':                     ['sci-fi', 'psychological', 'mystery', 'dark', 'philosophical'],

    // ── Fantasy / adventure ───────────────────────────────────────────────────
    'hunter x hunter':                ['fantasy', 'adventure', 'action', 'dark', 'coming-of-age'],
    'hunter x hunter (2011)':         ['fantasy', 'adventure', 'action', 'dark', 'coming-of-age'],
    'one piece':                      ['adventure', 'action', 'fantasy', 'comedy', 'journey'],
    'fairy tail':                     ['fantasy', 'adventure', 'action', 'magic', 'comedy'],
    'magi':                           ['fantasy', 'adventure', 'action', 'magic', 'historical'],
    'sword art online':               ['fantasy', 'action', 'adventure', 'sci-fi', 'romance'],
    're:zero':                        ['fantasy', 'dark', 'adventure', 'psychological', 'magic', 'drama'],
    'that time i got reincarnated as a slime': ['fantasy', 'adventure', 'comedy', 'magic', 'isekai'],
    'overlord':                       ['fantasy', 'dark', 'adventure', 'magic', 'isekai'],

    // ── Drama / romance ───────────────────────────────────────────────────────
    'spy x family':                   ['comedy', 'action', 'slice-of-life', 'family', 'spy', 'school'],
    'clannad':                        ['drama', 'romance', 'slice-of-life', 'emotional', 'school'],
    'anohana':                        ['drama', 'supernatural', 'emotional', 'slice-of-life', 'coming-of-age'],
    'toradora':                       ['romance', 'comedy', 'slice-of-life', 'school', 'drama'],
    'fruits basket':                  ['romance', 'drama', 'supernatural', 'slice-of-life', 'emotional'],
    'my hero academia':               ['action', 'school', 'superhero', 'coming-of-age', 'comedy', 'fantasy'],
    'haikyuu!!':                      ['sports', 'coming-of-age', 'school', 'drama', 'comedy'],
    'slam dunk':                      ['sports', 'school', 'comedy', 'drama', 'coming-of-age'],

    // ── Comedy ────────────────────────────────────────────────────────────────
    'gintama':                        ['comedy', 'action', 'sci-fi', 'historical', 'parody', 'drama'],
    'konosuba':                       ['comedy', 'fantasy', 'adventure', 'parody', 'isekai'],
    'the disastrous life of saiki k': ['comedy', 'school', 'supernatural', 'slice-of-life', 'parody'],
    'saiki k':                        ['comedy', 'school', 'supernatural', 'slice-of-life'],
    'nichijou':                       ['comedy', 'slice-of-life', 'school', 'absurd'],
  };

  /// Genre-string → semantic tags fallback (used when title isn't in the table).
  static const Map<String, List<String>> _genreTagTable = {
    'action':    ['action', 'adventure', 'fighting'],
    'adventure': ['adventure', 'journey', 'exploration'],
    'comedy':    ['comedy', 'slice-of-life', 'school'],
    'drama':     ['drama', 'emotional', 'slice-of-life'],
    'fantasy':   ['fantasy', 'magic', 'adventure'],
    'sci-fi':    ['sci-fi', 'technology', 'futuristic'],
    'horror':    ['horror', 'dark', 'supernatural'],
    'mystery':   ['mystery', 'thriller', 'psychological'],
    'romance':   ['romance', 'drama', 'slice-of-life'],
    'sports':    ['sports', 'coming-of-age', 'school'],
    'thriller':  ['thriller', 'mystery', 'psychological'],
    'historical':['historical', 'war', 'period'],
    'mecha':     ['mecha', 'sci-fi', 'action'],
    'music':     ['music', 'slice-of-life', 'drama'],
    'psychological': ['psychological', 'thriller', 'dark'],
    'supernatural':  ['supernatural', 'mystery', 'fantasy'],
  };

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns the semantic tag set for [anime].
  /// Tries the title table first (normalised), falls back to genre table.
  static Set<String> _tagsFor(AnimeModel anime) {
    final titleKey = anime.title.trim().toLowerCase();
    if (_titleTagTable.containsKey(titleKey)) {
      return _titleTagTable[titleKey]!.toSet();
    }
    final genreKey = anime.genre.trim().toLowerCase();
    final genreTags = _genreTagTable[genreKey] ?? [genreKey];
    return genreTags.toSet();
  }

  /// Jaccard similarity: |A ∩ B| / |A ∪ B|.
  /// Returns 0.0 when both sets are empty.
  static double _jaccardSimilarity(Set<String> a, Set<String> b) {
    if (a.isEmpty && b.isEmpty) return 0.0;
    final intersection = a.intersection(b).length;
    final union = a.union(b).length;
    return union == 0 ? 0.0 : intersection / union;
  }
}

// ---------------------------------------------------------------------------
// Internal value type
// ---------------------------------------------------------------------------

class _ScoredAnime {
  final AnimeModel anime;
  final double score;
  const _ScoredAnime({required this.anime, required this.score});
}
