#!/usr/bin/env python3
"""
bulk_links.py — generator entry my_episode_links.dart dari list URL.

Cara pakai:
  1. Buat file urls.txt, tiap baris:
       <Judul Anime>|<nomor episode>|<kualitas>|<URL>
     contoh:
       Tomb Raider King|1|360p|https://stor.halahgan.com/.../trk-01-360p.mp4
       Tomb Raider King|1|480p|https://stor.halahgan.com/.../trk-01-480p.mp4
       Tomb Raider King|2|360p|https://stor.halahgan.com/.../trk-02-360p.mp4
  2. Jalankan:
       python3 tools/bulk_links.py urls.txt
  3. Output (STDOUT) = entry Dart siap tempel ke my_episode_links.dart

Note: judul otomatis di-join pakai '_' (spasi -> underscore) biar match
dengan resolver di watch_screen. Kualitas bebas (360p/480p/Auto/dll).
"""
import sys
import re
from collections import defaultdict

def normalize_title(title: str) -> str:
    # "Tomb Raider King" -> "Tomb Raider King" (spasi dipertahankan di key,
    # tapi resolver cocokkan case-insensitive + trim, jadi aman)
    return title.strip()

def main():
    if len(sys.argv) < 2:
        print("Pakai: python3 tools/bulk_links.py urls.txt", file=sys.stderr)
        sys.exit(1)

    path = sys.argv[1]
    try:
        with open(path, "r", encoding="utf-8") as f:
            lines = f.readlines()
    except FileNotFoundError:
        print(f"File gak ketemu: {path}", file=sys.stderr)
        sys.exit(1)

    # episode_map[(title, ep)] = {quality: url}
    episode_map = defaultdict(dict)
    skipped = 0
    for raw in lines:
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("|")
        if len(parts) != 4:
            print(f"  skip (format salah): {line}", file=sys.stderr)
            skipped += 1
            continue
        title, ep, quality, url = (p.strip() for p in parts)
        if not url.lower().startswith(("http://", "https://")):
            print(f"  skip (url gak valid): {line}", file=sys.stderr)
            skipped += 1
            continue
        episode_map[(title, ep)][quality] = url

    if not episode_map:
        print("Gak ada entry valid.", file=sys.stderr)
        sys.exit(1)

    # Urutkan biar rapi
    out = []
    for (title, ep) in sorted(episode_map.keys(), key=lambda k: (k[0].lower(), int(k[1]) if k[1].isdigit() else 0)):
        qualities = episode_map[(title, ep)]
        key = f"{title}_{ep}"
        if len(qualities) == 1:
            (q, u), = qualities.items()
            out.append(f"  '{key}': MyEpisodeLink({{\n    '{q}': '{u}',\n  }}),")
        else:
            lines_q = ",\n".join(f"    '{q}': '{u}'" for q, u in qualities.items())
            out.append(f"  '{key}': MyEpisodeLink({{\n{lines_q},\n  }}),")

    print("  // ══════════════════════════════════════════════════")
    print(f"  // Bulk-generated ({len(episode_map)} episode) — tempel di bawah myEpisodeLinks")
    print("  // ══════════════════════════════════════════════════")
    print("\n".join(out))
    if skipped:
        print(f"\n  (skip {skipped} baris format salah)", file=sys.stderr)

if __name__ == "__main__":
    main()
