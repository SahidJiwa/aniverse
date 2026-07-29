// AniVerse Studio — Admin CMS Logic & Data Engine v2.0

const DEFAULT_PIN = "8888";
const STORAGE_PIN_KEY = "aniverse_admin_pin";
const STORAGE_CATALOG_KEY = "user_catalog_v1";

let defaultCatalog = [
  {
    id: "custom-frieren",
    title: "Sousou no Frieren",
    imageUrl: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx154587-qQTzQnEJJ3oB.jpg",
    rating: 9.26,
    genres: ["Adventure", "Award Winning", "Drama", "Fantasy"],
    description: "During a decade-long quest to defeat the Demon King, the members of the hero party — including Himmel, Heiter, Eisen, and the elven mage Frieren — forge bonds through adventures and battles. But time flows differently for an elf. When the party disbands after their victory, Frieren watches her human companions age and die, while she barely changes. Only then does she begin to question what it means to truly know someone.",
    isTrending: true,
    releaseDay: null,
    episodes: 28,
    status: "Tamat",
    trailerUrl: "https://www.youtube.com/watch?v=qgQunD218l0",
    catalogEpisodeLink: "{\"1\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/a97b2a070fc918b21efe6f892bd0ea49575f3978-svnAOy.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+01+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2001%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/f9bf1e6c0c85d27619d88402691c65dd665f623a-RfcDcj.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+01+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2001%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/c79b439311c8b774e7bf51de2555c030b74883e8-ihzh1K.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+01+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2001%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/ba63c1373fec268eb2fa502ab454979f503f298e-8m8nDh.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+01+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2001%20%28360p%29.mp4\",\"240p\":\"https://github.com/SahidJiwa/Sousou-no-Frieren/releases/download/frieren-ep1/ep.1_240p.mp4\",\"144p\":\"https://github.com/SahidJiwa/Sousou-no-Frieren/releases/download/frieren-ep1/ep.1_144p.mp4\"},\"2\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/d6b7dee64a834e6736c931e88de06a8d69de30bf-LiDdEx.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+02+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2002%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/b3f44d85538bc844d54c9c80656ea7acaa721e65-fqLoyF.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+02+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2002%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/2189ef1ae0f5d998154b5bc3280f0fcbff23d4bc-3VaJKc.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+02+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2002%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/f2b96fcd2aeab4f45df2b55171c32ff587520f0f-V7Ej0M.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+02+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2002%20%28360p%29.mp4\"},\"3\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/c7c924720409039a91807094c450fb26282ed6c6-57YGrG.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+03+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2003%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/a37d21365013c411574aafb29a582ec6c4b54a2c-RAeb8d.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+03+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2003%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/3643f88285ee752705235e14afb1930ed75b2490-Wkngvr.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+03+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2003%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/91fb401007e4126bd5dc41e5222921ac065e3c9c-AtY6wu.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+03+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2003%20%28360p%29.mp4\"},\"4\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/0fbbf6324b10be138bf87253be10764760fe2d24-onJuWz.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+04+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2004%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/20463b69567375bc9bfc66a7a5c416c240fb97f2-lz1Zxs.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+04+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2004%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/6f876945b24efb545b56e0fad78ee04297f7a1c6-T30Omn.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+04+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2004%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/b11307fa59885b9fa98d138b7989b34fb18e22bc-n08hh5.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+04+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2004%20%28360p%29.mp4\"},\"5\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/e58042b444ae673e820b1d014919441c70092c30-DqUjfN.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+05+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2005%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/ce9bae4c617686a0a8ab991cd1ec5cf676b84411-ZfG82z.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+05+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2005%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/5b17d7a4f7f423a92fe57716255d41cb73642a3b-4WT765.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+05+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2005%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/ac143b34b630be3d67755a4f9c2867003261ac34-T5QmVq.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+05+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2005%20%28360p%29.mp4\"},\"6\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/207faa60ee2f99fe53286a9441bae0ec320e9308-BxxUgT.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+06+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2006%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/420db09206449fe2ba6d03699369f4adf77f2bb8-kenOXi.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+06+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2006%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/51e89262d1d5bdcb4b37ca9db2b2966f32ea8214-EyYpli.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+06+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2006%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/a88d6845c7e7e0339b440095255e6a05f43bbd26-LAVtpK.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+06+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2006%20%28360p%29.mp4\"},\"7\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/81be44ec0469dc84b0d691173e837b31aadef6a8-zGefmd.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+07+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2007%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/34171634ce42561367ab4865aa1b6009ed95d29f-ieOBvc.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+07+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2007%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/128ba489669c0ffd76eca815ea2f11f3e0e75c41-SFDYme.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+07+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2007%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/f222638262de35d81debcd6c5a36a107bca75bb8-TE3Ncw.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+07+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2007%20%28360p%29.mp4\"},\"8\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/33da19602be3aead4c87668b0e46d10c20728ee5-Q0z0wV.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+08+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2008%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/c89ea67cfbb5a7062b194a43e0485468443a5fe1-C9KjVa.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+08+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2008%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/c66d5a2e60b3046aa452976e283937c0c02593ee-twU6bR.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+08+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2008%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/3426971909003aa6f5999ea98e8458e7ac8aba7a-Bn3ArR.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+08+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2008%20%28360p%29.mp4\"},\"9\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/7b8be9a6a3158ef9ff9532c9742e2f633b48b6dd-nSzJla.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+09+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2009%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/3c1361f3d82e4b89a19a22753598e423b9f9b7f3-U9y3Js.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+09+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2009%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/6dd16e090d9d8e756368f092f29dcd4ca509c6cb-9fcR4q.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+09+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2009%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/f628de4c18462725099f1cf1c35a2869d33dd046-RfiCNT.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+09+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2009%20%28360p%29.mp4\"},\"10\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/02d82f197665f81d80bb7a7d232068e0a44f3a08-bMPx1C.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+10+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2010%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/fb420b63ea8fe15d57345c3b74cee35b8d68c41e-jRD5c8.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+10+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2010%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/eac58e5a232486f0ee65404fb4006ca3d203a4c3-sYcoSZ.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+10+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2010%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/a57517df18203ffabfad960b75743b33498203b1-ej5TVz.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+10+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2010%20%28360p%29.mp4  \"},\"11\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/d5c75cfff26a46463143a60b48c8460f90cc0fe7-N3XraI.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+11+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2011%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/3c0a40c2b07c27388460b40c519dbcdd4cd46c40-z67EVT.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+11+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2011%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/3992d482a23dfc0f9b627cb749c4b0ed07de789e-oXbKKh.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+11+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2011%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/67a6700d43776028c79dfe7ba99f47df13e88378-RTDGag.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+11+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2011%20%28360p%29.mp4\"},\"12\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/bc3a48e8a4229dac8932a6f382aea138d54c0302-bGithk.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+12+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2012%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/2f8b66c3c2dcc69708e4d2fd02d9599a8551a4c8-e4Kh6d.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+12+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2012%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/93336b22f08ec8fcdec881aebca2817467dc16a0-kBPYBL.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+12+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2012%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/ba69186b4e80e1505daf2ca5515e5bce0eeb33a5-Vo6k9r.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+12+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2012%20%28360p%29.mp4\"},\"13\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/1b69429367d5e5134253da708346ce151be1439e-YbCvse.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+13+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2013%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/3454dddeff35b1c63482d17201126ae9dd30b7a9-X1rdlU.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+13+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2013%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/41523709f952e1729aac7c3dc0b50566550fc4b0-POMP0p.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+13+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2013%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/d2b100395c779dec24dd590e8b4296278a272b7f-uwzHex.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+13+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2013%20%28360p%29.mp4\"},\"14\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/d2083f9c4e980c9bbb10adb276f780571e2dc365-jMQQE7.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+14+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2014%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/76048ac170753c63f93f3328d7dd3fec5b855d8b-o7kko5.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+14+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2014%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/f965cc6d8c4d1dd60cc8ead78dd6cb1fbe69952f-9ffa4o.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+14+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2014%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/52ae06e2165f2a2fe7e07b384aa94f0225a8a149-JKjAgX.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+14+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2014%20%28360p%29.mp4\"},\"15\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/437021fd4a4ebcbff553cbe8354c4e54924d21a0-VBGXXs.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+15+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2015%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/b4799ca7944186686c1610f71e62785adb534dfa-PFvdwd.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+15+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2015%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/a8a3c2586512e6dcfd12c8dfa54643693f289fbf-c460qe.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+15+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2015%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/f208561fef3488cff3d4d292b8c142d89e1613e0-r2MdIX.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+15+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2015%20%28360p%29.mp4\"},\"16\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/76e3dddc7c9031354d2b5fdcd4bc53cdeb162a22-6AsUBm.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+16+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2016%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/d46273e916d32af72fcf777a434e345a74b115a5-XOASz5.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+16+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2016%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/82044c193bebe6cf9ee218f2e6996c2ac296be37-CKEnH9.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+16+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2016%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/6f369613811788996bfc50ececd83aa34163b462-UGtXmv.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+16+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2016%20%28360p%29.mp4\"},\"17\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/7264e9118fa1fba4e5cbcdf054a145ab3bc9d7fa-ZkCUbi.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+17+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2017%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/5cab5e5d07c501781a461d7d4496b23183800377-OLrDhf.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+17+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2017%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/3eecd7cb40d91f64d046df380f49bf942f928d19-97rECe.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+17+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2017%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/6dd1d92a8af6c9c682f06343e6b55bfbb4b11d93-8KxIfc.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+17+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2017%20%28360p%29.mp4\"},\"18\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/e4fba3b82df9ded71b837c674fb31f11a2e70849-I7V77k.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+18+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2018%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/08ca3f4b2598f94baea53a9130914dd7208419f7-Rp8Zf4.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+18+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2018%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/6affc70338aab482b5ee408d7f75029fbdd97dd2-UevFtB.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+18+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2018%20%28360p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/6affc70338aab482b5ee408d7f75029fbdd97dd2-UevFtB.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+18+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2018%20%28360p%29.mp4\"},\"19\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/f8e05cff86dcdafe17c1c42c141bb49cc8661828-MOSPGa.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+19+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2019%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/df3b79f146b4741b891cd2b9d9c3cd783c16f3b9-ddKpfy.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+19+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2019%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/5ae96ac0c90ceb7e315695706cf66b541a843b8c-jSbw9R.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+19+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2019%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/8e91cf97fb2dc0542b235397767c5f5aa15e0edf-SCSmrJ.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+19+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2019%20%28360p%29.mp4\"},\"20\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/414bb7a2267b798e4e0f24ef95250e68e345b787-KMlp7v.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+20+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2020%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/677a65e1d43cbfd2e94bb0b45b8cdaa12616b6b9-hkCD3o.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+20+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2020%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/c2c4615aa2917d332215b89ac090b3370bcca4cf-1lNBVI.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+20+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2020%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/2a3a0cfec47ec446a442e2ae415600022ecebef5-0Xubc0.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+20+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2020%20%28360p%29.mp4\"},\"21\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/03ec7afc9a2669ed98f50251a9ca1778d578341d-IrmJCA.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+21+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2021%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/c1595c08797d201cec6b59293e9cf944f3546e23-4RK6a6.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+21+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2021%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/629b4d4b5ddb8eaad677787f61bb4bdd88b296e8-hUoJQR.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+21+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2021%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/159c8998a8e96f0c10e89b3214a6312a6ecd7a28-s3zkqG.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+21+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2021%20%28360p%29.mp4\"},\"22\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/9c72953140a1c05144b2240de54f7891b3c42c77-u9amjW.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+22+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2022%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/8e0de2c5c3f894c207a6df4aee51bb19dd19e158-SSYZ4I.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+22+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2022%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/524aae794f3f2a8bd585be214b4ff69f0b87d1b5-zpGJp5.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+22+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2022%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/39ee10df670a6ba91f4bd98452a8e2083960c63b-UGE5Az.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+22+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2022%20%28360p%29.mp4\"},\"23\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/1541593d7e3fcf8e31cc3205d49f49b17a096d3f-d9OTtm.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+23+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2023%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/2f9f5674b03af4056b6c820fcd3b8c6199f87606-WPv2Ep.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+23+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2023%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/ba005297087666a2594979359be07d75e3a474cd-LzCZhW.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+23+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2023%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/dc747074b2faa1a03553baa368a6c30d6fc28569-f74zR8.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+23+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2023%20%28360p%29.mp4\"},\"24\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/cdd59c13e353b0ed29a8bb1e825284b48ba5804a-yKzyVR.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+24+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2024%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/12da81b219b3e4f01916a974a9fbd7fd0412fd45-8sJrSQ.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+24+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2024%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/efb954fcdd1cbbd971827980a0a711212bdf2ac9-UeAENr.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+24+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2024%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/209a7e9a453df38c231fa0e740dc025c02a1a84d-t3h0vo.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+24+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2024%20%28360p%29.mp4\"},\"25\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/c759116a56c3587532730ecb77f0603b669abb5f-sPFVTp.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+25+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2025%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/4f26b2089e2ec9160194e0bc6e194e1b55067126-NrMssm.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+25+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2025%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/620d96e77b2ea3ef119f4e3f0f364464b00e4290-7lwwr2.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+25+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2025%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/484b4c4729982d90099d21a0d4940c70d8369f4b-zF8nps.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+25+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2025%20%28360p%29.mp4\"},\"26\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/50a1a12f11b50147cf05254993280e7669f812a7-7pJoZH.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+26+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2026%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/6dcbbacb0d79139dec205436419fc7262894971c-86VGEw.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+26+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2026%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/a50b15c27e12683669c0938c68573e41adcb4abe-Em8TXE.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+26+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2026%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/26552635a024e5557950f412a8606137ff3ab540-eYLPFD.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+26+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2026%20%28360p%29.mp4\"},\"27\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/b5aab7ad2fbf109323a2029a8f5679e3fadab130-Q1wi4i.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+27+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2027%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/444e0d71c6688d7e80a754d114113dff3180bb32-DXDt0F.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+27+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2027%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/a114d28aa6692435bb9bf0aa71d4923c0b081f27-1yfBpQ.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+27+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2027%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/8860a29908aeb8b9132cb87f0f8304af141f583b-uuj0Iw.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+27+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2027%20%28360p%29.mp4\"},\"28\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/a2d0a1726cb8b633613d12dc813fa2ae58f3a0f3-Gvl90O.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+28+%281080p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2028%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/59afc89492cf2c551d9e1e44e2c0d9656969f2ba-uXtC9a.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+28+%28720p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2028%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/1a44436f3c560ea6237bf120c523c59f84c5b664-wV3JQw.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+28+%28480p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2028%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/52937fcb1985d504cfc3754b58337c092a883a1f-A4t63V.mp4?name=%5BNimegami%5D+Sousou+no+Frieren+Ep+28+%28360p%29.mp4?filename=%5BNimegami%5D%20Sousou%20no%20Frieren%20Ep%2028%20%28360p%29.mp4\"}}",
    voiceActors: [
      { name: "Atsumi Tanezaki", characterName: "Frieren", imageUrl: "https://cdn.myanimelist.net/images/voiceactors/3/68641.jpg", characterImageUrl: "https://cdn.myanimelist.net/images/characters/4/521703.jpg" },
      { name: "Kana Ichinose", characterName: "Fern", imageUrl: "https://cdn.myanimelist.net/images/voiceactors/1/56885.jpg", characterImageUrl: "https://cdn.myanimelist.net/images/characters/2/521704.jpg" },
      { name: "Chiaki Kobayashi", characterName: "Stark", imageUrl: "https://cdn.myanimelist.net/images/voiceactors/2/56574.jpg", characterImageUrl: "https://cdn.myanimelist.net/images/characters/3/521705.jpg" },
      { name: "Nobuhiko Okamoto", characterName: "Himmel", imageUrl: "https://cdn.myanimelist.net/images/voiceactors/2/63060.jpg", characterImageUrl: "https://cdn.myanimelist.net/images/characters/5/521706.jpg" },
      { name: "Hiroki Touchi", characterName: "Heiter", imageUrl: "https://cdn.myanimelist.net/images/voiceactors/3/174.jpg", characterImageUrl: "https://cdn.myanimelist.net/images/characters/2/521707.jpg" }
    ]
  },
  {
    id: "custom-frieren-s2",
    title: "Sousou no Frieren Season 2",
    imageUrl: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx154587-qQTzQnEJJ3oB.jpg",
    rating: 9.35,
    genres: ["Adventure", "Fantasy", "Drama"],
    description: "Petualangan Frieren, Fern, dan Stark berlanjut ke wilayah utara Benua Ende — tempat bersemayamnya jiwa para pahlawan dan misteri sihir kuno yang belum pernah dipecahkan siapapun. Di sana, Frieren akan menghadapi tantangan terbesar dalam perjalanannya yang sudah berabad-abad.",
    isTrending: true,
    releaseDay: 5,
    episodes: 12,
    status: "Ongoing",
    trailerUrl: "https://www.youtube.com/watch?v=qgQunD218l0",
    catalogEpisodeLink: "{\"1\":{\"1080p\":\"https://stor.halahgan.com/dl/anime/Anime_S/Sousou_no_Frieren_Season_2/1/2026/01/17/7zpug8rn-_Nimegami_Sousou_no_Frieren_S2_Ep_01_1080p_.mp4?name=%5BNimegami%5D%20Sousou%20no%20Frieren%20S2%20Ep%2001%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/anime/Anime_S/Sousou_no_Frieren_Season_2/7/2026/01/17/8gzpkjsn-_Nimegami_Sousou_no_Frieren_S2_Ep_01_720p_.mp4?name=%5BNimegami%5D%20Sousou%20no%20Frieren%20S2%20Ep%2001%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/anime/Anime_S/Sousou_no_Frieren_Season_2/4/2026/01/17/et67spxl-_Nimegami_Sousou_no_Frieren_S2_Ep_01_480p_.mp4?name=%5BNimegami%5D%20Sousou%20no%20Frieren%20S2%20Ep%2001%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/anime/Anime_S/Sousou_no_Frieren_Season_2/3/2026/01/17/kr9sgyjo-_Nimegami_Sousou_no_Frieren_S2_Ep_01_360p_.mp4?name=%5BNimegami%5D%20Sousou%20no%20Frieren%20S2%20Ep%2001%20%28360p%29.mp4\"},\"2\":{\"1080p\":\"https://stor.halahgan.com/dl/anime/Anime_S/Sousou_no_Frieren_Season_2/1/2026/01/24/zczufjmd-_Nimegami_Sousou_no_Frieren_S2_Ep_02_1080p_.mp4?name=%5BNimegami%5D%20Sousou%20no%20Frieren%20S2%20Ep%2002%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/anime/Anime_S/Sousou_no_Frieren_Season_2/7/2026/01/24/jn4rf4f5-_Nimegami_Sousou_no_Frieren_S2_Ep_02_720p_.mp4?name=%5BNimegami%5D%20Sousou%20no%20Frieren%20S2%20Ep%2002%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/anime/Anime_S/Sousou_no_Frieren_Season_2/4/2026/01/24/5dew780b-_Nimegami_Sousou_no_Frieren_S2_Ep_02_480p_.mp4?name=%5BNimegami%5D%20Sousou%20no%20Frieren%20S2%20Ep%2002%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/anime/Anime_S/Sousou_no_Frieren_Season_2/3/2026/01/24/m80qwcw6-_Nimegami_Sousou_no_Frieren_S2_Ep_02_360p_.mp4?name=%5BNimegami%5D%20Sousou%20no%20Frieren%20S2%20Ep%2002%20%28360p%29.mp4\"},\"3\":{\"1080p\":\"https://dlgan.halahgan.com/?id=3bfbe21d4452e267547a4993c66361bab33b1c57&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-03-1080p.mp4\",\"720p\":\"https://dlgan.halahgan.com/?id=834aa2f4da831d5ab816434558422b82955c017f&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-03-720p.mp4\",\"480p\":\"https://dlgan.halahgan.com/?id=834aa2f4da831d5ab816434558422b82955c017f&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-03-480p.mp4\",\"360p\":\"https://dlgan.halahgan.com/?id=4d35c9e9e078116adc29312a59413735170e744f&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-03-360p.mp4\"},\"4\":{\"1080p\":\"https://dlgan.halahgan.com/?id=d14298&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-04-1080p.mp4\",\"720p\":\"https://dlgan.halahgan.com/?id=90264c&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-04-720p.mp4\",\"480p\":\"https://dlgan.halahgan.com/?id=bed1d3&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-04-480p.mp4\",\"360p\":\"https://dlgan.halahgan.com/?id=b0b5b0&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-04-360p.mp4\"},\"5\":{\"1080p\":\"https://dlgan.halahgan.com/?id=71f0ca&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-05-1080p.mp4\",\"720p\":\"https://dlgan.halahgan.com/?id=99346c&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-05-720p.mp4\",\"480p\":\"https://dlgan.halahgan.com/?id=392a6e&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-05-480p.mp4\",\"360p\":\"https://dlgan.halahgan.com/?id=c09e4c&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-05-360p.mp4\"},\"6\":{\"1080p\":\"https://dlgan.halahgan.com/?id=18076e&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-06-1080p.mp4\",\"720p\":\"https://dlgan.halahgan.com/?id=8b89a5&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-06-720p.mp4\",\"480p\":\"https://dlgan.halahgan.com/?id=463190&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-06-480p.mp4\",\"360p\":\"https://dlgan.halahgan.com/?id=6044cc&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-06-360p.mp4\"},\"7\":{\"1080p\":\"https://dlgan.halahgan.com/?id=4337e8&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-07-1080p.mp4\",\"720p\":\"https://dlgan.halahgan.com/?id=05b491&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-07-720p.mp4\",\"480p\":\"https://dlgan.halahgan.com/?id=4806dd&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-07-480p.mp4\",\"360p\":\"https://dlgan.halahgan.com/?id=0a9e2f&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-07-360p.mp4\"},\"8\":{\"1080p\":\"https://dlgan.halahgan.com/?id=fcd5fc&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-08-1080p.mp4\",\"720p\":\"https://dlgan.halahgan.com/?id=9a54cf&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-08-720p.mp4\",\"480p\":\"https://dlgan.halahgan.com/?id=aeada8&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-08-480p.mp4\",\"360p\":\"https://dlgan.halahgan.com/?id=c3f83f&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-08-360p.mp4\"},\"9\":{\"1080p\":\"https://dlgan.halahgan.com/?id=8062c7&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-09-1080p.mp4\",\"720p\":\"https://dlgan.halahgan.com/?id=877a8a&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-09-720p.mp4\",\"480p\":\"https://dlgan.halahgan.com/?id=3f36c6&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-09-480p.mp4\",\"360p\":\"https://dlgan.halahgan.com/?id=8f679f&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-09-360p.mp4\"},\"10\":{\"1080p\":\"https://dlgan.halahgan.com/?id=39eca3&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-10-1080p.mp4\",\"720p\":\"https://dlgan.halahgan.com/?id=6f7561&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-10-720p.mp4\",\"480p\":\"https://dlgan.halahgan.com/?id=10da17&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-10-480p.mp4\",\"360p\":\"https://dlgan.halahgan.com/?id=b3ba8b&direct=1&name=Nimegami-Sousou-no-Frieren-S2-Ep-10-360p.mp4\"}}",
    voiceActors: [
      { name: "Atsumi Tanezaki", characterName: "Frieren", imageUrl: "https://cdn.myanimelist.net/images/voiceactors/3/68641.jpg", characterImageUrl: "https://cdn.myanimelist.net/images/characters/4/521703.jpg" },
      { name: "Kana Ichinose", characterName: "Fern", imageUrl: "https://cdn.myanimelist.net/images/voiceactors/1/56885.jpg", characterImageUrl: "https://cdn.myanimelist.net/images/characters/2/521704.jpg" },
      { name: "Chiaki Kobayashi", characterName: "Stark", imageUrl: "https://cdn.myanimelist.net/images/voiceactors/2/56574.jpg", characterImageUrl: "https://cdn.myanimelist.net/images/characters/3/521705.jpg" }
    ]
  },
  {
    id: "11",
    title: "Mushoku Tensei: Isekai Ittara Honki Dasu",
    imageUrl: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx108465-1ANspF1EWyFx.jpg",
    rating: 8.7,
    genres: ["Fantasy", "Isekai", "Adventure"],
    description: "Seorang pria berusia 34 tahun yang menghabiskan hidupnya sebagai hikikomori meninggal dan terlahir kembali di dunia sihir dan pedang sebagai Rudeus Greyrat. Kali ini ia bertekad untuk tidak menyia-nyiakan kesempatan kedua ini dan benar-benar hidup tanpa penyesalan.",
    isTrending: true,
    releaseDay: 5,
    episodes: 11,
    status: "Tamat",
    trailerUrl: "https://www.youtube.com/watch?v=r_sT__wzXN4",
    catalogEpisodeLink: "{\"1\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/07268259ceeea5b81dd21d28471ed25192f47d3e-MJPIQM.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+01+%281080p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2001%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/6756626234cb2c05325a3c766e2ea7881fd78b7e-9Mfe6j.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+01+%28720p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2001%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/3a167eb618b479f07e54bfd518490eaaa0761879-18laTc.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+01+%28480p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2001%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/6a4b1f0ff59f07fdc5d1e32242fb3a44029065b0-f6KbzV.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+01+%28360p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2001%20%28360p%29.mp4\"},\"2\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/615a1dce675ef3582f8ce6de5b99de36da4397dc-TQrko9.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+02+%281080p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2002%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/01dc27f6e3c03922a2f94631425303f850ceabae-cbJUoT.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+02+%28720p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2002%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/798bf555eee81348150ed863e79e81b3a3f06499-aRKRc5.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+02+%28480p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2002%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/82e14d7878dca94d047d395837500ac759352bef-hADR5A.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+02+%28360p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2002%20%28360p%29.mp4\"},\"3\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/e8a5959e439f2de5106d2f4643378fdfe6601890-xPxITF.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+03+%281080p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2003%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/84c326a3409ac1680c84c536967ca1b69b396f7b-9uAtIL.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+03+%28720p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2003%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/59d7ac59f1454d8409a799bfc0c9db2ad5ff8266-DXQTRC.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+03+%28480p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2003%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/99f5a1586aed222ac66ecedf35ea54cb3c1a4e69-u9xcqn.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+03+%28360p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2003%20%28360p%29.mp4\"},\"4\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/86fdeb545d7608a8434e5edea29b6699b041bea9-s7J57Z.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+04+%281080p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2004%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/edf0a2a6196555b12d4d6c4efcdc3b9f93495db0-j5TWSp.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+04+%28720p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2004%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/561437fef3dbfd49d44cfbe4b522ed52bf9806ec-FCew9j.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+04+%28480p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2004%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/39b590956d6f56cbc9f4d16f8efe40cad13ffe46-zrb7Dn.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+04+%28360p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2004%20%28360p%29.mp4\"},\"5\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/0a97efe25f85009f656321aae0927996bfa2cc7d-ZU3PJf.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+05+%281080p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2005%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/5e521621689976b1b24d5d3be8a9f2ca6daf55eb-Db5IvT.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+05+%28720p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2005%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/a5a6bf513b348ffee1c376e97ddbf5033721fb21-Vmtj4r.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+05+%28480p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2005%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/3437fc7895faf0d3ae96ed14e52121235c616318-ocV1BG.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+05+%28360p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2005%20%28360p%29.mp4\"},\"6\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/97b119e72bb53113b707d76bfb8e9b27463136e0-QroXOg.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+06+%281080p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2006%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/16eeb149bc3f94e62cc3351891260966630fbf7e-7BToc0.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+06+%28720p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2006%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/e8f03be8ef78e8b95b0f1e5328bfce958fd828fd-RWzlcE.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+06+%28480p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2006%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/537d0bd23054b9ae630ec8a4dcd9e04a7692c155-kqUSdr.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+06+%28360p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2006%20%28360p%29.mp4\"},\"7\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/194a5c70fa646ef79a8d2abe62e908a23e329457-IvpTqt.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+07+%281080p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2007%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/de2bb0a473632092b01de243af668c29996e79c4-i1i3X7.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+07+%28720p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2007%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/9a983bb58933c702415240b62c74ee32de97362c-ppsxCE.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+07+%28480p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2007%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/b46fbe12d35628e943df4eabd72686455b3ccda2-qeUSVL.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+07+%28360p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2007%20%28360p%29.mp4  \"},\"8\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/2a7e29dede7d13b4c0c7b7127842d0916d2a53c6-IJj0Oi.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+08+%281080p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2008%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/ea36c2b9252c2534c8fc45c85736b3bb5c0d14dd-GtSvdt.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+08+%28720p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2008%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/3e6a35c091acc62daa0c6cd800ae1161b78eaf46-UCZxJB.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+08+%28480p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2008%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/69825a244722e0377c98b19f58fb8e06bab413d3-rNVbj0.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+08+%28360p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2008%20%28360p%29.mp4\"},\"9\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/c1a2ae0e6c4fefcddfb8b8f19fef5f0a19dd2a4a-Qh0qwi.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+09+%281080p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2009%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/5d59c7f70a4405051b32e02e402d04ae2c0313b7-XiNVdX.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+09+%28720p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2009%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/15de23055a07cd24a098f6403c88e0da812e5919-AXhjBX.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+09+%28480p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2009%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/bd179909226585c7e34859ab8082ce831e6ce303-P9pecJ.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+09+%28360p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2009%20%28360p%29.mp4\"},\"10\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/023c3c0d716e44bf296c4b9d64d82caef020d7d1-CSOyqg.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+10+%281080p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2010%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/a8162da59d5eb59d3773fac46894aae14f214b7b-Oy9lAa.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+10+%28720p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2010%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/764617144a51777866f0a2b5b0088a92debde5c7-e38R6F.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+10+%28480p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2010%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/c4a1325a27a9892a1c1c6d278e9539fdce6772fb-D8gDG2.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+10+%28360p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2010%20%28360p%29.mp4\"},\"11\":{\"1080p\":\"https://stor.halahgan.com/dl/storage/86/66d4211eeba7361998b90a25c5214ee9bca3d3ce-Hr2pVq.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+11+%281080p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2011%20%281080p%29.mp4\",\"720p\":\"https://stor.halahgan.com/dl/storage/86/09dc9efb18b0ebdc02a7e547e2de80ea51d21721-ac2MpL.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+11+%28720p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2011%20%28720p%29.mp4\",\"480p\":\"https://stor.halahgan.com/dl/storage/86/9eae60bb5766e0eb28dd6ad69e47fa7ce6d442f6-EBgUU1.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+11+%28480p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2011%20%28480p%29.mp4\",\"360p\":\"https://stor.halahgan.com/dl/storage/86/b4a7e5d74f091a5d5f4a7c81313a1d3ba76e72b9-zck41u.mp4?name=%5BNimegami%5D+Mushoku+Tensei+Ep+11+%28360p%29.mp4?filename=%5BNimegami%5D%20Mushoku%20Tensei%20Ep%2011%20%28360p%29.mp4\"}}",
    voiceActors: [
      { name: "Yumi Uchiyama", characterName: "Rudeus Greyrat", imageUrl: "https://cdn.myanimelist.net/images/voiceactors/3/54868.jpg", characterImageUrl: "https://cdn.myanimelist.net/images/characters/3/426027.jpg" },
      { name: "Ai Kakuma", characterName: "Eris Boreas Greyrat", imageUrl: "https://cdn.myanimelist.net/images/voiceactors/2/62464.jpg", characterImageUrl: "https://cdn.myanimelist.net/images/characters/5/426028.jpg" },
      { name: "Konomi Kohara", characterName: "Roxy Migurdia", imageUrl: "https://cdn.myanimelist.net/images/voiceactors/1/54603.jpg", characterImageUrl: "https://cdn.myanimelist.net/images/characters/2/426029.jpg" },
      { name: "Hisako Kanemoto", characterName: "Zenith Greyrat", imageUrl: "https://cdn.myanimelist.net/images/voiceactors/1/11691.jpg", characterImageUrl: "https://cdn.myanimelist.net/images/characters/4/426030.jpg" },
      { name: "Toshiyuki Morikawa", characterName: "Paul Greyrat", imageUrl: "https://cdn.myanimelist.net/images/voiceactors/1/54506.jpg", characterImageUrl: "https://cdn.myanimelist.net/images/characters/2/426031.jpg" }
    ]
  },
  {
    id: "custom-mushoku-tensei-part-2",
    title: "Mushoku Tensei: Isekai Ittara Honki Dasu Part 2",
    imageUrl: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx146065-IjirxRK26O03.png",
    rating: 8.8,
    genres: ["Fantasy", "Isekai", "Adventure"],
    description: "Perjalanan Rudeus berlanjut ke Benua Demon (Begaritt Continent) bersama Ruijerd Superdia dan Eris. Di sana mereka menghadapi berbagai bahaya dan makhluk mematikan, sementara Rudeus perlahan-lahan bertumbuh menjadi penyihir paling kuat yang pernah ada.",
    isTrending: true,
    releaseDay: 5,
    episodes: 12,
    status: "Tamat",
    trailerUrl: "https://www.youtube.com/watch?v=r_sT__wzXN4",
    catalogEpisodeLink: "",
    voiceActors: [
      { name: "Yumi Uchiyama", characterName: "Rudeus Greyrat", imageUrl: "https://cdn.myanimelist.net/images/voiceactors/3/54868.jpg", characterImageUrl: "https://cdn.myanimelist.net/images/characters/3/426027.jpg" },
      { name: "Ai Kakuma", characterName: "Eris Boreas Greyrat", imageUrl: "https://cdn.myanimelist.net/images/voiceactors/2/62464.jpg", characterImageUrl: "https://cdn.myanimelist.net/images/characters/5/426028.jpg" },
      { name: "Konomi Kohara", characterName: "Roxy Migurdia", imageUrl: "https://cdn.myanimelist.net/images/voiceactors/1/54603.jpg", characterImageUrl: "https://cdn.myanimelist.net/images/characters/2/426029.jpg" },
      { name: "Daisuke Namikawa", characterName: "Ruijerd Superdia", imageUrl: "https://cdn.myanimelist.net/images/voiceactors/1/54867.jpg", characterImageUrl: "https://cdn.myanimelist.net/images/characters/4/426032.jpg" }
    ]
  }
];

