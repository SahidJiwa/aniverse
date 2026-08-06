// my_episode_links.dart
//
// ============================================================
// LINK VIDEO KAMU SENDIRI — INI SATU-SATUNYA FILE YANG PERLU
// KAMU EDIT SETIAP UPLOAD EPISODE BARU.
// ============================================================
//
// Cara pakai (1 kualitas aja):
//   'Judul Anime_1': MyEpisodeLink({
//     'Auto': 'https://link-video-kamu.com/ep1.mp4',
//   }),
//
// ── OPSI A (tercepat, gak download/upload): ──────────────────────────────
//   Copy URL mentah .m3u8 / .mp4 langsung dari DevTools (Network → filter
//   m3u8/mp4 → klik kanan → Copy link address). Tempel apa adanya — app
//   otomatis wrap lewat Cloudflare Worker biar gak kena anti-hotlink.
//   Contoh (URL upbolt/oploverz yg lo copy):
//   'Tomb Raider King_1': MyEpisodeLink({
//     'Auto': 'https://edge01.upbolt.to/xxx/playlist.m3u8',
//   }),
//   → app otomatis jadi:
//   https://aniverse-video-proxy.my-aniverse.workers.dev/stream?url=...
//   NOTE: token upbolt bisa expired — kalau besok mati, copy URL baru.
//
// Cara pakai (banyak kualitas, biar ada tombol pilih kualitas
// di player — lihat panduan generate multi-kualitas dari 1 file
// pakai ffmpeg yang dikasih terpisah):
//   'Judul Anime_1': MyEpisodeLink({
//     '1080p': 'https://link-video-kamu.com/ep1_1080p.mp4',
//     '720p':  'https://link-video-kamu.com/ep1_720p.mp4',
//     '480p':  'https://link-video-kamu.com/ep1_480p.mp4',
//     '360p':  'https://link-video-kamu.com/ep1_360p.mp4',
//     '240p':  'https://link-video-kamu.com/ep1_240p.mp4',
//     '144p':  'https://link-video-kamu.com/ep1_144p.mp4',
//   }),
//
// - Key kualitas BEBAS namanya, tapi disaranin pakai salah satu dari
//   '1080p','720p','480p','360p','240p','144p','Auto' — WatchScreen
//   otomatis milih yang paling tinggi buat diputer duluan, dan
//   nampilin tombol kualitas di player kalau entry-nya lebih dari 1.
// - Kalau cuma isi 1 kualitas, tombol pilih kualitas otomatis
//   disembunyikan (gak ada gunanya buat dipilih).
// - Judul anime gak harus persis sama huruf besar/kecil atau
//   spasi — dicocokkan otomatis. Yang penting nomor episode-nya pas.
// - Episode yang BELUM diisi di sini otomatis fallback ke sistem
//   lama (videoUrl bawaan episode, lalu auto-scrape).
// Cara pakai (nambahin subtitle .srt/.vtt, opsional):
//   'Judul Anime_1': MyEpisodeLink({
//     'Auto': 'https://link-video-kamu.com/ep1.mp4',
//   }, subtitleUrl: 'https://link-video-kamu.com/ep1.vtt'),
//
// - subtitleUrl harus file .srt atau .vtt yang timing-nya udah pas
//   sama video di atas (bukan subtitle acak dari sumber lain).
// - Kalau gak diisi, tombol CC di player otomatis kasih tau "Subtitle
//   belum tersedia" pas di-tap, gak pura-pura kerja.
// ============================================================

class MyEpisodeLink {
  /// Kualitas -> link video. Minimal harus ada 1 entry.
  final Map<String, String> qualities;
  final String? thumbnailUrl;

  /// Link subtitle (.srt/.vtt) yang timing-nya sinkron sama video di
  /// [qualities] — opsional, kosongin kalau belum ada.
  final String? subtitleUrl;

  /// URL HALAMAN episode (bukan file video) — opsional.
  /// Kalau diisi, app bakal minta Cloudflare Worker
  /// (aniverse-stream-proxy) nge-resolve halaman ini jadi URL .m3u8/.mp4
  /// otomatis. Ini buat anime baru: lo cuma tempel URL halaman situs
  /// (oploverz/animeboy/dll), Worker yang cari video tiap play.
  /// Contoh: 'https://oploverz.site/series/xxx/episode/1'
  final String? pageUrl;

  const MyEpisodeLink(
    this.qualities, {
    this.thumbnailUrl,
    this.subtitleUrl,
    this.pageUrl,
  });
}

