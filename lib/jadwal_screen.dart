// jadwal_screen.dart — AniVerse Premium Release: Jadwal Rilis
// Weekly release schedule with cinematic light-mode polish.

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'anime_api_service.dart';
import 'mock_data_service.dart';
import 'anime_model.dart';
import 'anime_detail_screen.dart';
import 'app_theme.dart';
import 'theme/aniverse_theme.dart';
import 'widgets/dashboard_sections.dart';
import 'notification_service.dart';
import 'proxied_network_image.dart';
import 'widgets/liquid_glass.dart';
import 'catalog_store.dart';



// ─── REMINDER STORE ─────────────────────────────────────────────────────────
// Persists which anime IDs the user has enabled a release reminder for.
// Stored as a single SharedPreferences string-set — cheap to load/save and
// avoids one key per anime.
//
// NOTE ON ACTUAL NOTIFICATIONS: this store only tracks the on/off *state*
// of the bell toggle so the UI can render correctly across app restarts.
// It deliberately does NOT schedule a native OS notification itself —
// wiring that up needs `flutter_local_notifications` (with its own Android
// manifest permissions and iOS entitlements), which isn't confirmed to be
// in this project's pubspec.yaml yet. `ReminderService.onToggle` below is
// the single hook to fill in once that package is added: call
// `flutterLocalNotificationsPlugin.zonedSchedule(...)` there using the
// anime's `nextEpisodeAt` when `enabled == true`, and `.cancel(id)` when
// `enabled == false`. Until then, toggling the bell just updates this
// local flag so the UI is honest about what it can currently guarantee.
class ReminderService {
  ReminderService._();

  static const _prefsKey = 'jadwal_reminders_enabled';
  static Set<String>? _cache;

  static Future<Set<String>> _load() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    _cache = (prefs.getStringList(_prefsKey) ?? const []).toSet();
    return _cache!;
  }

  static Future<void> _persist() async {
    if (_cache == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _cache!.toList());
  }

  /// Synchronous check once the cache is warm; false before first load.
  static bool isEnabledSync(String animeId) =>
      _cache?.contains(animeId) ?? false;

  /// Read-only snapshot of every anime ID with reminders on. Used by the
  /// day-tab badge dots and the "Diingatkan" filter chip — both need to
  /// check membership across many IDs at once rather than one at a time.
  /// Empty (not null) before warmUp() resolves, so callers don't need a
  /// separate loading branch.
  static Set<String> get enabledIdsSync => _cache ?? const {};

  static Future<bool> isEnabled(String animeId) async {
    final set = await _load();
    return set.contains(animeId);
  }

  /// Flips the reminder for [animeId] and persists it. Returns the new
  /// enabled state. On enable, requests notification permission (if not
  /// already granted) and schedules an exact-time OS notification for
  /// [episodeAirsAt]; on disable, cancels any pending one. [animeTitle] and
  /// [episodeAirsAt] are optional so this still works as a pure on/off
  /// toggle if the caller doesn't have that info handy — in that case no
  /// actual notification is scheduled, only the local flag changes.
  ///
  /// Errors from the notification plugin (e.g. setup steps in
  /// notification_service.dart not finished yet — manifest permissions
  /// missing, pubspec not yet pub-get'd) are caught and swallowed here
  /// rather than propagated: a half-finished notification setup should
  /// degrade to "reminder toggle works, but no actual alarm fires" rather
  /// than crash the whole toggle interaction. onToggle still fires
  /// normally either way, so the UI stays responsive; check your IDE's
  /// debug console for the printed error if reminders aren't arriving.
  static Future<bool> toggle(
    String animeId, {
    String? animeTitle,
    DateTime? episodeAirsAt,
    void Function(bool enabled)? onToggle,
  }) async {
    final set = await _load();
    final nowEnabled = !set.contains(animeId);
    if (nowEnabled) {
      set.add(animeId);
    } else {
      set.remove(animeId);
    }
    await _persist();

    try {
      if (nowEnabled && animeTitle != null && episodeAirsAt != null) {
        final granted = await NotificationService.requestPermissions();
        if (granted) {
          await NotificationService.scheduleReminder(
            animeId: animeId,
            animeTitle: animeTitle,
            episodeAirsAt: episodeAirsAt,
          );
        }
      } else if (!nowEnabled) {
        await NotificationService.cancelReminder(animeId);
      }
    } catch (e) {
      // ignore: avoid_print
      print('[ReminderService] notification scheduling failed (is '
          'notification_service.dart fully set up yet? see its setup '
          'checklist): $e');
    }

    onToggle?.call(nowEnabled);
    return nowEnabled;
  }

  /// Call once at app/screen startup so isEnabledSync works immediately.
  static Future<void> warmUp() => _load();
}

// ─── REMINDER BELL ──────────────────────────────────────────────────────────
// Small tappable bell shown on each anime card. Reflects and toggles
// ReminderService state. Kept as its own StatefulWidget (rather than lifting
// state into _JadwalScreenState) so tapping one bell doesn't rebuild the
// entire list — each card manages its own reminder flag independently.
class _ReminderBell extends StatefulWidget {
  const _ReminderBell({
    required this.animeId,
    required this.animeTitle,
    this.episodeAirsAt,
    this.onChanged,
  });

  final String animeId;
  final String animeTitle;
  // Null when the anime has no known real release timestamp (e.g. mock
  // data without nextEpisodeAt) — in that case the bell still toggles the
  // on/off flag, but no actual OS notification gets scheduled, since there
  // would be nothing real to schedule it against.
  final DateTime? episodeAirsAt;
  // Notifies the parent screen after a successful toggle, so things that
  // depend on the AGGREGATE reminder state across all cards — the day-tab
  // badge dot, the "Diingatkan" filter chip — can rebuild. This bell's own
  // visual state is still managed locally; this is purely a "something
  // changed, you may want to refresh" signal upward.
  final VoidCallback? onChanged;