let catalogData = [];
let activeFilter = 'all';
let viewMode = 'grid';
let sortOrder = 'newest';
let currentEpisodeQualitiesMap = {};
let currentModalTab = 'info';
let pendingDeleteId = null;
let lastDeletedItem = null;
let undoTimeout = null;

const GENRE_PRESETS = ["Action", "Adventure", "Comedy", "Drama", "Fantasy", "Horror", "Mecha", "Mystery", "Romance", "Sci-Fi", "Slice of Life", "Sports", "Supernatural", "Thriller"];

document.addEventListener("DOMContentLoaded", () => {
  checkAuthSession();
  loadCatalogData();
  renderGenrePresets();
});

// Toast System
function showToast(msg, type = 'success') {
  const container = document.getElementById("toast-container");
  if (!container) return;
  const t = document.createElement("div");
  t.className = `toast ${type}`;
  const icon = type === 'success' ? '✅' : type === 'error' ? '❌' : '⚠️';
  t.innerHTML = `<span>${icon}</span> <span>${escapeHtml(msg)}</span>`;
  container.appendChild(t);
  setTimeout(() => {
    t.style.opacity = '0';
    t.style.transform = 'translateX(100%)';
    setTimeout(() => t.remove(), 300);
  }, 3500);
}

// ── PWA App Installer Handler ─────────────────────────────────────────────
let deferredPrompt;
window.addEventListener('beforeinstallprompt', (e) => {
  e.preventDefault();
  deferredPrompt = e;
  const btn = document.getElementById('btn-install-pwa');
  if (btn) btn.classList.remove('hidden');
});