const Map<String, MyEpisodeLink> myEpisodeLinks = {
  // ══════════════════════════════════════════════════════════════
  // Sousou no Frieren
  // ══════════════════════════════════════════════════════════════
  'Sousou no Frieren_1': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/a97b2a070fc918b21efe6f892bd0ea49575f3978-svnAOy.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+01+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2001%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/f9bf1e6c0c85d27619d88402691c65dd665f623a-RfcDcj.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+01+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2001%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/c79b439311c8b774e7bf51de2555c030b74883e8-ihzh1K.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+01+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2001%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/ba63c1373fec268eb2fa502ab454979f503f298e-8m8nDh.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+01+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2001%20%28360p%29.mp4',
    '240p':
        'https://github.com/SahidJiwa/Sousou-no-Frieren/releases/download/frieren-ep1/ep.1_240p.mp4',
    '144p':
        'https://github.com/SahidJiwa/Sousou-no-Frieren/releases/download/frieren-ep1/ep.1_144p.mp4',
  }),
  'Sousou no Frieren_2': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/d6b7dee64a834e6736c931e88de06a8d69de30bf-LiDdEx.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+02+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2002%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/b3f44d85538bc844d54c9c80656ea7acaa721e65-fqLoyF.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+02+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2002%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/2189ef1ae0f5d998154b5bc3280f0fcbff23d4bc-3VaJKc.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+02+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2002%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/f2b96fcd2aeab4f45df2b55171c32ff587520f0f-V7Ej0M.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+02+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2002%20%28360p%29.mp4',
  }),
  'Sousou no Frieren_3': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/c7c924720409039a91807094c450fb26282ed6c6-57YGrG.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+03+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2003%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/a37d21365013c411574aafb29a582ec6c4b54a2c-RAeb8d.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+03+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2003%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/3643f88285ee752705235e14afb1930ed75b2490-Wkngvr.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+03+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2003%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/91fb401007e4126bd5dc41e5222921ac065e3c9c-AtY6wu.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+03+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2003%20%28360p%29.mp4',
  }),
  'Sousou no Frieren_4': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/0fbbf6324b10be138bf87253be10764760fe2d24-onJuWz.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+04+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2004%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/20463b69567375bc9bfc66a7a5c416c240fb97f2-lz1Zxs.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+04+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2004%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/6f876945b24efb545b56e0fad78ee04297f7a1c6-T30Omn.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+04+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2004%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/b11307fa59885b9fa98d138b7989b34fb18e22bc-n08hh5.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+04+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2004%20%28360p%29.mp4',
  }),
  'Sousou no Frieren_5': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/e58042b444ae673e820b1d014919441c70092c30-DqUjfN.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+05+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2005%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/ce9bae4c617686a0a8ab991cd1ec5cf676b84411-ZfG82z.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+05+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2005%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/5b17d7a4f7f423a92fe57716255d41cb73642a3b-4WT765.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+05+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2005%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/ac143b34b630be3d67755a4f9c2867003261ac34-T5QmVq.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+05+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2005%20%28360p%29.mp4',
  }),
  'Sousou no Frieren_6': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/207faa60ee2f99fe53286a9441bae0ec320e9308-BxxUgT.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+06+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2006%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/420db09206449fe2ba6d03699369f4adf77f2bb8-kenOXi.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+06+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2006%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/51e89262d1d5bdcb4b37ca9db2b2966f32ea8214-EyYpli.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+06+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2006%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/a88d6845c7e7e0339b440095255e6a05f43bbd26-LAVtpK.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+06+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2006%20%28360p%29.mp4',
  }),
  'Sousou no Frieren_7': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/81be44ec0469dc84b0d691173e837b31aadef6a8-zGefmd.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+07+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2007%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/34171634ce42561367ab4865aa1b6009ed95d29f-ieOBvc.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+07+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2007%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/128ba489669c0ffd76eca815ea2f11f3e0e75c41-SFDYme.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+07+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2007%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/f222638262de35d81debcd6c5a36a107bca75bb8-TE3Ncw.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+07+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2007%20%28360p%29.mp4',
  }),
  'Sousou no Frieren_8': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/33da19602be3aead4c87668b0e46d10c20728ee5-Q0z0wV.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+08+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2008%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/c89ea67cfbb5a7062b194a43e0485468443a5fe1-C9KjVa.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+08+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2008%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/c66d5a2e60b3046aa452976e283937c0c02593ee-twU6bR.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+08+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2008%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/3426971909003aa6f5999ea98e8458e7ac8aba7a-Bn3ArR.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+08+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2008%20%28360p%29.mp4',
  }),
  'Sousou no Frieren_9': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/7b8be9a6a3158ef9ff9532c9742e2f633b48b6dd-nSzJla.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+09+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2009%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/3c1361f3d82e4b89a19a22753598e423b9f9b7f3-U9y3Js.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+09+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2009%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/6dd16e090d9d8e756368f092f29dcd4ca509c6cb-9fcR4q.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+09+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2009%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/f628de4c18462725099f1cf1c35a2869d33dd046-RfiCNT.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+09+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2009%20%28360p%29.mp4',
  }),
  'Sousou no Frieren_10': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/02d82f197665f81d80bb7a7d232068e0a44f3a08-bMPx1C.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+10+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2010%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/fb420b63ea8fe15d57345c3b74cee35b8d68c41e-jRD5c8.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+10+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2010%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/eac58e5a232486f0ee65404fb4006ca3d203a4c3-sYcoSZ.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+10+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2010%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/a57517df18203ffabfad960b75743b33498203b1-ej5TVz.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+10+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2010%20%28360p%29.mp4  ',
  }),
  'Sousou no Frieren_11': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/d5c75cfff26a46463143a60b48c8460f90cc0fe7-N3XraI.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+11+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2011%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/3c0a40c2b07c27388460b40c519dbcdd4cd46c40-z67EVT.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+11+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2011%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/3992d482a23dfc0f9b627cb749c4b0ed07de789e-oXbKKh.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+11+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2011%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/67a6700d43776028c79dfe7ba99f47df13e88378-RTDGag.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+11+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2011%20%28360p%29.mp4',
  }),
  'Sousou no Frieren_12': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/bc3a48e8a4229dac8932a6f382aea138d54c0302-bGithk.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+12+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2012%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/2f8b66c3c2dcc69708e4d2fd02d9599a8551a4c8-e4Kh6d.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+12+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2012%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/93336b22f08ec8fcdec881aebca2817467dc16a0-kBPYBL.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+12+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2012%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/ba69186b4e80e1505daf2ca5515e5bce0eeb33a5-Vo6k9r.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+12+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2012%20%28360p%29.mp4',
  }),
  'Sousou no Frieren_13': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/1b69429367d5e5134253da708346ce151be1439e-YbCvse.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+13+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2013%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/3454dddeff35b1c63482d17201126ae9dd30b7a9-X1rdlU.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+13+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2013%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/41523709f952e1729aac7c3dc0b50566550fc4b0-POMP0p.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+13+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2013%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/d2b100395c779dec24dd590e8b4296278a272b7f-uwzHex.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+13+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2013%20%28360p%29.mp4',
  }),
  'Sousou no Frieren_14': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/d2083f9c4e980c9bbb10adb276f780571e2dc365-jMQQE7.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+14+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2014%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/76048ac170753c63f93f3328d7dd3fec5b855d8b-o7kko5.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+14+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2014%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/f965cc6d8c4d1dd60cc8ead78dd6cb1fbe69952f-9ffa4o.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+14+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2014%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/52ae06e2165f2a2fe7e07b384aa94f0225a8a149-JKjAgX.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+14+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2014%20%28360p%29.mp4',
  }),
  'Sousou no Frieren_15': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/437021fd4a4ebcbff553cbe8354c4e54924d21a0-VBGXXs.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+15+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2015%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/b4799ca7944186686c1610f71e62785adb534dfa-PFvdwd.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+15+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2015%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/a8a3c2586512e6dcfd12c8dfa54643693f289fbf-c460qe.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+15+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2015%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/f208561fef3488cff3d4d292b8c142d89e1613e0-r2MdIX.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+15+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2015%20%28360p%29.mp4',
  }),
  'Sousou no Frieren_16': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/76e3dddc7c9031354d2b5fdcd4bc53cdeb162a22-6AsUBm.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+16+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2016%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/d46273e916d32af72fcf777a434e345a74b115a5-XOASz5.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+16+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2016%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/82044c193bebe6cf9ee218f2e6996c2ac296be37-CKEnH9.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+16+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2016%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/6f369613811788996bfc50ececd83aa34163b462-UGtXmv.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+16+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2016%20%28360p%29.mp4',
  }),
  'Sousou no Frieren_17': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/7264e9118fa1fba4e5cbcdf054a145ab3bc9d7fa-ZkCUbi.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+17+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2017%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/5cab5e5d07c501781a461d7d4496b23183800377-OLrDhf.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+17+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2017%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/3eecd7cb40d91f64d046df380f49bf942f928d19-97rECe.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+17+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2017%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/6dd1d92a8af6c9c682f06343e6b55bfbb4b11d93-8KxIfc.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+17+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2017%20%28360p%29.mp4',
  }),
  'Sousou no Frieren_18': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/e4fba3b82df9ded71b837c674fb31f11a2e70849-I7V77k.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+18+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2018%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/08ca3f4b2598f94baea53a9130914dd7208419f7-Rp8Zf4.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+18+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2018%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/6affc70338aab482b5ee408d7f75029fbdd97dd2-UevFtB.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+18+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2018%20%28360p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/6affc70338aab482b5ee408d7f75029fbdd97dd2-UevFtB.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+18+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2018%20%28360p%29.mp4',
  }),
  'Sousou no Frieren_19': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/f8e05cff86dcdafe17c1c42c141bb49cc8661828-MOSPGa.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+19+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2019%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/df3b79f146b4741b891cd2b9d9c3cd783c16f3b9-ddKpfy.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+19+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2019%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/5ae96ac0c90ceb7e315695706cf66b541a843b8c-jSbw9R.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+19+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2019%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/8e91cf97fb2dc0542b235397767c5f5aa15e0edf-SCSmrJ.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+19+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2019%20%28360p%29.mp4',
  }),
  'Sousou no Frieren_20': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/414bb7a2267b798e4e0f24ef95250e68e345b787-KMlp7v.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+20+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2020%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/677a65e1d43cbfd2e94bb0b45b8cdaa12616b6b9-hkCD3o.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+20+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2020%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/c2c4615aa2917d332215b89ac090b3370bcca4cf-1lNBVI.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+20+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2020%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/2a3a0cfec47ec446a442e2ae415600022ecebef5-0Xubc0.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+20+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2020%20%28360p%29.mp4',
  }),
  'Sousou no Frieren_21': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/03ec7afc9a2669ed98f50251a9ca1778d578341d-IrmJCA.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+21+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2021%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/c1595c08797d201cec6b59293e9cf944f3546e23-4RK6a6.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+21+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2021%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/629b4d4b5ddb8eaad677787f61bb4bdd88b296e8-hUoJQR.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+21+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2021%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/159c8998a8e96f0c10e89b3214a6312a6ecd7a28-s3zkqG.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+21+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2021%20%28360p%29.mp4',
  }),
  'Sousou no Frieren_22': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/9c72953140a1c05144b2240de54f7891b3c42c77-u9amjW.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+22+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2022%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/8e0de2c5c3f894c207a6df4aee51bb19dd19e158-SSYZ4I.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+22+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2022%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/524aae794f3f2a8bd585be214b4ff69f0b87d1b5-zpGJp5.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+22+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2022%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/39ee10df670a6ba91f4bd98452a8e2083960c63b-UGE5Az.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+22+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2022%20%28360p%29.mp4',
  }),
  'Sousou no Frieren_23': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/1541593d7e3fcf8e31cc3205d49f49b17a096d3f-d9OTtm.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+23+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2023%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/2f9f5674b03af4056b6c820fcd3b8c6199f87606-WPv2Ep.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+23+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2023%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/ba005297087666a2594979359be07d75e3a474cd-LzCZhW.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+23+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2023%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/dc747074b2faa1a03553baa368a6c30d6fc28569-f74zR8.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+23+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2023%20%28360p%29.mp4',
  }),
  'Sousou no Frieren_24': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/cdd59c13e353b0ed29a8bb1e825284b48ba5804a-yKzyVR.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+24+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2024%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/12da81b219b3e4f01916a974a9fbd7fd0412fd45-8sJrSQ.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+24+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2024%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/efb954fcdd1cbbd971827980a0a711212bdf2ac9-UeAENr.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+24+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2024%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/209a7e9a453df38c231fa0e740dc025c02a1a84d-t3h0vo.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+24+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2024%20%28360p%29.mp4',
  }),
  'Sousou no Frieren_25': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/c759116a56c3587532730ecb77f0603b669abb5f-sPFVTp.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+25+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2025%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/4f26b2089e2ec9160194e0bc6e194e1b55067126-NrMssm.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+25+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2025%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/620d96e77b2ea3ef119f4e3f0f364464b00e4290-7lwwr2.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+25+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2025%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/484b4c4729982d90099d21a0d4940c70d8369f4b-zF8nps.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+25+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2025%20%28360p%29.mp4',
  }),
  'Sousou no Frieren_26': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/50a1a12f11b50147cf05254993280e7669f812a7-7pJoZH.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+26+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2026%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/6dcbbacb0d79139dec205436419fc7262894971c-86VGEw.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+26+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2026%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/a50b15c27e12683669c0938c68573e41adcb4abe-Em8TXE.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+26+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2026%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/26552635a024e5557950f412a8606137ff3ab540-eYLPFD.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+26+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2026%20%28360p%29.mp4',
  }),
  'Sousou no Frieren_27': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/b5aab7ad2fbf109323a2029a8f5679e3fadab130-Q1wi4i.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+27+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2027%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/444e0d71c6688d7e80a754d114113dff3180bb32-DXDt0F.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+27+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2027%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/a114d28aa6692435bb9bf0aa71d4923c0b081f27-1yfBpQ.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+27+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2027%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/8860a29908aeb8b9132cb87f0f8304af141f583b-uuj0Iw.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+27+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2027%20%28360p%29.mp4',
  }),
  'Sousou no Frieren_28': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/a2d0a1726cb8b633613d12dc813fa2ae58f3a0f3-Gvl90O.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+28+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2028%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/59afc89492cf2c551d9e1e44e2c0d9656969f2ba-uXtC9a.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+28+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2028%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/1a44436f3c560ea6237bf120c523c59f84c5b664-wV3JQw.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+28+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2028%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/52937fcb1985d504cfc3754b58337c092a883a1f-A4t63V.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+28+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2028%20%28360p%29.mp4',
  }),

  // ══════════════════════════════════════════════════════════════
  // Sousou no Frieren Season 2 (S2)
  // ══════════════════════════════════════════════════════════════
  'Sousou no Frieren Season 2_1': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/anime/Anime_S/Sousou_no_Frieren_Season_2/1/2026/01/17/7zpug8rn-_Nimegami_Sousou_no_Frieren_S2_Ep_01_1080p_.mp4?name=%5BNimegami%5D%20Sousou%20no%20Frieren%20S2%20Ep%2001%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/anime/Anime_S/Sousou_no_Frieren_Season_2/7/2026/01/17/8gzpkjsn-_Nimegami_Sousou_no_Frieren_S2_Ep_01_720p_.mp4?name=%5BNimegami%5D%20Sousou%20no%20Frieren%20S2%20Ep%2001%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/anime/Anime_S/Sousou_no_Frieren_Season_2/4/2026/01/17/et67spxl-_Nimegami_Sousou_no_Frieren_S2_Ep_01_480p_.mp4?name=%5BNimegami%5D%20Sousou%20no%20Frieren%20S2%20Ep%2001%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/anime/Anime_S/Sousou_no_Frieren_Season_2/3/2026/01/17/kr9sgyjo-_Nimegami_Sousou_no_Frieren_S2_Ep_01_360p_.mp4?name=%5BNimegami%5D%20Sousou%20no%20Frieren%20S2%20Ep%2001%20%28360p%29.mp4',
  }),
  'Sousou no Frieren Season 2_2': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/anime/Anime_S/Sousou_no_Frieren_Season_2/1/2026/01/24/zczufjmd-_Nimegami_Sousou_no_Frieren_S2_Ep_02_1080p_.mp4?name=%5BNimegami%5D%20Sousou%20no%20Frieren%20S2%20Ep%2002%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/anime/Anime_S/Sousou_no_Frieren_Season_2/7/2026/01/24/jn4rf4f5-_Nimegami_Sousou_no_Frieren_S2_Ep_02_720p_.mp4?name=%5BNimegami%5D%20Sousou%20no%20Frieren%20S2%20Ep%2002%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/anime/Anime_S/Sousou_no_Frieren_Season_2/4/2026/01/24/5dew780b-_Nimegami_Sousou_no_Frieren_S2_Ep_02_480p_.mp4?name=%5BNimegami%5D%20Sousou%20no%20Frieren%20S2%20Ep%2002%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/anime/Anime_S/Sousou_no_Frieren_Season_2/3/2026/01/24/m80qwcw6-_Nimegami_Sousou_no_Frieren_S2_Ep_02_360p_.mp4?name=%5BNimegami%5D%20Sousou%20no%20Frieren%20S2%20Ep%2002%20%28360p%29.mp4',
  }),
  'Sousou no Frieren Season 2_3': MyEpisodeLink({
    '1080p':
        'https://dlgan.halahgan.com/?id=3bfbe21d4452e267547a4993c66361bab33b1c57&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-03-1080p.mp4',
    '720p':
        'https://dlgan.halahgan.com/?id=834aa2f4da831d5ab816434558422b82955c017f&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-03-720p.mp4',
    '480p':
        'https://dlgan.halahgan.com/?id=834aa2f4da831d5ab816434558422b82955c017f&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-03-480p.mp4',
    '360p':
        'https://dlgan.halahgan.com/?id=4d35c9e9e078116adc29312a59413735170e744f&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-03-360p.mp4',
  }),
  'Sousou no Frieren Season 2_4': MyEpisodeLink({
    '1080p':
        'https://dlgan.halahgan.com/?id=d14298&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-04-1080p.mp4',
    '720p':
        'https://dlgan.halahgan.com/?id=90264c&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-04-720p.mp4',
    '480p':
        'https://dlgan.halahgan.com/?id=bed1d3&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-04-480p.mp4',
    '360p':
        'https://dlgan.halahgan.com/?id=b0b5b0&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-04-360p.mp4',
  }),
  'Sousou no Frieren Season 2_5': MyEpisodeLink({
    '1080p':
        'https://dlgan.halahgan.com/?id=71f0ca&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-05-1080p.mp4',
    '720p':
        'https://dlgan.halahgan.com/?id=99346c&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-05-720p.mp4',
    '480p':
        'https://dlgan.halahgan.com/?id=392a6e&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-05-480p.mp4',
    '360p':
        'https://dlgan.halahgan.com/?id=c09e4c&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-05-360p.mp4',
  }),
  'Sousou no Frieren Season 2_6': MyEpisodeLink({
    '1080p':
        'https://dlgan.halahgan.com/?id=18076e&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-06-1080p.mp4',
    '720p':
        'https://dlgan.halahgan.com/?id=8b89a5&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-06-720p.mp4',
    '480p':
        'https://dlgan.halahgan.com/?id=463190&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-06-480p.mp4',
    '360p':
        'https://dlgan.halahgan.com/?id=6044cc&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-06-360p.mp4',
  }),
  'Sousou no Frieren Season 2_7': MyEpisodeLink({
    '1080p':
        'https://dlgan.halahgan.com/?id=4337e8&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-07-1080p.mp4',
    '720p':
        'https://dlgan.halahgan.com/?id=05b491&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-07-720p.mp4',
    '480p':
        'https://dlgan.halahgan.com/?id=4806dd&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-07-480p.mp4',
    '360p':
        'https://dlgan.halahgan.com/?id=0a9e2f&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-07-360p.mp4',
  }),
  'Sousou no Frieren Season 2_8': MyEpisodeLink({
    '1080p':
        'https://dlgan.halahgan.com/?id=fcd5fc&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-08-1080p.mp4',
    '720p':
        'https://dlgan.halahgan.com/?id=9a54cf&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-08-720p.mp4',
    '480p':
        'https://dlgan.halahgan.com/?id=aeada8&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-08-480p.mp4',
    '360p':
        'https://dlgan.halahgan.com/?id=c3f83f&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-08-360p.mp4',
  }),
  'Sousou no Frieren Season 2_9': MyEpisodeLink({
    '1080p':
        'https://dlgan.halahgan.com/?id=8062c7&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-09-1080p.mp4',
    '720p':
        'https://dlgan.halahgan.com/?id=877a8a&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-09-720p.mp4',
    '480p':
        'https://dlgan.halahgan.com/?id=3f36c6&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-09-480p.mp4',
    '360p':
        'https://dlgan.halahgan.com/?id=8f679f&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-09-360p.mp4',
  }),
  'Sousou no Frieren Season 2_10': MyEpisodeLink({
    '1080p':
        'https://dlgan.halahgan.com/?id=39eca3&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-10-1080p.mp4',
    '720p':
        'https://dlgan.halahgan.com/?id=6f7561&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-10-720p.mp4',
    '480p':
        'https://dlgan.halahgan.com/?id=10da17&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-10-480p.mp4',
    '360p':
        'https://dlgan.halahgan.com/?id=b3ba8b&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-10-360p.mp4',
  }),

  // ══════════════════════════════════════════════════════════════
  // Mushoku Tensei: Isekai Ittara Honki Dasu
  // ══════════════════════════════════════════════════════════════
  'Mushoku Tensei: Isekai Ittara Honki Dasu_1': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/07268259ceeea5b81dd21d28471ed25192f47d3e-MJPIQM.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+01+%281080p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2001%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/6756626234cb2c05325a3c766e2ea7881fd78b7e-9Mfe6j.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+01+%28720p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2001%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/3a167eb618b479f07e54bfd518490eaaa0761879-18laTc.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+01+%28480p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2001%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/6a4b1f0ff59f07fdc5d1e32242fb3a44029065b0-f6KbzV.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+01+%28360p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2001%20%28360p%29.mp4',
  }),
  'Mushoku Tensei: Isekai Ittara Honki Dasu_2': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/615a1dce675ef3582f8ce6de5b99de36da4397dc-TQrko9.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+02+%281080p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2002%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/01dc27f6e3c03922a2f94631425303f850ceabae-cbJUoT.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+02+%28720p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2002%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/798bf555eee81348150ed863e79e81b3a3f06499-aRKRc5.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+02+%28480p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2002%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/82e14d7878dca94d047d395837500ac759352bef-hADR5A.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+02+%28360p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2002%20%28360p%29.mp4',
  }),
  'Mushoku Tensei: Isekai Ittara Honki Dasu_3': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/e8a5959e439f2de5106d2f4643378fdfe6601890-xPxITF.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+03+%281080p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2003%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/84c326a3409ac1680c84c536967ca1b69b396f7b-9uAtIL.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+03+%28720p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2003%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/59d7ac59f1454d8409a799bfc0c9db2ad5ff8266-DXQTRC.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+03+%28480p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2003%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/99f5a1586aed222ac66ecedf35ea54cb3c1a4e69-u9xcqn.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+03+%28360p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2003%20%28360p%29.mp4',
  }),
  'Mushoku Tensei: Isekai Ittara Honki Dasu_4': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/86fdeb545d7608a8434e5edea29b6699b041bea9-s7J57Z.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+04+%281080p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2004%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/edf0a2a6196555b12d4d6c4efcdc3b9f93495db0-j5TWSp.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+04+%28720p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2004%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/561437fef3dbfd49d44cfbe4b522ed52bf9806ec-FCew9j.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+04+%28480p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2004%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/39b590956d6f56cbc9f4d16f8efe40cad13ffe46-zrb7Dn.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+04+%28360p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2004%20%28360p%29.mp4',
  }),
  'Mushoku Tensei: Isekai Ittara Honki Dasu_5': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/0a97efe25f85009f656321aae0927996bfa2cc7d-ZU3PJf.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+05+%281080p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2005%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/5e521621689976b1b24d5d3be8a9f2ca6daf55eb-Db5IvT.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+05+%28720p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2005%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/a5a6bf513b348ffee1c376e97ddbf5033721fb21-Vmtj4r.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+05+%28480p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2005%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/3437fc7895faf0d3ae96ed14e52121235c616318-ocV1BG.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+05+%28360p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2005%20%28360p%29.mp4',
  }),
  'Mushoku Tensei: Isekai Ittara Honki Dasu_6': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/97b119e72bb53113b707d76bfb8e9b27463136e0-QroXOg.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+06+%281080p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2006%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/16eeb149bc3f94e62cc3351891260966630fbf7e-7BToc0.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+06+%28720p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2006%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/e8f03be8ef78e8b95b0f1e5328bfce958fd828fd-RWzlcE.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+06+%28480p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2006%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/537d0bd23054b9ae630ec8a4dcd9e04a7692c155-kqUSdr.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+06+%28360p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2006%20%28360p%29.mp4',
  }),
  'Mushoku Tensei: Isekai Ittara Honki Dasu_7': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/194a5c70fa646ef79a8d2abe62e908a23e329457-IvpTqt.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+07+%281080p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2007%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/de2bb0a473632092b01de243af668c29996e79c4-i1i3X7.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+07+%28720p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2007%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/9a983bb58933c702415240b62c74ee32de97362c-ppsxCE.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+07+%28480p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2007%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/b46fbe12d35628e943df4eabd72686455b3ccda2-qeUSVL.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+07+%28360p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2007%20%28360p%29.mp4  ',
  }),
  'Mushoku Tensei: Isekai Ittara Honki Dasu_8': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/2a7e29dede7d13b4c0c7b7127842d0916d2a53c6-IJj0Oi.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+08+%281080p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2008%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/ea36c2b9252c2534c8fc45c85736b3bb5c0d14dd-GtSvdt.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+08+%28720p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2008%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/3e6a35c091acc62daa0c6cd800ae1161b78eaf46-UCZxJB.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+08+%28480p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2008%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/69825a244722e0377c98b19f58fb8e06bab413d3-rNVbj0.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+08+%28360p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2008%20%28360p%29.mp4',
  }),
  'Mushoku Tensei: Isekai Ittara Honki Dasu_9': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/c1a2ae0e6c4fefcddfb8b8f19fef5f0a19dd2a4a-Qh0qwi.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+09+%281080p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2009%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/5d59c7f70a4405051b32e02e402d04ae2c0313b7-XiNVdX.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+09+%28720p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2009%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/15de23055a07cd24a098f6403c88e0da812e5919-AXhjBX.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+09+%28480p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2009%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/bd179909226585c7e34859ab8082ce831e6ce303-P9pecJ.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+09+%28360p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2009%20%28360p%29.mp4',
  }),
  'Mushoku Tensei: Isekai Ittara Honki Dasu_10': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/023c3c0d716e44bf296c4b9d64d82caef020d7d1-CSOyqg.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+10+%281080p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2010%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/a8162da59d5eb59d3773fac46894aae14f214b7b-Oy9lAa.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+10+%28720p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2010%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/764617144a51777866f0a2b5b0088a92debde5c7-e38R6F.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+10+%28480p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2010%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/c4a1325a27a9892a1c1c6d278e9539fdce6772fb-D8gDG2.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+10+%28360p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2010%20%28360p%29.mp4',
  }),
  'Mushoku Tensei: Isekai Ittara Honki Dasu_11': MyEpisodeLink({
    '1080p':
        'https://stor.halahgan.com/dl/storage/86/66d4211eeba7361998b90a25c5214ee9bca3d3ce-Hr2pVq.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+11+%281080p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2011%20%281080p%29.mp4',
    '720p':
        'https://stor.halahgan.com/dl/storage/86/09dc9efb18b0ebdc02a7e547e2de80ea51d21721-ac2MpL.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+11+%28720p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2011%20%28720p%29.mp4',
    '480p':
        'https://stor.halahgan.com/dl/storage/86/9eae60bb5766e0eb28dd6ad69e47fa7ce6d442f6-EBgUU1.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+11+%28480p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2011%20%28480p%29.mp4',
    '360p':
        'https://stor.halahgan.com/dl/storage/86/b4a7e5d74f091a5d5f4a7c81313a1d3ba76e72b9-zck41u.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+11+%28360p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2011%20%28360p%29.mp4',
  }),
  // ══════════════════════════════════════════════════════════════
  // Ansatsu Kyoushitsu Movie: Minna no Jikan
  // ══════════════════════════════════════════════════════════════
  'Ansatsu Kyoushitsu Movie: Minna no Jikan_1': MyEpisodeLink({
    '1080p':
        'https://direct-stor.berkasdrive.com/dl/UPLOAD_BARU_2/Nimegami/Anime%20A/Ansatsu%20Kyoushitsu%20Movie%3A%20Minna%20no%20Jikan/%5BNimegami%5D_Ansatsu_Kyoushitsu_Movie_Minna_no_Jikan_%281080p%29.mp4?name=%5BNimegami%5D_Ansatsu_Kyoushitsu_Movie_Minna_no_Jikan_%281080p%29.mp4',
  }),
};

