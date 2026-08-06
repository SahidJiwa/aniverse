// tools/gen_catalog_links.dart
// Baca lib/my_episode_links.dart, extract tiap entry
// 'Judul_eps': MyEpisodeLink({ '1080p': 'url', ... }) lalu cetak JSON
// per-anime: { "1": {"1080p":url,...}, "2": {...} }
// Output bisa di-paste ke Admin Panel field "catalogEpisodeLink".
//
// Jalankan:  flutter pub run tools/gen_catalog_links.dart
//           (atau:  dart run tools/gen_catalog_links.dart)

import 'dart:io';
import 'dart:convert';

void main() {
  final file = File('lib/my_episode_links.dart');
  if (!file.existsSync()) {
    print('File lib/my_episode_links.dart gak ketemu');
    exit(1);
  }
  final src = file.readAsStringSync();

  // Split per entry: cari pattern  'KEY': MyEpisodeLink({
  final entryRe = RegExp(r"'([^']+)'\s*:\s*MyEpisodeLink\(\{", dotAll: true);
  final matches = entryRe.allMatches(src);

  // Kumpulkan tiap entry: key + block sampai tutup MyEpisodeLink(...)
  final entries = <String, Map<String, String>>{};
  for (final m in matches) {
    final key = m.group(1)!;
    final start = m.end;
    // cari tutup '})' terdekat yang seimbang
    var depth = 1;
    var i = start;
    var block = '';
    while (i < src.length && depth > 0) {
      final c = src[i];
      if (c == '{') depth++;
      if (c == '}') {
        depth--;
        if (depth == 0) break;
      }
      block += c;
      i++;
    }
    // Extract qualities: 'QUAL': 'URL'
    final qRe = RegExp(r"'([^']+)'\s*:\s*'([^']*)'");
    final qMap = <String, String>{};
    for (final qm in qRe.allMatches(block)) {
      qMap[qm.group(1)!] = qm.group(2)!;
    }
    if (qMap.isNotEmpty) entries[key] = qMap;
  }

  // Kelompokkan per anime title (key sblm _<ep>)
  final byAnime = <String, Map<String, Map<String, String>>>{};
  for (final e in entries.entries) {
    final key = e.key;
    final sep = key.lastIndexOf('_');
    if (sep == -1) continue;
    final title = key.substring(0, sep);
    final ep = key.substring(sep + 1);
    byAnime.putIfAbsent(title, () => {})[ep] = e.value;
  }

  print('=== CATALOG EPISODE LINKS (paste ke Admin Panel) ===\n');
  byAnime.forEach((title, eps) {
    // Sort episode
    final sortedEps = eps.entries.toList()
      ..sort((a, b) => (int.tryParse(a.key) ?? 0).compareTo(int.tryParse(b.key) ?? 0));
    final map = {
      for (final e in sortedEps) e.key: e.value,
    };
    print('──────────────────────────────────────────');
    print('ANIME: $title');
    print('PASTE JSON INI ke field "catalogEpisodeLink":');
    print(jsonEncode(map));
    print('');
  });
}
