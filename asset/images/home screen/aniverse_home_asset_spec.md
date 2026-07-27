# AniVerse — Home Screen Asset Spec (Dark Liquid Glass)

Tema global semua aset di bawah: **dark liquid glass**, warm-dark base, aksen gold/purple. Semua PNG **transparent background**, export **@2x/@3x** kalau bisa (base size di bawah = @1x logis untuk Flutter `width`/`height`).

---

## 1. Genre Grid — karakter siluet per genre
**Path:** `asset/images/home screen/genre_<slug>.png`
**Ukuran:** 120×120 px, transparent bg
**Style:** Flat anime-art silhouette / half-body, warna dasar mengikuti `genreColors` di kode (bukan full color painting — cukup 1–2 tone + rim light tipis), posisi karakter nempel ke tepi kanan-bawah supaya pas di-fade dari kiri.
**Komposisi:** Karakter menghadap sedikit ke kiri (ke arah teks), crop dari dada ke atas atau full body kecil, jangan terlalu detail (card cuma ~78px lebar render-nya).

| File | Genre | Konsep karakter | Warna aksen |
|---|---|---|---|
| `genre_action.png` | Action | Swordsman/petarung pose dinamis, jubah berkibar | `#EF4444` merah |
| `genre_adventure.png` | Adventure | Petualang dengan ransel/kompas, latar gunung samar | `#22C55E` hijau |
| `genre_comedy.png` | Comedy | Karakter ekspresif, mata bintang/gaya chibi ringan | `#F59E0B` kuning |
| `genre_drama.png` | Drama | Sosok kontemplatif, cahaya rim tipis | `AppTheme.accent` (gold) |
| `genre_sci_fi.png` | Sci-Fi | Karakter dengan elemen tech/visor, garis neon halus | `#06B6D4` cyan |
| `genre_fantasy.png` | Fantasy | Penyihir/elf, elemen magic circle tipis | `AppTheme.accent` (gold) |
| `genre_horror.png` | Horror | Sosok berkabut/bayangan, mata menyala redup | `#6B7280` abu gelap |

---

## 2. Trending Row — badge rank #1
**Path:** `asset/images/home screen/badge_crown_gold.png`
**Ukuran:** 44×44 px (render di app 22×22 @1x — buat 2x biar tajam), transparent bg
**Style:** Mahkota emas metalik kecil, sudut isometrik ringan, highlight spekular di atas, drop shadow lembut sudah "baked in" ke PNG (karena posisinya melayang di atas badge angka).
**Catatan:** Ini murni dekorasi tambahan di atas badge angka gold yang sudah ada — jangan terlalu ramai, siluet harus jelas di ukuran kecil.

---

## 3. Flash Sale Banner — item preview
**Path:** `asset/images/home screen/flashsale_item_sakura_emperor_border.png`
**Ukuran:** 80×80 px (render di app 40×40 @1x), transparent bg
**Style:** Render item "Sakura Emperor Border" (profile border kosmetik) — bentuk cincin/frame melingkar dengan motif sakura, warna gold-orange (`#FFD700` → `#FF8800`), glow sudah baked in ke PNG (jangan andalkan boxShadow luar sepenuhnya, biar item terasa "menyala dari dalam").
**Catatan:** Ini item **beda dari** cosmetic showcase di bawah — meski nama mirip, treat sebagai render terpisah, boleh angle berbeda.

---

## 4. Cosmetic Spotlight — "Golden Dragon Ring"
**Path:** `asset/images/home screen/cosmetic_golden_dragon_ring.png`
**Ukuran:** 88×88 px (render di app 44×44 @1x), transparent bg
**Style:** Cincin naga emas 3D-ish render, naga melingkar membentuk cincin, mata permata kecil (ruby/emerald) sebagai aksen, metallic gold gradient, glow ambient baked in.

---

## Aturan umum biar konsisten & aman di kode

1. **Transparent PNG selalu** — semua widget punya fallback (icon/warna lama) kalau file belum ada atau gagal load, jadi build nggak akan crash. Begitu file kamu taruh di path yang benar, otomatis muncul.
2. **Jangan taruh shadow/vignette gelap di tepi luar gambar** kalau bakal ditumpuk di atas background gelap — cukup glow warna sendiri, biar nggak ada kotak gelap kelihatan.
3. **Resolusi:** Flutter otomatis pakai versi tertinggi yang ada (`@2x`, `@3x` folder) kalau kamu sediakan; kalau cuma 1 file, minimal 2x dari ukuran render supaya nggak pecah di layar HD.
4. **Penamaan file harus persis** seperti di tabel (huruf kecil semua, underscore, spasi di path folder "home screen" tetap ada karena itu path folder-nya, bukan nama file).
5. **Palet warna referensi:** ambil dari `AppTheme` — accent (gold `#F0D08A`-ish), highlight, primary/purple — supaya semua aset baru nyambung ke tema "Studio Ghibli Warm Dark → Liquid Glass" yang sudah jalan.

---

## Belum ada spek (menyusul saat section-nya digarap)
- Live Rooms — thumbnail cover per room
- Weekly Challenge — ikon trofi/medali gold-liquid
- Daily Login milestone — ikon hadiah Day 1/3/7

Kasih tahu kalau mau saya lanjut bikinin spek section-section ini juga sekarang, atau nanti pas gilirannya dikerjain.
