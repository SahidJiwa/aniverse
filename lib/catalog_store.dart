// catalog_store.dart — AniVerse Dynamic Catalog Store
// ─────────────────────────────────────────────────────────────────────────────
// Single source of truth for ALL anime in the app.
// • Hardcoded entries from custom_anime_catalog.dart (always present)
// • Dynamic entries added by user via CatalogManagerScreen (persisted in SharedPreferences)
// • Merged together and exposed as .all, .newEntries, .classicEntries
// • Any screen that was using CustomAnimeCatalog should use CatalogStore instead
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final tag = ((j['title'] as String?) ?? 'Untitled').replaceAll(' ', '');
  final epLink = j['catalogEpisodeLink'] as String?;
  final releaseDay = j['releaseDay'] as int?;

  // Build placement list from stored value, fallback to auto-infer
  List<String> placement = (j['placement'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
  if (placement.isEmpty) {
    placement = ['explore'];
    if (releaseDay != null) placement.add('jadwal');
  }

  return AnimeModel(
    // id/title kadang null di dokumen Firestore lama/belum lengkap — pakai
    // fallback aman alih-alih crash total (yang sebelumnya bikin SEMUA
    // dokumen gagal ke-parse dan _firestoreHasResponded tidak pernah true).
    id: (j['id'] as String?) ?? (j['title'] as String?) ?? 'unknown-${DateTime.now().microsecondsSinceEpoch}',
    title: (j['title'] as String?) ?? 'Untitled',
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
  StreamSubscription<QuerySnapshot>? _firestoreSub;

  // Jadi true begitu Firestore pernah kirim snapshot pertama (walau kosong).
  // Dipakai supaya syncFromCloud() dan fallback hardcoded tidak menimpa
  // data Firestore yang sudah dianggap authoritative.
  bool _firestoreHasResponded = false;

  bool get isReady => _ready;

  // ── All entries: Firestore adalah source of truth utama begitu sudah
  // pernah respond (walau hasilnya kosong, itu tetap valid — bukan alasan
  // untuk fallback ke katalog hardcoded lama).
  // Hardcoded catalog HANYA dipakai sebelum Firestore pernah connect sama
  // sekali (misal saat offline di run pertama).
  List<AnimeModel> get all {
    if (_firestoreHasResponded) return _userEntries;
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
        // Cache lokal ini cuma render sementara sebelum Firestore connect —
        // dedupe jaga-jaga kalau cache lama sempat kesimpan data ganda.
        _userEntries = _dedupeById(list);
      }
    } catch (e) {
      debugPrint('[CatalogStore] init local error: $e');
    }
    _ready = true;
    notifyListeners();

    // Realtime sync dari Firestore — auto update begitu ada perubahan dari Admin
    _listenToFirestore();
  }

  /// Dengarkan koleksi "anime" di Firestore secara realtime.
  /// Setiap ada tambah/edit/hapus dari Admin Panel, _userEntries otomatis
  /// ter-update dan semua screen yang listen ke CatalogStore langsung refresh.
  void _listenToFirestore() {
    _firestoreSub?.cancel();
    _firestoreSub = FirebaseFirestore.instance
        .collection('anime')
        .snapshots()
        .listen((snapshot) {
      final cloudEntries = <AnimeModel>[];
      for (final doc in snapshot.docs) {
        try {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = data['id'] ?? doc.id;
          cloudEntries.add(_animeFromJson(data));
        } catch (e) {
          // Skip dokumen yang bermasalah, tapi jangan gagalkan semua —
          // ini yang sebelumnya bikin seluruh snapshot gagal ke-parse
          // gara-gara satu field null di satu dokumen.
          debugPrint('[CatalogStore] Skip 1 doc gagal parse (id: ${doc.id}): $e');
        }
      }

      try {
        _userEntries = _dedupeById(cloudEntries);
        _firestoreHasResponded = true;
        _save();
        notifyListeners();
        debugPrint('[CatalogStore] Firestore realtime update: ${_userEntries.length} anime.');
      } catch (e) {
        debugPrint('[CatalogStore] Firestore parse error: $e');
      }
    }, onError: (e) {
      debugPrint('[CatalogStore] Firestore listen error (fallback ke cache lokal): $e');
    });
  }

  /// Sync real-time dengan Admin CMS Cloud JSON.
  /// Cloud JSON adalah Authoritative Single Source of Truth.
  Future<int> syncFromCloud() async {
    // Firestore adalah authoritative source begitu sudah pernah respond.
    // GitHub JSON ini cuma fallback offline sebelum Firestore connect —
    // jangan biarkan dia menimpa data Firestore yang lebih baru, karena
    // itu penyebab data ganda/stale (mis. Frieren muncul 2x).
    if (_firestoreHasResponded) {
      debugPrint('[CatalogStore] syncFromCloud dilewati — Firestore sudah authoritative.');
      return _userEntries.length;
    }
    try {
      final res = await http.get(Uri.parse(_kCloudUrl)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final listRaw = jsonDecode(res.body) as List<dynamic>;
        final cloudEntries = listRaw.map((e) => _animeFromJson(e as Map<String, dynamic>)).toList();

        if (cloudEntries.isNotEmpty && !_firestoreHasResponded) {
          _userEntries = _dedupeById(cloudEntries);
          await _save();
          notifyListeners();
          debugPrint('[CatalogStore] Realtime sync success: ${_userEntries.length} anime loaded from Admin CMS.');
          return _userEntries.length;
        }
      }
    } catch (e) {
      debugPrint('[CatalogStore] Cloud sync offline fallback to local cache: $e');
    }
    return _userEntries.length;
  }

  /// Hilangkan entri duplikat berdasarkan id (case/space-insensitive),
  /// menjaga dari kasus id sama tapi beda casing/spasi dianggap 2 entri.
  List<AnimeModel> _dedupeById(List<AnimeModel> entries) {
    final seen = <String>{};
    final result = <AnimeModel>[];
    for (final a in entries) {
      final key = a.id.trim().toLowerCase();
      if (seen.add(key)) result.add(a);
    }
    return result;
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
    try {
      // Firestore adalah source of truth — tulis ke sini, listener
      // realtime yang akan update _userEntries otomatis di semua device.
      final data = _animeToJson(anime);
      await FirebaseFirestore.instance
          .collection('anime')
          .doc(anime.id)
          .set(data);
    } catch (e) {
      debugPrint('[CatalogStore] add() Firestore write error, fallback lokal: $e');
      // Offline/gagal — tetap simpan lokal biar nggak hilang, tapi ini
      // TIDAK akan sync ke device lain sampai koneksi pulih & di-retry.
      _userEntries.insert(0, anime);
      notifyListeners();
      await _save();
    }
  }

  Future<void> update(String id, AnimeModel updated) async {
    try {
      final data = _animeToJson(updated);
      await FirebaseFirestore.instance
          .collection('anime')
          .doc(id)
          .set(data);
    } catch (e) {
      debugPrint('[CatalogStore] update() Firestore write error, fallback lokal: $e');
      final idx = _userEntries.indexWhere((a) => a.id == id);
      if (idx == -1) return;
      _userEntries[idx] = updated;
      notifyListeners();
      await _save();
    }
  }

  Future<void> delete(String id) async {
    try {
      await FirebaseFirestore.instance.collection('anime').doc(id).delete();
    } catch (e) {
      debugPrint('[CatalogStore] delete() Firestore write error, fallback lokal: $e');
      _userEntries.removeWhere((a) => a.id == id);
      notifyListeners();
      await _save();
    }
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