function installAdminApp() {
  if (deferredPrompt) {
    deferredPrompt.prompt();
    deferredPrompt.userChoice.then((choiceResult) => {
      if (choiceResult.outcome === 'accepted') {
        showToast('📱 Aplikasi Admin berhasil terpasang di HP!');
      }
      deferredPrompt = null;
    });
  } else {
    showToast('📱 Untuk install: Tekan Opsi Browser (⋮) ➔ Tambahkan ke Layar Utama', 'warning');
  }
}


// Auth System
function getAdminPIN() {
  return localStorage.getItem(STORAGE_PIN_KEY) || DEFAULT_PIN;
}

function checkAuthSession() {
  const isAuth = sessionStorage.getItem("aniverse_admin_authenticated");
  if (isAuth === "true") {
    document.getElementById("auth-modal").classList.add("hidden");
    document.getElementById("app-dashboard").classList.remove("hidden");
    renderCatalog();
  } else {
    document.getElementById("auth-modal").classList.remove("hidden");
    document.getElementById("app-dashboard").classList.add("hidden");
  }
}

function handleLogin(e) {
  e.preventDefault();
  const inputPin = document.getElementById("admin-pin").value;
  if (inputPin === getAdminPIN()) {
    sessionStorage.setItem("aniverse_admin_authenticated", "true");
    document.getElementById("auth-error").classList.add("hidden");
    checkAuthSession();
    showToast("Selamat datang kembali, Master Admin!");
  } else {
    document.getElementById("auth-error").classList.remove("hidden");
  }
}

