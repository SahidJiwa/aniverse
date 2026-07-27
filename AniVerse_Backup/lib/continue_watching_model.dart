class ContinueWatchingModel {
  final String animeId;
  final int episodeNumber;
  final double watchProgress;
  final DateTime lastWatched;

  const ContinueWatchingModel({
    required this.animeId,
    required this.episodeNumber,
    required this.watchProgress,
    required this.lastWatched,
  });

  ContinueWatchingModel copyWith({
    String? animeId,
    int? episodeNumber,
    double? watchProgress,
    DateTime? lastWatched,
  }) {
    return ContinueWatchingModel(
      animeId: animeId ?? this.animeId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      watchProgress: watchProgress ?? this.watchProgress,
      lastWatched: lastWatched ?? this.lastWatched,
    );
  }
}
