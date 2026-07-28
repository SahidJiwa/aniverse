import 'dart:convert';
import 'package:http/http.dart' as http;

class StreamingResult {
  final String? streamUrl;
  final String? error;
  final bool needsProxy;
  // Multiple quality options for this episode, if the provider returned
  // more than one (e.g. {'1080p': url, '720p': url, ...}). Null when only
  // a single stream URL is available — watch_screen.dart falls back to
  // just [streamUrl] in that case and hides the quality picker.
  final Map<String, String>? qualities;
  const StreamingResult({
    this.streamUrl,
    this.error,
    this.needsProxy = false,
    this.qualities,
  });
}

class EpisodeInfo {
  final String id;
  final int number;
  final String? title;
  final String? image;
  const EpisodeInfo(this.id, this.number, this.title, this.image);
}

class StreamingService {
  final http.Client _client = http.Client();

  // ── API mirrors ────────────────────────────────────────────────────────
  // Provider: gogoanime
  // Self-hosted worker (Cloudflare Workers) — ganti URL setelah deploy!
  // Cara deploy: cd worker && npx wrangler deploy
  static const _gogoBases = [
    'https://aniverse-proxy.my-aniverse.workers.dev/anime/gogoanime',
    'https://api.consumet.org/anime/gogoanime',
    'https://api-anime-rouge.vercel.app/gogoanime',
    'https://anime-api-rouge.vercel.app/gogoanime',
    'https://consumet-phi.vercel.app/anime/gogoanime',
    'https://consumet-xi.vercel.app/anime/gogoanime',
    'https://consumet-eta.vercel.app/anime/gogoanime',
    'https://animxer-api.vercel.app/anime/gogoanime',
    'https://anime-api-rouge.vercel.app/anime/gogoanime',
    'https://api-anime-rouge.vercel.app/anime/gogoanime',
  ];
  // Provider: zoro (AniWatch)
  static const _zoroBases = [
    'https://api.consumet.org/anime/zoro',
    'https://api-anime-rouge.vercel.app/zoro',
    'https://anime-api-rouge.vercel.app/zoro',
  ];
  // Provider: hianime (hianime.to, successor of Zoro)
  static const _hianimeBases = [
    'https://api.consumet.org/anime/hianime',
    'https://api-anime-rouge.vercel.app/hianime',
    'https://anime-api-rouge.vercel.app/hianime',
  ];
  // Provider: shirayuki (HiAnime scraper via Vercel — WORKING!)
  static const _shirayukiBases = [
    'https://shirayuki-scrapper-api-v2.vercel.app/api/v2/hianime',
  ];
  // Provider: Sub Indo Scraper / Consumet Indo API (Otakudesu / Samehadaku)
  static const _indoBases = [
    'https://consumet-api-clone.vercel.app/anime/otakudesu',
    'https://api.consumet.org/anime/otakudesu',
  ];
  // Community Consumet mirrors (try-all)
  static const _communityConsumet = [
    'https://consumet-phi.vercel.app/anime/gogoanime',
    'https://consumet-xi.vercel.app/anime/gogoanime',
    'https://consumet-eta.vercel.app/anime/gogoanime',
    'https://animxer-api.vercel.app/anime/gogoanime',
    'https://anime-api-rouge.vercel.app/anime/gogoanime',
    'https://api-anime-rouge.vercel.app/anime/gogoanime',
    'https://zoro-api-virid.vercel.app/anime/gogoanime',
    'https://consumet-extasec.vercel.app/anime/gogoanime',
    'https://consumet-inky.vercel.app/anime/gogoanime',
  ];

  // ── Gogoanime direct scraping ─────────────────────────────────────────
  static const _gogoDomains = [
    'https://gogoanime.gg',
    'https://gogoanime.lu',
    'https://gogoanime.sx',
    'https://gogoanime.pe',
  ];
  static const _ajaxCdn = 'https://ajax.gogo-cdn.com';
  static const _ajaxCdnAlt = 'https://gogo-cdn.com';

  // ── Helpers ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _fetchJson(String url) async {
    try {
      final res = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      return json.decode(res.body) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _fetchHtml(String url) async {
    try {
      final res = await _client
          .get(Uri.parse(url), headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          })
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      return res.body;
    } catch (_) {
      return null;
    }
  }

  // ── Generic API helpers (works with any Consumet provider) ──────────

