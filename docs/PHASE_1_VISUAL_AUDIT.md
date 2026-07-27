# PHASE 1 VISUAL AUDIT

## Source Material
Screenshot: Target design (ChatGPT_Image_Jun_6__2026__12_35_57_PM.png)
Compared against: HOME_V4_FINAL.md approved architecture
Audit scope: Gap analysis — what the target looks like vs what V4 requires

---

## Note on Screenshot Identity
The uploaded screenshot is the original target design mockup, not a
rendered output of the Phase 1 scaffold implementation. This audit
therefore serves two purposes:
1. Confirm which elements in the target design are already correct
2. Identify what the Phase 2+ implementation must achieve or deviate from

---

## Issues Ordered by Severity

---

### CRITICAL

---

**C-1: Screen is still a vertical scroll — not a lobby canvas**

What the screenshot shows:
Full-page vertical layout. Continue Your Journey, Friends Activity,
Daily Missions, Collection, Anime DNA, Universe Status all exist below
the fold. Total content height is approximately 3–4× screen height.

What V4 requires:
Single viewport. No scroll. All information visible in one frame.

Gap:
The entire lower 65% of the screenshot (everything below World Pulse)
violates the core architectural rule. These sections must be compressed
into Progress Rail and removed from the scroll chain entirely.

Sections to eliminate from vertical layout:
- Continue Your Journey (scroll section) → compress into Primary Action
- Friends Activity (standalone section) → compress into Progress Rail / World Pulse
- Daily Missions (standalone section) → compress into Progress Rail
- Your Collection (standalone section) → compress into Progress Rail
- Your Anime DNA → removed from Home entirely
- Universe Status → removed from Home entirely

---

**C-2: Protagonist Zone does not dominate**

What the screenshot shows:
Hero zone occupies approximately 38% of visible viewport height.
Character art is present but shares vertical space equally with
the stats row (Episodes Watched / Hours Watched / Anime Completed / Badges)
and the World Pulse panels below it.
The stats row at the bottom of the hero zone is a 4-column dashboard widget
— it breaks protagonist dominance by introducing metric grid thinking.

What V4 requires:
Protagonist Zone occupies the largest single zone. Identity anchor
bottom-left. Character art bleeds into background. No dashboard metrics.

Gap:
- Stats row (1.248 / 248h / 96 / 42) must be removed from Protagonist Zone.
  This is a dashboard widget, not identity. Per AI_RULES: never introduce
  dashboard UI.
- Protagonist height feels equal to World Pulse in the screenshot.
  In V4, Protagonist must feel 2× taller than any other zone.

---

**C-3: Primary Action is absent**

What the screenshot shows:
No dominant single CTA exists between the content zones and the nav dock.
"Tonton Sekarang" is buried inside Universe Highlight panel.
"Masuk Room" is inside Anime Room Live section.
Neither is positioned as the screen's primary affordance.

What V4 requires:
One full-width Primary Action zone between Progress Rail and Lobby Dock.
Contextual: Continue Watching > Join Active Room > Enter Universe.
This must be the most visually dominant interactive element on screen
below the protagonist.

Gap:
Primary Action zone does not exist in the target design at all.
Phase 2 must introduce it as a new zone, not adapt an existing widget.

---

**C-4: Lobby Dock is a standard navigation bar**

What the screenshot shows:
Bottom nav: Beranda · Jadwal · Library · Universe (center, glowing) · Community · Profile.
Universe is elevated and glowing — this is correct directionally.
But the dock reads as navigation, not as action affordance.

What V4 requires:
Dock is navigation. The action lives in Primary Action zone above it.
Universe as center dominant is correct and should be preserved.