function handleLogout() {
  sessionStorage.removeItem("aniverse_admin_authenticated");
  checkAuthSession();
}

function handleChangePin(e) {
  e.preventDefault();
  const newPin = document.getElementById("new-pin").value.trim();
  const confirmPin = document.getElementById("confirm-pin").value.trim();
  if (newPin.length < 4) {
    showToast("PIN minimal 4 karakter!", "error");
    return;
  }
  if (newPin !== confirmPin) {
    showToast("Konfirmasi PIN tidak cocok!", "error");
    return;
  }
  localStorage.setItem(STORAGE_PIN_KEY, newPin);
  showToast("PIN Admin berhasil diubah!");
  document.getElementById("new-pin").value = "";
  document.getElementById("confirm-pin").value = "";
}

// ── Catalog Version Sentinel ─────────────────────────────────────────────────
// Bump CATALOG_VERSION any time defaultCatalog changes so returning browsers
// automatically get the updated seed instead of their stale localStorage copy.
const CATALOG_VERSION = "v6_working_trailers";
const CATALOG_VERSION_KEY = "aniverse_catalog_version";

function loadCatalogData() {
  const storedVersion = localStorage.getItem(CATALOG_VERSION_KEY);
  const stored = localStorage.getItem(STORAGE_CATALOG_KEY);

  // Version mismatch or first run → always reset to current defaults
  if (storedVersion !== CATALOG_VERSION || !stored) {
    catalogData = [...defaultCatalog];
    localStorage.setItem(CATALOG_VERSION_KEY, CATALOG_VERSION);
    saveCatalogData(false);
    return;
  }

  try {
    const parsed = JSON.parse(stored);
    if (Array.isArray(parsed) && parsed.length > 0) {
      catalogData = parsed;
    } else {
      catalogData = [...defaultCatalog];
      saveCatalogData(false);
    }
  } catch (err) {
    catalogData = [...defaultCatalog];
    saveCatalogData(false);
  }
}