  Future<List<Map<String, dynamic>>> _apiSearch(
      String query, List<String> bases) async {
    for (final base in bases) {
      final data =
          await _fetchJson('$base/${Uri.encodeComponent(query)}');
      if (data != null) {
        return List<Map<String, dynamic>>.from(data['results'] ?? []);
      }
    }
    return [];
  }

  Future<List<EpisodeInfo>> _apiEpisodes(
      String animeId, List<String> bases) async {
    for (final base in bases) {
      final data = await _fetchJson('$base/info/$animeId');
      if (data == null) continue;
      final list = data['episodes'] as List?;
      if (list == null || list.isEmpty) continue;
      return list.map((e) => EpisodeInfo(
        e['id'] ?? '',
        (e['number'] ?? 0) as int,
        e['title'] as String?,
        e['image'] as String?,
      )).toList();
    }
    return [];
  }

  Future<StreamingResult> _apiStream(
      String episodeId, List<String> bases) async {
    for (final base in bases) {
      final data = await _fetchJson('$base/watch/$episodeId');
      if (data == null) continue;
      final sources = data['sources'] as List?;
      if (sources == null || sources.isEmpty) continue;
      final url = _pickBestSource(sources);
      if (url != null) {
        final qualities = _extractQualities(sources);
        return StreamingResult(
          streamUrl: url,
          qualities: qualities.length > 1 ? qualities : null,
        );
      }
    }
    return StreamingResult(error: '');
  }

  // ── Mapping judul → slug Gogoanime ─────────────────────────────────────
  // Dipake kalo judul Inggris ga cocok sama slug otomatis.
  static const _titleSlugMap = <String, String>{
    'frieren: beyond journey\'s end': 'sousou-no-frieren',
    'sousou no frieren': 'sousou-no-frieren',
    'attack on titan': 'shingeki-no-kyojin',
    'demon slayer': 'kimetsu-no-yaiba',
    'one punch man': 'one-punch-man',
    'mob psycho 100': 'mob-psycho-100',
    'steins;gate': 'steinsgate',
    'steins;gate 0': 'steinsgate-0',
    're:zero': 'rezero',
    're:zero kara hajimeru isekai seikatsu': 'rezero',
    'my hero academia': 'boku-no-hero-academia',
    'the rising of the shield hero': 'tate-no-yuusha-no-nariagari',
    'that time i got reincarnated as a slime': 'tensei-shitara-slime-datta-ken',
    'mushoku tensei': 'mushoku-tensei',
    'sword art online': 'sword-art-online',
    'fullmetal alchemist': 'fullmetal-alchemist',
    'death note': 'death-note',
    'tokyo ghoul': 'tokyo-ghoul',
    'cowboy bebop': 'cowboy-bebop',
    'neon genesis evangelion': 'neon-genesis-evangelion',
    'violet evergarden': 'violet-evergarden',
    'your lie in april': 'shigatsu-wa-kimi-no-uso',
    'kimi no na wa': 'kimi-no-na-wa',
    'spy x family': 'spy-x-family',
    'chainsaw man': 'chainsaw-man',
    'jujutsu kaisen': 'jujutsu-kaisen',
    'vinland saga': 'vinland-saga',
    'made in abyss': 'made-in-abyss',
    'horimiya': 'horimiya',
    'kaguya-sama: love is war': 'kaguya-sama',
  };

  // ── Slug helper ────────────────────────────────────────────────────────

  /// Generate kemungkinan slug Gogoanime dari judul anime.
  List<String> _toSlugs(String title) {
    final results = <String>{};
    // Cek manual map dulu
    final manual = _titleSlugMap[title.toLowerCase().trim()];
    if (manual != null) results.add(manual);

    final cleaned = title
        .toLowerCase()
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll("'", '')
        .trim();
    // Slug dari judul utama (sebelum ":")
    final mainTitle = cleaned.split(':').first.trim();
    final base = cleaned
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (base.isNotEmpty) {
      results.add(base);
      results.add(base.replaceAll(RegExp(r'-(tv|dub|movie|special|ona|ova)$'), ''));
    }
    // Slug dari judul utama aja (sebelum ":")
    final mainBase = mainTitle
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (mainBase.isNotEmpty) {
      results.add(mainBase);
    }
    // Kata pertama dari judul utama
    final firstWord = mainBase.split('-').first;
    if (firstWord.isNotEmpty && firstWord.length > 2) {
      results.add(firstWord);
    }
    return results.toList();
  }

