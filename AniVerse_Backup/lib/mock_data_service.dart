import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'anime_model.dart';
import 'continue_watching_model.dart';
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
  static const String _watchlistKey = 'watchlist_ids';
  static const String _favoritesKey = 'favorites_ids';
  static const String _recentlyWatchedKey = 'recently_watched_ids';
  static const String _continueWatchingKey = 'continue_watching_items';
  static const String _watchedEpisodesKey = 'watched_episodes_map';

  // Watchlist
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

  // Favorites
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

  // Continue Watching
  static final ValueNotifier<List<ContinueWatchingModel>>
      continueWatchingNotifier = ValueNotifier<List<ContinueWatchingModel>>([]);

  static ContinueWatchingModel? getContinueWatchingByAnimeId(String animeId) {
    for (final item in continueWatchingNotifier.value) {
      if (item.animeId == animeId) return item;
    }
    return null;
  }

  static void updateContinueWatching({
    required String animeId,
    required int episodeNumber,
    required double watchProgress,
  }) {
    debugPrint('[CW] updateContinueWatching called');
    final clampedProgress = watchProgress.clamp(0.0, 1.0);
    final current =
        List<ContinueWatchingModel>.from(continueWatchingNotifier.value);
    final existingIndex = current.indexWhere((item) => item.animeId == animeId);

    if (existingIndex >= 0) {
      current[existingIndex] = current[existingIndex].copyWith(
        episodeNumber: episodeNumber,
        watchProgress: clampedProgress,
        lastWatched: DateTime.now(),
      );
    } else {
      current.add(
        ContinueWatchingModel(
          animeId: animeId,
          episodeNumber: episodeNumber,
          watchProgress: clampedProgress,
          lastWatched: DateTime.now(),
        ),
      );
    }

    current.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
    continueWatchingNotifier.value = current;
    debugPrint(
      '[ContinueWatching] updateContinueWatching called animeId="$animeId" '
      'episode=$episodeNumber progress=${clampedProgress.toStringAsFixed(4)} '
      'items=${current.length}',
    );
    _saveContinueWatchingItems();
  }

  // Recently Watched
  static final ValueNotifier<List<AnimeModel>> recentlyWatchedNotifier =
      ValueNotifier<List<AnimeModel>>([]);

  // Episode History: animeId -> watched episode numbers
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
    debugPrint(
      '[EpisodeHistory] markEpisodeWatched input animeId="$animeId" episode=$episodeNumber',
    );
    if (animeId.trim().isEmpty) {
      debugPrint(
        '[EpisodeHistory] skip save: animeId is empty for episode=$episodeNumber',
      );
      return;
    }
    final map = <String, Set<int>>{
      for (final entry in watchedEpisodesNotifier.value.entries)
        entry.key: Set<int>.from(entry.value),
    };
    final set = map.putIfAbsent(animeId, () => <int>{});
    set.add(episodeNumber);
    watchedEpisodesNotifier.value = map;
    debugPrint(
      '[EpisodeHistory] markEpisodeWatched animeId=$animeId episode=$episodeNumber '
      'current=${map.map((k, v) => MapEntry(k, v.toList()..sort()))}',
    );
    _saveWatchedEpisodes();
  }

  static void addRecentlyWatched(AnimeModel anime) {
    final list = List<AnimeModel>.from(recentlyWatchedNotifier.value);
    list.removeWhere((a) => a.id == anime.id);
    list.insert(0, anime);

    if (list.length > 10) {
      list.removeRange(10, list.length);
    }

    recentlyWatchedNotifier.value = list;
    _saveRecentlyWatchedIds();
  }

  // Persistence bootstrap
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    print('========== STARTUP STORAGE DUMP ==========');
    print('[StartupLoad] prefs.getKeys()=${prefs.getKeys()}');
    print(
      '[StartupLoad] containsKey($_favoritesKey)='
      '${prefs.containsKey(_favoritesKey)}',
    );
    print(
      '[StartupLoad] containsKey($_recentlyWatchedKey)='
      '${prefs.containsKey(_recentlyWatchedKey)}',
    );
    print(
      '[StartupLoad] containsKey($_continueWatchingKey)='
      '${prefs.containsKey(_continueWatchingKey)}',
    );
    print(
      '[StartupLoad] containsKey($_watchedEpisodesKey)='
      '${prefs.containsKey(_watchedEpisodesKey)}',
    );
    print('[StartupLoad] value($_favoritesKey)=${prefs.getStringList(_favoritesKey)}');
    print(
      '[StartupLoad] value($_recentlyWatchedKey)='
      '${prefs.getStringList(_recentlyWatchedKey)}',
    );
    print(
      '[StartupLoad] value($_continueWatchingKey)='
      '${prefs.getStringList(_continueWatchingKey)}',
    );
    print('[StartupLoad] value($_watchedEpisodesKey)=${prefs.getString(_watchedEpisodesKey)}');
    print('========== END STARTUP STORAGE DUMP ==========');
    debugPrint('[EpisodeHistory] initialize() called');
    print('[StartupLoad] prefs.getKeys()=${prefs.getKeys()}');
    print(
      '[StartupLoad] continueWatchingKey exists='
      '${prefs.containsKey(_continueWatchingKey)}',
    );
    print(
      '[StartupLoad] watchedHistoryKey exists='
      '${prefs.containsKey(_watchedEpisodesKey)}',
    );
    print(
      '[StartupLoad] continueWatching raw='
      '${prefs.getStringList(_continueWatchingKey)}',
    );
    print(
      '[StartupLoad] watchedHistory raw=${prefs.getString(_watchedEpisodesKey)}',
    );
    final byId = {for (final anime in getMockAnimes()) anime.id: anime};

    final watchlistIds = prefs.getStringList(_watchlistKey) ?? const [];
    libraryNotifier.value = watchlistIds
        .map((id) => byId[id])
        .whereType<AnimeModel>()
        .toList();

    final favoriteIds = prefs.getStringList(_favoritesKey) ?? const [];
    favoritesNotifier.value = favoriteIds
        .map((id) => byId[id])
        .whereType<AnimeModel>()
        .toList();

    final recentlyIds = prefs.getStringList(_recentlyWatchedKey) ?? const [];
    recentlyWatchedNotifier.value = recentlyIds
        .map((id) => byId[id])
        .whereType<AnimeModel>()
        .take(10)
        .toList();

    final continueRaw = prefs.getStringList(_continueWatchingKey) ?? const [];
    debugPrint('[StartupLoad] continueWatchingKey($_continueWatchingKey) = $continueRaw');
    debugPrint('[CW] loadContinueWatching called');
    debugPrint('[ContinueWatching] loading raw payload: $continueRaw');
    final loadedContinue = <ContinueWatchingModel>[];

    for (final raw in continueRaw) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final animeId = map['animeId'] as String?;
        final episodeNumber = map['episodeNumber'] as int?;
        final watchProgressNum = map['watchProgress'];
        final lastWatchedIso = map['lastWatched'] as String?;

        if (animeId == null ||
            episodeNumber == null ||
            watchProgressNum == null ||
            lastWatchedIso == null) {
          continue;
        }

        if (!byId.containsKey(animeId)) continue;

        loadedContinue.add(
          ContinueWatchingModel(
            animeId: animeId,
            episodeNumber: episodeNumber,
            watchProgress: (watchProgressNum as num).toDouble(),
            lastWatched: DateTime.parse(lastWatchedIso),
          ),
        );
      } catch (_) {
        // Skip malformed records.
      }
    }

    loadedContinue.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
    continueWatchingNotifier.value = loadedContinue;
    debugPrint(
      '[ContinueWatching] parsed items count=${loadedContinue.length} '
      'items=${loadedContinue.map((e) => '{id:${e.animeId},ep:${e.episodeNumber},p:${e.watchProgress.toStringAsFixed(4)}}').toList()}',
    );

    final watchedRaw = prefs.getString(_watchedEpisodesKey);
    debugPrint('[StartupLoad] watchedHistoryKey($_watchedEpisodesKey) = $watchedRaw');
    debugPrint('[EpisodeHistory] loading raw watched data: $watchedRaw');
    if (watchedRaw != null && watchedRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(watchedRaw) as Map<String, dynamic>;
        final restored = <String, Set<int>>{};

        for (final entry in decoded.entries) {
          if (entry.key.trim().isEmpty) {
            debugPrint(
              '[EpisodeHistory] skip invalid loaded key: empty animeId',
            );
            continue;
          }
          final value = entry.value;
          if (value is List) {
            restored[entry.key] = value
                .whereType<num>()
                .map((n) => n.toInt())
                .toSet();
          }
        }

        watchedEpisodesNotifier.value = restored;
        debugPrint(
          '[EpisodeHistory] loaded watched map: '
          '${restored.map((k, v) => MapEntry(k, v.toList()..sort()))}',
        );
      } catch (_) {
        watchedEpisodesNotifier.value = {};
        debugPrint('[EpisodeHistory] failed to parse watched map; reset to empty');
      }
    } else {
      watchedEpisodesNotifier.value = {};
      debugPrint('[EpisodeHistory] no watched map found; using empty state');
    }

    debugPrint(
      '[StartupLoad] continueWatchingNotifier.length='
      '${continueWatchingNotifier.value.length}',
    );
    debugPrint(
      '[StartupLoad] recentlyWatchedNotifier.length='
      '${recentlyWatchedNotifier.value.length}',
    );
  }

  static Future<void> _saveFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _favoritesKey,
      favoritesNotifier.value.map((anime) => anime.id).toList(),
    );
  }

  static Future<void> _saveWatchlistIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _watchlistKey,
      libraryNotifier.value.map((anime) => anime.id).toList(),
    );
  }

  static Future<void> _saveRecentlyWatchedIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _recentlyWatchedKey,
      recentlyWatchedNotifier.value.map((anime) => anime.id).toList(),
    );
  }

  static Future<void> _saveContinueWatchingItems() async {
    debugPrint('[CW] saveContinueWatching called');
    final prefs = await SharedPreferences.getInstance();
    debugPrint(
      '[ContinueWatching] saving items count=${continueWatchingNotifier.value.length}',
    );
    for (final item in continueWatchingNotifier.value) {
      debugPrint(
        '[ContinueWatching] save item animeId="${item.animeId}" '
        'episode=${item.episodeNumber} progress=${item.watchProgress.toStringAsFixed(4)}',
      );
    }
    final serialized = continueWatchingNotifier.value
        .map(
          (item) => jsonEncode({
            'animeId': item.animeId,
            'episodeNumber': item.episodeNumber,
            'watchProgress': item.watchProgress,
            'lastWatched': item.lastWatched.toIso8601String(),
          }),
        )
        .toList();

    try {
      debugPrint('[ContinueWatching] SharedPreferences payload=$serialized');
      final saved = await prefs.setStringList(_continueWatchingKey, serialized);
      debugPrint('[ContinueWatching] setStringList success=$saved');
    } finally {
      print('========== AFTER SAVE DUMP ==========');
      print('keys=${prefs.getKeys()}');
      print('continueWatching=${prefs.getStringList(_continueWatchingKey)}');
      print('watchedHistory=${prefs.getString(_watchedEpisodesKey)}');
    }
  }

  static Future<void> _saveWatchedEpisodes() async {
    final prefs = await SharedPreferences.getInstance();
    final encodable = <String, List<int>>{
      for (final entry in watchedEpisodesNotifier.value.entries)
        entry.key: entry.value.toList()..sort(),
    };
    final payload = jsonEncode(encodable);
    try {
      final saved = await prefs.setString(_watchedEpisodesKey, payload);
      debugPrint(
        '[EpisodeHistory] saved watched map success=$saved payload=$payload',
      );
    } finally {
      print('========== AFTER SAVE DUMP ==========');
      print('keys=${prefs.getKeys()}');
      print('continueWatching=${prefs.getStringList(_continueWatchingKey)}');
      print('watchedHistory=${prefs.getString(_watchedEpisodesKey)}');
    }
  }

  // Data
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
