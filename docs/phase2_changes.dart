// ============================================================
// PHASE 2 — COMPLETE CODE CHANGES
// All changes are in home_screen.dart only.
// Three classes touched: _HomeScreenState, _CinematicHero,
// _CinematicHeroState.
// One new private widget added: _ActivityPill (extracted from
// _GlobalActivityOverlayState so parent Stack controls alignment).
// ============================================================


// ─────────────────────────────────────────────────────────────
// CHANGE 1 of 6
// Target: _HomeScreenState.initState()
// Op: Disable _heroTimer — cancel immediately after first fire
// so _currentPage never auto-advances.
// Audit closes: L-2
// ─────────────────────────────────────────────────────────────

// BEFORE:
void initState() {
  super.initState();
  // ... controller init ...
  _heroTimer = Timer.periodic(const Duration(seconds: 6), (_) {
    setState(() {
      _currentPage = (_currentPage + 1) % 5;
    });
  });
  // ...
}

// AFTER:
void initState() {
  super.initState();
  // ... controller init unchanged ...

  // _heroTimer: disabled. Protagonist Zone is a single world state,
  // not a carousel. Timer object is kept so dispose() remains safe.
  _heroTimer = Timer(Duration.zero, () {});

  // ... rest of initState unchanged ...
}


// ─────────────────────────────────────────────────────────────
// CHANGE 2 of 6
// Target: _CinematicHero (StatefulWidget class)
// Op: Make scrollCtrl optional (nullable).
// Audit closes: supports H-4, Risk 1 mitigation
// ─────────────────────────────────────────────────────────────

// BEFORE:
class _CinematicHero extends StatefulWidget {
  final ScrollController scrollCtrl;
  final Animation<double> zoomAnim;
  final int currentPage;
  final int total;
  final List<AnimeModel> animes;

  const _CinematicHero({
    required this.scrollCtrl,
    required this.zoomAnim,
    required this.currentPage,
    required this.total,
    required this.animes,
  });

  @override
  State<_CinematicHero> createState() => _CinematicHeroState();
}

// AFTER:
class _CinematicHero extends StatefulWidget {
  final ScrollController? scrollCtrl; // nullable — lobby has no scroll source
  final Animation<double> zoomAnim;
  final int currentPage;
  final int total;
  final List<AnimeModel> animes;

  const _CinematicHero({
    this.scrollCtrl,                   // optional, defaults to null
    required this.zoomAnim,
    required this.currentPage,
    required this.total,
    required this.animes,
  });

  @override
  State<_CinematicHero> createState() => _CinematicHeroState();
}


// ─────────────────────────────────────────────────────────────
// CHANGE 3 of 6
// Target: _CinematicHeroState.build() — three AnimatedBuilder
//         listeners that read widget.scrollCtrl
// Op: Guard all offset reads; remove SizedBox height wrapper;
//     return Stack(fit: StackFit.expand) directly so parent
//     Positioned controls height.
// Audit closes: Risk 2 (height assumption), L-3 (total:1 passed
//     from call site — no dots rendered)
// ─────────────────────────────────────────────────────────────

// BEFORE (abbreviated skeleton):
Widget build(BuildContext context) {
  final screenH = MediaQuery.of(context).size.height;
  final heroH = (screenH * 0.50).clamp(390.0, 500.0);

  return SizedBox(
    height: heroH,
    child: AnimatedBuilder(
      animation: Listenable.merge([widget.scrollCtrl, _driftCtrl, _pulseCtrl]),
      builder: (context, _) {
        final scroll = widget.scrollCtrl.hasClients
            ? widget.scrollCtrl.offset.clamp(0.0, 500.0)
            : 0.0;
        // ... parallax math using scroll ...
        return Stack(
          children: [
            // artwork AnimatedBuilder also reads widget.scrollCtrl ...
            // atmosphere painter also reads widget.scrollCtrl ...
          ],
        );
      },
    ),
  );
}

