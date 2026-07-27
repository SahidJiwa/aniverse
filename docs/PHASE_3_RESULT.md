# PHASE_3_RESULT

Status: COMPLETE
Date: 2026-06-10

---

## Goal

Replace Top Rail placeholder with real _TopRail widget.
Full-bleed Protagonist Zone (top: 0).
Remove ANIVERSE wordmark from hero content.
Anchor identity block to bottom-left.
Constrain Activity Overlay pill width.

---

## Completed

### P3-1 / P3-2 — Full-bleed hero + SafeArea decoupled
Protagonist Zone `top` changed from `kTopRailH` → `0`.
Artwork now starts at physical top of screen, bleeds under transparent Top Rail.
Top Rail is rendered above Protagonist Zone in Stack order — controls remain tappable.
`protagonistH` formula unchanged; height still measured from top of screen.

### P3-3 — ANIVERSE wordmark row removed
`_CinematicHeroContent.build()` — `SafeArea` wrapper removed.
`Row(ANIVERSE wordmark + notification icon)` block deleted.
`Padding` top inset changed from `16` → `0`.
Top Rail now owns the logo/wordmark zone. Audit issue closed: **M-1**.

### P3-4 — Dock shell stray padding removed
Stray `top: 8.0` padding from Phase 1 placeholder removed from Dock Positioned.
No layout change to nav items.

### P3-5 — `_TopRail` widget created and wired into L8
New `_TopRail` StatelessWidget. Zero AnimationControllers.
Layout: `Row` — logo mark (28×28 gradient box) · wordmark "AniVerse" ·
`Spacer` · search `IconButton` · notification `IconButton` with dot badge ·
avatar `CircleAvatar` (initial "H").
Background: `Colors.transparent` — artwork bleeds through.
`safeTop` passed from parent; internal `padding: EdgeInsets.only(top: safeTop)`.
`_LobbyZonePlaceholder` for Top Rail replaced.
Audit issue closed: **M-1** (confirmed).

### P3-6 — Activity Overlay pill `maxWidth` constrained
`_GlobalActivityOverlay` wrapped in `ConstrainedBox(maxWidth: 220)`.
Prevents pill stretch on wide devices or long activity strings.
Positioned anchor unchanged: `top: kTopRailH + 12`, `right: 0`.

### P3-7 — Identity block anchored bottom-left
`_CinematicHeroContent` moved from bare Stack child → `Positioned(left: 0, right: 0, bottom: 0)`.
`Spacer()` removed from Column — no longer needed; Positioned handles vertical anchor.
`Column.mainAxisSize` changed to `MainAxisSize.min`.
Username + rank + XP bar now sit bottom-left, consistent with WuWa/HSR grammar.
Audit issue closed: **M-2** (full).

---

## Audit Issues Resolved in Phase 3

| Issue | Description | Status |
|---|---|---|
| M-1 | Top Rail two-line tagline too dense | ✅ Closed |
| M-2 | Identity block vertical anchor | ✅ Closed |

---

## Files Changed

| File | Classes Touched |
|---|---|
| `home_screen.dart` | `_HomeScreenState.build()`, `_CinematicHeroState.build()`, `_CinematicHeroContent.build()`, `_TopRail` (new) |

---

## Source Verification (post-edit)

| Check | Source Line | Result |
|---|---|---|
| `class _TopRail` exists | 639 | ✅ |
| `_TopRail(` in build() | 334 | ✅ |
| Protagonist `top: 0` | 199 | ✅ |
| ANIVERSE widget gone | — (comment only at 1016) | ✅ |
| SafeArea removed | comment at 1015 | ✅ |
| Identity block `bottom: 0` Positioned | 958 | ✅ |
| World Pulse placeholder intact | 219/232 | ✅ |
| `kWorldPulseH = 72.0` unchanged | 144 | ✅ |

---

## Risks Carried Forward

| Risk | Notes |
|---|---|
| Stats row in `_CinematicHeroContent` still renders | Phase 9. |
| Sakura parallax permanently 0 | Phase 8. |
| `_computeRecommendations()` triggers full `setState()` | Phase 10. |
| `protagonistH` must be re-verified each phase that changes zone heights | Phase 4 changes `kWorldPulseH`. |

---

## Zone Status After Phase 3

| Zone | Layer | Status |
|---|---|---|
| Top Rail | L1 | **Wired.** `_TopRail` live. Transparent. Safe area internal. |
| Protagonist Zone | L2 | **Wired.** Full bleed. Identity anchor bottom-left. |
| World Pulse | L3 | Placeholder (72px). Content: Phase 4. |
| Progress Rail | L4 | Placeholder (58px). Phase 5. |
| Primary Action | L5 | Placeholder (68px). Phase 6. |
| Atmosphere Bar | L6 | Placeholder (3px). Phase 8. |
| Lobby Dock | L7 | Placeholder. Safe area correct. Phase 7. |
| Activity Overlay | L9 | Wired. `maxWidth: 220`. |

---

## Next Phase

**Phase 4: World Pulse real content**

- Replace World Pulse placeholder with `_WorldPulseZone`
- Single featured room — no list, no carousel, no right panel
- No `_LiveChatStream`, no `_RoomEnergyBar`
- Update `kWorldPulseH`, re-verify `protagonistH`
- Audit issues to close: H-1, M-3, M-5 (partial)

---

## Known Issues Remaining (Post Phase 3)

| Issue | Severity | Phase |
|---|---|---|
| C-1: Scroll sections below stack | CRITICAL | 4–6 |
| C-2: Protagonist not yet fully dominant | CRITICAL | 9 |
| C-3: Primary Action absent | CRITICAL | 6 |
| C-4: Dock navigation-only | CRITICAL | 7 |
| H-1: World Pulse oversized | HIGH | 4 |
| H-2: Stats row dashboard widget | HIGH | 9 |
| H-5: Progress Rail missing | HIGH | 5 |
| M-3: World Pulse right panel wrong hierarchy | MEDIUM | 4 |
| M-4: CTA duplication | MEDIUM | 6 |
| M-5: Visual density too high | MEDIUM | 4–6 |
| L-1: Atmosphere Bar invisible | LOW | 8 |
| L-4: Sakura parallax muted | LOW | 8 |
