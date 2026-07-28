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
  'episodesCount': a.episodes.length,
  'addedAt': a.addedAt?.toIso8601String(),
  'catalogEpisodeLink': a.catalogEpisodeLink,
  'trailerUrl': a.trailerUrl,
  'placement': a.placement,
  'status': a.status,
};

AnimeModel _animeFromJson(Map<String, dynamic> j) {
  // Support all 3 key variants: episodesCount (cloud), episodeCount (legacy), episodes (Jikan)
  final count = (j['episodesCount'] as int?)
      ?? (j['episodeCount'] as int?)
      ?? (j['episodes'] as int?)
      ?? 12;
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
    // Use null when addedAt absent — avoids incorrectly marking old entries as newly added
    addedAt: j['addedAt'] != null ? DateTime.tryParse(j['addedAt'] as String) : null,
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

  // ── All entries: User/Admin entries from Cloud CMS, fallback to baseline ──
  List<AnimeModel> get all {
    if (_userEntries.isNotEmpty) return _userEntries;
    return CustomAnimeCatalog.all;
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

    // Background sync from Cloud Remote Endpoint & setup auto-refresh
    await syncFromCloud();
  }

  /// Sync real-time dengan Admin CMS Cloud JSON.
  /// Cloud JSON adalah Authoritative Single Source of Truth.
  Future<int> syncFromCloud() async {
    try {
      final res = await http.get(Uri.parse(_kCloudUrl)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final listRaw = jsonDecode(res.body) as List<dynamic>;
        final cloudEntries = listRaw.map((e) => _animeFromJson(e as Map<String, dynamic>)).toList();

        if (cloudEntries.isNotEmpty) {
          _userEntries = cloudEntries;
          await _save();
          notifyListeners();
          debugPrint('[CatalogStore] Realtime sync success: ${cloudEntries.length} anime loaded from Admin CMS.');
          return cloudEntries.length;
        }
      }
    } catch (e) {
      debugPrint('[CatalogStore] Cloud sync offline fallback to local cache: $e');
    }
    return _userEntries.length;
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

  // ── Strict custom catalog (no live API mixing) ────────────────────────────
  /// Returns ONLY the curated catalog entries (hardcoded + user-added via CMS).
  /// Use this everywhere the app must show ONLY Mushoku Tensei / Frieren.
  /// Unlike [mergeWithLive], this never includes live Jikan/AniList results.
  List<AnimeModel> getCustomCatalog() => all;

  // ── Strict custom catalog (no live API mixing) ────────────────────────────
  /// Balikin HANYA anime yang terdaftar di Admin CMS.
  /// Memastikan tidak ada anime luar yang masuk dari API publik.
  List<AnimeModel> mergeWithLive(List<AnimeModel> live) {
    return all;
  }
}
