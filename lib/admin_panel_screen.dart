// admin_panel_screen.dart — AniVerse Hidden Admin Panel
// Tap logo 7x di Home → verifikasi PIN → halaman ini.
// CRUD anime langsung ke Firestore (koleksi "anime"), realtime lewat
// CatalogStore yang sudah dengarkan snapshots() — jadi setelah save di sini,
// semua screen lain auto-update tanpa refresh.

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'proxied_network_image.dart';
import 'custom_anime_catalog.dart';
import 'my_episode_links.dart';

// ── Image proxy — mengatasi CORS block dari CDN sosial media ───────────────
// Domain seperti i.pinimg.com (Pinterest), pbs.twimg.com (X), dll menolak
// request gambar langsung dari browser (Flutter web) karena kebijakan CORS
// mereka. Worker Cloudflare "aniverse-image-proxy" fetch gambar itu
// server-to-server (tidak kena CORS) lalu kirim balik dengan header yang
// mengizinkan. Ganti WORKER_BASE_URL di bawah dengan URL worker kamu setelah
// deploy (format: https://aniverse-image-proxy.<subdomain>.workers.dev).
//
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filter = 'all'; // all | trending | ongoing | finished | nolink

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _hasAnyLink(Map<String, dynamic> data) {
    final raw = data['catalogEpisodeLink'];
    if (raw is! String || raw.trim().isEmpty) return false;
    try {
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      return parsed.values.any((eps) {
        if (eps is! Map) return false;
        return eps.values.any((v) => v.toString().trim().isNotEmpty);
      });
    } catch (_) {
      return false;
    }
  }

  List<QueryDocumentSnapshot> _applyFilters(List<QueryDocumentSnapshot> docs) {
    var filtered = docs;
    if (_query.isNotEmpty) {
      filtered = filtered.where((d) {
        final data = d.data() as Map<String, dynamic>;
        final title = (data['title'] ?? '').toString().toLowerCase();
        return title.contains(_query);
      }).toList();
    }
    switch (_filter) {
      case 'trending':
        filtered = filtered.where((d) => (d.data() as Map)['isTrending'] == true).toList();
        break;
      case 'ongoing':
        filtered = filtered.where((d) {
          final s = ((d.data() as Map)['status'] ?? '').toString().toLowerCase();
          return !s.startsWith('finish') && !s.startsWith('tamat');
        }).toList();
        break;
      case 'finished':
        filtered = filtered.where((d) {
          final s = ((d.data() as Map)['status'] ?? '').toString().toLowerCase();
          return s.startsWith('finish') || s.startsWith('tamat');
        }).toList();
        break;
      case 'nolink':
        filtered = filtered.where((d) => !_hasAnyLink(d.data() as Map<String, dynamic>)).toList();
        break;
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Text(
          'Admin Panel',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        actions: [
          IconButton(
            tooltip: 'Seed Local → Cloud (push semua anime + link ke Firestore)',
            icon: const Icon(Icons.cloud_upload_rounded),
            onPressed: () => _seedFromLocalCatalog(context),
          ),
          IconButton(
            tooltip: 'Ganti PIN Admin',
            icon: const Icon(Icons.lock_reset_rounded),
            onPressed: () => AdminAccess.showChangePinDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accent,
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add_rounded, color: AppTheme.background),
        label: const Text(
          'Tambah Anime',
          style: TextStyle(
            color: AppTheme.background,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('anime').orderBy('title').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            );
          }

          final allDocs = snapshot.data!.docs;
          final total = allDocs.length;
          final trendingCount =
              allDocs.where((d) => (d.data() as Map)['isTrending'] == true).length;
          final ongoingCount = allDocs.where((d) {
            final s = ((d.data() as Map)['status'] ?? '').toString().toLowerCase();
            return !s.startsWith('finish') && !s.startsWith('tamat');
          }).length;
          final finishedCount = total - ongoingCount;
          final nolinkCount =
              allDocs.where((d) => !_hasAnyLink(d.data() as Map<String, dynamic>)).length;

          final docs = _applyFilters(allDocs);

          return Column(
            children: [
              // ── Stats strip ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    _StatChip(icon: '🎬', label: 'Total', value: total, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    _StatChip(icon: '🔥', label: 'Trending', value: trendingCount, color: AppTheme.highlight),
                    const SizedBox(width: 8),
                    _StatChip(icon: '🟢', label: 'Ongoing', value: ongoingCount, color: const Color(0xFF7B9E87)),
                    const SizedBox(width: 8),
                    _StatChip(icon: '🏁', label: 'Tamat', value: finishedCount, color: AppTheme.textSecondary),
                  ],
                ),
              ),
              // ── Search ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  onChanged: (v) => setState(() => _query = v.toLowerCase().trim()),
                  decoration: InputDecoration(
                    hintText: 'Cari judul anime...',
                    hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              // ── Filter chips ──
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _FilterChip(label: 'Semua ($total)', selected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
                    const SizedBox(width: 8),
                    _FilterChip(label: '🔥 Trending ($trendingCount)', selected: _filter == 'trending', onTap: () => setState(() => _filter = 'trending')),
                    const SizedBox(width: 8),
                    _FilterChip(label: '🟢 Ongoing ($ongoingCount)', selected: _filter == 'ongoing', onTap: () => setState(() => _filter = 'ongoing')),
                    const SizedBox(width: 8),
                    _FilterChip(label: '🏁 Tamat ($finishedCount)', selected: _filter == 'finished', onTap: () => setState(() => _filter = 'finished')),
                    const SizedBox(width: 8),
                    _FilterChip(label: '⚠️ Belum Ada Link ($nolinkCount)', selected: _filter == 'nolink', onTap: () => setState(() => _filter = 'nolink')),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: docs.isEmpty
                    ? Center(
                        child: Text(
                          _query.isNotEmpty || _filter != 'all'
                              ? 'Tidak ada anime yang cocok.'
                              : 'Belum ada anime. Tap "Tambah Anime" untuk mulai.',
                          style: const TextStyle(color: AppTheme.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: docs.length,
                        itemBuilder: (context, i) {
                          final doc = docs[i];
                          final data = doc.data() as Map<String, dynamic>;
                          return _AnimeAdminTile(
                            docId: doc.id,
                            data: data,
                            onEdit: () => _openForm(context, docId: doc.id, data: data),
                            onDelete: () => _confirmDelete(context, doc.id, data['title'] ?? ''),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, String docId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Hapus Anime?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Yakin mau hapus "$title"? Aksi ini tidak bisa dibatalkan.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('anime').doc(docId).delete();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"$title" dihapus.')),
                );
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _openForm(BuildContext context, {String? docId, Map<String, dynamic>? data}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AnimeFormScreen(docId: docId, data: data),
      ),
    );
  }

  /// Push semua anime + link video dari file lokal (custom_anime_catalog +
  /// my_episode_links) ke Firestore. Idempoten: anime yang sudah ada di
  /// Firestore (by id) dilewati, jadi aman di-klik berulang.
  /// Setelah seed, CatalogStore realtime listener menangani sync otomatis
  /// ke semua user — admin edit di sini langsung ter-reflect di app user.
  Future<void> _seedFromLocalCatalog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seed Local → Cloud?'),
        content: const Text(
          'Semua anime + link video dari file lokal akan di-push ke Firestore. '
          'Anime yang sudah ada (by id) dilewati. Setelah ini, edit di Admin Panel '
          'otomatis tersinkron ke semua user.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Seed Sekarang'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final existing = await firestore.collection('anime').get();
      final existingIds = existing.docs.map((d) => d.id).toSet();

      int added = 0;
      for (final anime in CustomAnimeCatalog.all) {
        if (existingIds.contains(anime.id)) continue;

        final epLinks = <String, Map<String, String>>{};
        for (final ep in anime.episodes) {
          final link = resolveMyEpisodeLink(anime.title, ep.number);
          if (link != null && link.qualities.isNotEmpty) {
            epLinks[ep.number.toString()] = Map.from(link.qualities);
          }
        }
        final catalogLinkJson = epLinks.isNotEmpty ? jsonEncode(epLinks) : '';

        final payload = <String, dynamic>{
          'title': anime.title,
          'imageUrl': anime.imageUrl,
          'rating': anime.rating,
          'genres': anime.genres,
          'description': anime.description,
          'isTrending': anime.isTrending,
          'status': anime.status,
          'episodes': anime.episodes.length,
          'episodeCount': anime.episodes.length,
          'catalogEpisodeLink': catalogLinkJson,
          'addedAt': FieldValue.serverTimestamp(),
          if (anime.releaseDay != null) 'releaseDay': anime.releaseDay,
          if (anime.trailerUrl != null) 'trailerUrl': anime.trailerUrl,
        };
        await firestore.collection('anime').doc(anime.id).set(payload);
        added++;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Seed selesai: $added anime di-push ke Cloud.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Seed gagal: $e')),
        );
      }
    }
  }
}

// ── Stats strip chip ────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String icon;
  final String label;
  final int value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              '$value',
              style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16),
            ),
            Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter chip pill ─────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent.withValues(alpha: 0.18) : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.accent : Colors.transparent,
            width: 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppTheme.accent : AppTheme.textSecondary,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

// ── Anime card (list item) ──────────────────────────────────────────────────
class _AnimeAdminTile extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AnimeAdminTile({
    required this.docId,
    required this.data,
    required this.onEdit,
    required this.onDelete,
  });

  bool get _hasLink {
    final raw = data['catalogEpisodeLink'];
    if (raw is! String || raw.trim().isEmpty) return false;
    try {
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      return parsed.values.any((eps) {
        if (eps is! Map) return false;
        return eps.values.any((v) => v.toString().trim().isNotEmpty);
      });
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] ?? 'Tanpa Judul').toString();
    final rating = (data['rating'] ?? 0).toString();
    final rawStatus = (data['status'] ?? 'Ongoing').toString();
    final isFinished = rawStatus.toLowerCase().startsWith('finish') ||
        rawStatus.toLowerCase().startsWith('tamat');
    final imageUrl = (data['imageUrl'] ?? '').toString();
    final isTrending = data['isTrending'] == true;
    final episodeCount = (data['episodeCount'] ?? data['episodes'] ?? '?').toString();
    final hasLink = _hasLink;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 68,
                  height: 92,
                  color: AppTheme.surfaceElevated,
                  child: ProxiedNetworkImage.forUrl(
                    url: imageUrl,
                    width: 68,
                    height: 92,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(10),
                    fallback: const Center(
                      child: Icon(
                        Icons.image_rounded,
                        color: AppTheme.textSecondary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MiniBadge(icon: '⭐', text: rating, color: AppTheme.accent),
                        _MiniBadge(
                          icon: isFinished ? '🏁' : '🟢',
                          text: isFinished ? 'Tamat' : 'Ongoing',
                          color: isFinished ? AppTheme.textSecondary : const Color(0xFF7B9E87),
                        ),
                        _MiniBadge(icon: '📺', text: '$episodeCount eps', color: AppTheme.textSecondary),
                        if (isTrending) _MiniBadge(icon: '🔥', text: 'Trending', color: AppTheme.highlight),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          hasLink ? Icons.check_circle_rounded : Icons.warning_rounded,
                          size: 12,
                          color: hasLink ? const Color(0xFF7B9E87) : Colors.orangeAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasLink ? 'Link tersedia' : 'Belum ada link',
                          style: TextStyle(
                            color: hasLink ? const Color(0xFF7B9E87) : Colors.orangeAccent,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded, color: AppTheme.accent, size: 20),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tiny inline badge used in the anime card ────────────────────────────────
class _MiniBadge extends StatelessWidget {
  final String icon;
  final String text;
  final Color color;

  const _MiniBadge({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 9.5)),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ── Section header used inside the Add/Edit form ───────────────────────────
class _SectionHeader extends StatelessWidget {
  final String icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 14.5,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: AppTheme.textSecondary.withValues(alpha: 0.15)),
        ),
      ],
    );
  }
}

// ── Add/Edit form ──────────────────────────────────────────────────────────
class _AnimeFormScreen extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? data;
  const _AnimeFormScreen({this.docId, this.data});

  @override
  State<_AnimeFormScreen> createState() => _AnimeFormScreenState();
}

