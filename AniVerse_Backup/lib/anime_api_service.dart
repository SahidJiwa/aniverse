import 'dart:convert';

import 'package:http/http.dart' as http;

import 'anime_model.dart';
import 'episode_model.dart';

class JikanAnimeDetail {
  final String title;
  final String synopsis;
  final double score;
  final int? rank;
  final int? episodes;
  final String status;
  final List<String> genres;
  final List<String> studios;
  final String largeImageUrl;

  const JikanAnimeDetail({
    required this.title,
    required this.synopsis,
    required this.score,
    required this.rank,
    required this.episodes,
    required this.status,
    required this.genres,
    required this.studios,
    required this.largeImageUrl,
  });
}

class AnimeApiService {
  static const String _topAnimeUrl = 'https://api.jikan.moe/v4/top/anime';
  static const String _searchAnimeUrl = 'https://api.jikan.moe/v4/anime';
  static const String _seasonNowUrl = 'https://api.jikan.moe/v4/seasons/now';

  static Future<List<AnimeModel>> fetchTopAnime() async {
    final uri = Uri.parse('$_topAnimeUrl?limit=25');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load top anime: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (decoded['data'] as List<dynamic>? ?? const []);
    return data.map(_mapAnimeFromJikan).where((a) => a.id.isNotEmpty).toList();
  }

  static Future<List<AnimeModel>> searchAnime(String query) async {
    final uri = Uri.parse(
      '$_searchAnimeUrl?q=${Uri.encodeQueryComponent(query)}&limit=25',
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to search anime: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (decoded['data'] as List<dynamic>? ?? const []);
    return data.map(_mapAnimeFromJikan).where((a) => a.id.isNotEmpty).toList();
  }

  static Future<List<AnimeModel>> fetchCurrentSeasonAnime() async {
    final uri = Uri.parse('$_seasonNowUrl?limit=25');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load current season anime: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (decoded['data'] as List<dynamic>? ?? const []);
    return data.map(_mapAnimeFromJikan).where((a) => a.id.isNotEmpty).toList();
  }

  static Future<List<EpisodeModel>> fetchAnimeEpisodes(String malId) async {
    final uri = Uri.parse('https://api.jikan.moe/v4/anime/$malId/episodes');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load episodes: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (decoded['data'] as List<dynamic>? ?? const []);

    return data.asMap().entries.map((entry) {
      final index = entry.key;
      final map = entry.value as Map<String, dynamic>;
      final title = (map['title'] as String?)?.trim();
      final airedRaw = (map['aired'] as String?)?.trim();
      String? airedDate;
      if (airedRaw != null && airedRaw.isNotEmpty) {
        airedDate = airedRaw.split('T').first;
      }

      return EpisodeModel(
        number: index + 1,
        title: (title == null || title.isEmpty) ? 'Episode ${index + 1}' : title,
        duration: airedDate ?? 'N/A',
        thumbnailUrl: 'https://placehold.co/320x180/png?text=Episode+${index + 1}',
        airedDate: airedDate,
      );
    }).toList();
  }

  static Future<List<AnimeModel>> fetchAnimeRecommendations(String malId) async {
    final uri = Uri.parse('https://api.jikan.moe/v4/anime/$malId/recommendations');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load recommendations: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (decoded['data'] as List<dynamic>? ?? const []);

    return data.map((item) {
      final map = item as Map<String, dynamic>;
      final entry = (map['entry'] as Map<String, dynamic>? ?? const {});
      final malId = entry['mal_id']?.toString() ?? '';
      final title = (entry['title'] as String?)?.trim();
      final images = (entry['images'] as Map<String, dynamic>? ?? const {});
      final jpg = (images['jpg'] as Map<String, dynamic>? ?? const {});
      final imageUrl = (jpg['image_url'] as String?) ??
          'https://placehold.co/600x800/png?text=No+Image';

      return AnimeModel(
        id: malId,
        title: (title == null || title.isEmpty) ? 'Unknown Title' : title,
        imageUrl: imageUrl,
        rating: 0,
        genre: 'Unknown',
        description: 'Recommended anime',
        isTrending: false,
        episodes: const [],
      );
    }).where((anime) => anime.id.isNotEmpty).toList();
  }

  static AnimeModel _mapAnimeFromJikan(dynamic item) {
    final map = item as Map<String, dynamic>;
    final malId = map['mal_id']?.toString() ?? '';
    final title = (map['title'] as String?)?.trim();
    final imageUrl = (((map['images'] as Map<String, dynamic>?)?['jpg']
            as Map<String, dynamic>?)?['image_url']
        as String?) ??
        'https://placehold.co/600x800/png?text=No+Image';
    final score = (map['score'] as num?)?.toDouble() ?? 0.0;
    final synopsis =
        (map['synopsis'] as String?)?.trim() ?? 'No synopsis available.';
    final genres = (map['genres'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((g) => (g['name'] as String?)?.trim())
        .whereType<String>()
        .toList();

    return AnimeModel(
      id: malId,
      title: (title == null || title.isEmpty) ? 'Unknown Title' : title,
      imageUrl: imageUrl,
      rating: score,
      genre: genres.isEmpty ? 'Unknown' : genres.first,
      description: synopsis,
      isTrending: true,
      episodes: const [],
    );
  }

  static Future<JikanAnimeDetail> fetchAnimeDetail(String malId) async {
    final uri = Uri.parse('https://api.jikan.moe/v4/anime/$malId/full');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load anime detail: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final map = (decoded['data'] as Map<String, dynamic>? ?? const {});
    final title = (map['title'] as String?)?.trim();
    final synopsis = (map['synopsis'] as String?)?.trim();
    final score = (map['score'] as num?)?.toDouble() ?? 0.0;
    final rank = (map['rank'] as num?)?.toInt();
    final episodes = (map['episodes'] as num?)?.toInt();
    final status = (map['status'] as String?)?.trim() ?? 'Unknown';
    final genres = (map['genres'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((g) => (g['name'] as String?)?.trim())
        .whereType<String>()
        .toList();
    final studios = (map['studios'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((s) => (s['name'] as String?)?.trim())
        .whereType<String>()
        .toList();
    final images = (map['images'] as Map<String, dynamic>? ?? const {});
    final jpg = (images['jpg'] as Map<String, dynamic>? ?? const {});
    final largeImageUrl = (jpg['large_image_url'] as String?) ??
        (jpg['image_url'] as String?) ??
        'https://placehold.co/600x800/png?text=No+Image';

    return JikanAnimeDetail(
      title: (title == null || title.isEmpty) ? 'Unknown Title' : title,
      synopsis: (synopsis == null || synopsis.isEmpty)
          ? 'No synopsis available.'
          : synopsis,
      score: score,
      rank: rank,
      episodes: episodes,
      status: status,
      genres: genres,
      studios: studios,
      largeImageUrl: largeImageUrl,
    );
  }
}