// Urutan kualitas dari terbaik ke terendah — dipakai buat milih
// default pas episode pertama kali dibuka, dan buat urutan tombol
// pilihan kualitas di player.
const List<String> qualityOrder = [
  '1080p',
  '720p',
  '480p',
  '360p',
  '240p',
  '144p',
  'Auto',
];

String _normalizeTitle(String s) {
  var normalized = s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  // Alias normalize s2 -> season2
  normalized = normalized.replaceAll('s2', 'season2');
  normalized = normalized.replaceAll('part2', 'part2');
  return normalized;
}

/// Cari entry manual buat [animeTitle] episode [episodeNumber].
/// Balikin null kalau belum diisi (WatchScreen akan lanjut ke sumber lain).
MyEpisodeLink? resolveMyEpisodeLink(String animeTitle, int episodeNumber) {
  final targetTitle = _normalizeTitle(animeTitle);

  for (final entry in myEpisodeLinks.entries) {
    final key = entry.key;
    final sep = key.lastIndexOf('_');
    if (sep == -1) continue;

    final keyTitle = key.substring(0, sep);
    final keyEpisode = int.tryParse(key.substring(sep + 1));
    if (keyEpisode == null) continue;

    if (keyEpisode == episodeNumber &&
        _normalizeTitle(keyTitle) == targetTitle) {
      final link = entry.value;
      return link.qualities.isEmpty ? null : link;
    }
  }
  return null;
}

/// Kualitas terbaik yang tersedia buat [link], sesuai [qualityOrder].
/// Kalau nama kualitasnya gak ada di daftar itu, fallback ke entry
/// pertama yang ada di map-nya (biar tetep ada yang keputer).
String bestQualityFor(MyEpisodeLink link) {
  for (final q in qualityOrder) {
    if (link.qualities.containsKey(q)) return q;
  }
  return link.qualities.keys.first;
}

/// Daftar kualitas [link], sudah diurutin dari terbaik ke terendah,
/// siap dipakai buat nampilin tombol pilihan kualitas.
List<String> sortedQualitiesFor(MyEpisodeLink link) {
  final known = qualityOrder.where((q) => link.qualities.containsKey(q));
  final unknown = link.qualities.keys.where((q) => !qualityOrder.contains(q));
  return [...known, ...unknown];
}
