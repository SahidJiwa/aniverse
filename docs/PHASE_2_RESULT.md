# PHASE_2_RESULT

Status: COMPLETE
Date: 2026-06-10

---

## Goal

Wire `_CinematicHero` into Protagonist Zone.
Implement SafeArea for Top Rail and Dock.
Disable `_heroTimer`.
Make `scrollCtrl` optional.
Extract `_GlobalActivityOverlay` pill so parent Stack controls alignment.

---

## Completed

### Op-1 — `_heroTimer` disabled
`Timer.periodic` replaced with `Timer(Duration.zero, () {})`.
`_currentPage` no longer auto-advances.
`dispose()` unchanged — `_heroTimer?.cancel()` still safe.
Audit issue closed: **L-2**.

### Op-2 — `scrollCtrl` made optional in `_CinematicHero`
Field type changed from `ScrollController` to `ScrollController?`.
Constructor parameter changed from `required this.scrollCtrl` to `this.scrollCtrl`.
All three offset reads guarded:
`widget.scrollCtrl?.hasClients == true ? widget.scrollCtrl!.offset.clamp(...) : 0.0`
`Listenable.merge` list built conditionally — null controller never added.
Risk 1 from HOME_MIGRATION_AUDIT closed.

### Op-3 — `SizedBox` height wrapper removed from `_CinematicHeroState.build()`
`SizedBox(height: heroH)` deleted.
Widget now returns `Stack(fit: StackFit.expand)` directly.
`heroH` local variable deleted — height is now controlled entirely by
parent `Positioned(height: protagonistH)` in `_HomeScreenState.build()`.
Risk 2 from HOME_MIGRATION_AUDIT closed.

### Op-4 — SafeArea computed in `_HomeScreenState.build()`
`kTopRailH` and `kDockH` changed from `static const double` to local
variables computed each build:
```
final safeTop  = MediaQuery.of(context).padding.top;
final safeBot  = MediaQuery.of(context).padding.bottom;
final kTopRailH = 56.0 + safeTop;
final kDockH    = 72.0 + safeBot;
```
`protagonistH` recomputed from updated constants.
`protagonistH` clamped to minimum 200.0px.
Audit issues closed: **H-3**, **M-6**.

### Op-5 — `_CinematicHero` wired into L2 Protagonist Zone
`_LobbyZonePlaceholder` for Protagonist Zone replaced with:
```dart
_CinematicHero(
  scrollCtrl:  null,
  zoomAnim:    _zoomAnim,
  currentPage: _currentPage,
  total:       1,
  animes:      _topAnimes.isNotEmpty ? _topAnimes : _seasonalAnimes,
)
```
`total: 1` suppresses page indicator dots.
Audit issues closed: **L-3**, Phase 2 primary goal.

### Op-6 — `_GlobalActivityOverlay` pill extracted, `Align` removed
New `_ActivityPill` stateless widget created.
Receives `animValue` from parent — owns only visual content.
`_GlobalActivityOverlayState.build()` now returns `AnimatedBuilder →
_ActivityPill` with no internal `Align` or `Positioned`.
Parent Stack places pill via:
```dart
Positioned(
  top:   kTopRailH + 12.0,
  right: 24.0,
  child: IgnorePointer(child: _GlobalActivityOverlay()),
)
```
Pill clears Top Rail by exactly 12px. Safe area already baked into
`kTopRailH`, so gap is device-invariant.
Audit issues closed: **H-4**.

---

## Audit Issues Resolved in Phase 2

| Issue | Description | Status |
|---|---|---|
| H-3 | Top Rail safe area violation | ✅ Closed |
| H-4 | Activity overlay overlaps Top Rail | ✅ Closed |
| M-2 | Protagonist Zone identity block position | ✅ Partial — _CinematicHeroContent column alignment is unchanged. Full resolution in Phase 3 when content is audited. |
| M-6 | Dock bottom safe area violation | ✅ Closed |
| L-2 | `_heroTimer` advancing dead carousel | ✅ Closed |
| L-3 | Page indicator dots will reappear | ✅ Closed |

