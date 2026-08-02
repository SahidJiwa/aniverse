import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'anime_model.dart';
import 'continue_watching_model.dart';
import 'episode_model.dart';
import 'tier_system.dart';
import 'voice_actor_model.dart';

// ── My List status ────────────────────────────────────────────────────────────

enum AnimeStatus { watching, completed, planToWatch, dropped }

extension AnimeStatusExt on AnimeStatus {
  String get label {
    switch (this) {
      case AnimeStatus.watching:
        return 'Watching';
      case AnimeStatus.completed:
        return 'Completed';
      case AnimeStatus.planToWatch:
        return 'Plan to Watch';
      case AnimeStatus.dropped:
        return 'Dropped';
    }
  }

  String get storageKey {
    switch (this) {
      case AnimeStatus.watching:
        return 'watching';
      case AnimeStatus.completed:
        return 'completed';
      case AnimeStatus.planToWatch:
        return 'planToWatch';
      case AnimeStatus.dropped:
        return 'dropped';
    }
  }
}

AnimeStatus? _animeStatusFromKey(String key) {
  switch (key) {
    case 'watching':
      return AnimeStatus.watching;
    case 'completed':
      return AnimeStatus.completed;
    case 'planToWatch':
      return AnimeStatus.planToWatch;
    case 'dropped':
      return AnimeStatus.dropped;
    default:
      return null;
  }
}

// ── Episode builder helper ────────────────────────────────────────────────────

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

class XpEvent {
  final String title;
  final int amount;
  final DateTime timestamp;
  XpEvent(this.title, this.amount, this.timestamp);
}

// ── MockDataService ───────────────────────────────────────────────────────────

class MockDataService {
  static const String _watchlistKey = 'watchlist_ids';
  static const String _favoritesKey = 'favorites_ids';
  static const String _recentlyWatchedKey = 'recently_watched_ids';
  static const String _continueWatchingKey = 'continue_watching_items';
  static const String _watchedEpisodesKey = 'watched_episodes_map';
  static const String _myListKey = 'my_list_status';