function saveCatalogData(notify = true) {
  localStorage.setItem(STORAGE_CATALOG_KEY, JSON.stringify(catalogData));
  renderCatalog();
  if (notify) showToast("Data katalog tersimpan & ter-sync!");
}

function resetToDefault() {
  if (confirm("Apakah Anda yakin ingin mereset seluruh katalog ke data bawaan? Entri kustom akan hilang.")) {
    catalogData = [...defaultCatalog];
    saveCatalogData(false);
    showToast("Katalog di-reset ke data bawaan.");
  }
}

function setViewMode(mode, el) {
  viewMode = mode;
  document.querySelectorAll(".view-toggle-btn").forEach(b => b.classList.remove("active"));
  el.classList.add("active");
  const grid = document.getElementById("anime-grid");
  if (mode === 'list') grid.classList.add("list-view");
  else grid.classList.remove("list-view");
}

function sortCatalog() {
  sortOrder = sortOrder === 'newest' ? 'rating' : sortOrder === 'rating' ? 'title' : 'newest';
  const sortLabel = sortOrder === 'newest' ? 'Terbaru' : sortOrder === 'rating' ? 'Rating Tinggi' : 'Judul A-Z';
  document.getElementById("sort-btn").textContent = `↕ ${sortLabel}`;
  renderCatalog();
}