  @override
  State<_ReminderBell> createState() => _ReminderBellState();
}

class _ReminderBellState extends State<_ReminderBell> {
  bool _enabled = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    // Sync path first (instant if the store's already warm from
    // ReminderService.warmUp() in initState of the parent screen), then a
    // proper async check as a safety net in case that warm-up hasn't
    // resolved yet.
    _enabled = ReminderService.isEnabledSync(widget.animeId);
    ReminderService.isEnabled(widget.animeId).then((value) {
      if (mounted) setState(() {
        _enabled = value;
        _loaded = true;
      });
    });
  }

  Future<void> _handleTap() async {
    HapticFeedback.selectionClick();
    final newState = await ReminderService.toggle(
      widget.animeId,
      animeTitle: widget.animeTitle,
      episodeAirsAt: widget.episodeAirsAt,
    );
    if (!mounted) return;
    setState(() => _enabled = newState);
    widget.onChanged?.call();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.surfaceElevated,
        content: Text(
          newState
              ? (widget.episodeAirsAt != null
                  ? 'Pengingat diaktifkan — kamu akan diberi tahu sebelum tayang'
                  : 'Pengingat diaktifkan untuk anime ini')
              : 'Pengingat dimatikan',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 12.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _enabled ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _enabled
                ? AppTheme.accent.withOpacity(0.16)
                : AppTheme.surfaceElevated.withOpacity(0.55),
            border: Border.all(
              color: _enabled
                  ? AppTheme.accent.withOpacity(0.35)
                  : AppTheme.textSecondary.withOpacity(0.15),
            ),
          ),
          child: Icon(
            _enabled ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
            size: 15,
            color: _enabled
                ? AppTheme.accent
                : AppTheme.textSecondary.withOpacity(0.65),
          ),
        ),
      ),
    );
  }
}

// ─── LIVE COUNTDOWN ─────────────────────────────────────────────────────────
// Self-refreshing countdown text — recomputes from `nextEpisodeAt` every 30
// seconds via its own Timer, so the "Xj Ym lagi" text stays accurate without
// needing the whole JadwalScreen (list, day selector, header) to rebuild.
// Each card owns one of these, so only the countdown row repaints on tick.
class _LiveCountdown extends StatefulWidget {
  const _LiveCountdown({required this.nextEpisodeAt});

  final DateTime nextEpisodeAt;

  @override
  State<_LiveCountdown> createState() => _LiveCountdownState();
}

class _LiveCountdownState extends State<_LiveCountdown>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  AnimationController? _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  AnimationController _ensurePulse() {
    return _pulseCtrl ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diff = widget.nextEpisodeAt.difference(DateTime.now());
    final isLive = diff.isNegative;
    final isImminent = !isLive && diff.inMinutes < 60;

    final String text;
    if (isLive) {
      text = 'Tayang sekarang';
    } else if (diff.inDays > 0) {
      text = '${diff.inDays}h ${diff.inHours % 24}j lagi';
    } else if (diff.inHours > 0) {
      text = '${diff.inHours}j ${diff.inMinutes % 60}m lagi';
    } else {
      text = '${diff.inMinutes}m lagi';
    }

    final color = isLive || isImminent ? AppTheme.highlight : AppTheme.highlight.withValues(alpha: 0.9);

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isLive ? Icons.podcasts_rounded : Icons.timer_rounded,
          size: 11,
          color: color.withValues(alpha: 0.85),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );

    // Only the imminent (<1h) or currently-airing case pulses — a subtle
    // breathing opacity that draws the eye without being distracting on
    // every card on screen. The AnimationController is created lazily and
    // disposed on unmount, so cards that never go imminent never pay for
    // an idle ticker.
    if (!isLive && !isImminent) return row;

    final ctrl = _ensurePulse();
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, child) => Opacity(
        opacity: 0.6 + (ctrl.value * 0.4),
        child: child,
      ),
      child: row,
    );
  }
}

enum _SortMode { time, rating }

// Extra filter dimension alongside genre — 'reminded' shows only anime with
// an active reminder toggle, 'unwatched' hides anime already marked watched.
// Kept separate from genre (rather than folding into one filter enum)
// because a user might reasonably want both a genre AND a status filter
// active at once (e.g. "Action" + "Belum ditonton").
enum _StatusFilter { all, reminded, unwatched }

// ─── WATCHED STORE ──────────────────────────────────────────────────────────
// Persists which anime IDs the user has marked as watched for the current
// episode. Same pattern as ReminderService — one SharedPreferences
// string-set, cheap to load/save.
//
// NOTE: this tracks "did the user mark this episode as watched" as a
// manual flag on the Jadwal card. When the anime's latest episode number
// is known (see [toggle]'s episodeNumber param), it also mirrors into
// MockDataService's per-episode watched history so Library reflects the
// same mark. It stays independent of automatic watch-progress tracking
// (video position, resume points) — that answers a different question
// (how far into the episode) than this one (did you catch today's release).
class WatchedStore {
  WatchedStore._();

  static const _prefsKey = 'jadwal_watched_ids';
  static Set<String>? _cache;