  // ── Watchlist ───────────────────────────────────────────────────────────────

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
    _saveWatchlistIds();
  }

  // ── Favorites ───────────────────────────────────────────────────────────────

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
    _saveFavoriteIds();
  }

  // ── My List ─────────────────────────────────────────────────────────────────

  static final ValueNotifier<Map<String, AnimeStatus>> myListNotifier =
      ValueNotifier<Map<String, AnimeStatus>>({});

  static AnimeStatus? getAnimeStatus(String animeId) =>
      myListNotifier.value[animeId];

  /// Pass [status] = null to remove the anime from My List.
  static void updateAnimeStatus(String animeId, AnimeStatus? status) {
    final map = Map<String, AnimeStatus>.from(myListNotifier.value);
    if (status == null) {
      map.remove(animeId);
    } else {
      map[animeId] = status;
    }
    myListNotifier.value = map;
    _saveMyList();
  }

  // ── Continue Watching ────────────────────────────────────────────────────────

  static final ValueNotifier<List<ContinueWatchingModel>>
  continueWatchingNotifier = ValueNotifier<List<ContinueWatchingModel>>([]);

  static ContinueWatchingModel? getContinueWatchingByAnimeId(String animeId) {
    for (final item in continueWatchingNotifier.value) {
      if (item.animeId == animeId) return item;
    }
    return null;
  }

  /// Creates a minimal playable AnimeModel from a ContinueWatchingModel
  /// when the anime cannot be resolved from any other in-memory source.
  static AnimeModel getPlayableAnimeForContinue(ContinueWatchingModel cw) {
    return AnimeModel(
      id: cw.animeId,
      title: cw.animeTitle.isNotEmpty ? cw.animeTitle : 'Unknown Anime',
      imageUrl: cw.thumbnailUrl.isNotEmpty ? cw.thumbnailUrl : '',
      rating: 0,
      genres: const ['Unknown'],
      description: '',
      episodes: const [],
    );
  }

  /// Throttle: write SharedPreferences at most once every 5 seconds.
  static DateTime _lastCwSave = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _cwSaveThrottle = Duration(seconds: 5);

  static void updateContinueWatching({
    required String animeId,
    required String animeTitle,
    required String thumbnailUrl,
    required int episodeNumber,
    required double watchProgress,
  }) {
    if (animeId.trim().isEmpty) return;

    final clampedProgress = watchProgress.clamp(0.0, 1.0);
    final current = List<ContinueWatchingModel>.from(
      continueWatchingNotifier.value,
    );
    final existingIndex = current.indexWhere((item) => item.animeId == animeId);

    if (existingIndex >= 0) {
      current[existingIndex] = current[existingIndex].copyWith(
        animeTitle: animeTitle,
        thumbnailUrl: thumbnailUrl,
        episodeNumber: episodeNumber,
        watchProgress: clampedProgress,
        lastWatched: DateTime.now(),
      );
    } else {
      current.add(
        ContinueWatchingModel(
          animeId: animeId,
          animeTitle: animeTitle,
          thumbnailUrl: thumbnailUrl,
          episodeNumber: episodeNumber,
          watchProgress: clampedProgress,
          lastWatched: DateTime.now(),
        ),
      );
    }

    current.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
    continueWatchingNotifier.value = current;

    final now = DateTime.now();
    if (now.difference(_lastCwSave) >= _cwSaveThrottle) {
      _lastCwSave = now;
      _saveContinueWatchingItems();
    }
  }

  // ── Recently Watched ─────────────────────────────────────────────────────────

  static final ValueNotifier<List<AnimeModel>> recentlyWatchedNotifier =
      ValueNotifier<List<AnimeModel>>([]);

  static void addRecentlyWatched(AnimeModel anime) {
    final list = List<AnimeModel>.from(recentlyWatchedNotifier.value);
    list.removeWhere((a) => a.id == anime.id);
    list.insert(0, anime);
    if (list.length > 20) list.removeRange(20, list.length);
    recentlyWatchedNotifier.value = list;
    _saveRecentlyWatchedIds();
  }

  // ── Episode History ──────────────────────────────────────────────────────────

  static final ValueNotifier<Map<String, Set<int>>> watchedEpisodesNotifier =
      ValueNotifier<Map<String, Set<int>>>({});

  static bool isEpisodeWatched({
    required String animeId,
    required int episodeNumber,
  }) {
    final set = watchedEpisodesNotifier.value[animeId];
    return set?.contains(episodeNumber) ?? false;
  }

  static void markEpisodeWatched({
    required String animeId,
    required int episodeNumber,
  }) {
    if (animeId.trim().isEmpty) return;
    final map = <String, Set<int>>{
      for (final entry in watchedEpisodesNotifier.value.entries)
        entry.key: Set<int>.from(entry.value),
    };
    map.putIfAbsent(animeId, () => <int>{}).add(episodeNumber);
    watchedEpisodesNotifier.value = map;
    _saveWatchedEpisodes();
  }

  /// Reverses [markEpisodeWatched]. Used when the user un-toggles a manual
  /// "watched" flag (e.g. from the Jadwal screen's per-card toggle) so
  /// Library's episode-history doesn't keep a stale mark the user disavowed.
  static void unmarkEpisodeWatched({
    required String animeId,
    required int episodeNumber,
  }) {
    if (animeId.trim().isEmpty) return;
    final map = <String, Set<int>>{
      for (final entry in watchedEpisodesNotifier.value.entries)
        entry.key: Set<int>.from(entry.value),
    };
    final set = map[animeId];
    if (set == null) return;
    set.remove(episodeNumber);
    if (set.isEmpty) map.remove(animeId);
    watchedEpisodesNotifier.value = map;
    _saveWatchedEpisodes();
  }

  // ── Persistence bootstrap ────────────────────────────────────────────────────

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final byId = {for (final anime in getMockAnimes()) anime.id: anime};

    // XP & tier — restore sebelum data lain supaya notifier sudah ready
    await _loadXP();
    await checkDailyLogin(); // +5 XP kalau belum login hari ini

    // Watchlist
    final watchlistIds = prefs.getStringList(_watchlistKey) ?? const [];
    libraryNotifier.value = watchlistIds
        .map((id) => byId[id])
        .whereType<AnimeModel>()
        .toList();

    // Favorites
    final favoriteIds = prefs.getStringList(_favoritesKey) ?? const [];
    favoritesNotifier.value = favoriteIds
        .map((id) => byId[id])
        .whereType<AnimeModel>()
        .toList();

    // Recently Watched — full JSON restore, no byId lookup.
    // Plain-ID entries written by the old format are silently dropped by the
    // try/catch, so there is no crash on first run after this upgrade.
    final recentlyRaw = prefs.getStringList(_recentlyWatchedKey) ?? const [];
    recentlyWatchedNotifier.value = recentlyRaw.map((raw) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        final id = m['id'] as String?;
        if (id == null || id.trim().isEmpty) return null;
        return AnimeModel(
          id: id,
          title: (m['title'] as String?) ?? '',
          imageUrl: (m['imageUrl'] as String?) ?? '',
          rating: (m['rating'] as num?)?.toDouble() ?? 0.0,
          // Reads new 'genres' list format; falls back to the old singular
          // 'genre' string (pre-migration cached entries) so existing
          // SharedPreferences data from before this update doesn't crash.
          genres: (m['genres'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              (((m['genre'] as String?)?.isNotEmpty ?? false) ? [m['genre'] as String] : const []),
          description: (m['description'] as String?) ?? '',
          isTrending: (m['isTrending'] as bool?) ?? false,
        );
      } catch (_) {
        return null;
      }
    }).whereType<AnimeModel>().take(20).toList();

    // Continue Watching — self-contained JSON, no byId filter needed
    final continueRaw = prefs.getStringList(_continueWatchingKey) ?? const [];
    var loadedContinue =
        continueRaw
            .map(ContinueWatchingModel.fromJsonString)
            .whereType<ContinueWatchingModel>()
            .toList()
          ..sort((a, b) => b.lastWatched.compareTo(a.lastWatched));

    // Dummy seed for fresh installs / preview only — never runs if the user
    // already has real saved progress (continueRaw is non-empty), so this
    // can't clobber anything genuine.
    if (continueRaw.isEmpty) {
      final now = DateTime.now();
      loadedContinue = [
        ContinueWatchingModel(
          animeId: 'custom-frieren-s2',
          animeTitle: 'Sousou no Frieren Season 2',
          thumbnailUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx154587-qQTzQnEJJ3oB.jpg',
          episodeNumber: 4,
          watchProgress: 0.65,
          lastWatched: now.subtract(const Duration(hours: 1)),
        ),
        ContinueWatchingModel(
          animeId: '11',
          animeTitle: 'Mushoku Tensei: Isekai Ittara Honki Dasu',
          thumbnailUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx108465-1ANspF1EWyFx.jpg',
          episodeNumber: 7,
          watchProgress: 0.85,
          lastWatched: now.subtract(const Duration(hours: 5)),
        ),
      ];
    }

    continueWatchingNotifier.value = loadedContinue;

    // My List
    final myListRaw = prefs.getString(_myListKey);
    if (myListRaw != null && myListRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(myListRaw) as Map<String, dynamic>;
        final restored = <String, AnimeStatus>{};
        for (final e in decoded.entries) {
          final status = _animeStatusFromKey(e.value as String? ?? '');
          if (status != null) restored[e.key] = status;
        }
        myListNotifier.value = restored;
      } catch (_) {
        myListNotifier.value = {};
      }
    } else {
      myListNotifier.value = {};
    }

    // Episode History
    final watchedRaw = prefs.getString(_watchedEpisodesKey);
    if (watchedRaw != null && watchedRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(watchedRaw) as Map<String, dynamic>;
        final restored = <String, Set<int>>{};
        for (final entry in decoded.entries) {
          if (entry.key.trim().isEmpty) continue;
          final value = entry.value;
          if (value is List) {
            restored[entry.key] = value
                .whereType<num>()
                .map((n) => n.toInt())
                .toSet();
          }
        }
        watchedEpisodesNotifier.value = restored;
      } catch (_) {
        watchedEpisodesNotifier.value = {};
      }
    } else {
      watchedEpisodesNotifier.value = {};
    }

    if (kDebugMode) {
      debugPrint(
        '[MockDataService] initialized — '
        'xp=${xpNotifier.value} '
        'cw=${loadedContinue.length} '
        'myList=${myListNotifier.value.length} '
        'favorites=${favoritesNotifier.value.length} '
        'watchlist=${libraryNotifier.value.length} '
        'recentlyWatched=${recentlyWatchedNotifier.value.length}',
      );
    }
  }

  // ── Private save helpers ─────────────────────────────────────────────────────

  static Future<void> _saveFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _favoritesKey,
      favoritesNotifier.value.map((a) => a.id).toList(),
    );
  }

  static Future<void> _saveWatchlistIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _watchlistKey,
      libraryNotifier.value.map((a) => a.id).toList(),
    );
  }

  static Future<void> _saveRecentlyWatchedIds() async {
    final prefs = await SharedPreferences.getInstance();
    // Store full AnimeModel fields as JSON so Jikan API anime (whose IDs are
    // not in getMockAnimes()) survive an app restart without a byId lookup.
    await prefs.setStringList(
      _recentlyWatchedKey,
      recentlyWatchedNotifier.value.map((a) => jsonEncode({
        'id': a.id,
        'title': a.title,
        'imageUrl': a.imageUrl,
        'rating': a.rating,
        'genres': a.genres,
        'description': a.description,
        'isTrending': a.isTrending,
      })).toList(),
    );
  }

  /// Force-save continue watching to SharedPreferences, BYPASSING the throttle.
  /// Harus dipanggil dari WatchScreen.dispose() agar progress terakhir
  /// selalu tersimpan, bahkan jika throttle belum expired.
  static Future<void> flushContinueWatching() => _saveContinueWatchingItems();

  static Future<void> _saveContinueWatchingItems() async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = continueWatchingNotifier.value
        .map((item) => item.toJsonString())
        .toList();
    await prefs.setStringList(_continueWatchingKey, serialized);
    if (kDebugMode) {
      debugPrint(
        '[MockDataService] saved continue_watching — ${serialized.length} items',
      );
    }
  }

  static Future<void> _saveMyList() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode({
      for (final e in myListNotifier.value.entries) e.key: e.value.storageKey,
    });
    await prefs.setString(_myListKey, encoded);
  }

  static Future<void> _saveWatchedEpisodes() async {
    final prefs = await SharedPreferences.getInstance();
    final encodable = <String, List<int>>{
      for (final entry in watchedEpisodesNotifier.value.entries)
        entry.key: entry.value.toList()..sort(),
    };
    await prefs.setString(_watchedEpisodesKey, jsonEncode(encodable));
  }

  // ── Mock data ────────────────────────────────────────────────────────────────

  static List<AnimeModel> getMockAnimes() {
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
      AnimeModel(
        id: 'custom-frieren',
        title: 'Sousou no Frieren',
        imageUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx154587-qQTzQnEJJ3oB.jpg',
        rating: 9.26,
        genres: const ['Adventure', 'Award Winning', 'Drama', 'Fantasy'],
        description:
            'During a decade-long quest to defeat the Demon King, the members of the hero party — including Himmel the priest Heiter the dwarf warrior Eisen and the elven mage Frieren — forge bonds through adventures and battles creating unforgettable memories.',
        isTrending: true,
        episodes: _buildEpisodes(28, 'SousouFrieren'),
        releaseDay: null,
        nextEpisodeAt: null,
        trailerUrl: 'https://www.youtube.com/watch?v=jy4tGgjT7P0',
        voiceActors: const [
          VoiceActorModel(malId: 0, name: 'Atsumi Tanezaki', characterName: 'Frieren', imageUrl: 'assets/images/voice_actors/tanezaki__atsumi.jpg', characterImageUrl: 'assets/images/voice_actors/frieren.jpg', language: 'Japanese'),
          VoiceActorModel(malId: 1, name: 'Chiaki Kobayashi', characterName: 'Himmel', imageUrl: 'assets/images/voice_actors/kobayashi__chiaki.jpg', characterImageUrl: 'assets/images/voice_actors/himmel.jpg', language: 'Japanese'),
          VoiceActorModel(malId: 2, name: 'Kana Ichinose', characterName: 'Fern', imageUrl: 'assets/images/voice_actors/ichinose__kana.jpg', characterImageUrl: 'assets/images/voice_actors/fern.jpg', language: 'Japanese'),
          VoiceActorModel(malId: 3, name: 'Hiroki Touchi', characterName: 'Heiter', imageUrl: 'assets/images/voice_actors/touchi__hiroki.jpg', characterImageUrl: 'assets/images/voice_actors/heiter.jpg', language: 'Japanese'),
        ],
      ),
      AnimeModel(
        id: 'custom-frieren-s2',
        title: 'Sousou no Frieren Season 2',
        imageUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx154587-qQTzQnEJJ3oB.jpg',
        rating: 9.35,
        genres: const ['Adventure', 'Fantasy', 'Drama'],
        description:
            'Petualangan Frieren, Fern, dan Stark berlanjut ke wilayah utara Benua Ende tempat bersemayamnya jiwa para pahlawan dan misteri sihir kuno.',
        isTrending: true,
        episodes: _buildEpisodes(12, 'FrierenS2'),
        releaseDay: 5,
        nextEpisodeAt: nextAiring(5, 23),
        trailerUrl: 'https://www.youtube.com/watch?v=jy4tGgjT7P0',
        voiceActors: const [
          VoiceActorModel(malId: 0, name: 'Atsumi Tanezaki', characterName: 'Frieren', imageUrl: 'assets/images/voice_actors/tanezaki__atsumi.jpg', characterImageUrl: 'assets/images/voice_actors/frieren.jpg', language: 'Japanese'),
          VoiceActorModel(malId: 1, name: 'Chiaki Kobayashi', characterName: 'Himmel', imageUrl: 'assets/images/voice_actors/kobayashi__chiaki.jpg', characterImageUrl: 'assets/images/voice_actors/himmel.jpg', language: 'Japanese'),
          VoiceActorModel(malId: 2, name: 'Kana Ichinose', characterName: 'Fern', imageUrl: 'assets/images/voice_actors/ichinose__kana.jpg', characterImageUrl: 'assets/images/voice_actors/fern.jpg', language: 'Japanese'),
          VoiceActorModel(malId: 3, name: 'Hiroki Touchi', characterName: 'Heiter', imageUrl: 'assets/images/voice_actors/touchi__hiroki.jpg', characterImageUrl: 'assets/images/voice_actors/heiter.jpg', language: 'Japanese'),
        ],
      ),
      AnimeModel(
        id: '11',
        title: 'Mushoku Tensei: Isekai Ittara Honki Dasu',
        imageUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx108465-1ANspF1EWyFx.jpg',
        rating: 8.7,
        genres: const ['Fantasy', 'Isekai', 'Adventure'],
        description:
            'A shut-in is reincarnated into a magical world as Rudeus Greyrat and resolves to live this new life without regrets.',
        isTrending: true,
        episodes: _buildEpisodes(11, 'MushokuTensei'),
        releaseDay: 5,
        nextEpisodeAt: nextAiring(5, 0),
        trailerUrl: 'https://www.youtube.com/watch?v=r_sT__wzXN4',
        voiceActors: const [
          VoiceActorModel(malId: 10, name: 'Yumi Uchiyama', characterName: 'Rudeus Greyrat', imageUrl: 'https://s4.anilist.co/file/anilistcdn/staff/large/n106263-K8bX4n3t8bY1.png', characterImageUrl: 'https://s4.anilist.co/file/anilistcdn/character/large/b138541-b1ANspF1EWyFx.jpg', language: 'Japanese'),
          VoiceActorModel(malId: 11, name: 'Ai Kakuma', characterName: 'Eris Boreas Greyrat', imageUrl: 'https://s4.anilist.co/file/anilistcdn/staff/large/n116499-aI6sP0JvT18n.png', characterImageUrl: 'https://s4.anilist.co/file/anilistcdn/character/large/b138543-IjirxRK26O03.png', language: 'Japanese'),
          VoiceActorModel(malId: 12, name: 'Konomi Kohara', characterName: 'Roxy Migurdia', imageUrl: 'https://s4.anilist.co/file/anilistcdn/staff/large/n124967-yXw7s5021S2J.png', characterImageUrl: 'https://s4.anilist.co/file/anilistcdn/character/large/b138542-qQTzQnEJJ3oB.jpg', language: 'Japanese'),
          VoiceActorModel(malId: 13, name: 'Daisuke Namikawa', characterName: 'Ruijerd Superdia', imageUrl: 'https://s4.anilist.co/file/anilistcdn/staff/large/n95277-9U3c8EmsM68n.png', characterImageUrl: 'https://s4.anilist.co/file/anilistcdn/character/large/b138544-xQn5gPshHjXz.png', language: 'Japanese'),
        ],
      ),
      AnimeModel(
        id: 'custom-mushoku-tensei-part-2',
        title: 'Mushoku Tensei: Isekai Ittara Honki Dasu Part 2',
        imageUrl: 'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx146065-IjirxRK26O03.png',
        rating: 8.8,
        genres: const ['Fantasy', 'Isekai', 'Adventure'],
        description:
            'The second cour of Rudeus\' journey continues as new challenges and revelations unfold in the Demon Continent.',
        isTrending: true,
        episodes: _buildEpisodes(12, 'MushokuTenseiPart2'),
        releaseDay: 5,
        nextEpisodeAt: nextAiring(5, 0),
        trailerUrl: 'https://www.youtube.com/watch?v=r_sT__wzXN4',
        voiceActors: const [
          VoiceActorModel(malId: 10, name: 'Yumi Uchiyama', characterName: 'Rudeus Greyrat', imageUrl: 'https://s4.anilist.co/file/anilistcdn/staff/large/n106263-K8bX4n3t8bY1.png', characterImageUrl: 'https://s4.anilist.co/file/anilistcdn/character/large/b138541-b1ANspF1EWyFx.jpg', language: 'Japanese'),
          VoiceActorModel(malId: 11, name: 'Ai Kakuma', characterName: 'Eris Boreas Greyrat', imageUrl: 'https://s4.anilist.co/file/anilistcdn/staff/large/n116499-aI6sP0JvT18n.png', characterImageUrl: 'https://s4.anilist.co/file/anilistcdn/character/large/b138543-IjirxRK26O03.png', language: 'Japanese'),
          VoiceActorModel(malId: 12, name: 'Konomi Kohara', characterName: 'Roxy Migurdia', imageUrl: 'https://s4.anilist.co/file/anilistcdn/staff/large/n124967-yXw7s5021S2J.png', characterImageUrl: 'https://s4.anilist.co/file/anilistcdn/character/large/b138542-qQTzQnEJJ3oB.jpg', language: 'Japanese'),
          VoiceActorModel(malId: 13, name: 'Daisuke Namikawa', characterName: 'Ruijerd Superdia', imageUrl: 'https://s4.anilist.co/file/anilistcdn/staff/large/n95277-9U3c8EmsM68n.png', characterImageUrl: 'https://s4.anilist.co/file/anilistcdn/character/large/b138544-xQn5gPshHjXz.png', language: 'Japanese'),
        ],
      ),
    ];
  }

  static List<String> getGenres() => [
    'Action',
    'Adventure',
    'Comedy',
    'Drama',
    'Sci-Fi',
    'Fantasy',
    'Horror',
  ];

  // ── XP & Tier System ─────────────────────────────────────────────────────────
  // XP tersimpan di SharedPreferences supaya persist antar sesi.
  // Semua aktivitas earn XP lewat satu method: `earnXP(amount, reason)`.
  // Profile screen tinggal listen ke `xpNotifier` buat update otomatis.

  static const String _xpKey = 'user_xp_total';
  static const String _lastLoginKey = 'user_last_login_date';
  static const String _episodeStreakKey = 'user_episode_streak';
  // Set berisi animeId yang sudah pernah ditonton ep pertamanya
  // (buat deteksi "first episode new anime" bonus).
  static const String _firstEpBonusKey = 'user_first_ep_bonus_ids';

  /// XP user saat ini. Listen ini di Profile/widget manapun yang butuh tier.
  static final ValueNotifier<int> xpNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<List<XpEvent>> xpEventsNotifier = ValueNotifier<List<XpEvent>>([]);
  static final ValueNotifier<String?> latestBadgeNotifier = ValueNotifier<String?>(null);

  /// Set animeId yang sudah dapat first-episode bonus (in-memory copy).
  static final Set<String> _firstEpBonusIds = {};

  /// Berapa episode berturut-turut yang sudah ditonton sesi ini.
  static int _episodeStreakCount = 0;

  /// Tambah XP dari aktivitas tertentu.
  /// [reason] dipakai untuk logging/debug, gak muncul ke user.
  static Future<void> earnXP(int amount, {String reason = ''}) async {
    if (amount <= 0) return;
    final oldXP = xpNotifier.value; // capture BEFORE update
    final newXP = oldXP + amount;
    xpNotifier.value = newXP;

    // Badge logic — compare oldXP vs newXP so thresholds only fire once
    if (newXP >= 100 && oldXP < 100) latestBadgeNotifier.value = 'Rookie';
    if (newXP >= 500 && oldXP < 500) latestBadgeNotifier.value = 'Pro';
    if (newXP >= 1000 && oldXP < 1000) latestBadgeNotifier.value = 'Elite';
    if (newXP >= 5000 && oldXP < 5000) latestBadgeNotifier.value = 'Legend';

    final events = List<XpEvent>.from(xpEventsNotifier.value);
    events.insert(0, XpEvent(reason.isNotEmpty ? reason : 'Aktivitas', amount, DateTime.now()));
    if (events.length > 10) events.removeLast();
    xpEventsNotifier.value = events;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_xpKey, newXP);
    if (kDebugMode) debugPrint('[XP] +$amount ($reason) → total $newXP');
  }

  /// Panggil ini tiap kali user nonton episode (dipanggil dari watch_screen
  /// lewat updateContinueWatching). Otomatis handle:
  /// - first episode new anime bonus (+30)
  /// - episode selesai bonus (+15)
  /// - streak 3 episode berturut-turut (+25)
  static Future<void> onEpisodeWatched({
    required String animeId,
    required bool completed, // true kalau progress > 90%
  }) async {
    // First episode of a new anime
    if (!_firstEpBonusIds.contains(animeId)) {
      _firstEpBonusIds.add(animeId);
      await earnXP(XPReward.firstEpisodeNewAnime, reason: 'first ep new anime');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_firstEpBonusKey, _firstEpBonusIds.toList());
    }

    if (completed) {
      await earnXP(XPReward.episodeCompleted, reason: 'episode completed');

      // Streak bonus — tiap 3 episode berturut-turut
      _episodeStreakCount++;
      if (_episodeStreakCount >= 3) {
        _episodeStreakCount = 0;
        await earnXP(XPReward.streakBonus3Episodes, reason: '3-ep streak');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_episodeStreakKey, _episodeStreakCount);
    }
  }

  /// Panggil sekali saat app dibuka / user login.
  /// Beri +5 XP kalau belum login hari ini.
  static Future<void> checkDailyLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
    final lastLogin = prefs.getString(_lastLoginKey) ?? '';
    if (lastLogin != today) {
      await prefs.setString(_lastLoginKey, today);
      await earnXP(XPReward.dailyLogin, reason: 'daily login');
    }
  }

  /// Restore XP dari SharedPreferences saat app start.
  /// Dipanggil dari `initialize()` — jangan panggil manual.
  static Future<void> _loadXP() async {
    final prefs = await SharedPreferences.getInstance();
    xpNotifier.value = prefs.getInt(_xpKey) ?? 0;
    _episodeStreakCount = prefs.getInt(_episodeStreakKey) ?? 0;
    final saved = prefs.getStringList(_firstEpBonusKey) ?? [];
    _firstEpBonusIds.addAll(saved);
  }
}
