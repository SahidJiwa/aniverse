// continue_watching_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// CW V2: tambah animeTitle + thumbnailUrl agar card tidak bergantung pada
// AnimeModel lookup (yang bisa gagal jika anime dari API belum ter-load).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';

class ContinueWatchingModel {
  final String animeId;
  final String animeTitle;      // ← BARU: judul anime untuk ditampilkan di card
  final String thumbnailUrl;    // ← BARU: cover/thumbnail anime untuk card
  final int episodeNumber;
  final double watchProgress;   // 0.0 – 1.0
  final DateTime lastWatched;

  const ContinueWatchingModel({
    required this.animeId,
    required this.animeTitle,
    required this.thumbnailUrl,
    required this.episodeNumber,
    required this.watchProgress,
    required this.lastWatched,
  });

  ContinueWatchingModel copyWith({
    String? animeId,
    String? animeTitle,
    String? thumbnailUrl,
    int? episodeNumber,
    double? watchProgress,
    DateTime? lastWatched,
  }) {
    return ContinueWatchingModel(
      animeId: animeId ?? this.animeId,
      animeTitle: animeTitle ?? this.animeTitle,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      watchProgress: watchProgress ?? this.watchProgress,
      lastWatched: lastWatched ?? this.lastWatched,
    );
  }

  // ── Serialization ────────────────────────────────────────────────────────────

  String toJsonString() => jsonEncode({
        'animeId': animeId,
        'animeTitle': animeTitle,
        'thumbnailUrl': thumbnailUrl,
        'episodeNumber': episodeNumber,
        'watchProgress': watchProgress,
        'lastWatched': lastWatched.toIso8601String(),
      });

  static ContinueWatchingModel? fromJsonString(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final animeId = map['animeId'] as String?;
      final episodeNumber = map['episodeNumber'] as int?;
      final watchProgress = (map['watchProgress'] as num?)?.toDouble();
      final lastWatchedIso = map['lastWatched'] as String?;

      if (animeId == null || animeId.isEmpty) return null;
      if (episodeNumber == null || episodeNumber < 1) return null;
      if (watchProgress == null) return null;
      if (lastWatchedIso == null) return null;

      return ContinueWatchingModel(
        animeId: animeId,
        animeTitle: (map['animeTitle'] as String?) ?? '',
        thumbnailUrl: (map['thumbnailUrl'] as String?) ?? '',
        episodeNumber: episodeNumber,
        watchProgress: watchProgress.clamp(0.0, 1.0),
        lastWatched: DateTime.parse(lastWatchedIso),
      );
    } catch (_) {
      return null;
    }
  }
}
