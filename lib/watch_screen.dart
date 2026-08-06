import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'anime_model.dart';
import 'episode_model.dart';
import 'app_theme.dart';
import 'mock_data_service.dart';
import 'my_episode_links.dart';
import 'browser_fullscreen.dart';
import 'streaming_service.dart';
import 'widgets/liquid_glass.dart';
import 'trailer_links.dart';
import 'trailer_player.dart';
import 'anime_api_service.dart';
// Conditional import: web uses HTML5 video element, mobile uses stub
import 'video_element_stub.dart'
    if (dart.library.html) 'video_element_web.dart';

// ─── Theme tokens ─────────────────────────────────────────────────────────────
const _kPink = AppTheme.highlight;
const _kPurple = AppTheme.accent;
const _kBg = AppTheme.background;
const _kSurface = AppTheme.surface;
const _kInk = AppTheme.textPrimary;
const _kMuted = AppTheme.textSecondary;
final _kPinkGlow = AppTheme.highlight.withValues(alpha: 0.2);
final _kPinkSubtle = AppTheme.highlight.withValues(alpha: 0.1);
final _kPinkBorder = AppTheme.highlight.withValues(alpha: 0.33);
final _kWhite80 = AppTheme.textPrimary.withValues(alpha: 0.86);
final _kWhite60 = AppTheme.textPrimary.withValues(alpha: 0.66);
final _kWhite40 = AppTheme.textPrimary.withValues(alpha: 0.46);
final _kWhite10 = AppTheme.textPrimary.withValues(alpha: 0.09);
final _kWhite06 = AppTheme.textPrimary.withValues(alpha: 0.09);

/// Legacy hardcoded last-resort stream (Sub Indo HD). Only used when neither a
/// manual link, a catalog link, an auto-scraped stream, nor a YouTube trailer
/// can be resolved — so the player is never left empty.
const String _kFrierenFallbackUrl =
    'https://stor.halahgan.com/dl/storage/86/a97b2a070fc918b21efe6f892bd0ea49575f3978-svnAOy.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+01+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2001%20%281080p%29.mp4';

// ─── Entry point ─────────────────────────────────────────────────────────────
class WatchScreen extends StatefulWidget {
  final AnimeModel anime;
  final int initialEpisodeIndex;
  final double initialWatchProgress;

  const WatchScreen({
    super.key,
    required this.anime,
    this.initialEpisodeIndex = 0,
    this.initialWatchProgress = 0.0,
  });

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen>
    with TickerProviderStateMixin {
  late int _currentIndex;
  bool _isPlaying = false;
  bool _showControls = true;
  double _seekValue = 0.0;
  bool _showSkipIntro = true;
  bool _showSkipEnding = false;
  bool _showAutoNext = false;
  int _nextEpisodeCountdown = 5;
  bool _forceMockPlayer = false;

  // ── Kosmetik state ─────────────────────────────────────────────────────────
  int _equippedFrameIndex = 0;
  int _previewFrameIndex = 0;
  String _cosmeticFilter = 'Semua';
  final Set<int> _purchasedPremiumFrames = {};

  // ── Panel tab (Episode / Komunitas) ──────────────────────────────────────
  int _panelTab = 0; // 0=Episode 1=Komunitas
  bool _episodeGridMode = false; // false=list, true=grid
  final TextEditingController _commentCtrl = TextEditingController();
  final ScrollController _commentListCtrl = ScrollController();

  // Mock comment data per episode — key = episodeNumber
  // Di production ini akan diganti dengan Firestore/Supabase realtime
  final Map<int, List<_Comment>> _comments = {};

  // Mock users buat simulasi komentar dari user lain
  static const _mockUsers = [
    _MockUser('Kirito_01', 47, 'Cosmic Legend', '🌸', '0xFF7C3AED'),
    _MockUser('AikoWatcher', 23, 'Elite Watcher', '⚔️', '0xFFD4AF37'),
    _MockUser('Rei_senpai', 15, 'Otaku Sejati', '🎴', '0xFFC17E74'),
    _MockUser('HanaFan99', 8, 'Anime Lover', '🌙', '0xFF7B9E87'),
    _MockUser('SoloLv999', 50, 'Cosmic Legend', '👑', '0xFF7C3AED'),
  ];
  // Null = belum resolve / episode belum ada linknya (fallback ke mock player)
  String? _resolvedVideoUrl;
  String? _resolvedQuality;
  List<String> _availableQualities = [];
  // Popup pemilih kualitas inline (jalan di mode fullscreen juga,
  // gak pakai showModalBottomSheet yang ke-tutup layar fullscreen).
  bool _showQualityPopup = false;
  // Unique key per-episode buat iframe HtmlElementView
  String _iframeViewId = '';
  bool _iframeRegistered = false;

  // ── Fullscreen ────────────────────────────────────────────────────────────
  bool _isFullscreen = false;
  // ignore: cancel_subscriptions
  late final _fullscreenSub = browserFullscreenChanges.listen((v) {
    if (mounted) setState(() => _isFullscreen = v);
  });

  late AnimationController _controlsFade;
  late Animation<double> _controlsAnim;

  late AnimationController _pulse;
  late Animation<double> _pulseAnim;

  final ScrollController _episodeListController = ScrollController();
  Timer? _playbackTimer;
  Timer? _nextEpisodeTimer;
  static const int _episodeDurationSeconds = 22 * 60 + 10;
  static const double _introSkipFraction = 0.065;
  static const double _endingSkipStartFraction = 0.92;

  @override
  void initState() {
    super.initState();
    // Matikan trailer di detail screen (kalau masih nyangkut di bawah)
    // biar audio gak nembus ke video episode.
    trailerAllowedNotifier.value = false;
    debugPrint(
      '[WatchScreen] init anime.id="${widget.anime.id}" anime.title="${widget.anime.title}" '
      'episodesCount=${widget.anime.episodes.length} '
      'initialEpisodeIndex=${widget.initialEpisodeIndex} initialProgress=${widget.initialWatchProgress}',
    );

    // ── BUG FIX #2: guard episodes kosong ────────────────────────────────────
    // Seharusnya dicegah di HomeScreen, tapi failsafe di sini untuk cegah
    // RangeError (index): Index out of range: no indices are valid: 0
    if (widget.anime.episodes.isEmpty) {
      debugPrint('[WatchScreen] ERROR: episodes kosong untuk anime="${widget.anime.id}" — abort init');
      _currentIndex = 0;
      _seekValue = 0.0;
    } else {
      // Clamp index agar tidak pernah out-of-range
      _currentIndex = widget.initialEpisodeIndex
          .clamp(0, widget.anime.episodes.length - 1);
      _seekValue = widget.initialWatchProgress.clamp(0.0, 1.0);

      // Jika progress >= 90% dan masih ada episode berikutnya, advance index.
      // ── BUG FIX #1: JANGAN panggil _syncContinueWatching di sini ──────────
      // Memanggil sync di sini akan menimpa CW record lama dengan seekValue=0.0
      // (setelah di-reset), menyebabkan progress hilang setiap kali resume.
      // CW hanya di-sync saat: play/pause (_togglePlay), timer tick, atau close (dispose).
      if (_seekValue >= 0.9) {
        if (_currentIndex < widget.anime.episodes.length - 1) {
          debugPrint(
            '[WatchScreen] progress=$_seekValue >= 0.9, advance episode '
            '$_currentIndex → ${_currentIndex + 1} (tidak sync CW dulu)',
          );
          _currentIndex = _currentIndex + 1;
          _seekValue = 0.0;
        } else {
          _seekValue = 1.0;
        }
      }
    }

    _controlsFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1.0,
    );
    _controlsAnim =
        CurvedAnimation(parent: _controlsFade, curve: Curves.easeInOut);

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );

    // Hanya mark episode jika episodes tidak kosong
    if (widget.anime.episodes.isNotEmpty) {
      MockDataService.markEpisodeWatched(
        animeId: widget.anime.id,
        episodeNumber: _currentEpisode.number,
      );
      debugPrint(
        '[WatchScreen] ready — currentIndex=$_currentIndex '
        'seekValue=$_seekValue episode=${_currentEpisode.number}',
      );
    }