// AFTER:
Widget build(BuildContext context) {
  // Height is NOT computed here. Parent Positioned in lobby Stack
  // owns the height via top/bottom constraints.
  // SizedBox wrapper is removed.

  // Build the listenable list conditionally — scrollCtrl may be null.
  final listenables = <Listenable>[_driftCtrl, _pulseCtrl];
  if (widget.scrollCtrl != null) listenables.add(widget.scrollCtrl!);

  return AnimatedBuilder(
    animation: Listenable.merge(listenables),
    builder: (context, _) {
      // Guard: offset is 0.0 when no scroll source exists.
      final scroll = (widget.scrollCtrl?.hasClients == true)
          ? widget.scrollCtrl!.offset.clamp(0.0, 500.0)
          : 0.0;

      final parallaxOffset = scroll * 0.22;
      final zoomFromScroll = 1.0 + scroll * 0.00013;

      return Stack(
        fit: StackFit.expand, // fills parent Positioned bounds exactly
        children: [

          // ── artwork (parallax + drift + zoom) ──────────────────
          // Inner AnimatedBuilder for artwork also guards scrollCtrl:
          AnimatedBuilder(
            // artwork listens to its own sub-set; scrollCtrl already
            // covered by outer AnimatedBuilder, no double-listen needed.
            animation: widget.zoomAnim,
            builder: (context, _) {
              return Transform.translate(
                offset: Offset(_driftCtrl.value * 8.0 - 4.0, -parallaxOffset * 0.5),
                child: Transform.scale(
                  scale: widget.zoomAnim.value * zoomFromScroll,
                  child: _buildArtwork(), // existing method, unchanged
                ),
              );
            },
          ),

          // ── atmosphere painter (parallax) ──────────────────────
          CustomPaint(
            painter: _HeroAtmospherePainter(
              progress: _pulseCtrl.value,
              // scroll value already guarded above — pass the local double
              scrollOffset: parallaxOffset,
            ),
          ),

          // ── gradient planes A, B, C ── unchanged ──────────────
          _buildGradients(),

          // ── top-right bloom ── unchanged ──────────────────────
          Positioned(
            top: 0, right: 0,
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => _buildBloom(),
            ),
          ),

          // ── hero content (identity block) ── unchanged ─────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: _CinematicHeroContent(
              key: ValueKey(widget.currentPage),
              anime: _currentAnime(),
              currentPage: widget.currentPage,
            ),
          ),

          // ── page indicator dots ────────────────────────────────
          // Rendered only when total > 1.
          // Call site passes total: 1 → dots never appear. Audit L-3.
          if (widget.total > 1)
            Positioned(
              right: 16,
              top: 0, bottom: 0,
              child: Center(child: _buildPageDots()),
            ),
        ],
      );
    },
  );
}


// ─────────────────────────────────────────────────────────────
// CHANGE 4 of 6
// Target: _HomeScreenState.build() — computed safe area constants
// Op: Replace const kTopRailH and kDockH with MediaQuery-aware
//     values computed at build time.
// Audit closes: H-3, M-6
// ─────────────────────────────────────────────────────────────

// BEFORE (at top of build, or as class-level const):
static const double kTopRailH  = 56.0;
static const double kDockH     = 72.0;
static const double kAtmoBarH  =  3.0;
static const double kWorldH    = 72.0;
static const double kProgressH = 58.0;
static const double kActionH   = 68.0;

// AFTER — computed inside build():
Widget build(BuildContext context) {
  final mq        = MediaQuery.of(context);
  final safeTop   = mq.padding.top;    // ~59px DynamicIsland, ~24px notch, 0 legacy
  final safeBot   = mq.padding.bottom; // ~34px iPhone swipe, 0 Android hardware keys

  // Effective zone heights — safe areas baked in, not added as extra padding.
  final double kTopRailH  = 56.0 + safeTop;
  final double kDockH     = 72.0 + safeBot;
  const double kAtmoBarH  =  3.0;
  const double kWorldH    = 72.0;
  const double kProgressH = 58.0;
  const double kActionH   = 68.0;

  // Bottom stack of fixed zones (everything below Protagonist).
  final double kBottomZonesH = kWorldH + kProgressH + kActionH + kAtmoBarH + kDockH;

  // Protagonist Zone gets everything that is not a fixed zone.
  // Clamped to 200px minimum for very small devices.
  final double protagonistH =
      (mq.size.height - kTopRailH - kBottomZonesH).clamp(200.0, double.infinity);

  // ... rest of build() below ...
}