function renderCatalog() {
  const grid = document.getElementById("anime-grid");
  if (!grid) return;
  const searchQuery = document.getElementById("search-input").value.toLowerCase().trim();
  const searchClearBtn = document.getElementById("search-clear");
  if (searchClearBtn) searchClearBtn.classList.toggle("hidden", searchQuery === "");

  let filtered = catalogData.filter(item => {
    const matchesSearch = (item.title || "").toLowerCase().includes(searchQuery);
    if (!matchesSearch) return false;
    const hasStream = _itemHasStreamLinks(item);
    if (activeFilter === 'trending') return item.isTrending;
    if (activeFilter === 'custom') return (item.id || "").startsWith('custom-');
    if (activeFilter === 'stream') return hasStream;
    if (activeFilter === 'nostream') return !hasStream;
    return true;
  });

  // Sort
  if (sortOrder === 'rating') filtered.sort((a, b) => (b.rating || 0) - (a.rating || 0));
  else if (sortOrder === 'title') filtered.sort((a, b) => (a.title || "").localeCompare(b.title || ""));

  // Update counters & stats
  const totalCount = catalogData.length;
  const trendingCount = catalogData.filter(x => x.isTrending).length;
  const isFinished = s => s === 'Finished Airing' || s === 'Tamat' || s === 'tamat';
  const ongoingCount = catalogData.filter(x => !isFinished(x.status)).length;
  const customCount = catalogData.filter(x => (x.id || "").startsWith('custom-')).length;
  const streamCount = catalogData.filter(x => _itemHasStreamLinks(x)).length;

  document.getElementById("count-all").textContent = totalCount;
  document.getElementById("count-trending").textContent = trendingCount;
  document.getElementById("count-custom").textContent = customCount;
  document.getElementById("count-stream").textContent = streamCount;
  document.getElementById("count-nostream").textContent = totalCount - streamCount;

  document.getElementById("stat-total").textContent = totalCount;
  document.getElementById("stat-trending").textContent = trendingCount;
  document.getElementById("stat-ongoing").textContent = ongoingCount;
  document.getElementById("stat-custom").textContent = customCount;
  document.getElementById("stat-stream").textContent = streamCount;

  document.getElementById("view-count-label").textContent = `Menampilkan ${filtered.length} dari ${totalCount} anime`;

  if (filtered.length === 0) {
    grid.innerHTML = `
      <div style="grid-column: 1/-1; text-align: center; padding: 60px 20px; color: #94a3b8;">
        <p style="font-size: 40px; margin-bottom: 8px;">🎬</p>
        <p style="font-weight: 700; font-size: 16px; color:#fff;">Tidak ada anime yang ditemukan</p>
        <p style="font-size: 13px;">Coba ubah kata kunci pencarian atau tekan "+ Tambah Anime".</p>
      </div>
    `;
    return;
  }

  grid.innerHTML = filtered.map(item => {
    const hasStream = _itemHasStreamLinks(item);
    return `
      <div class="anime-card-admin">
        <div class="card-cover" style="background-image: url('${escapeHtml(item.imageUrl)}')">
          <div class="card-badges">
            ${item.isTrending ? '<span class="badge-tag trending">🔥 Trending</span>' : ''}
            <span class="badge-tag">★ ${item.rating || '8.0'}</span>
          </div>
        </div>
        <div class="card-body">
          <h4>${escapeHtml(item.title)}</h4>
          <p>${escapeHtml(item.description)}</p>
          <div class="card-meta">
            <span class="meta-pill">📺 ${item.episodes || 12} Ep</span>
            <span class="meta-pill" style="color: ${isFinished(item.status) ? '#a855f7' : '#22c55e'}; font-weight:700;">
              ${isFinished(item.status) ? '🏁 Tamat' : '🟢 On-Going'}
            </span>
            ${item.trailerUrl ? '<span class="meta-pill" style="color:#00f2fe;">🎬 Trailer</span>' : ''}
            ${hasStream ? '<span class="meta-pill" style="color:#2ed573;">▶ Stream</span>' : '<span class="meta-pill" style="color:#ffa502;">⚠️ No Stream</span>'}
          </div>
          <div class="card-actions">
            <button class="btn-icon" onclick="editAnime('${item.id}')">✏ Edit</button>
            <button class="btn-icon" onclick="duplicateAnime('${item.id}')" title="Duplikat">📋 Duplikat</button>
            <button class="btn-icon delete" onclick="openDeleteModal('${item.id}')">🗑 Hapus</button>
          </div>
        </div>
      </div>
    `;
  }).join('');
}

function _itemHasStreamLinks(item) {
  if (!item.catalogEpisodeLink) return false;
  try {
    const parsed = JSON.parse(item.catalogEpisodeLink);
    return Object.keys(parsed).some(ep => ['360p','480p','720p','1080p'].some(q => parsed[ep][q] && parsed[ep][q].trim() !== ''));
  } catch (e) { return false; }
}

function handleSearch() { renderCatalog(); }
function clearSearch() { document.getElementById("search-input").value = ""; renderCatalog(); }

function filterCategory(cat, el) {
  activeFilter = cat;
  document.querySelectorAll('.filter-bar .chip').forEach(c => c.classList.remove('active'));
  el.classList.add('active');
  renderCatalog();
}

function switchTab(tab, el) {
  document.querySelectorAll('.nav-item').forEach(i => i.classList.remove('active'));
  document.querySelectorAll('.mnav-item').forEach(i => i.classList.remove('active'));
  document.querySelectorAll('.view-section').forEach(v => v.classList.add('hidden'));

  if (el) el.classList.add('active');
  document.getElementById(`view-${tab}`).classList.remove('hidden');
  if (tab === 'stats') renderStatsView();
}

function renderGenrePresets() {
  const container = document.getElementById("genre-presets");
  if (!container) return;
  container.innerHTML = GENRE_PRESETS.map(g => `<span class="g-tag" onclick="addGenreTag('${g}')">+ ${g}</span>`).join('');
}

function addGenreTag(genre) {
  const input = document.getElementById("field-genres");
  let current = input.value.split(',').map(s => s.trim()).filter(s => s);
  if (!current.includes(genre)) {
    current.push(genre);
    input.value = current.join(', ');
  }
}

// Modal Tabs Navigation
function switchModalTab(tab, el) {
  currentModalTab = tab;
  document.querySelectorAll(".mtab").forEach(b => b.classList.remove("active"));
  document.querySelectorAll(".modal-tab-content").forEach(c => c.classList.remove("active"));
  if (el) el.classList.add("active");
  document.getElementById(`mtab-${tab}`).classList.add("active");
}

function nextModalTab() {
  const tabs = ['info', 'media', 'episodes', 'placement'];
  const idx = tabs.indexOf(currentModalTab);
  if (idx < tabs.length - 1) {
    const target = tabs[idx + 1];
    switchModalTab(target, document.querySelector(`.mtab[data-tab="${target}"]`));
  }
}

function prevModalTab() {
  const tabs = ['info', 'media', 'episodes', 'placement'];
  const idx = tabs.indexOf(currentModalTab);
  if (idx > 0) {
    const target = tabs[idx - 1];
    switchModalTab(target, document.querySelector(`.mtab[data-tab="${target}"]`));
  }
}

// Episode Manager Engine
function _epHasAnyLink(epNum) {
  const d = currentEpisodeQualitiesMap[epNum];
  if (!d) return false;
  return ['360p','480p','720p','1080p'].some(q => d[q] && d[q].trim() !== '');
}

function _epIsMissingLink(epNum) {
  const d = currentEpisodeQualitiesMap[epNum];
  if (!d) return false;
  const filled = ['360p','480p','720p','1080p'].filter(q => d[q] && d[q].trim() !== '').length;
  return filled > 0 && filled < 4;
}

function onEpisodeCountChange() {
  renderEpisodeSelectorUI();
}

function renderEpisodeSelectorUI() {
  const totalEp = parseInt(document.getElementById("field-episodes").value) || 12;
  const select = document.getElementById("episode-select");
  const gridNav = document.getElementById("ep-grid-nav");
  const currentVal = parseInt(select.value) || 1;

  select.innerHTML = "";
  gridNav.innerHTML = "";

  for (let i = 1; i <= totalEp; i++) {
    const hasAll = _epHasAnyLink(i);
    const partial = _epIsMissingLink(i);
    
    // Select dropdown option
    const opt = document.createElement("option");
    opt.value = i;
    opt.textContent = `${hasAll && !partial ? '✅' : partial ? '⚠️' : '⚪'} Eps ${i}`;
    select.appendChild(opt);

    // Mini Chip Grid
    const chip = document.createElement("div");
    chip.className = `ep-chip ${hasAll && !partial ? 'filled' : partial ? 'partial' : ''} ${i === currentVal ? 'active' : ''}`;
    chip.textContent = i;
    chip.onclick = () => selectEpisodeNumber(i);
    gridNav.appendChild(chip);
  }

  if (currentVal <= totalEp) select.value = currentVal;
  else select.value = 1;

  updateEpisodeInputs(select.value);
  updateEpisodeProgressBar(totalEp);
}

