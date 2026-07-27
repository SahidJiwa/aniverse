import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Translates anime synopsis text (usually English, coming straight from the
/// Jikan/MyAnimeList API) into Indonesian.
///
/// Uses Google Translate's free, no-API-key endpoint — the same trick used
/// internally by popular pub.dev packages like `translator`. No new
/// dependency is needed since `http` is already in pubspec.yaml.
///
/// Results are cached forever in SharedPreferences, keyed by a hash of the
/// source text. A synopsis never changes once published, so there's no
/// reason to ever translate the same anime twice or burn extra requests.
class SynopsisTranslationService {
  SynopsisTranslationService._();

  static const String _cachePrefix = 'synopsis_tr_id_v1_';

  /// Translates [text] to Indonesian. Returns [text] unchanged if anything
  /// goes wrong (no internet, endpoint down/rate-limited, unexpected
  /// response shape, etc.) — the synopsis should never disappear or show an
  /// error just because translation failed; it just stays in English.
  static Future<String> translateToIndonesian(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return text;

    final cacheKey = _cachePrefix + _stableHash(trimmed);

    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(cacheKey);
      if (cached != null && cached.isNotEmpty) return cached;

      final translated = await _translateViaGoogle(trimmed);
      if (translated != null && translated.isNotEmpty) {
        await prefs.setString(cacheKey, translated);
        return translated;
      }
    } catch (_) {
      // Network error, timeout, bad JSON shape, prefs failure — all treated
      // the same way: fall back to the original text below.
    }
    return text;
  }

  static Future<String?> _translateViaGoogle(String text) async {
    final uri = Uri.https(
      'translate.googleapis.com',
      '/translate_a/single',
      {
        'client': 'gtx',
        'sl': 'auto',
        'tl': 'id',
        'dt': 't',
        'q': text,
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;

    // Response shape looks like:
    // [[["translated chunk 1","original chunk 1",null,null,3],
    //   ["translated chunk 2","original chunk 2",null,null,3], ...], ...]
    // Long synopses get split into multiple chunks, so all of them need to
    // be stitched back together in order.
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List || decoded.isEmpty || decoded[0] is! List) {
      return null;
    }

    final buffer = StringBuffer();
    for (final segment in decoded[0] as List) {
      if (segment is List && segment.isNotEmpty && segment[0] is String) {
        buffer.write(segment[0] as String);
      }
    }

    final result = buffer.toString().trim();
    return result.isEmpty ? null : result;
  }

  /// Deterministic FNV-1a hash used for the cache key. Dart's built-in
  /// `String.hashCode` works fine at runtime but isn't documented as stable
  /// across SDK versions or platforms, which makes it unsafe for a
  /// persistent cache key — this hand-rolled version always produces the
  /// same output for the same input, forever.
  static String _stableHash(String input) {
    int hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }
}