class _AnimeFormScreenState extends State<_AnimeFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _title;
  late TextEditingController _imageUrl;
  late TextEditingController _rating;
  late TextEditingController _genres;
  late TextEditingController _description;
  late TextEditingController _malId;
  late TextEditingController _trailerUrl;
  late TextEditingController _releaseDay;
  late TextEditingController _episodeCount;

  // ── Episode link data ─────────────────────────────────────────────────
  // Struktur PERSIS sama dengan Admin CMS lama (app.js):
  // { "1": {"1080p": "url", "720p": "url", "480p": "url", "360p": "url"}, "2": {...} }
  // Disimpan sebagai JSON string di field Firestore `catalogEpisodeLink`.
  // JANGAN diubah jadi single text field — akan menghapus link yang sudah diisi.
  static const _qualities = ['1080p', '720p', '480p', '360p'];
  final Map<String, Map<String, String>> _episodeLinks = {};
  int _expandedEpisode = 1;

  String _status = 'Ongoing';
  bool _isTrending = false;
  final Set<String> _placement = {};
  bool _saving = false;

  static const _placementOptions = [
    'explore',
    'jadwal',
    'home_new',
    'home_trending',
    'home_featured',
  ];

  bool get _isEdit => widget.docId != null;

  @override
  void initState() {
    super.initState();
    final d = widget.data ?? {};
    _title = TextEditingController(text: d['title'] ?? '');
    _imageUrl = TextEditingController(text: d['imageUrl'] ?? '');
    _rating = TextEditingController(text: (d['rating'] ?? '').toString());
    _genres = TextEditingController(
      text: (d['genres'] is List) ? (d['genres'] as List).join(', ') : '',
    );
    _description = TextEditingController(text: d['description'] ?? '');
    _malId = TextEditingController(text: (d['malId'] ?? '').toString());
    _trailerUrl = TextEditingController(text: d['trailerUrl'] ?? '');
    _releaseDay = TextEditingController(text: (d['releaseDay'] ?? '').toString());
    final epCount = d['episodeCount'] ?? d['episodes'];
    _episodeCount = TextEditingController(
      text: (epCount is int || epCount is num) ? epCount.toString() : '12',
    );
    _episodeCount.addListener(() => setState(() {}));

    // Parse existing catalogEpisodeLink JSON string — kompatibel dengan
    // data yang sudah diisi lewat Admin CMS lama (index.html/app.js).
    final rawLinks = d['catalogEpisodeLink'];
    if (rawLinks is String && rawLinks.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(rawLinks) as Map<String, dynamic>;
        parsed.forEach((epNum, qualities) {
          if (qualities is Map) {
            _episodeLinks[epNum] = {
              for (final q in _qualities) q: (qualities[q] ?? '').toString(),
            };
          }
        });
      } catch (_) {
        // JSON rusak/kosong — mulai dari map kosong, tidak menimpa apa pun
        // sampai user benar-benar simpan.
      }
    }

    final rawStatus = (d['status'] ?? 'Ongoing').toString().trim().toLowerCase();
    if (rawStatus.startsWith('finish') || rawStatus.startsWith('tamat')) {
      _status = 'Finished Airing';
    } else {
      _status = 'Ongoing';
    }
    _isTrending = d['isTrending'] == true;
    if (d['placement'] is List) {
      _placement.addAll((d['placement'] as List).map((e) => e.toString()));
    }
  }

  Map<String, String> _linksFor(String epNum) {
    return _episodeLinks.putIfAbsent(
      epNum,
      () => {for (final q in _qualities) q: ''},
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _imageUrl.dispose();
    _rating.dispose();
    _genres.dispose();
    _description.dispose();
    _malId.dispose();
    _trailerUrl.dispose();
    _releaseDay.dispose();
    _episodeCount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final genresList = _genres.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final epCount = int.tryParse(_episodeCount.text.trim()) ?? 12;

    // Hanya sertakan episode yang punya minimal satu link kualitas terisi,
    // persis perilaku CMS lama (JSON.stringify(currentEpisodeQualitiesMap)).
    final episodeLinksClean = <String, Map<String, String>>{};
    _episodeLinks.forEach((epNum, qualities) {
      final hasAny = qualities.values.any((v) => v.trim().isNotEmpty);
      if (hasAny) episodeLinksClean[epNum] = qualities;
    });

    final payload = <String, dynamic>{
      'title': _title.text.trim(),
      'imageUrl': _imageUrl.text.trim(),
      'rating': double.tryParse(_rating.text.trim()) ?? 0.0,
      'genres': genresList,
      'description': _description.text.trim(),
      'isTrending': _isTrending,
      'status': _status,
      'placement': _placement.toList(),
      'episodes': epCount,
      'episodeCount': epCount,
      'catalogEpisodeLink': jsonEncode(episodeLinksClean),
      if (_malId.text.trim().isNotEmpty)
        'malId': int.tryParse(_malId.text.trim()),
      if (_trailerUrl.text.trim().isNotEmpty)
        'trailerUrl': _trailerUrl.text.trim(),
      if (_releaseDay.text.trim().isNotEmpty)
        'releaseDay': int.tryParse(_releaseDay.text.trim()),
    };

    try {
      if (_isEdit) {
        await FirebaseFirestore.instance
            .collection('anime')
            .doc(widget.docId)
            .update(payload);
      } else {
        payload['addedAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('anime').add(payload);
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Perubahan disimpan.' : 'Anime ditambahkan.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal simpan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: Text(
          _isEdit ? 'Edit Anime' : 'Tambah Anime',
          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            _SectionHeader(icon: '📝', title: 'Info Dasar'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _title,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: _dec('Judul *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _genres,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: _dec('Genre (pisah koma)', hint: 'Action, Fantasy, Adventure'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              style: const TextStyle(color: AppTheme.textPrimary),
              maxLines: 4,
              decoration: _dec('Deskripsi'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _rating,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec('Rating', hint: '0-10'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _malId,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    keyboardType: TextInputType.number,
                    decoration: _dec('MAL ID (opsional)'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            _SectionHeader(icon: '🖼️', title: 'Poster & Trailer'),
            const SizedBox(height: 10),
            // ── Live cover preview — berubah tiap URL poster diketik ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 84,
                    height: 118,
                    color: AppTheme.surfaceElevated,
                    child: AnimatedBuilder(
                      animation: _imageUrl,
                      builder: (context, _) {
                        final url = _imageUrl.text.trim();
                        return ProxiedNetworkImage.forUrl(
                          url: url,
                          width: 84,
                          height: 118,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(12),
                          fallback: const Center(
                            child: Icon(
                              Icons.image_outlined,
                              color: AppTheme.textSecondary,
                              size: 26,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _imageUrl,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: _dec('URL Gambar (cover)', hint: 'https://...'),
                      ),
                      const SizedBox(height: 4),
                      AnimatedBuilder(
                        animation: _imageUrl,
                        builder: (context, _) {
                          final url = _imageUrl.text.trim();
                          if (url.isEmpty) {
                            return Text(
                              'Preview otomatis muncul di kiri saat link valid.',
                              style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7), fontSize: 10.5),
                            );
                          }
                          // Validasi ringan supaya user langsung lihat KENAPA
                          // gagal, tanpa perlu buka console F12.
                          final looksValid = url.startsWith('http://') || url.startsWith('https://');
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                looksValid ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                                size: 12,
                                color: looksValid ? const Color(0xFF7B9E87) : Colors.orangeAccent,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  looksValid
                                      ? 'Format URL OK (${url.length} karakter). Kalau tetap tidak muncul, cek console F12.'
                                      : 'URL harus diawali http:// atau https:// — cek apakah ada bagian yang kepotong.',
                                  style: TextStyle(
                                    color: looksValid
                                        ? AppTheme.textSecondary.withValues(alpha: 0.7)
                                        : Colors.orangeAccent,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _trailerUrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: _dec('URL Trailer YouTube (opsional)'),
            ),

            const SizedBox(height: 24),
            _SectionHeader(icon: '📡', title: 'Status & Jadwal'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _status,
                    dropdownColor: AppTheme.surface,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: _dec('Status'),
                    items: const [
                      DropdownMenuItem(value: 'Ongoing', child: Text('🟢 On-Going')),
                      DropdownMenuItem(value: 'Finished Airing', child: Text('🏁 Tamat')),
                    ],
                    onChanged: (v) => setState(() => _status = v ?? 'Ongoing'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _releaseDay,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    keyboardType: TextInputType.number,
                    decoration: _dec('Hari rilis', hint: '1=Sen...7=Min'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _isTrending,
              onChanged: (v) => setState(() => _isTrending = v),
              title: const Text('🔥 Trending', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
              activeColor: AppTheme.accent,
              tileColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),

            const SizedBox(height: 24),
            _SectionHeader(icon: '🎞️', title: 'Episode & Link Video'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _episodeCount,
              style: const TextStyle(color: AppTheme.textPrimary),
              keyboardType: TextInputType.number,
              decoration: _dec('Jumlah Episode'),
            ),
            const SizedBox(height: 12),
            Text(
              '✅ = semua kualitas terisi · ⚠️ = sebagian · kosong = belum diisi',
              style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.8), fontSize: 11.5),
            ),
            const SizedBox(height: 8),
            _EpisodeLinksEditor(
              episodeCountText: _episodeCount,
              episodeLinks: _episodeLinks,
              qualities: _qualities,
              expanded: _expandedEpisode,
              onExpandChanged: (ep) => setState(() => _expandedEpisode = ep),
              onFieldChanged: () => setState(() {}),
            ),

            const SizedBox(height: 24),
            _SectionHeader(icon: '📍', title: 'Penempatan Layar'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _placementOptions.map((opt) {
                final selected = _placement.contains(opt);
                return FilterChip(
                  label: Text(opt),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    v ? _placement.add(opt) : _placement.remove(opt);
                  }),
                  selectedColor: AppTheme.accent.withValues(alpha: 0.3),
                  backgroundColor: AppTheme.surface,
                  labelStyle: TextStyle(
                    color: selected ? AppTheme.accent : AppTheme.textSecondary,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  elevation: 4,
                  shadowColor: AppTheme.accent.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: AppTheme.background,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        _isEdit ? '💾 Simpan Perubahan' : '✨ Tambah Anime',
                        style: const TextStyle(
                          color: AppTheme.background,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Episode link editor ─────────────────────────────────────────────────────
// Replika UI CMS lama: expandable per-episode card, 4 kolom kualitas
// (1080p/720p/480p/360p). Data dibaca/ditulis langsung ke map yang dimiliki
// _AnimeFormScreenState — tidak pakai controller sendiri per episode supaya
// tidak boros memory kalau jumlah episode besar (puluhan).
class _EpisodeLinksEditor extends StatefulWidget {
  final TextEditingController episodeCountText;
  final Map<String, Map<String, String>> episodeLinks;
  final List<String> qualities;
  final int expanded;
  final ValueChanged<int> onExpandChanged;
  final VoidCallback onFieldChanged;

  const _EpisodeLinksEditor({
    required this.episodeCountText,
    required this.episodeLinks,
    required this.qualities,
    required this.expanded,
    required this.onExpandChanged,
    required this.onFieldChanged,
  });

  @override
  State<_EpisodeLinksEditor> createState() => _EpisodeLinksEditorState();
}

class _EpisodeLinksEditorState extends State<_EpisodeLinksEditor> {
  // Hanya episode yang sedang dibuka yang punya controller — supaya anime
  // dengan ribuan episode tidak membuat ribuan TextEditingController sekaligus.
  final Map<String, Map<String, TextEditingController>> _controllers = {};
  // Input kecil untuk loncat langsung ke nomor episode tertentu.
  final _miniJumpCtrl = TextEditingController();

  Map<String, TextEditingController> _ctrlsFor(String epNum) {
    return _controllers.putIfAbsent(epNum, () {
      final existing = widget.episodeLinks[epNum] ?? {};
      return {
        for (final q in widget.qualities)
          q: TextEditingController(text: existing[q] ?? ''),
      };
    });
  }

  void _disposeCtrlsExcept(String? keepEpNum) {
    final toRemove = _controllers.keys.where((k) => k != keepEpNum).toList();
    for (final k in toRemove) {
      for (final c in _controllers[k]!.values) {
        c.dispose();
      }
      _controllers.remove(k);
    }
  }

  @override
  void dispose() {
    for (final map in _controllers.values) {
      for (final c in map.values) {
        c.dispose();
      }
    }
    _miniJumpCtrl.dispose();
    super.dispose();
  }

  String _status(String epNum) {
    final data = widget.episodeLinks[epNum];
    if (data == null) return '';
    final filled = widget.qualities.where((q) => (data[q] ?? '').trim().isNotEmpty).length;
    if (filled == 0) return '';
    if (filled == widget.qualities.length) return '✅';
    return '⚠️';
  }

  void _openEpisode(int epNum) {
    // Tutup episode lama dulu (buang controllernya) sebelum buka yang baru,
    // jadi memory tetap flat walau totalnya ribuan.
    final isSame = widget.expanded == epNum;
    _disposeCtrlsExcept(isSame ? null : epNum.toString());
    widget.onExpandChanged(isSame ? 0 : epNum);
  }

  void _miniJump(int total) {
    final n = int.tryParse(_miniJumpCtrl.text.trim());
    _miniJumpCtrl.clear();
    if (n == null || n < 1 || n > total) return;
    FocusScope.of(context).unfocus();
    _disposeCtrlsExcept(n.toString());
    widget.onExpandChanged(n);
  }

  @override
  Widget build(BuildContext context) {
    final total = int.tryParse(widget.episodeCountText.text.trim()) ?? 0;
    if (total <= 0) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Isi jumlah episode dulu di atas untuk mulai isi link.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
        ),
      );
    }

    final filledCount = List.generate(total, (i) => (i + 1).toString())
        .where((ep) => _status(ep).isNotEmpty)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Ringkasan status: aman/lengkap semua atau masih ada yang kurang ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: filledCount == total
                ? const Color(0xFF7B9E87).withValues(alpha: 0.14)
                : Colors.orangeAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: filledCount == total
                  ? const Color(0xFF7B9E87).withValues(alpha: 0.4)
                  : Colors.orangeAccent.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                filledCount == total ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                size: 15,
                color: filledCount == total ? const Color(0xFF7B9E87) : Colors.orangeAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  filledCount == total
                      ? 'Semua $total episode sudah lengkap link-nya. ✅'
                      : '$filledCount / $total episode sudah ada link — ${total - filledCount} lagi belum diisi.',
                  style: TextStyle(
                    color: filledCount == total ? const Color(0xFF7B9E87) : Colors.orangeAccent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // ── Detail panel episode (navigasi via tombol ‹ › di dalam panel) ──
        // Grid nomor episode dihapus — buka lewat panel ini langsung,
        // default ke episode 1 kalau belum ada yang dibuka.
        Builder(builder: (context) {
          final effectiveExpanded = (widget.expanded > 0 && widget.expanded <= total) ? widget.expanded : 1;
          if (effectiveExpanded != widget.expanded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onExpandChanged(effectiveExpanded);
            });
          }
          {
            final epNum = effectiveExpanded.toString();
            final ctrls = _ctrlsFor(epNum);
            final hasPrev = effectiveExpanded > 1;
            final hasNext = effectiveExpanded < total;
            final epStatus = _status(epNum);
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: hasPrev ? () => _openEpisode(effectiveExpanded - 1) : null,
                        icon: Icon(
                          Icons.chevron_left_rounded,
                          color: hasPrev ? AppTheme.textPrimary : AppTheme.textSecondary.withValues(alpha: 0.25),
                        ),
                        tooltip: 'Episode sebelumnya',
                      ),
                      Text(
                        'Episode $epNum',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: hasNext ? () => _openEpisode(effectiveExpanded + 1) : null,
                        icon: Icon(
                          Icons.chevron_right_rounded,
                          color: hasNext ? AppTheme.textPrimary : AppTheme.textSecondary.withValues(alpha: 0.25),
                        ),
                        tooltip: 'Episode berikutnya',
                      ),
                      const Spacer(),
                      // ── Loncat kecil ke episode # tertentu ──
                      SizedBox(
                        width: 56,
                        height: 30,
                        child: TextField(
                          controller: _miniJumpCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                          onSubmitted: (_) => _miniJump(total),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: '#',
                            hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                            filled: true,
                            fillColor: AppTheme.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // ── Indikator kelengkapan link untuk episode ini ──
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: epStatus == '✅'
                              ? const Color(0xFF7B9E87).withValues(alpha: 0.18)
                              : epStatus == '⚠️'
                                  ? Colors.orangeAccent.withValues(alpha: 0.16)
                                  : AppTheme.textSecondary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          epStatus == '✅'
                              ? 'Lengkap ✅'
                              : epStatus == '⚠️'
                                  ? 'Sebagian ⚠️'
                                  : 'Belum diisi',
                          style: TextStyle(
                            color: epStatus == '✅'
                                ? const Color(0xFF7B9E87)
                                : epStatus == '⚠️'
                                    ? Colors.orangeAccent
                                    : AppTheme.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // ── Aksi cepat: copy dari episode sebelumnya + kosongkan ──
                  // Sangat membantu untuk anime ratusan episode karena link
                  // video biasanya cuma beda nomor episode di URL-nya.
                  if (hasPrev || _hasAnyFilled(epNum))
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (hasPrev)
                            _QuickActionChip(
                              icon: Icons.content_copy_rounded,
                              label: 'Salin dari Ep ${effectiveExpanded - 1}',
                              onTap: () => _copyFromPrevious(epNum, ctrls),
                            ),
                          if (_hasAnyFilled(epNum))
                            _QuickActionChip(
                              icon: Icons.delete_sweep_rounded,
                              label: 'Kosongkan',
                              color: Colors.redAccent,
                              onTap: () => _clearEpisode(epNum, ctrls),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  ...widget.qualities.map((q) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: ctrls[q],
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12.5),
                        onChanged: (v) {
                          widget.episodeLinks[epNum] = {
                            for (final qq in widget.qualities) qq: ctrls[qq]!.text,
                          };
                          widget.onFieldChanged();
                          setState(() {}); // refresh grid + tombol aksi cepat
                        },
                        decoration: InputDecoration(
                          labelText: q,
                          labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 11.5),
                          hintText: 'https://...',
                          hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                          isDense: true,
                          filled: true,
                          fillColor: AppTheme.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }
        }),
      ],
    );
  }

  bool _hasAnyFilled(String epNum) {
    final data = widget.episodeLinks[epNum];
    if (data == null) return false;
    return data.values.any((v) => v.trim().isNotEmpty);
  }

  // Menyalin semua link kualitas dari episode sebelumnya, lalu mencoba ganti
  // penanda nomor episode di URL secara otomatis (mis. "/86/ep12/..." jadi
  // "/86/ep13/..."). Kalau polanya tidak ketemu, tetap salin URL apa adanya
  // supaya user tinggal edit sedikit manual daripada ketik ulang semua.
  void _copyFromPrevious(String epNum, Map<String, TextEditingController> ctrls) {
    final prevKey = (int.parse(epNum) - 1).toString();
    final prevData = widget.episodeLinks[prevKey];
    if (prevData == null) return;

    for (final q in widget.qualities) {
      final prevUrl = (prevData[q] ?? '').trim();
      if (prevUrl.isEmpty) continue;
      final guessed = _bumpEpisodeNumberInUrl(prevUrl, int.parse(prevKey), int.parse(epNum));
      ctrls[q]!.text = guessed;
    }
    widget.episodeLinks[epNum] = {
      for (final q in widget.qualities) q: ctrls[q]!.text,
    };
    widget.onFieldChanged();
    setState(() {});
  }

  void _clearEpisode(String epNum, Map<String, TextEditingController> ctrls) {
    for (final q in widget.qualities) {
      ctrls[q]!.text = '';
    }
    widget.episodeLinks.remove(epNum);
    widget.onFieldChanged();
    setState(() {});
  }

  // Coba cari angka episode lama sebagai token terpisah di dalam URL (dibatasi
  // '/', '-', '_', atau awal/akhir string) dan ganti dengan nomor episode baru.
  // Kalau tidak ketemu polanya, URL dikembalikan apa adanya (tidak dipaksa).
  String _bumpEpisodeNumberInUrl(String url, int oldEp, int newEp) {
    final pattern = RegExp(r'(?<=[/_\-])' + oldEp.toString() + r'(?=[/_\-.]|$)');
    if (!pattern.hasMatch(url)) return url;
    return url.replaceFirst(pattern, newEp.toString());
  }
}

// ── Chip aksi cepat kecil (Salin / Kosongkan) di panel detail episode ──────
class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.withValues(alpha: 0.35), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ── PIN verification dialog + tap-counter trigger ──────────────────────────
// Call `AdminAccess.registerTap(context)` from the logo's onTap. After 7 taps
// within a short window it shows the PIN dialog; correct PIN opens the panel.
// PIN is stored in SharedPreferences so changing it from the Admin Panel
// persists across app restarts. Default PIN (first run only): 8888.
class AdminAccess {
  AdminAccess._();

  static const String _prefsKey = 'aniverse_admin_pin';
  static const String _defaultPin = '8888'; // PIN awal sebelum pernah diganti

  static int _tapCount = 0;
  static DateTime? _firstTapTime;
  static const _tapWindow = Duration(seconds: 3);

  static Future<String> _getPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey) ?? _defaultPin;
  }

  static Future<void> _setPin(String newPin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, newPin);
  }

  static void registerTap(BuildContext context) {
    final now = DateTime.now();
    if (_firstTapTime == null || now.difference(_firstTapTime!) > _tapWindow) {
      _firstTapTime = now;
      _tapCount = 1;
    } else {
      _tapCount++;
    }
    debugPrint('[AdminAccess] tap count: $_tapCount');

    if (_tapCount >= 7) {
      _tapCount = 0;
      _firstTapTime = null;
      HapticFeedback.mediumImpact();
      debugPrint('[AdminAccess] threshold reached, showing PIN dialog');
      _showPinDialog(context);
    }
  }

  static void _showPinDialog(BuildContext context) {
    final pinCtrl = TextEditingController();
    String? error;

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text(
            '🔒 Admin Access',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinCtrl,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textPrimary, letterSpacing: 4),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'Masukkan PIN',
                  hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final correctPin = await _getPin();
                if (pinCtrl.text == correctPin) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
                    );
                  }
                } else {
                  setState(() => error = 'PIN salah.');
                  HapticFeedback.heavyImpact();
                }
              },
              child: const Text('Masuk', style: TextStyle(color: AppTheme.accent)),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog ganti PIN — dipanggil dari tombol lock_reset di AppBar Admin
  /// Panel. Wajib masukkan PIN lama yang benar dulu sebelum bisa set PIN
  /// baru, supaya tidak sembarangan diganti orang lain yang kebetulan masuk.
  static void showChangePinDialog(BuildContext context) {
    final oldPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text(
            '🔑 Ganti PIN Admin',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldPinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'PIN lama',
                  hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: newPinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'PIN baru (min. 4 digit)',
                  hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmPinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Ulangi PIN baru',
                  hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final correctPin = await _getPin();
                if (oldPinCtrl.text != correctPin) {
                  setState(() => error = 'PIN lama salah.');
                  HapticFeedback.heavyImpact();
                  return;
                }
                if (newPinCtrl.text.trim().length < 4) {
                  setState(() => error = 'PIN baru minimal 4 digit.');
                  return;
                }
                if (newPinCtrl.text != confirmPinCtrl.text) {
                  setState(() => error = 'Konfirmasi PIN tidak cocok.');
                  return;
                }
                await _setPin(newPinCtrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN berhasil diganti.')),
                  );
                }
              },
              child: const Text('Simpan', style: TextStyle(color: AppTheme.accent)),
            ),
          ],
        ),
      ),
    );
  }


}