function selectEpisodeNumber(epNum) {
  document.getElementById("episode-select").value = epNum;
  onEpisodeSelectChange();
}

function onEpisodeSelectChange() {
  const epNum = document.getElementById("episode-select").value;
  renderEpisodeSelectorUI();
  updateEpisodeInputs(epNum);
}

function updateEpisodeInputs(epNum) {
  const epData = currentEpisodeQualitiesMap[epNum] || {};
  document.getElementById("link-360p").value = epData["360p"] || "";
  document.getElementById("link-480p").value = epData["480p"] || "";
  document.getElementById("link-720p").value = epData["720p"] || "";
  document.getElementById("link-1080p").value = epData["1080p"] || "";

  document.getElementById("ep-current-label").textContent = `Episode ${epNum}`;
  document.getElementById("episode-search").value = epNum;
}

function onLinkInput() {
  const currentEp = document.getElementById("episode-select").value || 1;
  currentEpisodeQualitiesMap[currentEp] = {
    "360p": document.getElementById("link-360p").value.trim(),
    "480p": document.getElementById("link-480p").value.trim(),
    "720p": document.getElementById("link-720p").value.trim(),
    "1080p": document.getElementById("link-1080p").value.trim(),
  };
  document.getElementById("field-watch").value = JSON.stringify(currentEpisodeQualitiesMap);
  
  // Re-render UI indicators non-destructively
  const totalEp = parseInt(document.getElementById("field-episodes").value) || 12;
  updateEpisodeProgressBar(totalEp);
}

function updateEpisodeProgressBar(totalEp) {
  const filled = Array.from({length: totalEp}, (_, i) => i + 1).filter(i => _epHasAnyLink(i)).length;
  const pct = totalEp > 0 ? Math.round((filled / totalEp) * 100) : 0;
  const bar = document.getElementById("ep-progress-bar");
  const label = document.getElementById("ep-progress-label");
  if (bar) bar.style.width = pct + "%";
  if (label) label.textContent = `${filled}/${totalEp} episode terisi (${pct}%)`;
}

function jumpToEpisodeSearch() {
  const searchInput = document.getElementById("episode-search");
  const num = parseInt(searchInput.value);
  const totalEp = parseInt(document.getElementById("field-episodes").value) || 12;
  if (num && num >= 1 && num <= totalEp) {
    selectEpisodeNumber(num);
  }
}

function navEpisode(dir) {
  const totalEp = parseInt(document.getElementById("field-episodes").value) || 12;
  let current = parseInt(document.getElementById("episode-select").value) || 1;
  current += dir;
  if (current >= 1 && current <= totalEp) {
    selectEpisodeNumber(current);
  }
}

function copyLinkToAll() {
  const currentEp = document.getElementById("episode-select").value || 1;
  const source = currentEpisodeQualitiesMap[currentEp];
  if (!source || !_epHasAnyLink(currentEp)) {
    showToast("Episode saat ini tidak memiliki link untuk disalin!", "warning");
    return;
  }
  const totalEp = parseInt(document.getElementById("field-episodes").value) || 12;
  if (confirm(`Salin link dari Episode ${currentEp} ke seluruh ${totalEp} episode?`)) {
    for (let i = 1; i <= totalEp; i++) {
      currentEpisodeQualitiesMap[i] = { ...source };
    }
    document.getElementById("field-watch").value = JSON.stringify(currentEpisodeQualitiesMap);
    renderEpisodeSelectorUI();
    showToast(`Link berhasil disalin ke semua ${totalEp} episode!`);
  }
}

function clearCurrentEpLinks() {
  const currentEp = document.getElementById("episode-select").value || 1;
  delete currentEpisodeQualitiesMap[currentEp];
  document.getElementById("field-watch").value = JSON.stringify(currentEpisodeQualitiesMap);
  renderEpisodeSelectorUI();
  showToast(`Link Episode ${currentEp} dibersihkan.`);
}

// Media Previews
function previewImage() {
  const url = document.getElementById("field-image").value.trim();
  const img = document.getElementById("img-preview");
  const ph = document.getElementById("img-preview-placeholder");
  if (url) {
    img.src = url;
    img.classList.remove("hidden");
    ph.classList.add("hidden");
  } else {
    img.classList.add("hidden");
    ph.classList.remove("hidden");
  }
}

function previewTrailer() {
  const url = document.getElementById("field-trailer").value.trim();
  if (!url) return;
  let embedUrl = url;
  if (url.includes("watch?v=")) embedUrl = url.replace("watch?v=", "embed/");
  document.getElementById("trailer-iframe").src = embedUrl;
  document.getElementById("trailer-preview").classList.remove("hidden");
}

// Modal Actions
function openAddModal() {
  document.getElementById("anime-id").value = "";
  document.getElementById("modal-title").textContent = "Tambah Anime Baru";
  document.getElementById("save-btn-text").textContent = "💾 Simpan Ke Katalog";
  document.getElementById("anime-form").reset();
  currentEpisodeQualitiesMap = {};
  switchModalTab('info', document.querySelector('.mtab[data-tab="info"]'));
  previewImage();
  renderEpisodeSelectorUI();
  document.getElementById("anime-modal").classList.remove("hidden");
}

function closeAnimeModal() {
  document.getElementById("anime-modal").classList.add("hidden");
}

function handleModalOverlayClick(e) {
  if (e.target.classList.contains("modal-overlay")) closeAnimeModal();
}

function editAnime(id) {
  const item = catalogData.find(x => x.id === id);
  if (!item) return;

  document.getElementById("anime-id").value = item.id;
  document.getElementById("modal-title").textContent = "Edit Anime: " + item.title;
  document.getElementById("save-btn-text").textContent = "💾 Perbarui Anime";

  document.getElementById("field-title").value = item.title || "";
  document.getElementById("field-rating").value = item.rating || 8.0;
  document.getElementById("field-desc").value = item.description || "";
  document.getElementById("field-image").value = item.imageUrl || "";
  document.getElementById("field-trailer").value = item.trailerUrl || "";
  document.getElementById("field-watch").value = item.catalogEpisodeLink || "";
  document.getElementById("field-episodes").value = item.episodes || 12;
  document.getElementById("field-release-day").value = item.releaseDay || "";
  document.getElementById("field-status").value = item.status || "Ongoing";
  document.getElementById("field-genres").value = (item.genres || []).join(", ");
  document.getElementById("field-trending").checked = !!item.isTrending;

  try { currentEpisodeQualitiesMap = JSON.parse(item.catalogEpisodeLink || "{}"); }
  catch (e) { currentEpisodeQualitiesMap = {}; }

  const savedPlacement = item.placement || ['explore'];
  document.querySelectorAll('input[name="placement"]').forEach(cb => {
    cb.checked = savedPlacement.includes(cb.value);
  });

  previewImage();
  renderEpisodeSelectorUI();
  switchModalTab('info', document.querySelector('.mtab[data-tab="info"]'));
  document.getElementById("anime-modal").classList.remove("hidden");
}

function duplicateAnime(id) {
  const item = catalogData.find(x => x.id === id);
  if (!item) return;
  const newItem = {
    ...item,
    id: `custom-${Date.now()}`,
    title: `${item.title} (Salinan)`,
    addedAt: new Date().toISOString()
  };
  catalogData.unshift(newItem);
  saveCatalogData();
  showToast(`Duplikat "${item.title}" berhasil dibuat!`);
}