  static Future<Set<String>> _load() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    _cache = (prefs.getStringList(_prefsKey) ?? const []).toSet();
    return _cache!;
  }

  static Future<void> _persist() async {
    if (_cache == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _cache!.toList());
  }

  static bool isWatchedSync(String animeId) => _cache?.contains(animeId) ?? false;

  /// Read-only snapshot of every watched anime ID. Used for the
  /// "Belum ditonton" filter chip and for sorting watched cards to the
  /// bottom of the list.
  static Set<String> get watchedIdsSync => _cache ?? const {};

  static Future<bool> isWatched(String animeId) async {
    final set = await _load();
    return set.contains(animeId);
  }

  /// Toggles the manual "watched" flag for [animeId] and persists it.
  /// [episodeNumber] is optional: when provided (Jadwal knows the anime's
  /// latest episode number), this also mirrors the change into Library's
  /// per-episode history via [MockDataService.markEpisodeWatched] /
  /// [MockDataService.unmarkEpisodeWatched], so a card marked watched here
  /// shows up consistently in Library too. When null (episode list was
  /// empty/unknown), only this screen's own flag changes — Library history
  /// is left untouched rather than guessing an episode number.
  static Future<bool> toggle(String animeId, {int? episodeNumber}) async {
    final set = await _load();
    final nowWatched = !set.contains(animeId);
    if (nowWatched) {
      set.add(animeId);
    } else {
      set.remove(animeId);
    }
    await _persist();
    // ignore: avoid_print
    print('[WatchedStore] toggle animeId=$animeId nowWatched=$nowWatched episodeNumber=$episodeNumber');
    if (episodeNumber != null) {
      if (nowWatched) {
        MockDataService.markEpisodeWatched(
          animeId: animeId,
          episodeNumber: episodeNumber,
        );
        // ignore: avoid_print
        print('[WatchedStore] called markEpisodeWatched, watchedEpisodesNotifier now = ${MockDataService.watchedEpisodesNotifier.value}');
      } else {
        MockDataService.unmarkEpisodeWatched(
          animeId: animeId,
          episodeNumber: episodeNumber,
        );
      }
    } else {
      // ignore: avoid_print
      print('[WatchedStore] episodeNumber is null — SKIPPING Library sync');
    }
    return nowWatched;
  }

  static Future<void> warmUp() => _load();
}

// ─── WATCHED WRAPPER ────────────────────────────────────────────────────────
// Wraps a fully-built anime card (from _animeCard) to add:
//   1. A dim/opacity treatment once marked watched, so watched cards recede
//      visually and unwatched ones stand out.
//   2. A small checkbox badge overlaid in the top-right corner to toggle
//      that state, positioned so it never overlaps the existing bell/badge
//      column on the card's right side (those sit lower, under the header).
//
// This wraps the card rather than modifying _animeCard's internals — the
// existing card layout has several nested Stacks/Rows already, and bolting
// the toggle on from outside avoids reopening all that existing code (a
// common source of cascade edits/breakage in this file).
class _WatchedWrapper extends StatefulWidget {
  const _WatchedWrapper({required this.anime, required this.child, this.onChanged});

  final AnimeModel anime;
  final Widget child;
  final VoidCallback? onChanged;

  @override
  State<_WatchedWrapper> createState() => _WatchedWrapperState();
}

class _WatchedWrapperState extends State<_WatchedWrapper> {
  bool _watched = false;
  bool _resolvingEpisode = false;

  String get _animeId => widget.anime.id.toString();

  @override
  void initState() {
    super.initState();
    _watched = WatchedStore.isWatchedSync(_animeId);
    WatchedStore.isWatched(_animeId).then((value) {
      if (mounted) setState(() => _watched = value);
    });
  }

  Future<void> _toggle() async {
    HapticFeedback.selectionClick();
    // ignore: avoid_print
    print('[WatchedToggle] start animeId=$_animeId, anime.episodes.length=${widget.anime.episodes.length}');
    // Anime coming from the live Jikan season list always has an empty
    // `episodes` list (season endpoint doesn't include it) — only the
    // custom-catalog/mock path pre-fills it. So we can't just read
    // anime.episodes.last.number here; when it's empty we fetch the real
    // episode list on-demand via the same API call the detail screen
    // uses (cached after first call, so this is cheap on repeat toggles).
    int? episodeNumber = widget.anime.episodes.isEmpty
        ? null
        : widget.anime.episodes.last.number;

    if (episodeNumber == null) {
      // ignore: avoid_print
      print('[WatchedToggle] episodes empty, fetching from API for $_animeId');
      setState(() => _resolvingEpisode = true);
      try {
        final fetched = await AnimeApiService.fetchAnimeEpisodes(_animeId);
        // ignore: avoid_print
        print('[WatchedToggle] fetched ${fetched.length} episodes for $_animeId');
        if (fetched.isNotEmpty) episodeNumber = fetched.last.number;
      } catch (e, st) {
        // ignore: avoid_print
        print('[WatchedToggle] fetchAnimeEpisodes FAILED for $_animeId: $e\n$st');
        // Network/parse failure — proceed without Library sync rather
        // than blocking the user's watched toggle on it.
      }
      if (mounted) setState(() => _resolvingEpisode = false);
    }

    // ignore: avoid_print
    print('[WatchedToggle] resolved episodeNumber=$episodeNumber for $_animeId, calling WatchedStore.toggle');
    final newState = await WatchedStore.toggle(_animeId, episodeNumber: episodeNumber);
    // ignore: avoid_print
    print('[WatchedToggle] done, newState=$newState');
    if (mounted) setState(() => _watched = newState);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AnimatedOpacity(
          opacity: _watched ? 0.52 : 1.0,
          duration: const Duration(milliseconds: 220),
          child: widget.child,
        ),
        Positioned(
          top: 10,
          left: 10,
          child: GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _watched
                    ? AppTheme.accent.withOpacity(0.85)
                    : Colors.black.withValues(alpha: 0.28),
                border: Border.all(
                  color: _watched
                      ? AppTheme.accent
                      : Colors.white.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: _resolvingEpisode
                  ? const Padding(
                      padding: EdgeInsets.all(4),
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: Colors.white,
                      ),
                    )
                  : (_watched
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : null),
            ),
          ),
        ),
      ],
    );
  }
}

class JadwalScreen extends StatefulWidget {
  const JadwalScreen({super.key});