  /// Coba akses category page Gogoanime langsung pake slug.
  Future<String?> _tryDirectSlug(String slug) async {
    for (final domain in _gogoDomains) {
      final html = await _fetchHtml('$domain/category/$slug');
      if (html == null) continue;
      // Validasi: pastiin halaman beneran category page, bukan 404/redirect
      if (html.contains('anime_video_body') ||
          RegExp(r"var\s+ep_start\s*=").hasMatch(html) ||
          html.contains('id="episode_page"')) return slug;
    }
    return null;
  }

  /// Cari slug yang valid: coba direct slug Gogoanime, lalu API search, lalu Gogoanime search.
  Future<String?> _findSlug(String title) async {
    // 1. Coba direct slug Gogoanime
    for (final slug in _toSlugs(title)) {
      final found = await _tryDirectSlug(slug);
      if (found != null) return found;
    }
    // 2. Coba API search (Gogoanime API)
    var results = await _apiSearch(title, _gogoBases);
    if (results.isNotEmpty) return results.first['id'] as String?;
    // 3. Coba API search (Zoro API)
    results = await _apiSearch(title, _zoroBases);
    if (results.isNotEmpty) return results.first['id'] as String?;
    // 4. Coba API search (HiAnime API)
    results = await _apiSearch(title, _hianimeBases);
    if (results.isNotEmpty) return results.first['id'] as String?;
    // 5. Fallback ke Gogoanime search langsung (HTML scrape)
    results = await _gogoSearch(title);
    if (results.isNotEmpty) return results.first['id'] as String?;
    return null;
  }

  Future<List<Map<String, dynamic>>> _gogoSearch(String query) async {
    for (final domain in _gogoDomains) {
      final html = await _fetchHtml(
          '$domain/search.html?keyword=${Uri.encodeComponent(query)}');
      if (html == null) continue;
      final results = <Map<String, dynamic>>[];
      final pages = _extractAll(
          html, r'<a\s+href\s*=\s*"([^"]*)"\s+title\s*=\s*"([^"]*)"');
      for (int i = 0; i + 1 < pages.length; i += 2) {
        final href = pages[i];
        final title = pages[i + 1];
        if (!href.startsWith('/category/')) continue;
        results.add({
          'id': href.replaceFirst('/category/', ''),
          'title': title,
        });
      }
      if (results.isNotEmpty) return results;
    }
    return [];
  }

  Future<List<EpisodeInfo>> _gogoEpisodes(String slug) async {
    for (final domain in _gogoDomains) {
      final html = await _fetchHtml('$domain/category/$slug');
      if (html == null) continue;

      // Cari data-id dari script
      final idMatch = RegExp(
        r"var\s+ep_start\s*=\s*\d+;\s*var\s+ep_end\s*=\s*\d+;\s*var\s+id\s*=\s*[']([^']+)[']",
      ).firstMatch(html);
      if (idMatch == null) continue;
      final dataId = idMatch.group(1);

      // Load episode list via AJAX
      var json = await _fetchJson(
          '$_ajaxCdn/ajax/load-list-episodes?ep_start=0&ep_end=9999&id=$dataId');
      if (json == null) {
        json = await _fetchJson(
            '$_ajaxCdnAlt/ajax/load-list-episodes?ep_start=0&ep_end=9999&id=$dataId');
      }
      if (json == null) continue;

      // Parse HTML dari response
      final epHtml = json['html'] as String?;
      if (epHtml == null) continue;

      // Ambil thumbnail dari category page (episode terbaru ada gambar)
      final epImages = _extractAll(
        html,
        r'<a\s+href\s*=\s*"/' + RegExp.escape(slug) + r'-episode-(\d+)"[^>]*>\s*<img\s+src\s*=\s*"([^"]*)"',
      );
      // Map episode number → thumbnail URL
      final thumbMap = <int, String>{};
      for (int i = 0; i + 1 < epImages.length; i += 2) {
        final epNum = int.tryParse(epImages[i]);
        final imgUrl = epImages[i + 1];
        if (epNum != null && imgUrl.isNotEmpty) {
          thumbMap[epNum] = imgUrl;
        }
      }

      final epLinks = _extractAll(
          epHtml, r'href\s*=\s*"([^"]*)"[^>]*>\s*([^<]+)');
      final episodes = <EpisodeInfo>[];
      for (int i = 0; i + 1 < epLinks.length; i += 2) {
        final href = epLinks[i].trim();
        final numStr = epLinks[i + 1].trim();
        if (!href.startsWith('/')) continue;
        final num = int.tryParse(numStr.replaceAll(RegExp(r'[^0-9]'), ''));
        if (num == null) continue;
        episodes.add(EpisodeInfo(
          href.replaceFirst('/', ''),
          num,
          'Episode $num',
          thumbMap[num],
        ));
      }
      if (episodes.isNotEmpty) return episodes;
    }
    return [];
  }