function handleSaveAnime(e) {
  e.preventDefault();
  let rawId = document.getElementById("anime-id").value;
  const isEditing = !!rawId;
  if (!rawId) rawId = `custom-${Date.now()}`;
  else if (!rawId.startsWith('custom-') && !rawId.startsWith('user-')) rawId = `custom-${rawId}`;

  const genresStr = document.getElementById("field-genres").value;
  const genresArr = genresStr.split(",").map(g => g.trim()).filter(g => g.length > 0);

  const placementChecks = document.querySelectorAll('input[name="placement"]:checked');
  let placement = Array.from(placementChecks).map(cb => cb.value);
  if (placement.length === 0) placement = ['explore'];

  const releaseDayVal = document.getElementById("field-release-day").value;
  if (placement.includes('jadwal') && !releaseDayVal) {
    showToast("Harap pilih Hari Rilis jika dimasukkan ke Jadwal!", "warning");
    switchModalTab('info', document.querySelector('.mtab[data-tab="info"]'));
    return;
  }

  // Preserve original addedAt when editing; only set to now for NEW entries
  const existingItem = catalogData.find(x => x.id === rawId);
  const addedAt = (isEditing && existingItem?.addedAt) ? existingItem.addedAt : new Date().toISOString();

  const animeObj = {
    id: rawId,
    title: document.getElementById("field-title").value.trim(),
    rating: parseFloat(document.getElementById("field-rating").value) || 8.0,
    description: document.getElementById("field-desc").value.trim(),
    imageUrl: document.getElementById("field-image").value.trim(),
    trailerUrl: document.getElementById("field-trailer").value.trim() || null,
    catalogEpisodeLink: JSON.stringify(currentEpisodeQualitiesMap),
    episodes: parseInt(document.getElementById("field-episodes").value) || 12,
    episodeCount: parseInt(document.getElementById("field-episodes").value) || 12,
    releaseDay: releaseDayVal ? parseInt(releaseDayVal) : null,
    status: document.getElementById("field-status").value || "Ongoing",
    genres: genresArr,
    isTrending: document.getElementById("field-trending").checked,
    placement: placement,
    addedAt: addedAt
  };

  const existingIdx = catalogData.findIndex(x => x.id === rawId);
  if (existingIdx !== -1) catalogData[existingIdx] = animeObj;
  else catalogData.unshift(animeObj);

  saveCatalogData();
  closeAnimeModal();
  showToast(`✅ "${animeObj.title}" berhasil ${isEditing ? 'diperbarui' : 'ditambahkan'}! Placement: [${placement.join(', ')}]`);
}

// Delete & Undo
function openDeleteModal(id) {
  pendingDeleteId = id;
  const item = catalogData.find(x => x.id === id);
  if (!item) return;
  document.getElementById("delete-title").textContent = `Hapus "${item.title}"?`;
  document.getElementById("delete-modal").classList.remove("hidden");
}

function closeDeleteModal() {
  document.getElementById("delete-modal").classList.add("hidden");
  pendingDeleteId = null;
}

function confirmDelete() {
  if (!pendingDeleteId) return;
  const item = catalogData.find(x => x.id === pendingDeleteId);
  if (item) {
    lastDeletedItem = { ...item };
    catalogData = catalogData.filter(x => x.id !== pendingDeleteId);
    saveCatalogData(false);
    showUndoBanner(item.title);
  }
  closeDeleteModal();
}

function showUndoBanner(title) {
  const banner = document.getElementById("undo-banner");
  document.getElementById("undo-text").textContent = `"${title}" dihapus.`;
  banner.classList.remove("hidden");
  if (undoTimeout) clearTimeout(undoTimeout);
  undoTimeout = setTimeout(() => { banner.classList.add("hidden"); }, 5000);
}

function undoDelete() {
  if (lastDeletedItem) {
    catalogData.unshift(lastDeletedItem);
    saveCatalogData();
    document.getElementById("undo-banner").classList.add("hidden");
    showToast(`"${lastDeletedItem.title}" dikembalikan!`);
    lastDeletedItem = null;
  }
}

// Export / Import
function exportCatalogJSON() {
  const toExport = catalogData.filter(x => x.id.startsWith('custom-'));
  downloadJSON(toExport, `aniverse_custom_catalog_${Date.now()}.json`);
}

function exportAllJSON() {
  downloadJSON(catalogData, `aniverse_full_catalog_${Date.now()}.json`);
}

function downloadJSON(data, filename) {
  const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(data, null, 2));
  const a = document.createElement('a');
  a.href = dataStr;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  showToast("Download JSON berhasil!");
}

function exportFriendTemplate() {
  const template = [{
    "id": "custom-NAMA_ANIME_BARU",
    "title": "Nama Anime",
    "imageUrl": "https://link-cover-image.jpg",
    "rating": 8.5,
    "genres": ["Action", "Fantasy"],
    "description": "Sinopsis singkat anime...",
    "isTrending": false,
    "releaseDay": 1,
    "episodes": 12,
    "trailerUrl": "",
    "catalogEpisodeLink": JSON.stringify({"1": {"360p": "", "480p": "", "720p": "", "1080p": ""}}),
    "addedAt": new Date().toISOString()
  }];
  downloadJSON(template, "aniverse_template_teman.json");
}

function importCatalogJSON(event) {
  const file = event.target.files[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = function(e) {
    try {
      const incoming = JSON.parse(e.target.result);
      if (!Array.isArray(incoming)) throw new Error("Format JSON harus berupa list array.");
      let added = 0, updated = 0;
      incoming.forEach(item => {
        if (!item.id) item.id = `custom-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`;
        else if (!item.id.startsWith('custom-') && !item.id.startsWith('user-')) item.id = `custom-${item.id}`;

        const idx = catalogData.findIndex(x => x.id === item.id || (x.title || '').toLowerCase() === (item.title || '').toLowerCase());
        if (idx !== -1) {
          catalogData[idx] = { ...catalogData[idx], ...item };
          updated++;
        } else {
          catalogData.unshift(item);
          added++;
        }
      });
      saveCatalogData();
      showToast(`Import Selesai! ➕ ${added} baru, 🔄 ${updated} diupdate.`);
    } catch (err) {
      showToast(`Import Gagal: ${err.message}`, 'error');
    }
  };
  reader.readAsText(file);
}

function renderStatsView() {
  const container = document.getElementById("stats-content");
  if (!container) return;
  const total = catalogData.length;
  const genreMap = {};
  catalogData.forEach(item => {
    (item.genres || []).forEach(g => { genreMap[g] = (genreMap[g] || 0) + 1; });
  });

  container.innerHTML = `
    <div style="display:grid; grid-template-columns:1fr 1fr; gap:20px;">
      <div class="settings-card">
        <h3>📊 Distribusi Genre</h3>
        <div style="margin-top:14px;">
          ${Object.entries(genreMap).map(([g, cnt]) => `
            <div style="display:flex; justify-between; align-center; margin-bottom:8px; font-size:13px;">
              <span>${g}</span>
              <span style="color:var(--accent-cyan); font-weight:700;">${cnt} anime</span>
            </div>
          `).join('')}
        </div>
      </div>
    </div>
  `;
}

function syncToAniVerseApp() {
  saveCatalogData();
  const cleanExport = catalogData.map(a => ({
    id: a.id,
    title: a.title,
    imageUrl: a.imageUrl,
    rating: a.rating,
    genres: a.genres || [],
    description: a.description || "",
    isTrending: !!a.isTrending,
    episodesCount: a.episodes || a.episodeCount || 12,
    status: a.status || "Ongoing",
    trailerUrl: a.trailerUrl || "",
    catalogEpisodeLink: a.catalogEpisodeLink || "",
    voiceActors: a.voiceActors || [],
    // ── PLACEMENT & SCHEDULE FIELDS (required by Flutter AnimeModel) ──
    placement: a.placement && a.placement.length > 0 ? a.placement : ['explore'],
    releaseDay: a.releaseDay || null,
    addedAt: a.addedAt || new Date().toISOString()
  }));

  // Breakdown placement summary for admin feedback
  const trendingCount = cleanExport.filter(a => a.placement.includes('home_trending') || a.isTrending).length;
  const jadwalCount = cleanExport.filter(a => a.placement.includes('jadwal')).length;
  const featuredCount = cleanExport.filter(a => a.placement.includes('home_featured')).length;

  // Auto trigger catalog_cloud.json download & save notification
  downloadJSON(cleanExport, "catalog_cloud.json");
  showToast(`⚡ SINGKRONISASI SUKSES! ${cleanExport.length} Anime — 🔥${trendingCount} Trending · 📅${jadwalCount} Jadwal · 🌟${featuredCount} Featured`);
}

function escapeHtml(str) {
  return (str || '').replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}
