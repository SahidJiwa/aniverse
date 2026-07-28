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

import 'package:http/http.dart' as http;
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
  'placement': a.placement,
  'status': a.status,
};

Map<String, String> _parseQualities(String? raw) {
  final out = <String, String>{};
  if (raw == null || raw.trim().isEmpty) return out;

  // Supports: "360p: url1, 720p: url2" or line separated "720p: url" or single "http..."
  final lines = raw.split(RegExp(r'[\r\n,]+'));
  for (final l in lines) {
    final trimmed = l.trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.contains(': http')) {
      final parts = trimmed.split(': http');
      final qLabel = parts[0].trim();
      final url = 'http${parts[1].trim()}';
      out[qLabel] = url;
    } else if (trimmed.startsWith('http')) {
      out['720p'] = trimmed;
    }
  }
  return out;
}

AnimeModel _animeFromJson(Map<String, dynamic> j) {
  final count = (j['episodeCount'] as int?) ?? (j['episodes'] as int?) ?? 12;
  final tag = (j['title'] as String).replaceAll(' ', '');
  final epLink = j['catalogEpisodeLink'] as String?;
  final releaseDay = j['releaseDay'] as int?;

  // Build placement list from stored value, fallback to auto-infer
  List<String> placement = (j['placement'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
  if (placement.isEmpty) {
    placement = ['explore'];
    if (releaseDay != null) placement.add('jadwal');
  }

  return AnimeModel(
    id: j['id'] as String,
    title: j['title'] as String,
    imageUrl: j['imageUrl'] as String? ?? '',
    rating: (j['rating'] as num?)?.toDouble() ?? 0.0,
    genres: (j['genres'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    description: j['description'] as String? ?? '',
    isTrending: j['isTrending'] as bool? ?? false,
    releaseDay: releaseDay,
    episodes: buildCatalogEpisodes(count, tag, customStreamUrl: epLink),
    addedAt: j['addedAt'] != null ? DateTime.tryParse(j['addedAt'] as String) : DateTime.now(),
    catalogEpisodeLink: epLink,
    trailerUrl: j['trailerUrl'] as String?,
    placement: placement,
    status: j['status'] as String? ?? 'Ongoing',
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

  // ── Persistence & Remote Cloud Sync ───────────────────────────────────────
  static const _kCloudUrl = 'https://raw.githubusercontent.com/SahidJiwa/aniverse/main/admin-cms/catalog_cloud.json';

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
      debugPrint('[CatalogStore] init local error: $e');
    }
    _ready = true;
    notifyListeners();

    // Background sync from Cloud Remote Endpoint
    syncFromCloud();
  }

  Future<void> syncFromCloud() async {
    try {
      final res = await http.get(Uri.parse(_kCloudUrl)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final listRaw = jsonDecode(res.body) as List<dynamic>;
        final cloudEntries = listRaw.map((e) => _animeFromJson(e as Map<String, dynamic>)).toList();

        final seen = <String>{..._userEntries.map((a) => a.id)};
        bool updated = false;
        for (final item in cloudEntries) {
          if (seen.add(item.id)) {
            _userEntries.add(item);
            updated = true;
          }
        }
        if (updated) {
          await _save();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[CatalogStore] cloud sync skipped or offline: $e');
    }
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
