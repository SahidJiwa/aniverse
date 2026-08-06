// Cloudflare Worker: aniverse-stream-proxy
// Deploy: wrangler deploy (lihat wrangler.toml di bawah)
//
// Tujuan:
//  1. Proxy pass-through untuk URL .m3u8 / .mp4 dari situs sub Indo
//     (oploverz / upbolt / acefile / animeboy / dll) supaya app Flutter
//     Web bisa muter tanpa kena anti-hotlink (Referer di-inject di sini).
//  2. Cache 24 jam biar gak fetch ulang tiap play.
//  3. Optional: scrape halaman episode -> cari .m3u8/.mp4 pertama.
//
// App memanggil:
//   GET /proxy?url=<encoded_url>
//   GET /resolve?page=<encoded_episode_page_url>
//
// Response proxy: stream binary (video) dengan header CORS terbuka.
// Response resolve: JSON { "streamUrl": "...", "qualities": {...} }

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const cors = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': '*',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: cors });
    }

    // ── /proxy?url=...  → stream video langsung (pass-through) ──
    if (url.pathname === '/proxy') {
      const target = url.searchParams.get('url');
      if (!target) {
        return new Response('missing url', { status: 400, headers: cors });
      }
      return proxyStream(target, request, cors);
    }

    // ── /resolve?page=... → scrape halaman, balikin JSON ──
    if (url.pathname === '/resolve') {
      const page = url.searchParams.get('page');
      if (!page) {
        return new Response('missing page', { status: 400, headers: cors });
      }
      try {
        const html = await fetch(page, {
          headers: { 'User-Agent': 'Mozilla/5.0', 'Referer': new URL(page).origin },
        }).then((r) => r.text());
        const m3u8 = (html.match(/https?:\/\/[^\s"']+\.m3u8/gi) || [])[0];
        const mp4 = (html.match(/https?:\/\/[^\s"']+\.mp4/gi) || [])[0];
        const streamUrl = m3u8 || mp4 || null;
        return new Response(
          JSON.stringify({ streamUrl, qualities: streamUrl ? { Auto: streamUrl } : {} }),
          { status: 200, headers: { ...cors, 'Content-Type': 'application/json' } }
        );
      } catch (e) {
        return new Response(JSON.stringify({ streamUrl: null, error: String(e) }), {
          status: 200,
          headers: { ...cors, 'Content-Type': 'application/json' },
        });
      }
    }

    return new Response('aniverse-stream-proxy', { status: 200, headers: cors });
  },
};

async function proxyStream(target, request, cors) {
  // Inject Referer biar situs gak nolak (anti-hotlink).
  let referer = '';
  try { referer = new URL(target).origin; } catch (_) {}
  const upstream = await fetch(target, {
    headers: {
      'User-Agent': 'Mozilla/5.0',
      'Referer': referer,
      'Origin': referer,
    },
    redirect: 'follow',
  });

  // Cache 24 jam di edge.
  const headers = new Headers(upstream.headers);
  headers.set('Access-Control-Allow-Origin', '*');
  headers.set('Cache-Control', 'public, max-age=86400');
  return new Response(upstream.body, {
    status: upstream.status,
    headers,
  });
}
