Reading everything first.Semua terbaca. Ini full audit-nya.

---

## 1. Widget Tree

```
HomeScreen (StatefulWidget)
└── Scaffold
    └── Stack
        ├── Positioned.fill → AnimatedBuilder → CustomPaint(_UniverseBackgroundPainter)
        ├── Positioned.fill → AnimatedBuilder → CustomPaint(_SakuraPainter)        ← parallax dari _scrollCtrl
        ├── CustomScrollView(controller: _scrollCtrl)
        │   └── SliverToBoxAdapter
        │       └── Column
        │           ├── _CinematicHero                                              ← consumes scrollCtrl + zoomAnim
        │           │   └── Stack
        │           │       ├── AnimatedBuilder → Image.network (artwork)           ← parallax dari scrollCtrl
        │           │       ├── AnimatedBuilder → CustomPaint(_HeroAtmospherePainter) ← parallax dari scrollCtrl
        │           │       ├── Container (gradient plane A, B, C)
        │           │       ├── Positioned → AnimatedBuilder (top-right bloom)
        │           │       ├── AnimatedSwitcher → _CinematicHeroContent            ← username, rank, XP, CTA
        │           │       └── Positioned → page indicator dots
        │           ├── _AnimeWorldSection (StatelessWidget)
        │           │   ├── _sectionLabel
        │           │   ├── _FeaturedRoomScene                                      ← own AnimationController
        │           │   │   └── Stack: Image + gradients + _WorldAura + content
        │           │   │       ├── _LiveBadge                                      ← own AnimationController
        │           │   │       ├── _RoomEnergyBar                                  ← own AnimationController
        │           │   │       ├── _AvatarCluster → _BreathingAvatar ×5            ← each own AnimationController
        │           │   │       ├── _GlowTag ×3                                    ← each own AnimationController
        │           │   │       ├── _LiveChatStream                                 ← own AnimationController
        │           │   │       └── _JoinRoomCTA                                    ← own AnimationController
        │           │   ├── ListView.builder (horizontal)
        │           │   │   ├── _RoomCard ×3                                        ← each own AnimationController
        │           │   │   └── _CreateRoomCard
        │           │   └── friends list (_friendEvents ×3, inline RichText)
        │           ├── _CommunitySection (StatelessWidget)
        │           │   └── static content + TextButton
        │           └── SizedBox(height: 100)
        ├── Positioned.fill → IgnorePointer → _GlobalActivityOverlay               ← own AnimationController, floating pill
        └── Positioned(top) → IgnorePointer → AnimatedBuilder (top edge bloom)
```

---

## 2. State Variables

| Variable | Type | Purpose |
|---|---|---|
| `_topAnimes` | `List<AnimeModel>` | API result dari `fetchTopAnime` |
| `_seasonalAnimes` | `List<AnimeModel>` | API result dari `fetchCurrentSeasonAnime` |
| `_currentPage` | `int` | Index hero carousel saat ini (0–4) |

---

## 3. Controllers

| Controller | Duration | Mode | Used By |
|---|---|---|---|
| `_zoomCtrl` | 20s | repeat reverse | `_zoomAnim` → artwork scale di `_CinematicHero` |
| `_particleCtrl` | 10s | repeat | `_UniverseBackgroundPainter`, `_SakuraPainter`, top edge bloom |
| `_scrollCtrl` | — | ScrollController | `_SakuraPainter` parallax, `_CinematicHero` parallax + zoom-on-scroll |
| `_driftCtrl` (inside `_CinematicHeroState`) | 16s | repeat reverse | artwork horizontal drift |
| `_pulseCtrl` (inside `_CinematicHeroState`) | 2s | repeat reverse | `_HeroAtmospherePainter`, top-right bloom, CTA glow |
| `_c` in `_FeaturedRoomSceneState` | 3s | repeat reverse | border glow, `_WorldAura` |
| `_c` in `_RoomCardState` ×3 | 2s | repeat reverse | border glow per card |
| `_c` in `_GlobalActivityOverlayState` | 8.2s | repeat | floating activity pill |
| `_c` in `_LiveBadgeState` | 800ms | repeat reverse | live dot pulse |
| `_c` in `_LiveDotState` | 1s | repeat reverse | live dot glow |
| `_c` in `_LiveChatStreamState` | 3.6s | repeat | chat message cycling |
| `_c` in `_RoomEnergyBarState` | 1.5s | forward | bar fill animation |
| `_c` in `_BreathingAvatarState` ×5 | 1.5–2s | repeat reverse | avatar scale breathing |
| `_c` in `_GlowTagState` ×3 | 2s | repeat reverse | tag border glow |
| `_c` in `_JoinRoomCTAState` | 2s | repeat reverse | button glow pulse |

**Total controller instances aktif sekaligus: ~20+**

---

## 4. Timers

| Timer | Interval | Purpose |
|---|---|---|
| `_heroTimer` | 6 detik | Auto-advance `_currentPage` → hero carousel |

---

## 5. Dependencies (External)

| Import | Used For |
|---|---|
| `anime_api_service.dart` | `fetchTopAnime()`, `fetchCurrentSeasonAnime()` |
| `mock_data_service.dart` | `getMockAnimes()`, `favoritesNotifier`, `recentlyWatchedNotifier`, `continueWatchingNotifier` |
| `anime_model.dart` | `AnimeModel` type |
| `anime_detail_screen.dart` | Navigator push dari hero CTA |
| `app_theme.dart` | `AppTheme.sakuraPink`, `AppTheme.surfaceDark` |
| `watch_screen.dart` | Navigator push dari hero CTA |
| `recommendation_service.dart` | `RecommendationService.compute()` |

