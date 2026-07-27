// catalog_store.dart — AniVerse Dynamic Catalog Store
// ─────────────────────────────────────────────────────────────────────────────
// Single source of truth for ALL anime in the app.
// • Hardcoded entries from custom_anime_catalog.dart (always present)
// • Dynamic entries added by user via CatalogManagerScreen (persisted in SharedPreferences)
// • Merged together and exposed as .all, .newEntries, .classicEntries
// • Any screen that was using CustomAnimeCatalog should use CatalogStore instead
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'anime_model.dart';
import 'episode_model.dart';
import 'custom_anime_catalog.dart';

// ─── Serialisation helpers ──────────────────────────────────────────────────

Map<String, dynamic> _animeToJson(AnimeModel a) => {
  'id': a.id,
  'title': a.title,
  'imageUrl': a.imageUrl,
  'rating': a.rating,
  'genres': a.genres,
  'description': a.description,
  'isTrending': a.isTrending,
  'releaseDay': a.releaseDay,
  'episodeCount': a.episodes.length,
  'addedAt': a.addedAt?.toIso8601String(),
  'catalogEpisodeLink': a.catalogEpisodeLink,
  'trailerUrl': a.trailerUrl,
};

AnimeModel _animeFromJson(Map<String, dynamic> j) {
  final count = (j['episodeCount'] as int?) ?? 0;
  final tag = (j['title'] as String).replaceAll(' ', '');
  return AnimeModel(
    id: j['id'] as String,
    title: j['title'] as String,
    imageUrl: j['imageUrl'] as String? ?? '',
    rating: (j['rating'] as num?)?.toDouble() ?? 0.0,
    genres: (j['genres'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    description: j['description'] as String? ?? '',
    isTrending: j['isTrending'] as bool? ?? false,
    releaseDay: j['releaseDay'] as int?,
    episodes: buildCatalogEpisodes(count, tag),
    addedAt: j['addedAt'] != null ? DateTime.tryParse(j['addedAt'] as String) : DateTime.now(),
    catalogEpisodeLink: j['catalogEpisodeLink'] as String?,
    trailerUrl: j['trailerUrl'] as String?,
  );
}

// ─── CatalogStore ───────────────────────────────────────────────────────────

class CatalogStore extends ChangeNotifier {
  CatalogStore._();
  static final CatalogStore instance = CatalogStore._();

  static const _kKey = 'user_catalog_v1';
  static const _kNewDays = 14; // days before "new" badge expires

  List<AnimeModel> _userEntries = [];
  bool _ready = false;

  bool get isReady => _ready;

  // ── All entries: hardcoded first, then user entries (deduplicated by id) ──
  List<AnimeModel> get all {
    final hardcoded = CustomAnimeCatalog.all;
    final seen = <String>{};
    final out = <AnimeModel>[];
    for (final a in [...hardcoded, ..._userEntries]) {
      if (seen.add(a.id)) out.add(a);
    }
    return out;
  }

  /// Entries added within the last 14 days (user-added only)
  List<AnimeModel> get newEntries {
    final cutoff = DateTime.now().subtract(const Duration(days: _kNewDays));
    return _userEntries.where((a) {
      final at = a.addedAt;
      return at != null && at.isAfter(cutoff);
    }).toList()
      ..sort((a, b) => (b.addedAt ?? DateTime(0)).compareTo(a.addedAt ?? DateTime(0)));
  }

  /// Entries older than 14 days (user-added only)
  List<AnimeModel> get classicEntries {
    final cutoff = DateTime.now().subtract(const Duration(days: _kNewDays));
    return _userEntries.where((a) {
      final at = a.addedAt;
      return at == null || at.isBefore(cutoff);
    }).toList()
      ..sort((a, b) => (b.addedAt ?? DateTime(0)).compareTo(a.addedAt ?? DateTime(0)));
  }

  /// All user-added entries (sorted newest first)
  List<AnimeModel> get userEntries => List.unmodifiable(_userEntries);

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_ready) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw != null) {
        final list = (jsonDecode(raw) as List<dynamic>)
            .map((e) => _animeFromJson(e as Map<String, dynamic>))
            .toList();
        _userEntries = list;
      }
    } catch (e) {
      debugPrint('[CatalogStore] init error: $e');
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_userEntries.map(_animeToJson).toList());
      await prefs.setString(_kKey, raw);
    } catch (e) {
      debugPrint('[CatalogStore] save error: $e');
    }
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<void> add(AnimeModel anime) async {
    _userEntries.insert(0, anime);
    notifyListeners();
    await _save();
  }

  Future<void> update(String id, AnimeModel updated) async {
    final idx = _userEntries.indexWhere((a) => a.id == id);
    if (idx == -1) return;
    _userEntries[idx] = updated;
    notifyListeners();
    await _save();
  }

  Future<void> delete(String id) async {
    _userEntries.removeWhere((a) => a.id == id);
    notifyListeners();
    await _save();
  }

  bool isUserEntry(String id) => _userEntries.any((a) => a.id == id);

  // ── Merge with live API results ───────────────────────────────────────────

  List<AnimeModel> mergeWithLive(List<AnimeModel> live) {
    final seen = <String>{};
    final out = <AnimeModel>[];
    for (final a in [...all, ...live]) {
      if (seen.add(a.id)) out.add(a);
    }
    return out;
  }
}