  @override
  State<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen>
    with SingleTickerProviderStateMixin {
  static const _dayNames = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  static const _dayShort = ['SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MIN'];

  List<AnimeModel> _animes = const [];
  bool _loading = true;
  bool _failed = false;
  late int _selectedDay;
  late final ScrollController _dayStripCtrl;
  late final AnimationController _livePulseCtrl;
  late final Animation<double> _livePulse;

  // 'Semua' means no genre filter applied. Genre chips are derived from
  // whatever's actually in _animes for the selected day, so this list never
  // shows a genre with zero results for the current day.
  String _selectedGenre = 'Semua';
  _SortMode _sortMode = _SortMode.time;
  _StatusFilter _statusFilter = _StatusFilter.all;
  bool _searchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  int get _todayIndex => (DateTime.now().weekday - 1).clamp(0, 6);

  @override
  void initState() {
    super.initState();
    _selectedDay = _todayIndex;
    _dayStripCtrl = ScrollController();
    _livePulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _livePulse = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _livePulseCtrl, curve: Curves.easeInOut),
    );
    _load();
    CatalogStore.instance.addListener(_onCatalogChanged);
    ReminderService.warmUp().then((_) {
      if (mounted) setState(() {});
    });
    WatchedStore.warmUp().then((_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerDayStrip());
  }