  Future<StreamingResult> _gogoStream(String episodeSlug) async {
    for (final domain in _gogoDomains) {
      final html = await _fetchHtml('$domain/$episodeSlug');
      if (html == null) continue;

      // Cari data-server dan data-id
      final dataIdMatch = RegExp(
        r"data-id\s*=\s*[']([^']+)[']",
      ).firstMatch(html);
      if (dataIdMatch == null) continue;
      final dataId = dataIdMatch.group(1)!;

      // Fetch video sources via AJAX
      var data = await _fetchJson('$_ajaxCdn/ajax/get-video-sources/$dataId');
      if (data == null) {
        data = await _fetchJson('$_ajaxCdnAlt/ajax/get-video-sources/$dataId');
      }
      if (data == null) continue;

      // Cek source type: direct m3u8 or encrypted
      final sourceType = data['sourceType']?.toString() ?? '';
      final sourcesJson = data['sources'] as List? ?? [];

      if (sourceType.contains('encrypt')) {
        // Goload server — butuh decrypt (complex), skip
        continue;
      }

      final url = _pickBestSource(sourcesJson);
      if (url != null) {
        final qualities = _extractQualities(sourcesJson);
        return StreamingResult(
          streamUrl: url,
          qualities: qualities.length > 1 ? qualities : null,
        );
      }
    }
    return StreamingResult(error: '');
  }

  // ── Source picking ────────────────────────────────────────────────────

  String? _pickBestSource(List sources) {
    String? bestUrl;
    for (final s in sources) {
      final q = (s['quality'] ?? '').toString().toLowerCase();
      final url = s['url'] as String?;
      if (url == null) continue;
      if (q == 'default' || q.contains('1080') || q.contains('720')) {
        bestUrl = url;
        break;
      }
      if (bestUrl == null) bestUrl = url;
    }
    if (bestUrl != null && bestUrl.startsWith('http://')) {
      bestUrl = bestUrl.replaceFirst('http://', 'https://');
    }
    return bestUrl;
  }

  /// Builds a {quality label: url} map from a raw `sources` list, so
  /// watch_screen.dart's quality picker has every resolution the provider
  /// actually returned — not just the single "best" pick from
  /// [_pickBestSource]. Returns an empty map if nothing usable is found;
  /// callers should treat that the same as "no quality options" and just
  /// use the single best-pick URL.
  Map<String, String> _extractQualities(List sources) {
    final map = <String, String>{};
    for (final s in sources) {
      final rawQuality = (s['quality'] ?? '').toString().trim().toLowerCase();
      var url = s['url'] as String?;
      if (url == null || url.isEmpty) continue;
      if (url.startsWith('http://')) {
        url = url.replaceFirst('http://', 'https://');
      }

      final String label;
      if (rawQuality.contains('1080')) {
        label = '1080p';
      } else if (rawQuality.contains('720')) {
        label = '720p';
      } else if (rawQuality.contains('480')) {
        label = '480p';
      } else if (rawQuality.contains('360')) {
        label = '360p';
      } else if (rawQuality.contains('240')) {
        label = '240p';
      } else if (rawQuality.contains('144')) {
        label = '144p';
      } else {
        label = 'Auto';
      }
      // First match wins so a higher-priority duplicate entry (if a
      // provider ever lists the same label twice) doesn't get silently
      // overwritten by a worse one later in the list.
      map.putIfAbsent(label, () => url!);
    }
    return map;
  }

  List<String> _extractAll(String html, String pattern) {
    final regex = RegExp(pattern, caseSensitive: false);
    return regex.allMatches(html).expand((m) {
      return List.generate(m.groupCount, (i) => m.group(i + 1) ?? '');
    }).toList();
  }

  void _log(String msg) => print('[Aniverse] $msg');