Gap:
The dock itself is directionally correct. No structural issue here.
The problem is that in the current mockup, the dock is asked to be
both navigation AND action (because Primary Action zone doesn't exist).
Once Primary Action is introduced, dock reverts to pure navigation role.
Universe center elevation: keep. Everything else: keep.

---

### HIGH

---

**H-1: World Pulse is two large dashboard cards, not live world state**

What the screenshot shows:
Universe Highlight: large card with section header "UNIVERSE HIGHLIGHT",
episode label, title, description text, friend avatars, and a CTA button.
Sakura Festival: large card with section header, event name in pink,
countdown number, and a button.
Both cards are 50% width, ~180px tall each, with explicit section headers.
Combined they occupy approximately 22% of viewport height.

What V4 requires:
World Pulse is not two dashboard cards. It is a live world state organism.
Height target: 72px. Not 180px.
No section headers. No "UNIVERSE HIGHLIGHT" label.
Left: current anime pulse (title + live viewer signal).
Right: event signal (countdown only — no header).
Top strip: live dot + friend avatars inline.

Gap:
Current cards are 2.5× too tall.
Section headers ("UNIVERSE HIGHLIGHT", "SAKURA FESTIVAL") violate AI_RULES:
"add section labels unnecessarily" is explicitly forbidden.
CTA buttons inside World Pulse belong in Primary Action zone, not here.

---

**H-2: Stats row between Protagonist and World Pulse is a dashboard widget**

What the screenshot shows:
Four-column row: Episodes Watched 1,248 / Hours Watched 248h /
Anime Completed 96 / Total Badges 42.
Located between the hero zone and World Pulse panels.
Has icon + large number + small label per column.
Clear dashboard grid pattern.

What V4 requires:
Per AI_RULES: "never introduce dashboard UI", "never introduce analytics
style widgets". This row is exactly that.

Gap:
This entire row must be removed from the layout.
Stats of this type belong in Profile screen.
If XP/level signal is needed on Home, it belongs inside Protagonist Zone
identity block (as a single compressed element, not a four-metric grid).

---

**H-3: Safe area violation — status bar overlap**

What the screenshot shows:
Top Rail content (AniVerse logo, search, mail, avatar) sits immediately
below the status bar (9:41 / signal / battery). On this device the
status bar appears to float over the Top Rail content without padding.
The logo and wordmark start at approximately y=44px — dangerously close
to system UI on notched devices.

What V4 requires:
Top Rail must account for `MediaQuery.of(context).padding.top` (status bar
height). On iPhone with Dynamic Island: ~59px. On Android with notch: ~24–48px.
Failing to handle this will render logo behind system UI on real devices.

Gap:
`kTopRailH = 56.0` in Phase 1 scaffold is a fixed value.
It does not add `MediaQuery.padding.top`.
Phase 2 must compute effective Top Rail height as:
`kTopRailH = 56.0 + MediaQuery.of(context).padding.top`
Or wrap Top Rail content with `SafeArea(bottom: false, child: ...)`.

---

**H-4: Global Activity Overlay overlaps Top Rail**

What the screenshot shows:
The floating activity pill ("🌸 Aiko unlocked...") appears at approximately
Alignment(0.72, -0.68) — which in the current design sits inside the
hero zone, roughly at y=25% of screen height. This is acceptable in
the scroll layout where hero is 50% of screen.

What V4 requires:
In the lobby layout, Alignment(0.72, -0.68) maps to approximately
y = screen_height * 0.16 = ~134px on a 812px screen.
Top Rail height is 56px. The overlay will render at y≈134px which is
inside Protagonist Zone — this is actually correct.
However if SafeArea adds ~59px to Top Rail (H-3), effective top boundary
is 115px, and overlay at 134px is only 19px below Top Rail.
On smaller screens this gets tighter.

Gap:
Overlay alignment must be recalculated after SafeArea is resolved in H-3.
Target: overlay sits in upper-right of Protagonist Zone, minimum 12px
below Top Rail bottom edge.

---

**H-5: Progress Rail missing entirely from target design**

What the screenshot shows:
There is no compressed Progress Rail between World Pulse and any action zone.
Missions exist as a full standalone section far below fold.
Collection exists as a full standalone section even further below.
Friends Activity exists as a full standalone section.

What V4 requires:
Progress Rail: 58px height, three inline modules:
Missions (label + progress bar) · Collection (count + bar) ·
World Activity (live dot + last friend action).
All three compressed into one horizontal strip.

Gap:
This zone does not exist anywhere in the target design.
Phase 2 must create it from scratch using existing data sources:
- MockDataService.continueWatchingNotifier (missions context)
- MockDataService.favoritesNotifier (collection count)
- _AnimeWorldSection._friendEvents (world activity)

---

### MEDIUM

---

**M-1: Top Rail has inconsistent visual weight**

What the screenshot shows:
AniVerse logo (star icon + wordmark + two-line tagline) occupies
approximately 60% of Top Rail horizontal space.
Right side: search icon · mail icon (with red badge) · avatar (circular, with green dot).
The avatar is relatively large (~36px diameter) and draws attention.
The mail icon has a red notification badge.

What V4 requires:
Top Rail should be minimal — identity signal, not a header.
The current treatment is directionally correct but the two-line tagline
("すべてのアニメ、ひとつの宇宙。/ ALL ANIME, ONE UNIVERSE.") adds
unnecessary vertical density at 56px height.

Gap:
At kTopRailH = 56px the two-line tagline is tight but workable.
On small screens (SE, Android compact) the tagline will be cut or cramped.
Recommendation: single-line wordmark only, tagline removed or shown as
tooltip/subtle opacity text that collapses on small screens.

---

**M-2: Protagonist Zone identity block vertical position is ambiguous**

What the screenshot shows:
Identity content (Good Evening / HITAKU / Sakura Emperor / Lv.3000 / XP bar)
is positioned in the left-bottom area of the hero zone, as approved.
However the content block starts quite high — "Good Evening" appears at
approximately y=38% of hero height, leaving significant empty space below
the XP bar before the stats row begins.

What V4 requires:
Identity anchored bottom-left. Character art dominates upper portion.
Identity block should start closer to bottom — approximately bottom 35%
of Protagonist Zone height.

Gap:
Current positioning places identity block at mid-hero, not bottom-hero.
The `_CinematicHeroContent` Column uses `Spacer()` between the wordmark
row and the protagonist block. In the lobby layout, this Spacer behavior
needs to push identity further down — approximately:
`mainAxisAlignment: MainAxisAlignment.end` with bottom padding ~20px.

---

**M-3: World Pulse right panel (Sakura Festival) has wrong visual hierarchy**

What the screenshot shows:
Sakura Festival panel shows: pink "SAKURA FESTIVAL" header text,
"EVENT SEASONAL" subtitle, large "14" countdown number, "HARI TERSISA" label,
and a "Lihat Event >" button. Full card with background art.

What V4 requires:
Right panel is an event signal — ambient, not a card.
Should read: event name (small) · countdown number (large, dominant) ·
no button inside panel (action belongs in Primary Action zone).

Gap:
"Lihat Event >" button must be removed from this panel.
Section header style ("SAKURA FESTIVAL / EVENT SEASONAL") must be
replaced with a minimal ambient label.
Card background art is correct — keep.
Overall height must compress from ~180px to ~72px (shared with left panel).

---

**M-4: CTA duplication across zones**

What the screenshot shows:
"Tonton Sekarang" button exists inside Universe Highlight panel.
"Masuk Room" button exists inside Anime Room Live section.
"Klaim Semua Reward" button exists inside Daily Missions section.
Each section has its own CTA.

What V4 requires:
One Primary Action. One dominant CTA. Context determines which.
Supporting CTAs inside zones (World Pulse panels) should not exist.

Gap:
World Pulse panel CTAs must be removed.
Primary Action zone absorbs the dominant action.
World Pulse panels become informational only — tap to navigate,
not CTA-bearing cards.

---

**M-5: Visual density is too high for a lobby canvas**

What the screenshot shows:
The visible viewport (above fold) contains:
- Top Rail with logo + 3 icons
- Hero zone with username + rank + level + XP bar + stats row
- 4-metric dashboard row
- Two large World Pulse cards with headers, text, avatars, and CTAs

Approximately 14 distinct interactive or information elements above the fold.

What V4 requires:
Lobby feel = atmosphere first, information second.
Target: maximum 6–8 distinct information signals visible above dock.
Each zone should breathe. Character art should dominate.

Gap:
Density needs to reduce by approximately 40%.
Primary reduction comes from:
1. Removing the 4-metric stats row (H-2) — eliminates 4 elements
2. Compressing World Pulse from 2 tall cards to 1 strip (H-1) — eliminates ~6 sub-elements
3. Moving CTA out of World Pulse into Primary Action (M-4) — eliminates 2 buttons

---

**M-6: Lobby Dock bottom safe area not handled**

What the screenshot shows:
Bottom nav sits flush at screen bottom. On the screenshot device (iPhone
style) there is a home indicator bar below the nav items. The nav items
appear to have internal padding that clears the home bar — but this is
not guaranteed by the current kDockH = 72.0 constant.

What V4 requires:
Dock must account for `MediaQuery.of(context).padding.bottom`
(home indicator / gesture bar height: ~34px on iPhone, ~0 on Android
with hardware buttons).

Gap:
`kDockH = 72.0` is fixed. Effective dock height should be:
`kDockH = 72.0 + MediaQuery.of(context).padding.bottom`
Or wrap dock content with `SafeArea(top: false, child: ...)`.

---

### LOW

---

**L-1: Atmosphere Bar is invisible at 3px**

What the screenshot shows:
No visible atmosphere bar strip between content and the bottom nav.
The transition from content to dock is direct.

What V4 requires:
Atmosphere Bar: 3px animated gradient strip. Color shifts with world state.

Gap:
At 3px the bar is easily invisible against dark background unless
it has sufficient glow. Phase 2 must add `boxShadow` blur to the
3px strip to make it perceivable — without increasing its physical height.
Alternative: increase to 4–6px if 3px proves imperceptible.

---

**L-2: _heroTimer advancing _currentPage serves no purpose in lobby**

What the PHASE_1_RESULT documents:
`_heroTimer` fires every 6 seconds, advancing `_currentPage`.
In lobby architecture, Protagonist Zone is one character — not a carousel.

What V4 requires:
No carousel in Protagonist Zone. Single world state.

Gap:
Timer is running but `_currentPage` is not consumed by any Phase 1
placeholder. No visible effect now. In Phase 2, when `_CinematicHero`
is wired, the carousel behavior will return unless timer is explicitly
disabled or repurposed.
Decision required before Phase 2: disable timer, or repurpose to
cycle World Pulse content instead of hero art.

---

**L-3: Page indicator dots will reappear in Phase 2**

What the screenshot shows:
Small vertical dots (page indicator) visible on right edge of hero zone,
above the World Pulse panels (faint, approximately 5 dots).

What V4 requires:
No carousel, no page indicator in Protagonist Zone.

Gap:
`_CinematicHero` renders page indicator when `widget.total > 1`.
In Phase 2, when wiring `_CinematicHero`, the `total` parameter must
be passed as `1` (or page indicator must be removed from widget).
This prevents dots from reappearing.

---

**L-4: Sakura particle parallax permanently muted**

What the PHASE_1_RESULT documents:
`_scrollCtrl` has no scroll source. Parallax input to `_SakuraPainter`
is permanently `0`. Particles animate but lack depth.

Gap:
Low visual impact — particles still animate and contribute atmosphere.
Phase 8 (per PHASE_1_RESULT recommendation) should introduce a
replacement input: gyroscope data, subtle idle drift, or remove
parallax input entirely and add a secondary drift animation to the painter.

---

## Zone Proportion Analysis

Target proportions for 812px screen height (iPhone 8 / SE baseline):

| Zone | Target H | % of screen | Status in screenshot |
|---|---|---|---|
| Top Rail | 56px + SafeArea | 7% | Present, needs SafeArea |
| Protagonist Zone | ~354px | 44% | Present but diluted by stats row |
| World Pulse | 72px | 9% | Oversized (~180px = 22%) |
| Progress Rail | 58px | 7% | Absent from design |
| Primary Action | 68px | 8% | Absent from design |
| Atmosphere Bar | 3px | <1% | Invisible |
| Lobby Dock | 72px + SafeArea | 9% | Present, needs SafeArea |
| **Total** | **683px** | **84%** | |
| System safe areas | ~93px | 11% | Not accounted |
| Remaining float | ~36px | 4% | buffer |

Critical gap: Progress Rail + Primary Action = 126px of screen height
that currently does not exist in the target design. This space comes
from compressing World Pulse from 180px to 72px (saves 108px) and
removing the stats row (saves ~52px). Net gain: 160px available.
126px needed. Buffer: 34px. Math works.

---

## Phase 2 Goals

### Primary Goal
Wire `_CinematicHero` into Protagonist Zone (L2).

### Mandatory Before Phase 2 Code

1. **Decide: `_heroTimer` fate**
   Disable timer (`_heroTimer?.cancel()` in `initState` after first fire,
   or simply don't start it). Protagonist Zone is not a carousel.
   `_currentPage` becomes irrelevant.

2. **Resolve: `_scrollCtrl` parameter**
   Make `scrollCtrl` optional in `_CinematicHero` signature with default null.
   Guard all `.offset` reads: `scrollCtrl?.hasClients == true ? scrollCtrl!.offset : 0.0`.
   This is a minimal signature change — not a full widget migration.

3. **Resolve: SafeArea for Top Rail and Dock (H-3, M-6)**
   Before any real content is wired, safe area must be computed.
   Both `kTopRailH` and `kDockH` must become dynamic values, not const.
   Compute once in `build()` using `MediaQuery.of(context).padding`.

### Phase 2 Scope (Protagonist Zone only)

Step 1: Resolve `_scrollCtrl` parameter (make optional, guard reads).
Step 2: Compute `safeTop` and `safeBottom` from MediaQuery in `build()`.
Step 3: Update `kTopRailH` and `kDockH` to include safe area padding.
Step 4: Recalculate `protagonistH` with updated constants.
Step 5: Replace L2 `_LobbyZonePlaceholder` with `_CinematicHero`.
Step 6: Pass `total: 1` to suppress page indicator dots.
Step 7: Move identity block anchor to bottom: verify `_CinematicHeroContent`
        Column alignment pushes identity block to bottom 35% of zone.
Step 8: Remove `_heroTimer` auto-advance (or repurpose — decision required).
Step 9: Verify Protagonist Zone height visually dominates all other zones.

### Phase 2 Out of Scope
- World Pulse content wiring
- Progress Rail creation
- Primary Action creation
- Top Rail real content
- Lobby Dock restyle
- Stats row removal (part of _CinematicHeroContent — Phase 3)
- Global Activity Overlay repositioning

### Post Phase 2 Sequence (unchanged from PHASE_1_RESULT)
- Phase 3: Top Rail real content
- Phase 4: World Pulse (compress to 72px strip, remove section headers and CTAs)
- Phase 5: Progress Rail (new widget — three inline modules)
- Phase 6: Primary Action (new widget — contextual CTA)
- Phase 7: Lobby Dock restyle
- Phase 8: Atmosphere Bar animation + Overlay repositioning
- Phase 9: Stats row removal from _CinematicHeroContent
- Phase 10: Performance audit

---

## Summary

| Severity | Count | Resolved in Phase |
|---|---|---|
| CRITICAL | 4 | C-1→phases 4–6, C-2→phase 2+9, C-3→phase 6, C-4→phase 7 |
| HIGH | 5 | H-1→phase 4, H-2→phase 9, H-3→phase 2, H-4→phase 2, H-5→phase 5 |
| MEDIUM | 6 | M-1→phase 3, M-2→phase 2, M-3→phase 4, M-4→phase 6, M-5→phases 4–6, M-6→phase 2 |
| LOW | 4 | L-1→phase 8, L-2→phase 2, L-3→phase 2, L-4→phase 8 |
| **Total** | **19** | |

Phase 2 resolves: H-3, H-4, M-2, M-6, L-2, L-3 — 6 issues closed.
Most visually impactful change in Phase 2: SafeArea + Protagonist dominance.
Most architecturally impactful: `_heroTimer` decision + `_scrollCtrl` decoupling.