**ValueNotifier listeners aktif:** `favoritesNotifier`, `recentlyWatchedNotifier`, `continueWatchingNotifier` — semua trigger `_computeRecommendations()` → `setState()`.

---

## 6. Widgets yang Akan Break Ketika `CustomScrollView` Dihapus

**Langsung break:**

`_CinematicHero` — tiga tempat di dalamnya secara eksplisit membaca `widget.scrollCtrl.offset`:
- `widget.scrollCtrl.hasClients ? widget.scrollCtrl.offset.clamp(0.0, 500.0)` di artwork transform
- `widget.scrollCtrl.hasClients ? widget.scrollCtrl.offset.clamp(0.0, 500.0)` di `_HeroAtmospherePainter`
- `scroll * 0.22` sebagai parallax offset, `scroll * 0.00013` sebagai zoom multiplier

Jika `CustomScrollView` dihapus dan `_scrollCtrl` tidak punya scroll source, `hasClients` tetap true tapi `offset` akan selalu `0.0` — tidak crash, tapi semua parallax efek mati diam-diam.

`_SakuraPainter` — membaca `_scrollCtrl.offset * 0.12` sebagai parallax. Sama, mati diam-diam.

Top edge bloom di `build()` — `AnimatedBuilder(animation: _particleCtrl, ...)` membaca `_particleCtrl.value` untuk breath. Ini aman, tidak depends on scroll.

**Tidak langsung break, tapi kehilangan konteks:**

`_AnimeWorldSection` dengan internal `ListView` horizontal — ListView ini punya `ScrollController` sendiri yang terpisah, jadi tidak break. Tapi widget ini adalah `StatelessWidget` yang di-build inside `Column` inside `SliverToBoxAdapter` — ketika `CustomScrollView` hilang, seluruh ini perlu di-rewrap.

**Perlu explicit height setelah migration:**

Semua widget di dalam `Column` di `SliverToBoxAdapter` sekarang mendapat height unbounded dari sliver system. Setelah pindah ke `Stack`, setiap zone perlu `Positioned` atau `SizedBox` dengan explicit constraint — terutama `_AnimeWorldSection` yang mengandung `ListView` horizontal.

---

## 7. Exact Migration Risks

**Risk 1 — Scroll parallax orphan (HIGH)**
`_scrollCtrl` di-pass ke `_CinematicHero` sebagai required parameter dan dibaca di tiga `AnimatedBuilder`. Setelah `CustomScrollView` dihapus, controller ini tidak punya source. Options: hapus parallax (paling bersih), atau ganti dengan `GestureDetector` drag delta untuk simulasi efek. Keputusan ini harus dibuat sebelum Phase 1.

**Risk 2 — `_CinematicHero` height assumption (HIGH)**
`heroH = (screenH * 0.50).clamp(390.0, 500.0)` — hero sekarang mengatur height-nya sendiri berdasarkan `MediaQuery`. Di arsitektur lobby baru, Protagonist Zone perlu height yang lebih besar (~65% viewport minus rail dan dock). Nilai clamp ini perlu direvisi dan dikontrol dari parent `Stack`, bukan dari dalam widget.

**Risk 3 — `_AnimeWorldSection` adalah Column yang tidak tahu tingginya (MEDIUM)**
Section ini render tanpa fixed height — relies on scroll to give infinite vertical space. Di `Stack` lobby, zone ini harus masuk ke `Positioned` dengan explicit top/bottom bounds. Internal `ListView` horizontal aman, tapi outer `Column` perlu dibatasi.

**Risk 4 — `_GlobalActivityOverlay` alignment hardcoded (MEDIUM)**
Overlay ini di-position dengan `Alignment(0.72, -0.68)` — koordinat relatif ke full-screen `Stack`. Di arsitektur baru, overlay ini perlu di-remap ke zona yang benar (World Pulse atau Protagonist Zone) agar tidak overlap dengan Top Rail.

**Risk 5 — `_heroTimer` masih auto-advance carousel (LOW)**
Timer ini advance `_currentPage` setiap 6 detik. Di lobby, hero bukan carousel — satu karakter, satu world state. Timer perlu di-disable atau di-repurpose untuk rotate World Pulse content, bukan page index.

**Risk 6 — `_computeRecommendations()` memanggil `setState()` (LOW)**
Setiap kali notifier berubah, seluruh `build()` di-rebuild. Di arsitektur scroll ini tidak masalah. Di lobby, rebuild penuh pada `Stack` dengan 20+ AnimationController akan mahal. Perlu isolasi rebuild ke zone-level widget masing-masing.

**Risk 7 — `_SakuraPainter` parallax input hilang (LOW)**
Parallax dari `_scrollCtrl.offset * 0.12` akan jadi `0` permanent. Efek partikel tetap jalan, tapi tidak ada depth. Ini bisa diterima atau diganti dengan mouse/gyro parallax — keputusan opsional.

---

Semua dependency, controller, dan risk sudah terpetakan. Siap untuk Phase 1 instruksi dari lu.