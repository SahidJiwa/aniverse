import 'episode_model.dart';
import 'voice_actor_model.dart';

class AnimeModel {
  final String id;
  final String title;
  final String imageUrl;
  final double rating;

  /// All genres for this anime (e.g. ['Action', 'Fantasy', 'Adventure']).
  /// Always non-null; empty list means genre data wasn't available from the
  /// source (Jikan API or mock data).
  final List<String> genres;

  final String description;
  final bool isTrending;
  final List<EpisodeModel> episodes;

  /// Day of week this anime's new episode airs.
  /// 1 = Senin ... 7 = Minggu. Null if not a currently-airing schedule item.
  final int? releaseDay;

  /// Exact datetime the next episode airs/aired. Used for countdown timers
  /// on Jadwal/Home screens. Null if unknown or anime has finished airing.
  final DateTime? nextEpisodeAt;

  /// Voice actors list — optional, populated from Jikan API or custom catalog.
  final List<VoiceActorModel> voiceActors;

  /// When this title was added to the custom catalog. Used to compute
  /// "NEW" badge visibility (auto-hides after 14 days).
  final DateTime? addedAt;

  /// Related anime titles (e.g. sequels, prequels, spin-offs).
  final List<AnimeModel> relatedAnime;

  /// MyAnimeList ID — used for deep-linking and deduplication with Jikan API.
  final int? malId;

  /// Optional direct watch link entered by the user in Catalog Manager.
  /// When set, the WatchScreen uses this URL before falling back to
  /// my_episode_links.dart entries or the auto-scrape system.
  /// Can be a direct .mp4 URL or an embed/streaming page URL.
  final String? catalogEpisodeLink;

  /// Optional YouTube trailer URL entered by user or fetched via API.
  final String? trailerUrl;

  AnimeModel({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.rating,
    required this.genres,
    required this.description,
    this.isTrending = false,
    this.episodes = const [],
    this.releaseDay,
    this.nextEpisodeAt,
    this.voiceActors = const [],
    this.addedAt,
    this.relatedAnime = const [],
    this.malId,
    this.catalogEpisodeLink,
    this.trailerUrl,
  });

  /// Backward-compat single-genre accessor. Prefer [genres] for any
  /// filtering/counting logic — this only returns the first genre and
  /// exists so older call sites that haven't been migrated yet don't
  /// crash on a missing getter.
  String get genre => genres.isEmpty ? 'Unknown' : genres.first;
}
