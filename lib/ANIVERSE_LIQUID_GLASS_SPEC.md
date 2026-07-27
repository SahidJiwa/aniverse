# AniVerse — Liquid Glass Spec (v1, sourced from `jadwal_screen.dart`)

Reusable prompt/spec. Paste this whole block when asking Claude to apply
liquid glass to a new screen (`home_screen.dart`, `watch_screen.dart`,
`vault_screen.dart`, etc).

---

## PROMPT TO REUSE

> Terapkan AniVerse Liquid Glass style (spec di bawah) ke `[NAMA_FILE].dart`.
> Port `_LiquidGlassPill` dan `GradientBoxBorder` dari `jadwal_screen.dart`
> apa adanya (jangan re-derive dari nol), lalu pasang ke [SEBUTKAN ELEMEN:
> header, search bar, tab/day selector, cards, dll]. Kalau elemen itu
> punya dua state (selected/unselected, active/inactive), pastikan KEDUA
> cabang punya `height` eksplisit yang sama — jangan andalkan intrinsic
> sizing dari child, itu penyebab bug "geser saat pertama render vs
> setelah tap" yang udah pernah kejadian di jadwal_screen. Backdrop foto
> (kalau ada) dikasih dark overlay `Colors.black.withValues(alpha: X)` —
> mulai dari 0.3–0.4, aku kasih tau kalau kurang gelap.

---

## 1. Komponen inti — PORT, jangan tulis ulang

- `_LiquidGlassPill` (StatelessWidget) — dari `jadwal_screen.dart`
- `GradientBoxBorder` (extends `BoxBorder`) — dari `jadwal_screen.dart`

Kedua class ini generik, tidak bergantung ke state Jadwal Rilis. Copy-paste
langsung ke file baru atau (lebih baik, kalau dipakai di ≥2 screen) pindahkan
ke `widgets/liquid_glass.dart` supaya satu sumber kebenaran.

## 2. Parameter kunci `_LiquidGlassPill`

| Param | Default | Kapan diubah |
|---|---|---|
| `borderRadius` | 18 | 18 untuk pill kecil (tab/badge), 20–24 untuk card besar |
| `padding` | `EdgeInsets.symmetric(h:16, v:8)` | `EdgeInsets.zero` kalau child sudah punya padding sendiri (mis. `_dayPillContent`) |
| `height` | null | **WAJIB diisi eksplisit** kalau widget ini punya sibling/cabang lain (selected vs unselected) yang harus sama tinggi. Kalau berdiri sendiri (mis. search bar), boleh null. |
| `alignment` | `Alignment.centerLeft` | Set `Alignment.center` untuk pill/badge; biarkan default untuk elemen isi teks panjang (search bar, dsb) |
| `compact` | false | true untuk elemen kecil (badge, tag, tab pill) — blur lebih rendah (5 vs 8) + fill/border lebih pekat, biar detail nggak washed out di area sekecil itu |

## 3. Visual recipe (nilai baku, jangan diubah tanpa alasan)

- **Blur**: `sigmaX/Y = compact ? 5.0 : 8.0`
- **Fill**: `RadialGradient`, center `Alignment(-0.6, -0.8)`, radius `1.4`,
  alpha `compact ? 0.10/0.05 : 0.08/0.03` (top-left brighter → falloff)
- **Border**: `GradientBoxBorder`, width `1.0`, top→bottom alpha
  `compact ? 0.40→0.08 : 0.32→0.05`
- **Shadow**: dua layer — `alpha 0.12 blur 18 offset(0,6)` +
  `alpha 0.08 blur 4 offset(0,1)`
- **Top sheen**: `Positioned` strip tinggi `(height ?? 40) * 0.5`,
  gradient putih `alpha compact?0.10:0.06 → 0`
- **Inner refraction**: lingkaran soft di `Alignment(0.7, 0.9)`,
  `widthFactor/heightFactor: 0.5`, radial alpha `compact?0.05:0.035 → 0`

Nilai-nilai ini yang bikin efek "glass" tetap kelihatan meski di atas
backdrop gelap — jangan naikkan alpha fill terlalu tinggi atau efeknya jadi
solid box biasa, bukan glass.

## 4. Anti-bug checklist (WAJIB dicek tiap kali pasang ke elemen baru)