  @override
  void dispose() {
    CatalogStore.instance.removeListener(_onCatalogChanged);
    _dayStripCtrl.dispose();
    _livePulseCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onCatalogChanged() {
    if (!mounted || _loading) return;
    setState(() {
      _animes = CatalogStore.instance.mergeWithLive(_animes);
    });
  }

  void _centerDayStrip() {
    if (!_dayStripCtrl.hasClients) return;
    final target = (_selectedDay * 76.0) - 100;
    _dayStripCtrl.animateTo(
      target.clamp(0, _dayStripCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _selectDay(int i) {
    if (i == _selectedDay) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDay = i;
      // The previously-selected genre chip might not exist on the new day
      // (e.g. "Horror" filtered on Monday, switching to a Tuesday with no
      // Horror anime) — reset rather than silently show an empty list.
      _selectedGenre = 'Semua';
      _statusFilter = _StatusFilter.all;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerDayStrip());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _animes = CatalogStore.instance.getCustomCatalog();
      _loading = false;
      _failed = false;
    });
  }

  int _dayOf(AnimeModel a) => a.releaseDay != null ? (a.releaseDay! - 1).clamp(0, 6) : a.id.hashCode.abs() % 7;

  String _timeOf(AnimeModel a) {
    if (a.nextEpisodeAt != null) {
      final h = a.nextEpisodeAt!.hour.toString().padLeft(2, '0');
      final m = a.nextEpisodeAt!.minute.toString().padLeft(2, '0');
      return '$h.$m';
    }
    final base = a.id.hashCode.abs();
    final h = 17 + (base % 6);
    final m = (base ~/ 7) % 2 == 0 ? '00' : '30';
    return '${h.toString().padLeft(2, '0')}.$m';
  }

  // Countdown text logic now lives in _LiveCountdown (self-refreshing widget
  // below), so it can tick every 30s without rebuilding this whole screen.

  int _episodeOf(AnimeModel a) => 1 + (a.id.hashCode.abs() % 12);

  int _countForDay(int day) => _animes.where((a) => _dayOf(a) == day).length;

  String get _seasonLabel {
    final now = DateTime.now();
    const seasons = ['Musim Semi', 'Musim Panas', 'Musim Gugur', 'Musim Dingin'];
    final idx = ((now.month - 1) ~/ 3).clamp(0, 3);
    return '${seasons[idx]} ${now.year}';
  }

  /// The anime with the soonest still-upcoming release, across ALL days —
  /// not just the currently-selected day tab. Used for the next-up banner
  /// under the header, so it stays useful regardless of which day the user
  /// happens to be looking at. Only considers anime with a real
  /// `nextEpisodeAt` in the future; returns null if nothing qualifies (e.g.
  /// still loading, or every known release this week has already passed —
  /// mock/fallback anime without a real timestamp are excluded rather than
  /// guessed at, since a wrong "next up" claim is worse than none).
  AnimeModel? get _nextUpAnime {
    if (_loading || _failed || _animes.isEmpty) return null;
    final now = DateTime.now();
    final upcoming = _animes
        .where((a) => a.nextEpisodeAt != null && a.nextEpisodeAt!.isAfter(now))
        .toList()
      ..sort((a, b) => a.nextEpisodeAt!.compareTo(b.nextEpisodeAt!));
    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  List<AnimeModel> _animesForDay(int day) {
    var list = _animes.where((a) => _dayOf(a) == day);
    if (_selectedGenre != 'Semua') {
      list = list.where((a) {
        final primaryGenre = a.genre.isNotEmpty ? a.genre.split(',').first.trim() : 'Anime';
        return primaryGenre == _selectedGenre;
      });
    }
    switch (_statusFilter) {
      case _StatusFilter.all:
        break;
      case _StatusFilter.reminded:
        list = list.where((a) => ReminderService.enabledIdsSync.contains(a.id.toString()));
        break;
      case _StatusFilter.unwatched:
        list = list.where((a) => !WatchedStore.watchedIdsSync.contains(a.id.toString()));
        break;
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((a) => titleOfAnime(a).toLowerCase().contains(q));
    }
    final result = list.toList();
    final watched = WatchedStore.watchedIdsSync;
    // Watched-to-bottom is folded into the SAME comparator as the primary
    // sort (time or rating) rather than sorted separately — List.sort in
    // Dart isn't guaranteed stable, so a second standalone sort() call
    // could scramble the primary ordering instead of just moving watched
    // items down within it.
    final sinkWatched = _statusFilter != _StatusFilter.unwatched;
    int primaryCompare(AnimeModel a, AnimeModel b) {
      switch (_sortMode) {
        case _SortMode.time:
          return _timeOf(a).compareTo(_timeOf(b));
        case _SortMode.rating:
          final ra = ratingOfAnime(a);
          final rb = ratingOfAnime(b);
          // Treat "no rating yet" (0) as lowest regardless of sort
          // direction — an unrated anime shouldn't outrank a genuinely
          // low-but-real rating, and shouldn't be scattered randomly among
          // rated ones either.
          if (ra <= 0 && rb <= 0) return 0;
          if (ra <= 0) return 1;
          if (rb <= 0) return -1;
          return rb.compareTo(ra);
      }
    }

    result.sort((a, b) {
      if (sinkWatched) {
        final aWatched = watched.contains(a.id.toString());
        final bWatched = watched.contains(b.id.toString());
        if (aWatched != bWatched) return aWatched ? 1 : -1;
      }
      return primaryCompare(a, b);
    });
    return result;
  }

  /// Genres present among today's/selected-day's anime, for the filter
  /// chips. Computed from the UNFILTERED day list (ignores _selectedGenre)
  /// so switching genres doesn't make other genre chips disappear.
  List<String> _genresForDay(int day) {
    final genres = _animes
        .where((a) => _dayOf(a) == day)
        .map((a) => a.genre.isNotEmpty ? a.genre.split(',').first.trim() : 'Anime')
        .toSet()
        .toList()
      ..sort();
    return ['Semua', ...genres];
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final filtered = _animesForDay(_selectedDay);
    final isToday = _selectedDay == _todayIndex;
    // Featured cover for the glass backdrop — today's first-airing anime,
    // sorted the same way the day list already sorts. Falls back to any
    // anime in the full list if today happens to have none scheduled yet
    // (empty state), so the glass backdrop isn't blank on a slow day.
    final backdropSource = _animesForDay(_todayIndex).isNotEmpty
        ? _animesForDay(_todayIndex).first
        : (_animes.isNotEmpty ? _animes.first : null);
    final backdropCandidates = backdropSource != null
        ? corsProxyCandidates(coverOfAnime(backdropSource))
        : const <String>[];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          _atmosphere(),
          // ── Glass backdrop ── Real photographic detail behind the header
          // and day selector, so BackdropFilter blur has texture/light to
          // refract. A radial-gradient orb alone (the previous attempt) is
          // mathematically flat — no amount of blur strength makes a solid
          // color look like glass, because there's no light variation to
          // bend. This mirrors the home screen hero's same underlying fix.
          // Placed AFTER _atmosphere() in the stack (i.e. drawn on top of
          // it) — it was previously placed before, so the atmosphere's
          // solid-alpha orbs were painting over and hiding this image.
          if (backdropCandidates.isNotEmpty)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              // Tall enough to cover header + next-up banner + day selector
              // on virtually any phone height, plus extra runway before the
              // fade so the image never visibly ends before the content
              // below it — it was previously cut short on taller screens.
              height: 1100,
              child: ShaderMask(
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.black, Colors.transparent],
                  stops: const [0.0, 0.96, 1.0],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: ProxiedNetworkImage(
                  candidates: backdropCandidates,
                  title: backdropSource != null ? titleOfAnime(backdropSource) : null,
                  width: double.infinity,
                  height: 1100,
                  // Anchor the crop toward the top of the source image so
                  // BoxFit.cover trims from the bottom/sides rather than
                  // squashing — cover never distorts aspect ratio, but a
                  // centered crop on a portrait cover can lose the top of
                  // the character art, which read as "gepeng" before.
                  alignment: Alignment.topCenter,
                  fit: BoxFit.cover,
                  colorFilterColor: Colors.black.withValues(alpha: 0.58),
                  colorBlendMode: BlendMode.darken,
                  fallback: const SizedBox.shrink(),
                ),
              ),
            ),
          RefreshIndicator(
            color: AppTheme.accent,
            backgroundColor: AppTheme.surfaceElevated,
            strokeWidth: 2.4,
            displacement: 48,
            triggerMode: RefreshIndicatorTriggerMode.onEdge,
            onRefresh: _load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: safeTop + 12)),
                SliverToBoxAdapter(child: _header()),
                SliverToBoxAdapter(child: _nextUpBanner()),
                SliverToBoxAdapter(child: const SizedBox(height: 16)),
                SliverToBoxAdapter(child: _daySelector()),
                SliverToBoxAdapter(child: const SizedBox(height: 8)),
                SliverToBoxAdapter(child: _daySummary(isToday, filtered.length)),
                SliverToBoxAdapter(child: _statusFilterBar(_selectedDay)),
                SliverToBoxAdapter(child: _filterSortBar(_selectedDay)),
                if (_loading)
                  SliverToBoxAdapter(
                    key: const ValueKey('loading'),
                    child: _skeletonList(),
                  )
                else if (_failed)
                  SliverFillRemaining(
                    key: const ValueKey('failed'),
                    hasScrollBody: false,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _errorState(),
                    ),
                  )
                else if (filtered.isEmpty)
                  SliverFillRemaining(
                    key: ValueKey('empty_${_selectedDay}_$_selectedGenre'),
                    hasScrollBody: false,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _emptyState(),
                    ),
                  )
                else
                  SliverPadding(
                    key: ValueKey('list_${_selectedDay}_$_selectedGenre'),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) => FadeSlideIn(
                        key: ValueKey('${_selectedDay}_${_selectedGenre}_${filtered[i].id}'),
                        delay: Duration(milliseconds: 45 * i),
                        child: _WatchedWrapper(
                          anime: filtered[i],
                          onChanged: () => setState(() {}),
                          child: _animeCard(filtered[i], isToday: isToday),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _atmosphere() {
    return IgnorePointer(
      child: Stack(
        children: [
          // ── Header glow cluster ── Positioned directly behind the header
          // card + day selector (the top ~280px of the scroll). Previous
          // atmosphere orbs sat too far off-screen and too faint (0.08–0.12
          // alpha) to give the glass blur anything real to refract, so the
          // "glass" pills were rendering as flat solid chips over near-blank
          // background. These are bigger, more saturated, and placed to
          // sit right where the header/day-strip glass reads them.
          Positioned(
            top: -40,
            left: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accent.withValues(alpha: 0.38),
                    AppTheme.accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -20,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.highlight.withValues(alpha: 0.32),
                    AppTheme.highlight.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 140,
            left: 60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.glow.withValues(alpha: 0.26),
                    AppTheme.glow.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // ── Lower-page ambient orbs (original, kept fainter) ──
          Positioned(
            bottom: 120,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accent.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LiquidGlassPill(
        borderRadius: AniVerseTheme.radiusXl,
        padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppTheme.accent, AppTheme.glow],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withOpacity(0.38),
                        blurRadius: 18,
                        spreadRadius: 0,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Jadwal Rilis',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Anime musim ini, per hari tayang',
                        style: TextStyle(
                          color: AppTheme.textSecondary.withOpacity(0.95),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      LiquidGlassPill(
                        borderRadius: 999,
                        compact: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 12,
                              color: AppTheme.accent.withOpacity(0.85),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _seasonLabel,
                              style: TextStyle(
                                color: AppTheme.accent.withOpacity(0.92),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedBuilder(
                  animation: _livePulse,
                  builder: (_, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.highlight.withValues(
                            alpha: 0.10 + (_livePulse.value * 0.06),
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppTheme.highlight.withValues(
                              alpha: 0.22 + (_livePulse.value * 0.12),
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.highlight.withValues(
                                alpha: 0.12 * _livePulse.value,
                              ),
                              blurRadius: 12,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppTheme.highlight.withValues(
                                  alpha: _livePulse.value,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'LIVE',
                              style: TextStyle(
                                color: AppTheme.highlight,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }

  /// Compact banner under the header showing the very next anime to air,
  /// regardless of which day tab is selected. Returns an empty SizedBox
  /// (not shown at all) when there's no qualifying upcoming release —
  /// see _nextUpAnime's doc for why that's preferred over a guessed one.
  Widget _nextUpBanner() {
    final next = _nextUpAnime;
    if (next == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => AnimeDetailScreen(anime: next)),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.highlight.withOpacity(0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.highlight.withOpacity(0.28)),
          ),
          child: Row(
            children: [
              Icon(Icons.new_releases_rounded, size: 16, color: AppTheme.highlight),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tayang berikutnya: ${titleOfAnime(next)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _LiveCountdown(nextEpisodeAt: next.nextEpisodeAt!),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textSecondary.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _daySelector() {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        controller: _dayStripCtrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 7,
        itemBuilder: (ctx, i) {
          final selected = i == _selectedDay;
          final isToday = i == _todayIndex;
          final count = _loading ? 0 : _countForDay(i);
          // Whether any anime scheduled on this day has an active reminder
          // — drawn as a small bell dot in the tab's corner so users can
          // spot at a glance which days they've set reminders for, without
          // needing to tap into each day first.
          final hasReminder = !_loading &&
              _animes.any((a) => _dayOf(a) == i && ReminderService.enabledIdsSync.contains(a.id.toString()));

          return GestureDetector(
            onTap: () => _selectDay(i),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 66,
                  height: 72,
                  margin: const EdgeInsets.only(right: 10),
                  child: selected
                      // Selected day keeps the solid accent gradient — it's
                      // meant to read as a filled, opaque "active" state, not
                      // glass, so it stays outside the liquid-glass shell.
                      ? AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.accent, AppTheme.glow],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accent.withOpacity(0.30),
                                blurRadius: 20,
                                spreadRadius: -4,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: _dayPillContent(
                            i: i,
                            selected: selected,
                            isToday: isToday,
                            count: count,
                          ),
                        )
                      // Unselected days use the same thin liquid-glass shell
                      // as the header, for a consistent frosted look across
                      // the whole screen.
                      : LiquidGlassPill(
                          borderRadius: 18,
                          padding: EdgeInsets.zero,
                          alignment: Alignment.center,
                          height: 72,
                          compact: true,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: isToday
                                  ? Border.all(
                                      color: AppTheme.accent.withOpacity(0.40),
                                      width: 1.4,
                                    )
                                  : null,
                            ),
                            child: _dayPillContent(
                              i: i,
                              selected: selected,
                              isToday: isToday,
                              count: count,
                            ),
                          ),
                        ),
                ),
                if (hasReminder)
                  Positioned(
                    top: -2,
                    right: 6,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.highlight,
                        border: Border.all(color: AppTheme.background, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.notifications_rounded,
                        size: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Shared inner content (day label, count badge, today-dot) for both the
  // selected (solid gradient) and unselected (liquid glass) day pills, so
  // the two branches stay visually identical apart from their shell.
  Widget _dayPillContent({
    required int i,
    required bool selected,
    required bool isToday,
    required int count,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
          Text(
            _dayShort[i],
            style: TextStyle(
              color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 5),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: 7,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.textPrimary.withOpacity(0.22)
                  : AppTheme.accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _loading ? '—' : '$count',
              style: TextStyle(
                color: selected ? AppTheme.textPrimary : AppTheme.accent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (isToday) ...[
            const SizedBox(height: 4),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: selected ? AppTheme.textPrimary : AppTheme.accent,
                shape: BoxShape.circle,
              ),
            ),
          ],
          ],
        ),
      ),
    );
  }

  Widget _daySummary(bool isToday, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: _searchOpen ? _searchField() : _daySummaryRow(isToday, count),
    );
  }

  Widget _searchField() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface.withOpacity(0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 17, color: AppTheme.textSecondary.withOpacity(0.7)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13.5),
                    cursorColor: AppTheme.accent,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Cari judul anime…',
                      hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5), fontSize: 13.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _searchOpen = false;
              _searchQuery = '';
              _searchCtrl.clear();
            });
          },
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.surface.withOpacity(0.78),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.surface),
            ),
            child: Icon(Icons.close_rounded, size: 17, color: AppTheme.textSecondary.withOpacity(0.85)),
          ),
        ),
      ],
    );
  }

  Widget _daySummaryRow(bool isToday, int count) {
    return Row(
        children: [
          if (isToday) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.redAccent, // Tetap merah untuk indikator bahaya
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.45),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              isToday
                  ? 'Hari ini, ${_dayNames[_selectedDay]}'
                  : _dayNames[_selectedDay],
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (!_loading && !_failed) ...[
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _searchOpen = true);
              },
              child: Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.surface.withOpacity(0.78),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.surface),
                ),
                child: Icon(Icons.search_rounded, size: 16, color: AppTheme.textSecondary.withOpacity(0.85)),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.surface.withOpacity(0.78),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.surface),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                '$count anime',
                style: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.95),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
    );
  }

  /// Genre filter chips (horizontally scrollable) plus a compact sort
  /// toggle (time vs rating), scoped to whichever day is currently selected.
  /// Status chips (Diingatkan / Belum ditonton) render above this row via
  /// _statusFilterBar, called separately so a day with no reminders/watched
  /// items yet doesn't show a pointless empty status row.
  Widget _filterSortBar(int day) {
    if (_loading || _failed) return const SizedBox.shrink();
    final genres = _genresForDay(day);
    // Only one genre present ("Semua" + itself) means filtering wouldn't do
    // anything useful — skip the row entirely rather than show a single
    // useless chip.
    if (genres.length <= 2) return _sortOnlyBar();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: genres.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (ctx, i) {
                  final g = genres[i];
                  final selected = g == _selectedGenre;
                  return GestureDetector(
                    onTap: () {
                      if (selected) return;
                      HapticFeedback.selectionClick();
                      setState(() => _selectedGenre = g);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.accent.withOpacity(0.16)
                            : AppTheme.surface.withOpacity(0.70),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: selected
                              ? AppTheme.accent.withOpacity(0.45)
                              : AppTheme.textSecondary.withOpacity(0.14),
                        ),
                      ),
                      child: Text(
                        g,
                        style: TextStyle(
                          color: selected ? AppTheme.accent : AppTheme.textSecondary.withOpacity(0.85),
                          fontSize: 11.5,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          _sortToggle(),
        ],
      ),
    );
  }

  /// Status filter row: "Diingatkan" and "Belum ditonton" toggle chips.
  /// Counts are computed against the selected day's UNFILTERED list (genre
  /// filter ignored) so the chip reflects "how many today", not "how many
  /// after other filters" — that would make the number confusingly shrink
  /// as other filters get applied.
  Widget _statusFilterBar(int day) {
    if (_loading || _failed) return const SizedBox.shrink();
    final dayAnimes = _animes.where((a) => _dayOf(a) == day).toList();
    if (dayAnimes.isEmpty) return const SizedBox.shrink();

    final remindedCount = dayAnimes
        .where((a) => ReminderService.enabledIdsSync.contains(a.id.toString()))
        .length;
    final unwatchedCount = dayAnimes
        .where((a) => !WatchedStore.watchedIdsSync.contains(a.id.toString()))
        .length;

    // No point showing "Diingatkan (0)" or "Belum ditonton (0 of 0)" — only
    // surface a chip when it would actually filter something in or out.
    final showReminded = remindedCount > 0;
    final showUnwatched = unwatchedCount > 0 && unwatchedCount < dayAnimes.length;
    if (!showReminded && !showUnwatched) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: SizedBox(
        height: 28,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            if (showReminded)
              _statusChip(
                label: 'Diingatkan',
                count: remindedCount,
                icon: Icons.notifications_active_rounded,
                active: _statusFilter == _StatusFilter.reminded,
                onTap: () => setState(() {
                  _statusFilter = _statusFilter == _StatusFilter.reminded
                      ? _StatusFilter.all
                      : _StatusFilter.reminded;
                }),
              ),
            if (showReminded && showUnwatched) const SizedBox(width: 6),
            if (showUnwatched)
              _statusChip(
                label: 'Belum ditonton',
                count: unwatchedCount,
                icon: Icons.visibility_off_rounded,
                active: _statusFilter == _StatusFilter.unwatched,
                onTap: () => setState(() {
                  _statusFilter = _statusFilter == _StatusFilter.unwatched
                      ? _StatusFilter.all
                      : _StatusFilter.unwatched;
                }),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip({
    required String label,
    required int count,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppTheme.highlight.withOpacity(0.18) : AppTheme.surface.withOpacity(0.70),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppTheme.highlight.withOpacity(0.5) : AppTheme.textSecondary.withOpacity(0.14),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: active ? AppTheme.highlight : AppTheme.textSecondary.withOpacity(0.75)),
            const SizedBox(width: 5),
            Text(
              '$label ($count)',
              style: TextStyle(
                color: active ? AppTheme.highlight : AppTheme.textSecondary.withOpacity(0.9),
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fallback row for days with too little genre variety to filter — still
  /// gives the user the sort toggle without an empty/pointless chip row.
  Widget _sortOnlyBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [_sortToggle()],
      ),
    );
  }

  Widget _sortToggle() {
    final isRating = _sortMode == _SortMode.rating;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _sortMode = isRating ? _SortMode.time : _SortMode.rating;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.78),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.surface),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isRating ? Icons.star_rounded : Icons.schedule_rounded,
              size: 13,
              color: AppTheme.highlight,
            ),
            const SizedBox(width: 5),
            Text(
              isRating ? 'Rating' : 'Jam tayang',
              style: TextStyle(
                color: AppTheme.textSecondary.withOpacity(0.95),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _animeCard(AnimeModel a, {required bool isToday}) {
    final title = titleOfAnime(a);
    final rating = ratingOfAnime(a);
    final coverCandidates = corsProxyCandidates(coverOfAnime(a));
    final time = _timeOf(a);
    final ep = _episodeOf(a);
    final genre = a.genre.isNotEmpty ? a.genre.split(',').first.trim() : 'Anime';

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => AnimeDetailScreen(anime: a),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.surface.withOpacity(0.95)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.glow.withOpacity(0.07),
              blurRadius: 24,
              spreadRadius: -8,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 14,
              bottom: 14,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.accent.withOpacity(0.9),
                      AppTheme.highlight.withOpacity(0.65),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 58,
                      height: 78,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          coverCandidates.isNotEmpty
                              ? ProxiedNetworkImage(
                                  candidates: coverCandidates,
                                  title: title,
                                  width: 58,
                                  height: 78,
                                  fit: BoxFit.cover,
                                  fallback: Container(
                                    color: AppTheme.surfaceElevated,
                                    child: const Icon(
                                      Icons.movie_outlined,
                                      color: AppTheme.textSecondary,
                                      size: 20,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: AppTheme.surfaceElevated,
                                  child: const Icon(
                                    Icons.movie_outlined,
                                    color: AppTheme.textSecondary,
                                    size: 20,
                                  ),
                                ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              height: 28,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.55),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 5,
                            bottom: 4,
                            child: Text(
                              'EP $ep',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 1.25,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            genre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.accent.withOpacity(0.88),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _metaChip(
                              icon: Icons.schedule_rounded,
                              label: '$time WIB',
                              color: AppTheme.accent,
                            ),
                            // A rating of 0 almost always means the API
                            // hasn't got a score yet (brand-new/unaired
                            // anime) rather than an actual 0/10 — showing
                            // "0.0" reads as a bug, so the chip is simply
                            // omitted instead of a fabricated fallback text.
                            if (rating > 0) ...[
                              const SizedBox(width: 8),
                              _metaChip(
                                icon: Icons.star_rounded,
                                label: rating.toStringAsFixed(1),
                                color: AppTheme.highlight,
                              ),
                            ],
                          ],
                        ),
                        if (isToday && a.nextEpisodeAt != null) ...[
                          const SizedBox(height: 6),
                          _LiveCountdown(nextEpisodeAt: a.nextEpisodeAt!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ReminderBell(
                        animeId: a.id.toString(),
                        animeTitle: titleOfAnime(a),
                        episodeAirsAt: a.nextEpisodeAt,
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isToday
                                ? [
                                    AppTheme.accent.withOpacity(0.18),
                                    AppTheme.accent.withOpacity(0.10),
                                  ]
                                : [
                                    AppTheme.surfaceElevated.withOpacity(0.70),
                                    AppTheme.surfaceElevated.withOpacity(0.50),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isToday
                                ? AppTheme.accent.withOpacity(0.30)
                                : AppTheme.textSecondary.withOpacity(0.15),
                          ),
                        ),
                        child: Text(
                          isToday ? 'BARU' : 'TAYANG',
                          style: TextStyle(
                            color: isToday ? AppTheme.accent : AppTheme.textSecondary.withOpacity(0.70),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.textSecondary.withOpacity(0.55),
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color.withValues(alpha: 0.90), size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonList() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: List.generate(
          5,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 102,
              decoration: BoxDecoration(
                color: AppTheme.surface.withOpacity(0.92),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.surface.withOpacity(0.90)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: const ShimmerBox(width: 58, height: 78),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const ShimmerBox(
                            width: double.infinity,
                            height: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const SizedBox(
                            width: 80,
                            height: 10,
                            child: ShimmerBox(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const SizedBox(
                            width: 140,
                            height: 10,
                            child: ShimmerBox(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    final filteredByGenre = _selectedGenre != 'Semua';
    final filteredByStatus = _statusFilter != _StatusFilter.all;
    final filteredBySearch = _searchQuery.trim().isNotEmpty;
    final hasActiveFilter = filteredByGenre || filteredByStatus || filteredBySearch;

    String statusLabel() {
      switch (_statusFilter) {
        case _StatusFilter.reminded:
          return 'yang diingatkan';
        case _StatusFilter.unwatched:
          return 'yang belum ditonton';
        case _StatusFilter.all:
          return '';
      }
    }

    final String title;
    if (filteredBySearch) {
      title = 'Tidak ada hasil untuk "${_searchQuery.trim()}"';
    } else if (filteredByGenre && filteredByStatus) {
      title = 'Tidak ada anime "$_selectedGenre" ${statusLabel()}';
    } else if (filteredByGenre) {
      title = 'Tidak ada anime "$_selectedGenre" hari ini';
    } else if (filteredByStatus) {
      title = 'Tidak ada anime ${statusLabel()} hari ini';
    } else {
      title = 'Tidak ada jadwal hari ini';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.glow.withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(color: AppTheme.accent.withOpacity(0.22)),
              ),
              child: Icon(
                hasActiveFilter ? Icons.filter_alt_off_rounded : Icons.bedtime_rounded,
                color: AppTheme.textSecondary,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasActiveFilter
                  ? 'Coba ubah atau hapus filter yang aktif.'
                  : 'Coba pilih hari lain di atas,\natau kembali lagi nanti.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary.withOpacity(0.95),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
            if (hasActiveFilter) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedGenre = 'Semua';
                    _statusFilter = _StatusFilter.all;
                    _searchQuery = '';
                    _searchCtrl.clear();
                    _searchOpen = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
                  ),
                  child: Text(
                    'Hapus semua filter',
                    style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accent.withOpacity(0.18), // Menggunakan accent
                    Colors.transparent,
                  ],
                ),
                border: Border.all(
                  color: AppTheme.accent.withOpacity(0.28), // Menggunakan accent
                ),
              ),
              child: Icon( // Mengubah const menjadi non-const
                Icons.wifi_off_rounded,
                color: AppTheme.accent, // Menggunakan accent
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text( // Mengubah const menjadi non-const
              'Gagal memuat jadwal',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Periksa koneksi internet,\nlalu coba muat ulang.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary.withOpacity(0.95),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _load,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.accent, AppTheme.glow],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withOpacity(0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Text(
                  'Coba Lagi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
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