Phase 2 closes **5 of 6** targeted issues.
M-2 (identity block vertical anchor) carries to Phase 3.

---

## Files Changed

| File | Classes Touched |
|---|---|
| `home_screen.dart` | `_HomeScreenState`, `_CinematicHero`, `_CinematicHeroState`, `_GlobalActivityOverlayState`, `_ActivityPill` (new) |

No other files changed.

---

## Risks Carried Forward

| Risk | Notes |
|---|---|
| `_CinematicHeroContent` still renders 4-metric stats row | Deferred to Phase 9 per PHASE_1_VISUAL_AUDIT. Stats row removal requires content surgery inside `_CinematicHeroContent`. |
| Sakura parallax permanently 0 | `_scrollCtrl` has no scroll source. `_SakuraPainter` receives `offset * 0.12 = 0`. Particles animate but lack depth. Deferred to Phase 8 (gyro or idle drift replacement). |
| `_computeRecommendations()` triggers full `setState()` | Low-cost in Phase 2 since only Protagonist Zone is wired. Becomes an issue in Phase 5+ when more zones render expensive widgets. Isolate to Phase 10 performance audit. |
| `protagonistH` calculation depends on all `kBottomZonesH` being final | Phases 4–7 will change World Pulse height from 72px to actual measured value, Progress Rail from placeholder to real 58px, etc. Each phase must re-verify `protagonistH` math. |

---

## Zone Status After Phase 2

| Zone | Layer | Status |
|---|---|---|
| Top Rail | L1 | Placeholder. Safe area correct. Real content: Phase 3. |
| Protagonist Zone | L2 | **Wired.** `_CinematicHero` live. Safe area baked into top offset. |
| World Pulse | L3 | Placeholder (72px). Content: Phase 4. |
| Progress Rail | L4 | Placeholder (58px). Widget creation: Phase 5. |
| Primary Action | L5 | Placeholder (68px). Widget creation: Phase 6. |
| Atmosphere Bar | L6 | Placeholder (3px). Animation: Phase 8. |
| Lobby Dock | L7 | Placeholder. Safe area correct. Restyle: Phase 7. |
| Activity Overlay | L9 | Wired. Placement: `top = kTopRailH + 12`, `right = 24`. |

---

## Next Phase

**Phase 3: Top Rail real content**

- Replace Top Rail placeholder with real widget
- Logo (icon + wordmark, single line — tagline removed per M-1)
- Right cluster: search icon · notification icon · avatar
- Avatar taps to Profile
- Notification badge from `favoritesNotifier` or dedicated notifier
- Audit issue to close: M-1

---

## Known Issues Remaining (Post Phase 2)

| Issue | Severity | Phase |
|---|---|---|
| C-1: Screen still has scroll sections below stack | CRITICAL | 4–6 |
| C-2: Protagonist does not yet fully dominate | CRITICAL | 2+9 |
| C-3: Primary Action absent | CRITICAL | 6 |
| C-4: Dock is navigation-only (Primary Action missing above it) | CRITICAL | 7 |
| H-1: World Pulse oversized | HIGH | 4 |
| H-2: Stats row is dashboard widget | HIGH | 9 |
| H-5: Progress Rail missing | HIGH | 5 |
| M-1: Top Rail two-line tagline too dense | MEDIUM | 3 |
| M-2: Identity block vertical anchor (partial) | MEDIUM | 3 |
| M-3: World Pulse right panel wrong hierarchy | MEDIUM | 4 |
| M-4: CTA duplication across zones | MEDIUM | 6 |
| M-5: Visual density too high | MEDIUM | 4–6 |
| L-1: Atmosphere Bar invisible at 3px | LOW | 8 |
| L-4: Sakura parallax permanently muted | LOW | 8 |