Ini lesson-learned dari bug day-pill di Jadwal Rilis — dua cabang render
beda ukuran di first-build vs after-rebuild karena keduanya sizing dari
intrinsic content, bukan dari constraint tetap.

- [ ] Kalau elemen punya >1 visual state (selected/unselected,
      active/inactive, loading/loaded): **beri `height` (dan `width` kalau
      relevan) eksplisit yang identik** di kedua cabang — jangan biarkan
      Flutter menghitung sendiri dari child.
- [ ] Kalau isi elemen berupa `Column`/`Row` yang kontennya bisa berubah
      (mis. angka badge yang awalnya `—` lalu jadi `4`), bungkus dengan
      `SizedBox(width/height: fixed)` supaya intrinsic size-nya tidak
      goyang antara loading state dan data-loaded state.
- [ ] Test bukan cuma elemen yang lagi "selected" tapi juga yang belum
      pernah disentuh (first paint) — itu yang paling sering ke-skip.

## 5. Backdrop darken overlay (untuk screen dengan foto di background)

```dart
colorFilterColor: Colors.black.withValues(alpha: X),
```

- Titik awal aman: `0.3`
- Naikkan bertahap (`+0.12` per iterasi) kalau masih kurang kontras
- Jadwal Rilis saat ini di `0.58` — kalau home_screen pakai backdrop foto
  serupa, mulai dari situ sebagai referensi, bukan dari 0.3 lagi

## 6. Current known usage

- `widgets/liquid_glass.dart`: **UPDATED** — the content `Padding` inside
  `LiquidGlassPill`'s internal `Stack` is now wrapped in `Positioned.fill`.
  This was found missing here while diffing against `home_screen.dart`'s
  local copy, which already had the fix: without it, that `Padding` is a
  non-positioned child inside the `Stack` and sizes from its own
  intrinsic content instead of filling the pill — the exact
  first-paint-vs-after-rebuild size mismatch the anti-bug checklist (§4)
  warns about. If any screen migrated to `LiquidGlassPill` *before* this
  fix, it's worth a quick re-check for that symptom, though none has been
  reported so far.
- `home_screen.dart`: fully migrated — local `_LiquidGlassPill` /
  `GradientBoxBorder` class definitions removed, all 19 call sites
  renamed to the shared `LiquidGlassPill` from `widgets/liquid_glass.dart`
  (Daily Mission card, chips, hero section, and others). The dead
  `import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';` was
  also removed — grepped the whole file first and confirmed zero usage of
  any class from that external package (it was leftover from an earlier
  approach, fully superseded by the hand-rolled `LiquidGlassPill`). The
  `dart:ui as ui` import stays, since several manual `BackdropFilter`
  blurs elsewhere in this file (outside `LiquidGlassPill`) still use it
  directly.
- `jadwal_screen.dart`: header glass shell, day-selector tab pills
  (unselected branch), live-pulse badge. Refactored to import
  `LiquidGlassPill`/`GradientBoxBorder` from `widgets/liquid_glass.dart`
  instead of defining them locally — this file is no longer the source of
  truth, `widgets/liquid_glass.dart` is.
- `anime_detail_screen.dart`: rating badge, genre chips, `_InfoGrid`
  (Studio/Episodes/Status/Rank panel), back button + favorite/watchlist
  top-bar icons (circle via `borderRadius: 24`, `compact: true`) all
  migrated to `LiquidGlassPill`. Synopsis card and the Watchlist/Favorite
  morph-toggle button use `LiquidGlassPill` as a base layer with a
  `DecoratedBox`/`AnimatedContainer` overlay on top for their
  per-instance accent glow / active-state tint, since `LiquidGlassPill`'s
  shared recipe is intentionally neutral-white-only (no per-instance tint
  param) — see inline comments at each site for why. Episode list tiles
  deliberately NOT migrated (list can be 28+ items; a shared blur per row
  is a scroll-perf risk).
- `voice_actors_section.dart`: voice-actor detail dialog (static,
  non-scrolling) migrated to `LiquidGlassPill` + accent-glow
  `DecoratedBox` overlay, same pattern as Synopsis. The small
  bottom-of-avatar language ribbon (9px text) deliberately NOT migrated —
  `LiquidGlassPill`'s neutral-white tint washes out at that size over a
  colorful photo; kept as manual `BackdropFilter` with a darker
  background-tinted fill for contrast.
- *(update baris ini tiap kali dipasang ke screen baru)*
