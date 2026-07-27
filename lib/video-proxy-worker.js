// video-proxy-worker.js
//
// ============================================================
// ANIVERSE VIDEO PROXY WORKER
// ============================================================
// Kenapa ini perlu: worker metadata kamu yang sekarang
// (aniverse-proxy.my-aniverse.workers.dev) cuma proxy hasil
// SEARCH/INFO/EPISODE LIST. URL video final (mp4/m3u8) dari
// _pickBestSource() tetap nunjuk LANGSUNG ke CDN asli
// (gogo-cdn.com, CDN HiAnime, dll) — domain-domain itu yang
// sering diblokir ISP di Indonesia. Makanya app kamu bisa
// browse/search di HP manapun, tapi videonya cuma keputer di
// jaringan yang gak blokir CDN itu.
//
// Worker ini nge-proxy VIDEO-nya juga, dan yang penting: kalau
// yang diproxy adalah playlist HLS (.m3u8), isinya di-rewrite
// dulu — setiap baris URL segment (.ts) dan URI kunci enkripsi
// (#EXT-X-KEY) diganti supaya ikut lewat proxy ini juga. Kalau
// cuma file .m3u8-nya doang yang diproxy tapi isinya masih
// nunjuk ke CDN asli, video tetep gagal di jaringan yang blokir.
//
// ============================================================
// CARA DEPLOY
// ============================================================
//   1. npm install -g wrangler        (sekali aja, kalau belum ada)
//   2. wrangler login
//   3. cd ke folder ini, lalu:  wrangler deploy
//   4. Wrangler bakal ngeprint URL kayak:
//        https://aniverse-video-proxy.<subdomain>.workers.dev
//      Copy URL itu ke `_videoProxyBase` di streaming_service.dart
// ============================================================

const DEFAULT_HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
};

function corsHeaders(extra = {}) {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
    'Access-Control-Allow-Headers': 'Range, Content-Type',
    'Access-Control-Expose-Headers':
      'Content-Length, Content-Range, Accept-Ranges',
    ...extra,
  };
}

function isPlaylistUrl(targetUrl) {
  return targetUrl.split('?')[0].toLowerCase().endsWith('.m3u8');
}

function proxyUrlFor(origin, targetUrl, referer) {
  const p = new URL(origin + '/proxy');
  p.searchParams.set('url', targetUrl);
  if (referer) p.searchParams.set('ref', referer);
  return p.toString();
}

// Satu baris di file .m3u8 bisa berupa:
//  - komentar/tag biasa (#EXTINF, dll)        -> dibiarin apa adanya
//  - tag dengan atribut URI="..."             -> URI-nya di-rewrite
//  - baris URL segment/nested-playlist polos  -> di-rewrite semua
function rewriteLine(line, baseUrl, origin, referer) {
  const trimmed = line.trim();
  if (!trimmed) return line;

  if (trimmed.startsWith('#')) {
    const uriMatch = trimmed.match(/URI="([^"]+)"/);
    if (uriMatch) {
      const abs = new URL(uriMatch[1], baseUrl).toString();
      const proxied = proxyUrlFor(origin, abs, referer);
      return line.replace(uriMatch[1], proxied);
    }
    return line;
  }

  const abs = new URL(trimmed, baseUrl).toString();
  return proxyUrlFor(origin, abs, referer);
}

async function handlePlaylist(targetUrl, referer, origin) {
  const upstream = await fetch(targetUrl, {
    headers: {
      ...DEFAULT_HEADERS,
      ...(referer ? { Referer: referer } : {}),
    },
  });
  if (!upstream.ok) {
    return new Response('Upstream error ' + upstream.status, {
      status: upstream.status,
      headers: corsHeaders(),
    });
  }
  const text = await upstream.text();
  const rewritten = text
    .split('\n')
    .map((line) => rewriteLine(line, targetUrl, origin, referer))
    .join('\n');

  return new Response(rewritten, {
    status: 200,
    headers: corsHeaders({
      'Content-Type': 'application/vnd.apple.mpegurl',
      'Cache-Control': 'no-store',
    }),
  });
}

async function handleBinary(targetUrl, referer, request) {
  const headers = { ...DEFAULT_HEADERS };
  if (referer) headers['Referer'] = referer;
  // Forward header Range biar seek/scrub di video player tetap jalan
  // (kalau ini gak di-forward, video cuma bisa diputer dari awal doang).
  const range = request.headers.get('Range');
  if (range) headers['Range'] = range;

  const upstream = await fetch(targetUrl, { headers });

  const respHeaders = corsHeaders({
    'Content-Type':
      upstream.headers.get('Content-Type') || 'application/octet-stream',
  });
  for (const h of ['Content-Length', 'Content-Range', 'Accept-Ranges', 'Cache-Control']) {
    const v = upstream.headers.get(h);
    if (v) respHeaders[h] = v;
  }

  return new Response(upstream.body, {
    status: upstream.status,
    headers: respHeaders,
  });
}

export default {
  async fetch(request) {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders() });
    }

    if (url.pathname !== '/proxy') {
      return new Response(
        'Aniverse video proxy aktif. Pakai: /proxy?url=<video atau m3u8 url>&ref=<referer opsional>',
        { status: 200, headers: corsHeaders() },
      );
    }

    const targetUrl = url.searchParams.get('url');
    if (!targetUrl) {
      return new Response('Missing url param', {
        status: 400,
        headers: corsHeaders(),
      });
    }
    const referer = url.searchParams.get('ref') || undefined;
    const origin = url.origin;

    try {
      if (isPlaylistUrl(targetUrl)) {
        return await handlePlaylist(targetUrl, referer, origin);
      }
      return await handleBinary(targetUrl, referer, request);
    } catch (err) {
      return new Response('Proxy error: ' + err.message, {
        status: 502,
        headers: corsHeaders(),
      });
    }
  },
};
