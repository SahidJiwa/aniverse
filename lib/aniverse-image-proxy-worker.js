// aniverse-image-proxy — Cloudflare Worker
// Proxy generik untuk gambar dari domain manapun (Pinterest, X/Twitter,
// Instagram publik, Google, dll) yang mem-block CORS untuk request
// XMLHttpRequest/fetch dari browser (termasuk Flutter web di localhost
// atau domain produksi AniVerse).
//
// CARA KERJA:
// Browser (Flutter web) -> request ke Worker ini -> Worker fetch gambar
// asli dari server tujuan (server-to-server, tidak kena CORS) -> Worker
// kirim balik gambar itu ke browser dengan header CORS yang mengizinkan.
//
// PEMAKAIAN DI APP:
// Ganti:
//   https://i.pinimg.com/736x/9f/25/4c/9f254ca....jpg
// Jadi:
//   https://aniverse-image-proxy.<subdomain-kamu>.workers.dev/?url=<url-asli-di-encode>
//
// Contoh lengkap:
//   https://aniverse-image-proxy.XXXX.workers.dev/?url=https%3A%2F%2Fi.pinimg.com%2F736x%2F9f%2F25%2F4c%2F9f254ca1a897e27a4887e6a7d31560d9.jpg

// Whitelist domain sumber gambar yang diizinkan di-proxy. Ini PENTING untuk
// keamanan — tanpa whitelist, Worker ini bisa disalahgunakan orang lain
// sebagai proxy anonim buat request apa saja (open proxy = risiko abuse,
// bisa bikin akun Cloudflare kena suspend karena traffic tidak wajar).
// Tambahkan domain baru di sini kalau nanti butuh sumber lain.
const ALLOWED_HOSTS = [
  'i.pinimg.com',
  'pinimg.com',
  'pbs.twimg.com',           // X/Twitter
  'abs.twimg.com',
  'scontent.cdninstagram.com', // Instagram (kadang berhasil, kadang butuh session)
  'scontent-*.cdninstagram.com',
  'lookaside.fbsbx.com',     // Facebook
  'encrypted-tbn0.gstatic.com', // Google Images thumbnail
  'lh3.googleusercontent.com',
  'cdn.myanimelist.net',     // MAL, siapa tau kepake
  'image.tmdb.org',          // TMDB, siapa tau kepake
];

// Cek apakah hostname termasuk domain yang diizinkan di-proxy, dengan
// dukungan wildcard sederhana (mis. 'scontent-*.cdninstagram.com').
function hostMatches(hostname) {
  for (const pattern of ALLOWED_HOSTS) {
    if (pattern.includes('*')) {
      const regex = new RegExp('^' + pattern.replace(/\./g, '\\.').replace('*', '.*') + '$');
      if (regex.test(hostname)) return true;
    } else if (hostname === pattern || hostname.endsWith('.' + pattern)) {
      return true;
    }
  }
  return false;
}

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
  'Access-Control-Allow-Headers': '*',
};

export default {
  async fetch(request) {
    // Preflight CORS
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS_HEADERS });
    }

    const requestUrl = new URL(request.url);
    const targetUrlParam = requestUrl.searchParams.get('url');

    if (!targetUrlParam) {
      return new Response(
        JSON.stringify({ error: 'Parameter ?url= wajib diisi dengan URL gambar yang sudah di-encode.' }),
        { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
      );
    }

    let targetUrl;
    try {
      targetUrl = new URL(targetUrlParam);
    } catch (_) {
      return new Response(
        JSON.stringify({ error: 'URL tidak valid.' }),
        { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
      );
    }

    if (targetUrl.protocol !== 'https:' && targetUrl.protocol !== 'http:') {
      return new Response(
        JSON.stringify({ error: 'Hanya URL http/https yang diizinkan.' }),
        { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
      );
    }

    if (!hostMatches(targetUrl.hostname)) {
      return new Response(
        JSON.stringify({
          error: `Domain "${targetUrl.hostname}" belum ada di whitelist proxy.`,
          hint: 'Tambahkan domain ini ke ALLOWED_HOSTS di kode Worker kalau memang sumber tepercaya.',
        }),
        { status: 403, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
      );
    }

    try {
      // Fetch gambar asli server-to-server — tidak kena CORS karena ini
      // bukan request dari browser.
      const upstreamResponse = await fetch(targetUrl.toString(), {
        headers: {
          // Beberapa CDN (termasuk Pinterest) kadang cek User-Agent/Referer
          // dan menolak request tanpa itu. Kirim header yang wajar supaya
          // diperlakukan seperti request browser biasa.
          'User-Agent': 'Mozilla/5.0 (compatible; AniVerseImageProxy/1.0)',
        },
        cf: {
          // Cache di edge Cloudflare selama 1 hari — mengurangi beban ke
          // server asal dan mempercepat load berikutnya untuk gambar sama.
          cacheTtl: 86400,
          cacheEverything: true,
        },
      });

      if (!upstreamResponse.ok) {
        return new Response(
          JSON.stringify({
            error: `Gagal ambil gambar dari sumber asli.`,
            status: upstreamResponse.status,
          }),
          { status: upstreamResponse.status, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
        );
      }

      const contentType = upstreamResponse.headers.get('Content-Type') || 'image/jpeg';

      return new Response(upstreamResponse.body, {
        status: 200,
        headers: {
          ...CORS_HEADERS,
          'Content-Type': contentType,
          'Cache-Control': 'public, max-age=86400',
        },
      });
    } catch (err) {
      return new Response(
        JSON.stringify({ error: 'Gagal fetch gambar.', detail: String(err) }),
        { status: 502, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
      );
    }
  },
};
