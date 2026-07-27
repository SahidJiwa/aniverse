# PHASE_5_RESULT

Status: COMPLETE
Date: 2026-07-17

---

## Goal

Replace hardcoded XP/level values in `_LobbyProgressRail` with live data from
`MockDataService.xpNotifier`, using `TierSystem` helpers for tier name, badge,
color, and XP-to-next-tier computation.
Audit issue to close: **H-5** (Progress Rail missing live data).

---

## Completed

### P5-1 — `tier_system.dart` imported into `home_screen.dart`
Line 22. `import 'tier_system.dart';` added after `library_screen.dart`.
Zero compilation errors.

### P5-2 — `_LobbyProgressRail` constructor made `const`
`_LobbyProgressRail()` → `const _LobbyProgressRail()`.
Call site in `_LobbyShellV4` updated to `const _LobbyProgressRail()`.

### P5-3 — Live `ValueListenableBuilder<int>` wraps entire content
Listens to `MockDataService.xpNotifier`.
Rebuilds only the Progress Rail zone on XP change — no full-screen setState.

### P5-4 — TierSystem helpers wired in
| Helper | Usage |
|---|---|
| `TierSystem.getTier(xp)` | Tier badge, name, color, glowColor |
| `TierSystem.getProgress(xp)` | Progress bar fill (0.0–1.0) |
| `TierSystem.getNextTier(xp)` | "X XP lagi → next badge name" callout |
| `TierSystem.xpToNextTier(xp)` | Remaining XP integer |

### P5-5 — UI layout
- Row: `[tier.badge]  [tier.name in tier.color]  [tierXP / tierTarget XP]`
- `LinearProgressIndicator` colored with `tier.color` (replaces hardcoded `_kPurple`)
- Border tinted with `tier.color.withValues(alpha: 0.18)` — badge identity visible
- "X XP → next tier" micro-callout right-aligned below bar (hidden when max tier)
- `mainAxisSize: MainAxisSize.min` — no fixed-height column overflow

---

## Audit Issues Resolved in Phase 5

| Issue | Description | Status |
|---|---|---|
| H-5 | Progress Rail missing live data | ✅ Closed |

---

## Files Changed

| File | Classes Touched |
|---|---|
| `home_screen.dart` | `_LobbyProgressRail` (rewritten), `_LobbyShellV4.build()` (const), imports |

---

## Source Verification

| Check | Line | Result |
|---|---|---|
| `import 'tier_system.dart'` | 22 | ✅ |
| `const _LobbyProgressRail()` in build | ~703 | ✅ |
| `class _LobbyProgressRail` has `const` ctor | ~3431 | ✅ |
| `ValueListenableBuilder<int>` wraps content | ~3434 | ✅ |
| `TierSystem.getTier(xp)` called | ~3436 | ✅ |
| Build succeeds (no compile errors) | flutter run | ✅ |

---

## Risks Carried Forward

| Risk | Notes |
|---|---|
| `progressH` zone height may clip "X XP lagi" row on very small devices | clamp is 52px; 3-row content needs ~68px. Phase 9 layout review. |
| `continueWatchingNotifier` active count hardcoded 128 in WorldPulse | Phase 6 will wire room API. |
| `protagonistH` re-verify after zone height tuning | Phase 6. |

---

## Zone Status After Phase 5

| Zone | Layer | Status |
|---|---|---|
| Top Rail | L1 | Wired. `_TopRail` live. |
| Protagonist Zone | L2 | Wired. Full bleed. Identity anchor bottom-left. |
| World Pulse | L3 | Wired. `_LiveActivityPulse` live. |
| **Progress Rail** | L4 | **Wired.** Live XP + TierSystem. `_LobbyProgressRail`. |
| Primary Action | L5 | Wired. `_LobbyPrimaryAction` live. |
| Lobby Dock | L6 | Wired. `_LobbyDock` live. |
| Atmosphere Bar | L7 | Glow strip live. |
| Activity Overlay | L9 | Wired. `maxWidth: 220`. |

---

## Next Phase

**Phase 6: World Pulse → RoomScreen integration**

- `_LiveActivityPulse` "Gabung" button routes to `RoomScreen`
- Pass `roomTitle`, `roomColor`, `roomBgPath` from pulse data
- Close audit issue: C-4 (Dock navigation-only), M-4 (CTA duplication partial)
- No new widgets; only navigation wiring

---

## Known Issues Remaining (Post Phase 5)

| Issue | Severity | Phase |
|---|---|---|
| C-1: Scroll sections below stack | CRITICAL | 6 |
| C-2: Protagonist not yet fully dominant | CRITICAL | 9 |
| C-4: Dock navigation-only | CRITICAL | 7 |
| H-2: Stats row dashboard widget | HIGH | 9 |
| M-4: CTA duplication | MEDIUM | 6 |
| M-5: Visual density (remaining) | MEDIUM | 6 |
| L-1: Atmosphere Bar invisible | LOW | 8 |
| L-4: Sakura parallax muted | LOW | 8 |