    // ── BUG FIX #1: _syncContinueWatching DIHAPUS dari initState ─────────────
    // Alasan: initState dipanggil sebelum user mulai nonton. Jika dipanggil
    // di sini, akan meng-overwrite CW record (episodeNumber + progress) dengan
    // nilai saat ini yang mungkin sudah di-advance atau di-reset ke 0.0.
    // Sync pertama akan terjadi saat user menekan play.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updatePlaybackUiFlags();
      _resolveVideoForCurrentEpisode();
      _seedMockComments();
      if (_resolvedVideoUrl == null || _forceMockPlayer) {
        _isPlaying = true;
        _startPlaybackTimer();
      }
    });
  }

  @override
  void dispose() {
    // Balikin flag trailer biar detail screen (kalau masih di stack) bisa
    // lanjut muter trailer lagi setelah WatchScreen ditutup.
    trailerAllowedNotifier.value = true;
    // CW V2: simpan progress terakhir saat user menutup WatchScreen
    _syncContinueWatching();
    _fullscreenSub.cancel();
    _commentCtrl.dispose();
    _commentListCtrl.dispose();
    _playbackTimer?.cancel();
    _nextEpisodeTimer?.cancel();
    _controlsFade.dispose();
    _pulse.dispose();
    _episodeListController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ── BUG FIX #2: guard episodes kosong + auto-clamp ──────────────────────────
  // Sebelumnya: episodes[_currentIndex] → RangeError jika episodes kosong
  // atau _currentIndex out-of-range setelah advance-episode logic di initState.
  EpisodeModel get _currentEpisode {
    if (widget.anime.episodes.isEmpty) {
      debugPrint('[WatchScreen] FATAL: _currentEpisode dipanggil saat episodes kosong!');
      return EpisodeModel(
        number: 1,
        title: 'Episode 1',
        duration: '0m',
        thumbnailUrl: widget.anime.imageUrl,
      );
    }
    if (_currentIndex < 0 || _currentIndex >= widget.anime.episodes.length) {
      debugPrint(
        '[WatchScreen] WARNING: _currentIndex=$_currentIndex out of range '
        '(episodes.length=${widget.anime.episodes.length}), auto-clamp',
      );
      _currentIndex = _currentIndex.clamp(0, widget.anime.episodes.length - 1);
    }
    return widget.anime.episodes[_currentIndex];
  }
  bool get _hasPrev => _currentIndex > 0;
  bool get _hasNext => _currentIndex < widget.anime.episodes.length - 1;


  void _updatePlaybackUiFlags() {
    final shouldShowIntro = _seekValue < _introSkipFraction;
    final shouldShowEnding = _seekValue >= _endingSkipStartFraction && _seekValue < 1.0;

    if (_showSkipIntro != shouldShowIntro ||
        _showSkipEnding != shouldShowEnding) {
      setState(() {
        _showSkipIntro = shouldShowIntro;
        _showSkipEnding = shouldShowEnding;
      });
    }

    if (_seekValue >= 1.0) {
      _startAutoNextCountdownIfNeeded();
    } else {
      _cancelAutoNextCountdown();
    }
  }

  void _skipIntro() {
    setState(() {
      _seekValue = _introSkipFraction.clamp(0.0, 1.0);
      _showSkipIntro = false;
    });
    _maybeMarkEpisodeWatched('skip_intro');
    _syncContinueWatching();
    _updatePlaybackUiFlags();
  }

  void _skipEnding() {
    setState(() {
      _seekValue = 1.0;
      _showSkipEnding = false;
      _isPlaying = false;
    });
    _playbackTimer?.cancel();
    _maybeMarkEpisodeWatched('skip_ending');
    _syncContinueWatching();
    _updatePlaybackUiFlags();
  }

  void _cancelAutoNextCountdown() {
    _nextEpisodeTimer?.cancel();
    if (_showAutoNext || _nextEpisodeCountdown != 5) {
      setState(() {
        _showAutoNext = false;
        _nextEpisodeCountdown = 5;
      });
    }
  }

  void _startAutoNextCountdownIfNeeded() {
    if (!_hasNext) return;
    if (_showAutoNext && _nextEpisodeTimer != null) return;

    _nextEpisodeTimer?.cancel();
    setState(() {
      _showAutoNext = true;
      _nextEpisodeCountdown = 5;
    });

    _nextEpisodeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_nextEpisodeCountdown <= 1) {
        timer.cancel();
        setState(() {
          _showAutoNext = false;
          _nextEpisodeCountdown = 5;
        });
        _goToEpisode(_currentIndex + 1, autoPlay: true);
        return;
      }
      setState(() => _nextEpisodeCountdown -= 1);
    });
  }

  void _goToEpisode(int index, {bool autoPlay = false}) {
    if (index < 0 || index >= widget.anime.episodes.length) return;
    _nextEpisodeTimer?.cancel();
    debugPrint(
      '[WatchScreen] goToEpisode anime.id="${widget.anime.id}" anime.title="${widget.anime.title}" '
      'episode=${widget.anime.episodes[index].number} autoPlay=$autoPlay',
    );
    setState(() {
      _currentIndex = index;
      _isPlaying = autoPlay;
      _seekValue = 0.0;
      _showControls = true;
      _showSkipIntro = true;
      _showSkipEnding = false;
      _showAutoNext = false;
      _nextEpisodeCountdown = 5;
      _controlsFade.value = 1.0;
    });
    _playbackTimer?.cancel();
    MockDataService.markEpisodeWatched(
      animeId: widget.anime.id,
      episodeNumber: widget.anime.episodes[index].number,
    );
    _syncContinueWatching();
    _resolveVideoForCurrentEpisode();
    if (autoPlay) {
      _startPlaybackTimer();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_episodeListController.hasClients) return;
      final offset = (index * 84.0)
          .clamp(0.0, _episodeListController.position.maxScrollExtent);
      _episodeListController.animateTo(
        offset,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOut,
      );
    });
  }

  void _togglePlay() {
    debugPrint(
      '[WatchScreen] play button pressed anime.id="${widget.anime.id}" '
      'episode=${_currentEpisode.number} wasPlaying=$_isPlaying',
    );
    setState(() => _isPlaying = !_isPlaying);
    if (_isPlaying) {
      _cancelAutoNextCountdown();
      _startPlaybackTimer();
    } else {
      _playbackTimer?.cancel();
      // CW V2: simpan progress saat pause
      _syncContinueWatching();
      debugPrint('[WatchScreen] timer stopped');
    }
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    debugPrint(
      '[WatchScreen] timer started anime.id="${widget.anime.id}" episode=${_currentEpisode.number}',
    );
    _playbackTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      // CW V2: update setiap 3 detik (bukan tiap 1 detik) untuk mengurangi
      // write ke SharedPreferences, tapi tetap cukup sering untuk terasa real-time.
      if (!mounted || !_isPlaying) return;
      final next = (_seekValue + (3 / _episodeDurationSeconds)).clamp(0.0, 1.0);
      setState(() => _seekValue = next);
      _updatePlaybackUiFlags();
      _syncContinueWatching();
      _maybeMarkEpisodeWatched('timer_tick');
      if (_seekValue >= 1.0) {
        setState(() => _isPlaying = false);
        _playbackTimer?.cancel();
        debugPrint('[WatchScreen] timer completed episode end');
      }
    });
  }

  void _maybeMarkEpisodeWatched(String source) {
    if (_seekValue >= 0.9) {
      debugPrint(
        '[WatchScreen] markEpisodeWatched trigger source=$source anime.id="${widget.anime.id}" '
        'episode=${_currentEpisode.number} watchProgress=${_seekValue.toStringAsFixed(4)}',
      );
      MockDataService.markEpisodeWatched(
        animeId: widget.anime.id,
        episodeNumber: _currentEpisode.number,
      );
    }
  }

  /// CW V2: _syncContinueWatching sekarang juga mengirim animeTitle + thumbnailUrl.
  /// Card di HomeScreen tidak perlu lagi lookup AnimeModel — data sudah self-contained.
  void _syncContinueWatching() {
    MockDataService.updateContinueWatching(
      animeId: widget.anime.id,
      animeTitle: widget.anime.title,
      thumbnailUrl: widget.anime.imageUrl,
      episodeNumber: _currentEpisode.number,
      watchProgress: _seekValue,
    );
  }

  // ── Mock comment seed ────────────────────────────────────────────────────
  void _seedMockComments() {
    if (widget.anime.episodes.isEmpty) return;
    final mockData = {
      1: [
        _Comment(_mockUsers[4], 'Episode pertama langsung kena banget! 🔥', DateTime.now().subtract(const Duration(hours: 3))),
        _Comment(_mockUsers[1], 'Opening-nya epic abis, soundtrack-nya chef kiss 🎵', DateTime.now().subtract(const Duration(hours: 2))),
        _Comment(_mockUsers[2], 'Scene pertarungan di menit ke-18 itu luar biasa animasinya!', DateTime.now().subtract(const Duration(hours: 1))),
        _Comment(_mockUsers[3], 'Baru mulai nonton, udah ketagihan 😭', DateTime.now().subtract(const Duration(minutes: 30))),
      ],
      2: [
        _Comment(_mockUsers[0], 'Plot twist di akhir episode ini gila parah!!', DateTime.now().subtract(const Duration(hours: 5))),
        _Comment(_mockUsers[2], 'Character development-nya bagus banget', DateTime.now().subtract(const Duration(hours: 4))),
      ],
    };
    setState(() {
      for (final ep in widget.anime.episodes) {
        _comments[ep.number] = mockData[ep.number] ?? [];
      }
    });
  }

  void _submitComment() {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final epNumber = widget.anime.episodes.isEmpty ? 0 : _currentEpisode.number;
    final comment = _Comment(
      const _MockUser('Kamu', 12, 'Otaku Sejati', '🎮', '0xFF7B9E87'),
      text,
      DateTime.now(),
      isOwn: true,
    );
    setState(() {
      _comments.putIfAbsent(epNumber, () => []).add(comment);
      _commentCtrl.clear();
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_commentListCtrl.hasClients) {
        _commentListCtrl.animateTo(
          _commentListCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Video URL resolver ────────────────────────────────────────────────────
  void _resolveVideoForCurrentEpisode() {
    if (widget.anime.episodes.isEmpty) return;
    final ep = _currentEpisode;
    final link = resolveMyEpisodeLink(widget.anime.title, ep.number);

    if (link != null) {
      // ── Mode baru: pageUrl → Worker resolve halaman jadi stream ──
      if (link.qualities.isEmpty && link.pageUrl != null && link.pageUrl!.isNotEmpty) {
        setState(() {
          _resolvedVideoUrl = null;
          _resolvedQuality = 'Searching...';
          _availableQualities = [];
          _iframeViewId = '';
        });
        debugPrint('[WatchScreen] resolving pageUrl via Worker: ${link.pageUrl}');
        StreamingService().resolveFromPage(link.pageUrl!).then((res) {
          if (!mounted) return;
          if (res.streamUrl != null && res.streamUrl!.isNotEmpty) {
            final newViewId = 'video_iframe_${widget.anime.id}_ep${ep.number}_page_' + DateTime.now().millisecondsSinceEpoch.toString();
            final qualities = res.qualities != null ? res.qualities!.keys.toList() : ['Auto'];
            setState(() {
              _resolvedVideoUrl = res.streamUrl;
              _resolvedQuality = qualities.first;
              _availableQualities = qualities;
              _iframeViewId = newViewId;
              _iframeRegistered = false;
            });
            debugPrint('[WatchScreen] pageUrl resolve SUCCESS: ${res.streamUrl}');
          } else {
            debugPrint('[WatchScreen] pageUrl resolve empty: ${res.error}');
            _applyTrailerFallback();
          }
        }).catchError((e) {
          if (!mounted) return;
          debugPrint('[WatchScreen] pageUrl resolve error: $e');
          _applyTrailerFallback();
        });
        return;
      }

      final quality = bestQualityFor(link);
      final url = StreamingService.wrapProxyUrl(link.qualities[quality]!);
      // NAMA kualitas (1080p/720p/...), BUKAN URL — dipakai buat nampilin
      // & match di popup pemilih kualitas. URL di-wrap pas dipilih.
      final qualities = sortedQualitiesFor(link);
      final newViewId = 'video_iframe_${widget.anime.id}_ep${ep.number}_${DateTime.now().millisecondsSinceEpoch}';

      setState(() {
        _resolvedVideoUrl = url;
        _resolvedQuality = quality;
        _availableQualities = qualities;
        _iframeViewId = newViewId;
        _iframeRegistered = false;
      });

      debugPrint('[WatchScreen] resolved url for "${widget.anime.title}" ep${ep.number}: $url (quality=$quality)');
    } else if (widget.anime.catalogEpisodeLink != null && widget.anime.catalogEpisodeLink!.isNotEmpty) {
      // ── Admin CMS / Firestore catalogEpisodeLink ──
      // Bisa berupa:
      //   a) JSON per-episode per-kualitas:
      //      {"1":{"1080p":"url",...}, "2":{...}}
      //   b) URL flat tunggal (atau pakai {ep} placeholder)
      // Prioritas #1 (di atas file lokal) biar admin edit → user langsung dapet.
      final raw = widget.anime.catalogEpisodeLink!;
      final epKey = ep.number.toString();
      Map<String, String>? qualitiesForEp;

      if (raw.trim().startsWith('{')) {
        try {
          final parsed = jsonDecode(raw) as Map<String, dynamic>;
          // Cari key episode persis, atau '1' kalau cuma 1 entry flat.
          final epData = parsed[epKey] ?? parsed['1'];
          if (epData is Map) {
            qualitiesForEp = {
              for (final q in (epData as Map).keys)
                q.toString(): (epData[q] ?? '').toString()
            }..removeWhere((_, v) => v.trim().isEmpty);
          }
        } catch (_) {
          // JSON rusak → treat sebagai URL flat di bawah.
        }
      }

      if (qualitiesForEp != null && qualitiesForEp!.isNotEmpty) {
        // Punya multi-kualitas dari Firestore → pakai logika sama kayak
        // my_episode_links (pilih terbaik, wrap proxy, isi _availableQualities).
        final tmpLink = MyEpisodeLink(qualitiesForEp!);
        final quality = bestQualityFor(tmpLink);
        final url = StreamingService.wrapProxyUrl(tmpLink.qualities[quality]!);
        final qualities = sortedQualitiesFor(tmpLink);
        final newViewId = 'video_iframe_${widget.anime.id}_ep${ep.number}_cms_' + DateTime.now().millisecondsSinceEpoch.toString();
        setState(() {
          _resolvedVideoUrl = url;
          _resolvedQuality = quality;
          _availableQualities = qualities;
          _iframeViewId = newViewId;
          _iframeRegistered = false;
        });
        debugPrint('[WatchScreen] CMS multi-quality for "${widget.anime.title}" ep${ep.number}: $quality');
        return;
      }

      // Fallback: URL flat (atau {ep} placeholder).
      String url = raw;
      if (url.contains('{ep}')) {
        url = url.replaceAll('{ep}', ep.number.toString());
      } else if (url.contains('{episode}')) {
        url = url.replaceAll('{episode}', ep.number.toString());
      }
      final newViewId = 'video_iframe_${widget.anime.id}_ep${ep.number}_custom_' + DateTime.now().millisecondsSinceEpoch.toString();

      setState(() {
        _resolvedVideoUrl = url;
        _resolvedQuality = 'Kustom';
        _availableQualities = ['Kustom'];
        _iframeViewId = newViewId;
        _iframeRegistered = false;
      });

    } else {
      // ── Auto Scraper Fallback ─────────────────────────────────────────────
      // If no manual link is set in MyEpisodeLinks or Admin CMS, attempt to
      // auto-resolve video stream via Sub Indo / Shirayuki / Gogoanime scrapers.
      setState(() {
        _resolvedVideoUrl = null;
        _resolvedQuality = 'Searching...';
        _availableQualities = [];
        _iframeViewId = '';
      });
      debugPrint('[WatchScreen] attempting auto-stream resolution for "${widget.anime.title}" ep${ep.number}...');
      StreamingService().resolveStream(widget.anime.title, ep.number).then((res) {
        if (!mounted) return;
        if (res.streamUrl != null && res.streamUrl!.isNotEmpty) {
          final newViewId = 'video_iframe_${widget.anime.id}_ep${ep.number}_auto_' + DateTime.now().millisecondsSinceEpoch.toString();
          final qualities = res.qualities != null ? res.qualities!.keys.toList() : ['Auto'];
          setState(() {
            _resolvedVideoUrl = res.streamUrl;
            _resolvedQuality = qualities.first;
            _availableQualities = qualities;
            _iframeViewId = newViewId;
            _iframeRegistered = false;
          });
          debugPrint('[WatchScreen] auto-stream SUCCESS: ${res.streamUrl}');
        } else {
          debugPrint('[WatchScreen] auto-stream empty — falling back to trailer for "${widget.anime.title}"');
          _applyTrailerFallback();
        }
      }).catchError((e) {
        if (!mounted) return;
        debugPrint('[WatchScreen] auto-stream error — falling back to trailer: $e');
        _applyTrailerFallback();
      });
    }
  }

  /// Fallback when no manual/catalog link exists and auto-scrape yields
  /// nothing: play the anime's YouTube trailer instead of a wrong hardcoded
  /// video. Resolution order:
  ///   1. trailer registered in trailer_links.dart (getTrailerUrl),
  ///   2. trailer fetched from Jikan by malId (AnimeApiService),
  ///   3. legacy hardcoded Sub Indo stream as an absolute last resort.
  Future<void> _applyTrailerFallback() async {
    String? trailer = getTrailerUrl(widget.anime.title, anime: widget.anime);
    if (trailer == null && widget.anime.malId != null) {
      try {
        final detail = await AnimeApiService.fetchAnimeDetail(
          widget.anime.malId.toString(),
        );
        final yt = detail.trailerYoutubeId;
        if (yt != null && yt.isNotEmpty) {
          trailer = 'https://www.youtube.com/watch?v=$yt';
        }
      } catch (e) {
        debugPrint('[WatchScreen] Jikan trailer fetch failed for malId=${widget.anime.malId}: $e');
      }
    }
    if (!mounted) return;
    setState(() {
      if (trailer != null) {
        _resolvedVideoUrl = trailer;
        _resolvedQuality = 'Trailer (YouTube)';
        _availableQualities = const ['Trailer (YouTube)'];
        _iframeViewId = '';
        _iframeRegistered = false;
      } else {
        _resolvedVideoUrl = _kFrierenFallbackUrl;
        _resolvedQuality = '1080p (Sub Indo)';
        _availableQualities = const ['1080p (Sub Indo)', '720p HD', '480p'];
        _iframeViewId = 'video_iframe_${widget.anime.id}_ep${_currentEpisode.number}_fallback_' +
            DateTime.now().millisecondsSinceEpoch.toString();
        _iframeRegistered = false;
      }
    });
  }

  /// Renders a YouTube trailer as the watch fallback (reuses TrailerPlayer,
  /// which handles both the web iframe and the native youtube_player_flutter).
  Widget _trailerFallbackPlayer(String url) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.background.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              TrailerPlayer(
                trailerUrl: url,
                fallback: _thumbnail(),
                playWithSound: false,
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'TRAILER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── HTML5 video element — Flutter Web only ───────────────────────────────
  Widget _buildVideoIframe(String url) {
    // This method is only called on web (kIsWeb guard in caller).
    // On mobile this path is never reached — YouTube player is used instead.
    if (!kIsWeb) return const SizedBox.shrink();
    return _buildVideoIframeWeb(url);
  }

  Widget _buildVideoIframeWeb(String url) {
    if (!_iframeRegistered && _iframeViewId.isNotEmpty) {
      _iframeRegistered = true;
      registerVideoElement(url, _iframeViewId); // from conditional import
    }
    return HtmlElementView(viewType: _iframeViewId);
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _controlsFade.forward();
    } else {
      _controlsFade.reverse();
    }
  }

  Future<void> _toggleFullscreen() async {
    if (_isFullscreen) {
      await exitBrowserFullscreen();
    } else {
      await enterBrowserFullscreen();
    }
    // _isFullscreen akan diupdate otomatis via _fullscreenSub listener
  }

  String _formatTime(double fraction) {
    const totalSec = 22 * 60 + 10;
    final elapsed = (fraction * totalSec).round();
    final m = elapsed ~/ 60;
    final s = elapsed % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 720;
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: isWide ? _wideLayout(context) : _narrowLayout(context),
      ),
    );
  }

  // ─── Narrow (phone) ───────────────────────────────────────────────────────

  Widget _narrowLayout(BuildContext context) {
    return Column(
      children: [
        _persistentBackBar(context),
        _videoPlayer(context),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _controlsBar(),
                _rewardDropPanel(),
                _panelTabBar(),
                _panelTab == 0
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _episodeHeader(),
                          _episodeListScrollable(),
                        ],
                      )
                    : _panelTab == 1
                        ? SizedBox(height: 400, child: _communityPanel())
                        : SizedBox(height: 500, child: _kosmetikPanel()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Wide (tablet) ────────────────────────────────────────────────────────

  Widget _wideLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _persistentBackBar(context),
              _videoPlayer(context),
              _controlsBar(),
              _rewardDropPanel(),
            ],
          ),
        ),
        Container(width: 0.5, color: _kWhite06),
        SizedBox(
          width: 310,
          child: Column(
            children: [
              _panelTabBar(),
              Expanded(
                child: _panelTab == 0
                    ? Column(children: [
                        _episodeHeader(),
                        Expanded(child: _episodeList()),
                      ])
                    : _panelTab == 1
                        ? _communityPanel()
                        : _kosmetikPanel(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Persistent back bar — selalu visible, tidak ikut fade controls ─────
  Widget _persistentBackBar(BuildContext context) {
    final epTitle = widget.anime.episodes.isEmpty
        ? widget.anime.title
        : 'EP ${_currentEpisode.number} · ${_currentEpisode.title}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: LiquidGlassPill(
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kWhite06),
                  boxShadow: [BoxShadow(color: _kPurple.withValues(alpha: 0.10), blurRadius: 10)],
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: _kInk, size: 14),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.anime.title,
                    style: const TextStyle(color: _kInk, fontSize: 13, fontWeight: FontWeight.w800, height: 1.2),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(color: _kPink, shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: _kPink.withValues(alpha: 0.5), blurRadius: 4)]),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(epTitle,
                          style: TextStyle(color: _kWhite60, fontSize: 11, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 11),
                  const SizedBox(width: 3),
                  Text('${widget.anime.rating}',
                    style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Premium Video Player ─────────────────────────────────────────────────

  Widget _videoPlayer(BuildContext context) {
    final videoUrl = _resolvedVideoUrl;
    // ── Trailer fallback (YouTube): kalau URL-nya YouTube, render player trailer ──
    if (videoUrl != null && videoUrl.isNotEmpty && !_forceMockPlayer && extractYoutubeId(videoUrl) != null) {
      return _trailerFallbackPlayer(videoUrl);
    }
    // ── Kalau ada URL dari my_episode_links/catalog → tampilkan iframe real ──────────
    if (videoUrl != null && videoUrl.isNotEmpty && _iframeViewId.isNotEmpty && !_forceMockPlayer) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.background.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: _buildVideoIframe(videoUrl),
              ),
              Container(
                color: AppTheme.background,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    if (_availableQualities.isNotEmpty) ...[
                      Icon(Icons.hd_rounded, color: AppTheme.highlight, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Kualitas:',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      ..._availableQualities.map((q) => GestureDetector(
                        onTap: () {
                          final link = resolveMyEpisodeLink(widget.anime.title, _currentEpisode.number);
                          setState(() {
                            _resolvedQuality = q;
                            if (link != null) {
                              _resolvedVideoUrl = link.qualities[q];
                            } else {
                              _resolvedVideoUrl = widget.anime.catalogEpisodeLink;
                            }
                            _iframeRegistered = false;
                            _iframeViewId = 'video_iframe_${widget.anime.id}_ep${_currentEpisode.number}_${q}_' + DateTime.now().millisecondsSinceEpoch.toString();
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: q == _resolvedQuality
                                ? AppTheme.highlight.withValues(alpha: 0.15)
                                : AppTheme.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: q == _resolvedQuality
                                  ? AppTheme.highlight
                                  : AppTheme.textSecondary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            q,
                            style: TextStyle(
                              color: q == _resolvedQuality
                                  ? AppTheme.highlight
                                  : AppTheme.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )),
                    ],
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _forceMockPlayer = true);
                      },
                      icon: const Icon(Icons.videogame_asset_rounded, size: 14, color: AppTheme.accent),
                      label: const Text(
                        'Cara Dulu (Simulasi)',
                        style: TextStyle(fontSize: 11, color: AppTheme.accent, fontWeight: FontWeight.bold),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Loading state: lagi nunggu auto-scrape (gak langsung mock player) ──
    if (_resolvedQuality == 'Searching...') {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.08)),
          color: AppTheme.background,
        ),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppTheme.highlight),
                const SizedBox(height: 12),
                Text('Mencari stream sub Indo...',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
    }

    // ── Empty state: gak ada link manual & scrape gagal ──
    if (_resolvedVideoUrl == null || _resolvedVideoUrl!.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
          color: AppTheme.background,
        ),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.video_library_outlined, color: AppTheme.accent, size: 36),
                  const SizedBox(height: 10),
                  Text('Belum ada link video',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('Isi link .m3u8/.mp4 di lib/my_episode_links.dart\natau set catalogEpisodeLink di Catalog Manager.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ── Fallback: mock player (thumbnail + controls simulasi) ─────────────────
    return RepaintBoundary(
      child: GestureDetector(
        onTap: _toggleControls,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.background.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.08)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _thumbnail(),
                    _vignette(),
                    _bottomGradient(),
                    _floatingSkipButtons(),
                    FadeTransition(
                      opacity: _controlsAnim,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _topBarV2(context),
                          _centerPlayButtonV2(),
                          _bottomOverlayV2(),
                          if (_showQualityPopup) _qualityPopup(),
                        ],
                      ),
                    ),
                    _autoNextOverlay(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbnail() {
    return Image.network(
      _currentEpisode.thumbnailUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Image.network(
        widget.anime.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: _kSurface,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.movie_creation_outlined,
                    color: _kWhite40, size: 52),
                const SizedBox(height: 10),
                Text(
                  widget.anime.title,
                  style: TextStyle(color: _kWhite40, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _vignette() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.4,
          colors: [Colors.transparent, Color(0x99000000)],
        ),
      ),
    );
  }

  Widget _bottomGradient() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: 160,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.55),
              Colors.black.withValues(alpha: 0.88),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Controls bar (below player) ─────────────────────────────────────────

  Widget _controlsBar() {
    final watchedPct = (_seekValue * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: LiquidGlassPill(
        borderRadius: 16,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Progress strip ─────────────────────────────────────
            Row(
              children: [
                Text(_formatTime(_seekValue),
                  style: TextStyle(color: _kWhite60, fontSize: 10, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Expanded(
                  child: _PremiumSeekBar(
                    value: _seekValue,
                    onChanged: (v) {
                      setState(() => _seekValue = v);
                      _updatePlaybackUiFlags();
                      _syncContinueWatching();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text('22:10',
                  style: TextStyle(color: _kWhite40, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 8),
            // ── Nav + episode info ──────────────────────────────────
            Row(
              children: [
                _NavButton(icon: Icons.skip_previous_rounded, label: 'Sebelum',
                  enabled: _hasPrev, onTap: () => _goToEpisode(_currentIndex - 1)),
                const SizedBox(width: 6),
                _NavButton(icon: Icons.skip_next_rounded, label: 'Berikut',
                  enabled: _hasNext, onTap: () => _goToEpisode(_currentIndex + 1)),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_currentEpisode.title,
                      style: const TextStyle(color: _kInk, fontWeight: FontWeight.w800, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_currentEpisode.duration,
                          style: TextStyle(color: _kWhite40, fontSize: 10)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _kPink.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _kPinkBorder),
                          ),
                          child: Text('$watchedPct%',
                            style: TextStyle(color: _kPink, fontSize: 9, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _rewardDropPanel() {
    final progress = (_seekValue / 0.9).clamp(0.0, 1.0);
    final isEligible = _seekValue >= 0.9;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _kPink.withValues(alpha: 0.16),
            AppTheme.accent.withValues(alpha: 0.12),
            _kSurface,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kPink.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: _kPink.withValues(alpha: 0.10),
            blurRadius: 18,
            spreadRadius: -6,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [_kPink, AppTheme.accent]),
                  boxShadow: [BoxShadow(color: _kPink.withValues(alpha: 0.35), blurRadius: 12)],
                ),
                child: const Icon(Icons.card_giftcard_rounded, color: AppTheme.textPrimary, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hadiah Episode',
                      style: TextStyle(
                        color: _kInk,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEligible
                          ? 'Hadiah terbuka setelah episode ini'
                          : 'Tonton 90% untuk membuka hadiah',
                      style: TextStyle(
                        color: _kMuted.withValues(alpha: 0.95),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: isEligible
                      ? AppTheme.success.withValues(alpha: 0.14)
                      : _kPink.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isEligible
                        ? AppTheme.success.withValues(alpha: 0.36)
                        : _kPink.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  isEligible ? 'SIAP' : '${(progress * 100).round()}%',
                  style: TextStyle(color: isEligible ? AppTheme.success : _kWhite60, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: AppTheme.background,
              valueColor: const AlwaysStoppedAnimation(_kPink),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              Expanded(child: _RewardChip(icon: Icons.flash_on_rounded, label: '+30 XP')),
              SizedBox(width: 8),
              Expanded(child: _RewardChip(icon: Icons.local_florist_rounded, label: '+18 Coin')),
              SizedBox(width: 8),
              Expanded(child: _RewardChip(icon: Icons.auto_awesome_rounded, label: '5% Drop')),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Episode list header ──────────────────────────────────────────────────

  Widget _episodeHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border(bottom: BorderSide(color: _kWhite06)),
      ),
      child: Row(
        children: [
          const Text(
            'Episode',
            style: TextStyle(
              color: _kInk,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _kWhite06,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${widget.anime.genre} • ${widget.anime.episodes.length} eps',
              style: TextStyle(color: _kWhite60, fontSize: 11),
            ),
          ),
          const Spacer(),
          // Grid / List toggle
          GestureDetector(
            onTap: () => setState(() => _episodeGridMode = !_episodeGridMode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _episodeGridMode
                    ? _kPink.withValues(alpha: 0.15)
                    : _kWhite06,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _episodeGridMode
                      ? _kPinkBorder
                      : AppTheme.textPrimary.withValues(alpha: 0.08),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  _episodeGridMode
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                  key: ValueKey(_episodeGridMode),
                  color: _episodeGridMode ? _kPink : _kWhite60,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Episode list ─────────────────────────────────────────────────────────

  Widget _episodeList() {
    return ValueListenableBuilder<Map<String, Set<int>>>(
      valueListenable: MockDataService.watchedEpisodesNotifier,
      builder: (context, watchedMap, _) {
        final watchedSet = watchedMap[widget.anime.id] ?? const <int>{};
        return RepaintBoundary(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: _episodeGridMode
                ? _episodeGrid(watchedSet)
                : _episodeListView(watchedSet),
          ),
        );
      },
    );
  }

  Widget _episodeListScrollable() {
    return ValueListenableBuilder<Map<String, Set<int>>>(
      valueListenable: MockDataService.watchedEpisodesNotifier,
      builder: (context, watchedMap, _) {
        final watchedSet = watchedMap[widget.anime.id] ?? const <int>{};
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
          itemCount: widget.anime.episodes.length,
          itemBuilder: (context, index) {
            final ep = widget.anime.episodes[index];
            final isSelected = index == _currentIndex;
            return _EpisodeTile(
              episode: ep,
              isSelected: isSelected,
              isWatched: watchedSet.contains(ep.number),
              animeCoverUrl: widget.anime.imageUrl,
              currentProgress: isSelected ? _seekValue : 0.0,
              onTap: () => _goToEpisode(index),
            );
          },
        );
      },
    );
  }

  Widget _episodeListView(Set<int> watchedSet) {
    return Container(
      key: const ValueKey('list'),
      color: _kBg,
      child: ListView.builder(
        controller: _episodeListController,
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
        itemCount: widget.anime.episodes.length,
        itemBuilder: (context, index) {
          final ep = widget.anime.episodes[index];
          final isSelected = index == _currentIndex;
          return _EpisodeTile(
            episode: ep,
            isSelected: isSelected,
            isWatched: watchedSet.contains(ep.number),
            animeCoverUrl: widget.anime.imageUrl,
            currentProgress: isSelected ? _seekValue : 0.0,
            onTap: () => _goToEpisode(index),
          );
        },
      ),
    );
  }

  Widget _episodeGrid(Set<int> watchedSet) {
    return GridView.builder(
      key: const ValueKey('grid'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.45, // wider card for 16:9 thumb + label below
      ),
      itemCount: widget.anime.episodes.length,
      itemBuilder: (context, index) {
        final ep = widget.anime.episodes[index];
        final isSelected = index == _currentIndex;
        final isWatched = watchedSet.contains(ep.number);
        final progress = isSelected ? _seekValue : 0.0;
        final hasDropBoost = ep.number % 3 == 0;
        return _EpisodeGridItem(
          episode: ep,
          isSelected: isSelected,
          isWatched: isWatched,
          animeCoverUrl: widget.anime.imageUrl,
          progress: progress,
          hasDropBoost: hasDropBoost,
          onTap: () => _goToEpisode(index),
        );
      },
    );
  }

  // ─── Panel tab bar ────────────────────────────────────────────────────────
  Widget _panelTabBar() {
    final epComments = widget.anime.episodes.isEmpty
        ? 0
        : (_comments[_currentEpisode.number]?.length ?? 0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: LiquidGlassPill(
        borderRadius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: _PanelTab(
                label: 'Episode',
                icon: Icons.playlist_play_rounded,
                isActive: _panelTab == 0,
                onTap: () => setState(() => _panelTab = 0),
              ),
            ),
            Expanded(
              child: _PanelTab(
                label: 'Komunitas',
                icon: Icons.chat_bubble_outline_rounded,
                isActive: _panelTab == 1,
                badge: epComments > 0 ? '$epComments' : null,
                onTap: () => setState(() => _panelTab = 1),
              ),
            ),
            Expanded(
              child: _PanelTab(
                label: 'Kosmetik',
                icon: Icons.auto_awesome_rounded,
                isActive: _panelTab == 2,
                onTap: () => setState(() => _panelTab = 2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Kosmetik panel ───────────────────────────────────────────────────────
  Widget _kosmetikPanel() {
    const myLevel = 12;

    // Filter list preserving original indices for state tracking
    final filtered = _kosmetikFrames.asMap().entries.where((e) {
      if (_cosmeticFilter == 'Gratis')   return e.value.unlockLabel != 'Premium';
      if (_cosmeticFilter == 'Premium')  return e.value.unlockLabel == 'Premium';
      return true;
    }).toList();

    final preview  = _kosmetikFrames[_previewFrameIndex];
    final isPreviewEquipped = _previewFrameIndex == _equippedFrameIndex;

    return Column(
      children: [
        // ── Hero preview section ────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [preview.color.withValues(alpha: 0.18), _kBg, _kBg],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.55, 1.0],
            ),
            border: Border(bottom: BorderSide(color: _kWhite06)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Bordered avatar preview ───────────────────────────────
              SizedBox(
                width: 108,
                height: 108,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glow for premium frames
                    if (preview.unlockLabel == 'Premium')
                      Container(
                        width: 108, height: 108,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: preview.color.withValues(alpha: 0.45), blurRadius: 24, spreadRadius: 4),
                          ],
                        ),
                      ),
                    // Avatar background circle
                    Container(
                      width: 76, height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [preview.color.withValues(alpha: 0.3), preview.color.withValues(alpha: 0.08)],
                        ),
                        border: Border.all(color: preview.color.withValues(alpha: 0.25), width: 1),
                      ),
                      child: Center(
                        child: Text(preview.emoji, style: const TextStyle(fontSize: 32)),
                      ),
                    ),
                    // Border PNG overlay — full stack size so border frames avatar
                    Positioned.fill(
                      child: Image.asset(
                        preview.assetPath,
                        fit: BoxFit.contain,
                      ),
                    ),
                    // Equipped checkmark badge
                    if (isPreviewEquipped)
                      Positioned(
                        bottom: 4, right: 4,
                        child: Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            color: preview.color,
                            shape: BoxShape.circle,
                            border: Border.all(color: _kBg, width: 2),
                            boxShadow: [BoxShadow(color: preview.color.withValues(alpha: 0.5), blurRadius: 8)],
                          ),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 13),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // ── Frame info + action ───────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + badge
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            preview.name,
                            style: TextStyle(
                              color: preview.color,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (preview.unlockLabel == 'Premium') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFFF2D87)]),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text('PREMIUM', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    // Description
                    Text(
                      preview.description,
                      style: TextStyle(color: _kWhite60, fontSize: 11, height: 1.35),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    // Action button
                    isPreviewEquipped
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: preview.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: preview.color.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, color: preview.color, size: 14),
                                const SizedBox(width: 5),
                                Text('Sedang Dipakai', style: TextStyle(color: preview.color, fontSize: 11, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          )
                        : _buildFrameActionButton(context, _previewFrameIndex, preview, myLevel),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Category filter tabs ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _kBg,
            border: Border(bottom: BorderSide(color: _kWhite06)),
          ),
          child: Row(
            children: [
              ...['Semua', 'Gratis', 'Premium'].map((label) {
                final active = _cosmeticFilter == label;
                final isPrem = label == 'Premium';
                return GestureDetector(
                  onTap: () => setState(() => _cosmeticFilter = label),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: active && isPrem
                          ? const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFFF2D87)])
                          : null,
                      color: active
                          ? (isPrem ? null : AppTheme.highlight.withValues(alpha: 0.15))
                          : _kSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active
                            ? (isPrem ? Colors.transparent : AppTheme.highlight.withValues(alpha: 0.5))
                            : _kWhite06,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: active
                            ? (isPrem ? Colors.white : AppTheme.highlight)
                            : _kWhite40,
                        fontSize: 11,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              Icon(Icons.auto_awesome_rounded, color: _kWhite40, size: 12),
              const SizedBox(width: 4),
              Text('Lv. $myLevel', style: TextStyle(color: _kWhite40, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ),

        // ── Frame grid ───────────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text('Tidak ada item', style: TextStyle(color: _kWhite40)))
              : GridView.builder(
                  padding: const EdgeInsets.all(10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final entry = filtered[i];
                    final idx   = entry.key;
                    final f     = entry.value;
                    final isPremium  = f.unlockLabel == 'Premium';
                    final isBought   = _purchasedPremiumFrames.contains(idx);
                    final unlocked   = isPremium ? isBought : myLevel >= f.requiredLevel;
                    final isEquipped = idx == _equippedFrameIndex;
                    final isSelected = idx == _previewFrameIndex;
                    final isBestSeller = f.name == 'Cosmic Nebula';

                    return GestureDetector(
                      onTap: () => setState(() => _previewFrameIndex = idx),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        decoration: BoxDecoration(
                          color: isSelected ? f.color.withValues(alpha: 0.08) : _kSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isEquipped
                                ? f.color
                                : isSelected
                                    ? f.color.withValues(alpha: 0.5)
                                    : _kWhite06,
                            width: isEquipped ? 2 : isSelected ? 1.5 : 1,
                          ),
                          boxShadow: (isSelected || isEquipped)
                              ? [BoxShadow(color: f.color.withValues(alpha: 0.28), blurRadius: 16)]
                              : null,
                        ),
                        child: Column(
                          children: [
                            // ── PNG Border preview ──────────────────────
                            Expanded(
                              flex: 3,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Avatar bg
                                  Container(
                                    margin: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: RadialGradient(
                                        colors: [f.color.withValues(alpha: 0.25), f.color.withValues(alpha: 0.04)],
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(f.emoji, style: TextStyle(fontSize: 26, color: unlocked ? null : Colors.white24)),
                                    ),
                                  ),
                                  // PNG border image
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Image.asset(
                                        f.assetPath,
                                        fit: BoxFit.contain,
                                        color: unlocked ? null : Colors.black45,
                                        colorBlendMode: unlocked ? null : BlendMode.darken,
                                      ),
                                    ),
                                  ),
                                  // Lock overlay
                                  if (!unlocked)
                                    Positioned.fill(
                                      child: Container(
                                        margin: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isPremium ? Icons.diamond_rounded : Icons.lock_rounded,
                                                color: isPremium ? const Color(0xFFD4AF37) : _kWhite60,
                                                size: 20,
                                              ),
                                              if (!isPremium) ...[
                                                const SizedBox(height: 3),
                                                Text('Lv ${f.requiredLevel}', style: TextStyle(color: _kWhite60, fontSize: 9, fontWeight: FontWeight.w800)),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  // Equipped badge
                                  if (isEquipped)
                                    Positioned(
                                      top: 10, right: 10,
                                      child: Container(
                                        width: 22, height: 22,
                                        decoration: BoxDecoration(
                                          color: f.color,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: _kSurface, width: 1.5),
                                        ),
                                        child: const Icon(Icons.check, color: Colors.white, size: 13),
                                      ),
                                    ),
                                  // Best seller badge
                                  if (isBestSeller)
                                    Positioned(
                                      top: 10, left: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(colors: [Color(0xFFFF2D87), Color(0xFFD4AF37)]),
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: const Text('🔥 BEST', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // ── Card info ────────────────────────────────
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      f.name,
                                      style: TextStyle(
                                        color: isSelected || isEquipped ? f.color : AppTheme.textPrimary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    isPremium
                                        ? Row(
                                            children: [
                                              Text('💎', style: const TextStyle(fontSize: 10)),
                                              const SizedBox(width: 3),
                                              Text(
                                                isBought ? 'Sudah Dibeli' : 'Rp ${_formatFramePrice(f.price)}',
                                                style: TextStyle(
                                                  color: isBought ? const Color(0xFF7B9E87) : const Color(0xFFD4AF37),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Text(
                                            unlocked ? '✓ Tersedia' : 'Butuh Lv ${f.requiredLevel}',
                                            style: TextStyle(
                                              color: unlocked ? const Color(0xFF7B9E87) : _kWhite40,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                    const SizedBox(height: 6),
                                    // Quick action mini-button
                                    SizedBox(
                                      width: double.infinity,
                                      child: isEquipped
                                          ? Container(
                                              padding: const EdgeInsets.symmetric(vertical: 4),
                                              decoration: BoxDecoration(
                                                color: f.color.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: f.color.withValues(alpha: 0.3)),
                                              ),
                                              child: Center(
                                                child: Text('Dipakai', style: TextStyle(color: f.color, fontSize: 9, fontWeight: FontWeight.w900)),
                                              ),
                                            )
                                          : isPremium && !isBought
                                              ? GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      _purchasedPremiumFrames.add(idx);
                                                      _equippedFrameIndex = idx;
                                                      _previewFrameIndex  = idx;
                                                    });
                                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                      content: Text('🎉 "${f.name}" berhasil dibeli & dipasang!'),
                                                      behavior: SnackBarBehavior.floating,
                                                      backgroundColor: f.color,
                                                    ));
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                                    decoration: BoxDecoration(
                                                      gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFFF8C00)]),
                                                      borderRadius: BorderRadius.circular(8),
                                                      boxShadow: [BoxShadow(color: const Color(0xFFD4AF37).withValues(alpha: 0.35), blurRadius: 8)],
                                                    ),
                                                    child: const Center(
                                                      child: Text('Beli', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                                                    ),
                                                  ),
                                                )
                                              : unlocked
                                                  ? GestureDetector(
                                                      onTap: () {
                                                        setState(() {
                                                          _equippedFrameIndex = idx;
                                                          _previewFrameIndex  = idx;
                                                        });
                                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                          content: Text('✨ Border "${f.name}" dipakai!'),
                                                          behavior: SnackBarBehavior.floating,
                                                          backgroundColor: f.color,
                                                        ));
                                                      },
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: f.color.withValues(alpha: 0.15),
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(color: f.color.withValues(alpha: 0.4)),
                                                        ),
                                                        child: Center(
                                                          child: Text('Pakai', style: TextStyle(color: f.color, fontSize: 9, fontWeight: FontWeight.w900)),
                                                        ),
                                                      ),
                                                    )
                                                  : Container(
                                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: _kWhite06,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Center(
                                                        child: Text('Terkunci', style: TextStyle(color: _kWhite40, fontSize: 9)),
                                                      ),
                                                    ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Frame action button (hero preview area) ──────────────────────────────
  Widget _buildFrameActionButton(BuildContext context, int idx, _Frame f, int myLevel) {
    final isPremium = f.unlockLabel == 'Premium';
    final isBought  = _purchasedPremiumFrames.contains(idx);
    final unlocked  = isPremium ? isBought : myLevel >= f.requiredLevel;

    if (isPremium && !isBought) {
      return GestureDetector(
        onTap: () {
          setState(() {
            _purchasedPremiumFrames.add(idx);
            _equippedFrameIndex = idx;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('🎉 Border "${f.name}" berhasil dibeli & dipasang!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: f.color,
          ));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFFF8C00)]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: const Color(0xFFD4AF37).withValues(alpha: 0.45), blurRadius: 12, offset: const Offset(0, 3))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💎 Beli — Rp ', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
              Text(_formatFramePrice(f.price), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      );
    }

    if (!unlocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _kWhite06)),
        child: Text('Butuh Lv ${f.requiredLevel}', style: TextStyle(color: _kWhite40, fontSize: 11)),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() => _equippedFrameIndex = idx);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✨ Border "${f.name}" dipakai!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: f.color,
        ));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: f.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: f.color.withValues(alpha: 0.5)),
          boxShadow: [BoxShadow(color: f.color.withValues(alpha: 0.2), blurRadius: 10)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, color: f.color, size: 14),
            const SizedBox(width: 6),
            Text('Pakai Sekarang', style: TextStyle(color: f.color, fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  String _formatFramePrice(int price) {
    if (price >= 1000) return '${(price / 1000).toStringAsFixed(price % 1000 == 0 ? 0 : 1)}k';
    return price.toString();
  }

  // ─── Community / comment panel ────────────────────────────────────────────

  Widget _communityPanel() {
    final epNumber = widget.anime.episodes.isEmpty ? 0 : _currentEpisode.number;
    final epComments = List<_Comment>.from(_comments[epNumber] ?? []);

    return Column(
      children: [
        // Episode info bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _kBg,
            border: Border(bottom: BorderSide(color: _kWhite06)),
          ),
          child: Row(
            children: [
              Icon(Icons.chat_bubble_rounded, color: AppTheme.highlight, size: 14),
              const SizedBox(width: 6),
              Text(
                widget.anime.episodes.isEmpty
                    ? 'Komentar'
                    : 'EP ${_currentEpisode.number} · ${epComments.length} komentar',
                style: TextStyle(
                  color: _kWhite60,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.highlight.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.highlight.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.public_rounded, color: AppTheme.highlight, size: 10),
                    const SizedBox(width: 4),
                    Text(
                      'Publik',
                      style: TextStyle(color: AppTheme.highlight, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Comment list
        Expanded(
          child: epComments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, color: _kWhite40, size: 36),
                      const SizedBox(height: 10),
                      Text('Belum ada komentar', style: TextStyle(color: _kWhite40, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('Jadi yang pertama!', style: TextStyle(color: _kWhite60.withValues(alpha: 0.5), fontSize: 11)),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _commentListCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: epComments.length,
                  itemBuilder: (context, i) => _CommentTile(comment: epComments[i]),
                ),
        ),

        // Input box
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: _kSurface,
            border: Border(top: BorderSide(color: _kWhite06)),
          ),
          child: Row(
            children: [
              // Avatar kamu
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accent.withValues(alpha: 0.2),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
                ),
                child: const Center(child: Text('🎮', style: TextStyle(fontSize: 15))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  maxLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submitComment(),
                  decoration: InputDecoration(
                    hintText: 'Tulis komentar...',
                    hintStyle: TextStyle(color: _kWhite40, fontSize: 13),
                    filled: true,
                    fillColor: _kBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _kWhite06),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _kWhite06),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.highlight.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _submitComment,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppTheme.highlight, AppTheme.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _topBarV2(BuildContext context) {
    return Positioned(
      top: 14,
      left: 14,
      right: 14,
      child: Row(
        children: [
          _GlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          if (_forceMockPlayer && _resolvedVideoUrl != null && _resolvedVideoUrl!.isNotEmpty) ...[
            const SizedBox(width: 8),
            _GlassIconButton(
              icon: Icons.video_stable_rounded,
              onTap: () {
                setState(() => _forceMockPlayer = false);
              },
            ),
          ],
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.background.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.anime.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'EP ${_currentEpisode.number} · ${_currentEpisode.title}',
                    style: TextStyle(color: _kWhite60, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _centerPlayButtonV2() {
    return Center(
      child: ScaleTransition(
        scale: _pulseAnim,
        child: GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.44),
              border: Border.all(color: _kPinkBorder, width: 1.8),
              boxShadow: [
                BoxShadow(color: _kPinkGlow, blurRadius: 22),
                BoxShadow(color: AppTheme.accent.withValues(alpha: 0.2), blurRadius: 18),
              ],
            ),
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomOverlayV2() {
    return Positioned(
      left: 14,
      right: 14,
      bottom: 12,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.26),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'EP ${_currentEpisode.number} · ${_currentEpisode.title}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(_seekValue * 100).round()}%',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  _formatTime(_seekValue),
                  style: TextStyle(
                    color: _kWhite80,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: _PremiumSeekBar(
                    value: _seekValue,
                    onChanged: (v) {
                      setState(() => _seekValue = v);
                      _updatePlaybackUiFlags();
                      _maybeMarkEpisodeWatched('slider_change');
                      _syncContinueWatching();
                    },
                  ),
                ),
                Text(
                  '22:10',
                  style: TextStyle(color: _kWhite60, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _PlayerIconBtn(
                  icon: Icons.skip_previous_rounded,
                  enabled: _hasPrev,
                  onTap: () => _goToEpisode(_currentIndex - 1),
                ),
                const SizedBox(width: 4),
                _PlayerIconBtn(
                  icon: Icons.skip_next_rounded,
                  enabled: _hasNext,
                  onTap: () => _goToEpisode(_currentIndex + 1),
                ),
                const Spacer(),
                _PlayerIconBtn(
                  icon: Icons.closed_caption_off_rounded,
                  onTap: () {},
                ),
                const SizedBox(width: 4),
                _PlayerIconBtn(icon: Icons.speed_rounded, onTap: () {}),
                const SizedBox(width: 4),
                _PlayerIconBtn(
                  icon: Icons.hd_rounded,
                  onTap: _showQualitySelector,
                ),
                const SizedBox(width: 4),
                _PlayerIconBtn(
                  icon: _isFullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  onTap: _toggleFullscreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showQualitySelector() {
    setState(() => _showQualityPopup = !_showQualityPopup);
  }

  /// Popup pemilih kualitas inline — di-render di DALAM overlay player
  /// (bukan modal), jadi bisa dipakai pas fullscreen. Klik di luar /
  /// pilih item akan menutupnya.
  Widget _qualityPopup() {
    final qualities = _availableQualities.isNotEmpty
        ? _availableQualities
        : ['1080p (FHD)', '720p (HD)', '480p (SD)', 'Auto'];

    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showQualityPopup = false),
        behavior: HitTestBehavior.opaque,
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 56, right: 16),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 240,
                constraints: const BoxConstraints(maxHeight: 320),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kPinkBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Text(
                        'Pilih Kualitas',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    Flexible(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: qualities.map((q) {
                          final isSelected = q == _resolvedQuality;
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: isSelected ? _kPink : Colors.white38,
                              size: 20,
                            ),
                            title: Text(
                              q,
                              style: TextStyle(
                                color: isSelected ? _kPink : Colors.white,
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            onTap: () {
                              final link = resolveMyEpisodeLink(
                                  widget.anime.title, _currentEpisode.number);
                              setState(() {
                                _resolvedQuality = q;
                                if (link != null && link.qualities.containsKey(q)) {
                                  _resolvedVideoUrl = link.qualities[q];
                                }
                                _iframeRegistered = false;
                                _iframeViewId =
                                    'video_iframe_${widget.anime.id}_ep${_currentEpisode.number}_${q}_${DateTime.now().millisecondsSinceEpoch}';
                                _showQualityPopup = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Kualitas diubah ke $q'),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: _kPink,
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _floatingSkipButtons() {
    return Positioned(
      right: 14,
      bottom: 104,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AnimatedSlide(
            duration: const Duration(milliseconds: 260),
            offset: _showSkipIntro ? Offset.zero : const Offset(0.2, 0),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: _showSkipIntro ? 1 : 0,
              child: IgnorePointer(
                ignoring: !_showSkipIntro,
                child: _ActionPillButton(
                  label: 'Lewati Intro',
                  icon: Icons.forward_10_rounded,
                  onTap: _skipIntro,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          AnimatedSlide(
            duration: const Duration(milliseconds: 260),
            offset: _showSkipEnding ? Offset.zero : const Offset(0.2, 0),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: _showSkipEnding ? 1 : 0,
              child: IgnorePointer(
                ignoring: !_showSkipEnding,
                child: _ActionPillButton(
                  label: 'Lewati Ending',
                  icon: Icons.skip_next_rounded,
                  onTap: _skipEnding,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _autoNextOverlay() {
    return Positioned(
      right: 18,
      bottom: 188,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 260),
        offset: _showAutoNext ? Offset.zero : const Offset(0.25, 0),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: _showAutoNext ? 1 : 0,
          child: IgnorePointer(
            ignoring: !_showAutoNext,
            child: Container(
              width: 230,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.46),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _kPinkBorder),
                boxShadow: [
                  BoxShadow(color: _kPinkGlow, blurRadius: 16),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Berikutnya',
                    style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Episode berikutnya dalam $_nextEpisodeCountdown detik...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _cancelAutoNextCountdown,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Batal'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          _cancelAutoNextCountdown();
                          _goToEpisode(_currentIndex + 1, autoPlay: true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPink,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Putar Sekarang',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Premium Seek Bar ─────────────────────────────────────────────────────────

// ─── Rank tier definitions ───────────────────────────────────────────────────
// Matches _MockUser.rank values used in mock comments and leaderboard.
// Each tier has label, color, emoji and level range.
const _rankTiers = [
  _RankTier('Beginner',      '🌱', Color(0xFF7B9E87), 0,  9),
  _RankTier('Anime Lover',   '🌙', Color(0xFF60A5FA), 10, 19),
  _RankTier('Otaku Sejati',  '🎴', Color(0xFFC17E74), 20, 29),
  _RankTier('Elite Watcher', '⚔️', Color(0xFFD4AF37), 30, 39),
  _RankTier('Cosmic Legend', '🌸', Color(0xFF9D4EDD), 40, 49),
  _RankTier('Cosmic Legend', '👑', Color(0xFF7C3AED), 50, 99),
];

class _RankTier {
  final String name;
  final String emoji;
  final Color color;
  final int minLv;
  final int maxLv;
  const _RankTier(this.name, this.emoji, this.color, this.minLv, this.maxLv);

  static _RankTier forLevel(int level) {
    for (final t in _rankTiers) {
      if (level >= t.minLv && level <= t.maxLv) return t;
    }
    return _rankTiers.last;
  }
}

// ─── Kosmetik (unlockable frames backed by real PNG assets) ──────────────────
const _kosmetikFrames = [
  _Frame('Moonlit Shrine',  '🌙', Color(0xFF7EC8E3), 0,  'Gratis',  'assets/border/Moonlit Shrine.png',  'Border kuil bulan yang menenangkan & elegan',    price: 0),
  _Frame('Sakura Emperor',  '🌸', Color(0xFFF48FB1), 10, 'Lv 10',   'assets/border/Sakura Emperor.png',  'Keindahan kerajaan sakura musim semi',            price: 0),
  _Frame('Thunder God',     '⚡', Color(0xFFFFD54F), 20, 'Lv 20',   'assets/border/Thunder God.png',     'Kekuatan Dewa Petir yang menggelegar',            price: 0),
  _Frame('Dragon Flame',    '🐉', Color(0xFFEF5350), 30, 'Lv 30',   'assets/border/Dragon Flame.png',    'Api naga legendaris yang membara dahsyat',        price: 0),
  _Frame('Cosmic Nebula',   '🌠', Color(0xFF9C27B0), 0,  'Premium', 'assets/border/Cosmic Nebula.png',   'Nebula kosmik ultra‑rare. Hanya untuk legenda.',  price: 2900),
  _Frame('Cyberpunk Neon',  '💎', Color(0xFF00E5FF), 0,  'Premium', 'assets/border/Cyberpunk Neon.png',  'Neon cyberpunk futuristik yang menyilaukan',      price: 3500),
  _Frame('Wraithling Cloak','👻', Color(0xFF7C3AED), 0,  'Premium', 'assets/border/Wraithling Cloak.png','Jubah hantu misterius dari kegelapan abadi',      price: 4900),
];

class _Frame {
  final String name;
  final String emoji;
  final Color color;
  final int requiredLevel;
  final String unlockLabel;
  final String assetPath;
  final String description;
  final int price;
  const _Frame(
    this.name,
    this.emoji,
    this.color,
    this.requiredLevel,
    this.unlockLabel,
    this.assetPath,
    this.description, {
    this.price = 0,
  });
}

class _PremiumSeekBar extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _PremiumSeekBar({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: _kPink,
        inactiveTrackColor: _kWhite10,
        thumbColor: Colors.white,
        overlayColor: _kPinkSubtle,
      ),
      child: Slider(value: value, onChanged: onChanged),
    );
  }
}

// ─── Player icon button ───────────────────────────────────────────────────────

class _RewardChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RewardChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _kPink, size: 13),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerIconBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PlayerIconBtn({
    required this.icon,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon,
          color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.25),
          size: 20),
      onPressed: enabled ? onTap : null,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      splashRadius: 18,
    );
  }
}

// ─── Nav button ──────────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: enabled ? onTap : null,
      style: TextButton.styleFrom(
        foregroundColor:
            enabled ? _kPurple : _kMuted.withValues(alpha: 0.35),
        backgroundColor:
            enabled ? _kPurple.withValues(alpha: 0.08) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 19),
      label: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Episode tile ─────────────────────────────────────────────────────────────

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _ActionPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionPillButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _kPinkBorder),
          boxShadow: [
            BoxShadow(color: _kPinkGlow, blurRadius: 14),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}




// ─── Episode Tile (Enhanced) ───────────────────────────────────────────────
// ─── Episode grid item ────────────────────────────────────────────────────────

class _EpisodeGridItem extends StatelessWidget {
  final EpisodeModel episode;
  final bool isSelected;
  final bool isWatched;
  final String animeCoverUrl;
  final double progress;
  final bool hasDropBoost;
  final VoidCallback onTap;

  const _EpisodeGridItem({
    required this.episode,
    required this.isSelected,
    required this.isWatched,
    required this.animeCoverUrl,
    required this.progress,
    required this.hasDropBoost,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _kPink : AppTheme.textPrimary.withValues(alpha: 0.1),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: _kPink.withValues(alpha: 0.28), blurRadius: 14, spreadRadius: 0)]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Thumbnail ────────────────────────────────────────────────
              Image.network(
                episode.thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Image.network(
                  animeCoverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(color: AppTheme.surfaceElevated),
                ),
              ),

              // ── Bottom gradient scrim for text readability ────────────
              Positioned(
                left: 0, right: 0, bottom: 0,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.82)],
                    ),
                  ),
                ),
              ),

              // ── Progress bar at very bottom ───────────────────────────
              if (isSelected && progress > 0.01)
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(_kPink),
                  ),
                ),

              // ── Watched dim overlay ───────────────────────────────────
              if (isWatched && !isSelected)
                Container(color: Colors.black.withValues(alpha: 0.38)),

              // ── EP number + title (bottom-left) ──────────────────────
              Positioned(
                left: 8, right: 8, bottom: isSelected && progress > 0.01 ? 7 : 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'EP ${episode.number}',
                      style: TextStyle(
                        color: isSelected ? _kPink : Colors.white60,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      episode.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // ── Top-right badges ─────────────────────────────────────
              Positioned(
                top: 6, right: 6,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // DROP BOOST badge
                    if (hasDropBoost)
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.highlight.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'DROP',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    // WATCHED checkmark
                    if (isWatched)
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 13),
                      ),
                  ],
                ),
              ),

              // ── Current playing indicator (top-left) ──────────────────
              if (isSelected)
                Positioned(
                  top: 6, left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kPink,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: Colors.white, size: 10),
                        SizedBox(width: 2),
                        Text(
                          'NOW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Progress % pill ───────────────────────────────────────
              if (isSelected && progress > 0.02)
                Positioned(
                  top: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: _kPink.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(
                        color: _kPink,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Episode list tile ────────────────────────────────────────────────────────

class _EpisodeTile extends StatelessWidget {
  final EpisodeModel episode;
  final bool isSelected;
  final bool isWatched;
  final String animeCoverUrl;
  final VoidCallback onTap;
  final double currentProgress;

  const _EpisodeTile({
    required this.episode,
    required this.isSelected,
    required this.isWatched,
    required this.animeCoverUrl,
    required this.onTap,
    this.currentProgress = 0.0,   // ← CW V2
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: _kPinkSubtle,
      highlightColor: _kPinkSubtle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.surfaceElevated : AppTheme.surface,
          border: Border.all(
            color: isSelected ? _kPinkBorder : AppTheme.textPrimary.withValues(alpha: 0.1),
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _kPink.withValues(alpha: 0.15),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        child: Row(
          children: [
            _EpisodeThumbnail(
              thumbnailUrl: episode.thumbnailUrl,
              fallbackUrl: animeCoverUrl,
              episodeNumber: episode.number,
              isSelected: isSelected,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'EP ${episode.number}',
                            style: TextStyle(
                              color: isSelected ? _kPink : _kWhite40,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            const _EqualizerWave(),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          if (isSelected && currentProgress > 0.02) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withValues(alpha: 0.13),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AppTheme.accent.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                '${(currentProgress * 100).round()}%',
                                style: const TextStyle(
                                  color: AppTheme.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (isWatched) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 11,
                                    color: AppTheme.success,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Selesai',
                                    style: TextStyle(
                                      color: AppTheme.success,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Icon(Icons.access_time_rounded,
                              size: 11, color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                          const SizedBox(width: 3),
                          Text(
                            episode.duration,
                            style: TextStyle(
                                color: AppTheme.textSecondary.withValues(alpha: 0.6), fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    episode.title,
                    style: TextStyle(
                      color:
                          isSelected
                              ? AppTheme.textPrimary
                              : AppTheme.textPrimary.withValues(alpha: 0.86),
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // CW V2: progress bar hanya tampil jika episode sedang dipilih
                  // dan menggunakan currentProgress (bukan hardcoded 0.31).
                  if (isSelected) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: currentProgress,          // ← FIX: was 0.31
                        minHeight: 2.5,
                        backgroundColor: AppTheme.background,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(_kPink),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Episode thumbnail ────────────────────────────────────────────────────────

class _EpisodeThumbnail extends StatelessWidget {
  final String thumbnailUrl;
  final String fallbackUrl;
  final int episodeNumber;
  final bool isSelected;

  const _EpisodeThumbnail({
    required this.thumbnailUrl,
    required this.fallbackUrl,
    required this.episodeNumber,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: SizedBox(
        width: 104,
        height: 60,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Image: episode thumbnail → anime cover → solid fallback ──
            Image.network(
              thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Image.network(
                fallbackUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(color: _kSurface),
              ),
            ),

            // ── Dark overlay — always present, stronger when selected ────
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isSelected
                      ? [
                          Colors.black.withValues(alpha: 0.55),
                          Colors.black.withValues(alpha: 0.72),
                        ]
                      : [
                          Colors.black.withValues(alpha: 0.18),
                          Colors.black.withValues(alpha: 0.50),
                        ],
                ),
              ),
            ),

            // ── Episode number badge (top-left) ──────────────────────────
            Positioned(
              top: 5,
              left: 5,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? _kPink : Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(4),
                  border: isSelected
                      ? null
                      : Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                          width: 0.5,
                        ),
                ),
                child: Text(
                  'EP $episodeNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),

            // ── Playing indicator (center, only when selected) ───────────
            if (isSelected)
              const Center(child: _PlayingIndicator()),
          ],
        ),
      ),
    );
  }
}

// ─── Animated playing bars indicator ─────────────────────────────────────────

class _PlayingIndicator extends StatefulWidget {
  const _PlayingIndicator();

  @override
  State<_PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<_PlayingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _bars;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _bars = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + i * 80),
      )..repeat(reverse: true),
    );
    _anims = _bars
        .map((c) => Tween<double>(begin: 0.25, end: 1.0).animate(
              CurvedAnimation(parent: c, curve: Curves.easeInOut),
            ))
        .toList();
    Future.delayed(const Duration(milliseconds: 150),
        () { if (mounted) _bars[1].forward(); });
    Future.delayed(const Duration(milliseconds: 300),
        () { if (mounted) _bars[2].forward(); });
    _bars[0].forward();
  }

  @override
  void dispose() {
    for (final c in _bars) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _anims[i],
          builder: (_, _) => Container(
            width: 3.5,
            height: 16 * _anims[i].value,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: _kPink,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}



// ─── Data models untuk komentar ───────────────────────────────────────────

class _MockUser {
  final String name;
  final int level;
  final String rank;
  final String frameEmoji;
  final String colorHex; // AppTheme color hex string

  const _MockUser(this.name, this.level, this.rank, this.frameEmoji, this.colorHex);

  Color get rankColor {
    final hex = colorHex.replaceAll('0xFF', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}

class _Comment {
  final _MockUser user;
  final String text;
  final DateTime time;
  final bool isOwn;

  const _Comment(this.user, this.text, this.time, {this.isOwn = false});
}

// ─── Panel tab button ─────────────────────────────────────────────────────

class _PanelTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final String? badge;
  final VoidCallback onTap;

  const _PanelTab({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? AppTheme.highlight : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? AppTheme.highlight : AppTheme.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? AppTheme.highlight : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.highlight.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      color: AppTheme.highlight,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Comment tile ─────────────────────────────────────────────────────────

class _CommentTile extends StatelessWidget {
  final _Comment comment;
  const _CommentTile({required this.comment});

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    return '${diff.inDays}h lalu';
  }

  @override
  Widget build(BuildContext context) {
    final u = comment.user;
    final isOwn = comment.isOwn;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isOwn
            ? AppTheme.highlight.withValues(alpha: 0.06)
            : AppTheme.surfaceElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOwn
              ? AppTheme.highlight.withValues(alpha: 0.2)
              : AppTheme.textSecondary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: avatar + nama + rank + waktu
          Row(
            children: [
              // Frame avatar
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: u.rankColor.withValues(alpha: 0.15),
                  border: Border.all(color: u.rankColor.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Center(child: Text(u.frameEmoji, style: const TextStyle(fontSize: 14))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isOwn ? 'Kamu' : u.name,
                          style: TextStyle(
                            color: isOwn ? AppTheme.highlight : AppTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Level badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: u.rankColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Lv.${u.level}',
                            style: TextStyle(
                              color: u.rankColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      u.rank,
                      style: TextStyle(color: u.rankColor.withValues(alpha: 0.8), fontSize: 10),
                    ),
                  ],
                ),
              ),
              Text(
                _timeAgo(comment.time),
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Isi komentar
          Text(
            comment.text,
            style: TextStyle(
              color: AppTheme.textPrimary.withValues(alpha: 0.9),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Equalizer Wave Animation ───────────────────────────────────────────────
class _EqualizerWave extends StatefulWidget {
  const _EqualizerWave();

  @override
  State<_EqualizerWave> createState() => _EqualizerWaveState();
}

class _EqualizerWaveState extends State<_EqualizerWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final val = _anim.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _bar(6 + (val * 8)),
            const SizedBox(width: 2),
            _bar(12 - (val * 6)),
            const SizedBox(width: 2),
            _bar(4 + (val * 10)),
          ],
        );
      },
    );
  }

  Widget _bar(double h) {
    return Container(
      width: 2.5,
      height: h.clamp(3.0, 14.0),
      decoration: BoxDecoration(
        color: _kPink,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: _kPink.withValues(alpha: 0.6),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}