// ─────────────────────────────────────────────────────────────
// CHANGE 5 of 6
// Target: _HomeScreenState.build() — L2 Protagonist Zone
// Op: Replace _LobbyZonePlaceholder with wired _CinematicHero.
//     Pass total: 1 to suppress dots. Pass scrollCtrl: null.
// Audit closes: Phase 2 primary goal, L-3
// ─────────────────────────────────────────────────────────────

// BEFORE (inside Stack children list):
// L2 — Protagonist Zone
Positioned(
  top: kTopRailH,
  left: 0, right: 0,
  height: protagonistH,
  child: _LobbyZonePlaceholder(label: 'Protagonist Zone', color: Colors.purple),
),

// AFTER:
// L2 — Protagonist Zone
Positioned(
  top: kTopRailH,
  left: 0,
  right: 0,
  height: protagonistH,
  child: _CinematicHero(
    scrollCtrl:  null,           // no scroll source in lobby — parallax returns 0
    zoomAnim:    _zoomAnim,
    currentPage: _currentPage,
    total:       1,              // suppresses page indicator dots (L-3)
    animes:      _topAnimes.isNotEmpty ? _topAnimes : _seasonalAnimes,
  ),
),


// ─────────────────────────────────────────────────────────────
// CHANGE 6 of 6
// Target: _GlobalActivityOverlay + new _ActivityPill
// Op: Extract pill content into standalone stateless _ActivityPill.
//     _GlobalActivityOverlayState no longer owns Align — it owns
//     only the animation controller and exposes a build-able pill.
//     Parent Stack places the pill via Positioned with explicit
//     top/right offsets computed from kTopRailH (safe area baked in).
// Audit closes: H-4 (overlay must clear Top Rail by ≥12px)
// ─────────────────────────────────────────────────────────────

// ── NEW: _ActivityPill ─────────────────────────────────────────
// Stateless. Receives the animation value from its StatefulWidget
// parent. No Align, no Positioned inside — pure content.

class _ActivityPill extends StatelessWidget {
  final double animValue; // 0.0 → 1.0 from _GlobalActivityOverlayState._c

  const _ActivityPill({required this.animValue});

  @override
  Widget build(BuildContext context) {
    // Pill only visible in the upper half of the animation cycle.
    final opacity = (1.0 - (animValue * 2.0 - 1.0).abs()).clamp(0.0, 1.0);

    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.sakuraPink.withOpacity(0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.sakuraPink.withOpacity(0.15),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🌸', style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Text(
              'Aiko unlocked Sakura Emperor',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ── MODIFIED: _GlobalActivityOverlay ───────────────────────────
// Widget now exposes its animation controller publicly so that
// the parent can consume it via AnimatedBuilder when placing
// _ActivityPill inside the root Stack.
//
// Alternative (simpler, chosen here): keep _GlobalActivityOverlay
// as a StatefulWidget but have its build() return _ActivityPill
// with NO Align wrapper. Parent Stack uses Positioned for placement.

class _GlobalActivityOverlayState extends State<_GlobalActivityOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No Align here. No Positioned here.
    // Pure pill content — placement is the parent's responsibility.
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => _ActivityPill(animValue: _c.value),
    );
  }
}


// ── IN _HomeScreenState.build() — overlay placement ───────────
// BEFORE (somewhere in Stack children):
//
// Positioned.fill(
//   child: IgnorePointer(
//     child: _GlobalActivityOverlay(),   // owned its own Align internally
//   ),
// ),

// AFTER:
// Overlay pill — Positioned with explicit safe-area-aware offsets.
// Sits in upper-right of Protagonist Zone, 12px below Top Rail bottom.
Positioned(
  top: kTopRailH + 12.0,   // clears Top Rail (safe area already in kTopRailH)
  right: 24.0,
  child: IgnorePointer(
    child: _GlobalActivityOverlay(),   // now returns pill only, no internal Align
  ),
),