  // ── Shirayuki provider ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _shirayukiSearch(String query) async {
    for (final base in _shirayukiBases) {
      final data = await _fetchJson('$base/search?q=${Uri.encodeComponent(query)}');
      if (data == null) continue;
      final results = data['data']?['results'] as List?;
      if (results == null || results.isEmpty) continue;
      return results.map((r) => <String, dynamic>{
        'id': r['id'] ?? '',
        'title': r['title'] ?? r['jname'] ?? '',
        'image': r['poster'],
      }).toList();
    }
    return [];
  }

  Future<List<EpisodeInfo>> _shirayukiEpisodes(String animeId) async {
    for (final base in _shirayukiBases) {
      final data = await _fetchJson('$base/anime/$animeId');
      if (data == null) continue;
      final eps = data['data']?['episodes'] as List?;
      if (eps == null || eps.isEmpty) continue;
      return eps.map((e) => EpisodeInfo(
        e['episodeId'] ?? '',
        (e['episodeNo'] ?? 0) as int,
        e['title'] as String? ?? 'Episode ${e['episodeNo']}',
        e['image'] as String?,
      )).toList();
    }
    return [];
  }

  Future<StreamingResult> _resolveShirayuki(
      String animeTitle, int episodeNumber) async {
    _log('[Shirayuki] resolving: $animeTitle ep $episodeNumber');
    for (final base in _shirayukiBases) {
      _log('[Shirayuki] trying base: $base');
      final searchUrl = '$base/search?q=${Uri.encodeComponent(animeTitle)}';
      _log('[Shirayuki] search: $searchUrl');
      final searchData = await _fetchJson(searchUrl);
      if (searchData == null) {
        _log('[Shirayuki] search returned null');
        continue;
      }
      _log('[Shirayuki] search OK, keys: ${searchData.keys}');
      final results = searchData['data']?['results'] as List?;
      if (results == null || results.isEmpty) {
        _log('[Shirayuki] no results');
        continue;
      }
      _log('[Shirayuki] found ${results.length} results');
      final slug = results.first['id'] as String?;
      if (slug == null || slug.isEmpty) {
        _log('[Shirayuki] slug is null/empty');
        continue;
      }
      _log('[Shirayuki] slug: $slug');
      final srcUrl = '$base/episode/sources?animeEpisodeId=$slug&ep=$episodeNumber&server=hd-1&category=sub';
      _log('[Shirayuki] sources: $srcUrl');
      final srcData = await _fetchJson(srcUrl);
      if (srcData == null) {
        _log('[Shirayuki] sources returned null');
        continue;
      }
      final sources = srcData['data']?['sources'] as List?;
      if (sources == null || sources.isEmpty) {
        _log('[Shirayuki] no sources');
        continue;
      }
      _log('[Shirayuki] found ${sources.length} sources');
      for (final s in sources) {
        _log('[Shirayuki] source: m3u8=${s['m3u8']}');
      }
      final m3u8 = sources.firstWhere(
        (s) => s['m3u8'] is String && (s['m3u8'] as String).isNotEmpty,
        orElse: () => null,
      )?['m3u8'] as String?;
      if (m3u8 != null) {
        _log('[Shirayuki] success! m3u8: $m3u8');
        return StreamingResult(streamUrl: m3u8);
      }
    }
    _log('[Shirayuki] failed for: $animeTitle ep $episodeNumber');
    return StreamingResult(error: '');
  }

  // ── Public API ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> search(String query) async {
    var results = await _shirayukiSearch(query);
    if (results.isNotEmpty) return results;
    results = await _apiSearch(query, _gogoBases);
    if (results.isNotEmpty) return results;
    results = await _apiSearch(query, _zoroBases);
    if (results.isNotEmpty) return results;
    results = await _apiSearch(query, _hianimeBases);
    if (results.isNotEmpty) return results;
    return await _gogoSearch(query);
  }

  Future<List<EpisodeInfo>> getEpisodes(String animeId) async {
    var episodes = await _shirayukiEpisodes(animeId);
    if (episodes.isNotEmpty) return episodes;
    episodes = await _apiEpisodes(animeId, _gogoBases);
    if (episodes.isNotEmpty) return episodes;
    episodes = await _apiEpisodes(animeId, _zoroBases);
    if (episodes.isNotEmpty) return episodes;
    episodes = await _apiEpisodes(animeId, _hianimeBases);
    if (episodes.isNotEmpty) return episodes;
    return await _gogoEpisodes(animeId);
  }

  Future<StreamingResult> resolveStream(
      String animeTitle, int episodeNumber) async {
    try {
      // 1. Coba provider Sub Indo terlebih dahulu (Otakudesu/Samehadaku API)
      final indoResult = await _resolveIndoProvider(animeTitle, episodeNumber);
      if (indoResult.streamUrl != null) return _proxied(indoResult);

      // 2. Coba provider Shirayuki (HiAnime)
      final result = await _resolveShirayuki(animeTitle, episodeNumber);
      if (result.streamUrl != null) return _proxied(result);

      // 3. Fallback ke Gogoanime / Zoro
      final slug = await _findSlug(animeTitle);
      if (slug == null) {
        return StreamingResult(error: 'Anime tidak ditemukan');
      }
      final episodes = await getEpisodes(slug);
      final ep = episodes.where((e) => e.number == episodeNumber).firstOrNull;
      if (ep == null) {
        return StreamingResult(error: 'Episode $episodeNumber tidak ditemukan');
      }
      return getStreamUrl(ep.id); // already proxied internally
    } catch (e) {
      return StreamingResult(error: 'Error: ${e.toString()}');
    }
  }

  Future<StreamingResult> _resolveIndoProvider(
      String animeTitle, int episodeNumber) async {
    _log('[IndoScraper] Resolving: $animeTitle ep $episodeNumber');
    for (final base in _indoBases) {
      final searchResults = await _apiSearch(animeTitle, [base]);
      if (searchResults.isEmpty) continue;
      final animeId = searchResults.first['id'] as String?;
      if (animeId == null || animeId.isEmpty) continue;

      final episodes = await _apiEpisodes(animeId, [base]);
      final ep = episodes.where((e) => e.number == episodeNumber).firstOrNull;
      if (ep == null) continue;

      final streamRes = await _apiStream(ep.id, [base]);
      if (streamRes.streamUrl != null) {
        _log('[IndoScraper] Success! Stream URL found.');
        return streamRes;
      }
    }
    return StreamingResult(error: '');
  }

  // ── Video-stream proxy ──────────────────────────────────────────────────
  // Metadata calls (search/episode-list) already go through Vercel/CF
  // mirrors, which resolve fine on any network. But the final VIDEO url
  // returned by those providers points straight at their own CDN (e.g.
  // gogo-cdn.com), which some Indonesian ISPs block outright — so browsing
  // works everywhere while playback only works on networks that don't
  // block that specific CDN domain. Routing the resolved stream URL
  // through this worker fixes that: the worker fetches the video
  // server-side (Cloudflare's network isn't ISP-blocked) and also rewrites
  // HLS (.m3u8) playlists so their segment URLs stay proxied too.
  static const _streamProxyBase =
      'https://aniverse-video-proxy.my-aniverse.workers.dev/stream';

  StreamingResult _proxied(StreamingResult result) {
    final url = result.streamUrl;
    if (url == null || url.startsWith(_streamProxyBase)) return result;

    String wrap(String raw) => raw.startsWith(_streamProxyBase)
        ? raw
        : '$_streamProxyBase?url=${Uri.encodeComponent(raw)}';

    final qualities = result.qualities;
    final wrappedQualities = qualities == null
        ? null
        : qualities.map((label, rawUrl) => MapEntry(label, wrap(rawUrl)));

    return StreamingResult(
      streamUrl: wrap(url),
      needsProxy: true,
      qualities: wrappedQualities,
    );
  }

  Future<StreamingResult> getStreamUrl(String episodeId) async {
    var result = await _apiStream(episodeId, _gogoBases);
    if (result.streamUrl != null) return _proxied(result);
    result = await _apiStream(episodeId, _zoroBases);
    if (result.streamUrl != null) return _proxied(result);
    result = await _apiStream(episodeId, _hianimeBases);
    if (result.streamUrl != null) return _proxied(result);
    result = await _gogoStream(episodeId);
    return _proxied(result);
  }

  /// Cek apakah koneksi ke server streaming tersedia
  Future<bool> checkConnectivity() async {
    for (final url in [
      ..._shirayukiBases,
      ..._gogoBases,
      ..._zoroBases,
      ..._hianimeBases,
      ..._communityConsumet,
      ..._gogoDomains.map((d) => '$d/'),
    ]) {
      try {
        final res = await _client
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  void dispose() => _client.close();
}
