// AniVerse Proxy Worker
//
// Single Cloudflare Worker that handles BOTH problems AniVerse Web has had
// with third-party proxies:
//
// 1. MAL image CORS — cdn.myanimelist.net sends no
//    Access-Control-Allow-Origin header, so Flutter Web's Image.network
//    (a normal browser cross-origin fetch) gets blocked outright.
// 2. AniList CORS — graphql.anilist.co has the same problem for the
//    title-based fallback search used when Jikan fails.
//
// Every public proxy tried before this (wsrv.nl, corsproxy.io,
// images.weserv.nl, allorigins.win, corsproxy.org, proxy.cors.sh,
// proxy.corsfix.com) either went down, required an API key, or got rate
// limited by OTHER apps' traffic sharing the same public proxy pool —
// completely out of this app's control. This Worker is used by AniVerse
// only, so none of that applies: no shared rate limit, no API key, no
// "is this proxy still alive today" guessing game, and it runs on
// Cloudflare's free tier (100,000 requests/day), which is far more than
// one app's image + GraphQL traffic will ever need.
//
// ── Routes ───────────────────────────────────────────────────────────────
//   GET  /image?url=<encoded MAL image URL>
//        Proxies the image bytes through with a permissive CORS header.
//   POST /anilist
//        Proxies the request body straight through to
//        https://graphql.anilist.co and returns the response with a
//        permissive CORS header. Body/headers are passed through
//        unmodified other than the origin change.
//
// ── Deploy ───────────────────────────────────────────────────────────────
//   1. https://dash.cloudflare.com → Workers & Pages → Create → Create
//      Worker.
//   2. Paste this whole file into the editor, replacing the default
//      "Hello World" code.
//   3. Deploy. Note the URL Cloudflare gives you, e.g.
//      https://aniverse-proxy.<your-subdomain>.workers.dev
//   4. Update ANIVERSE_PROXY_BASE in proxied_network_image.dart and
//      anime_api_service.dart to point at that URL (see the comment left
//      in each of those files for exactly what to change).

const ALLOWED_IMAGE_HOSTS = new Set([
  'cdn.myanimelist.net',
]);

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

export default {
  async fetch(request) {
    const url = new URL(request.url);

    // CORS preflight — browsers send this before the real request for
    // POST-with-JSON (the /anilist route). Answer it immediately so the
    // real request isn't blocked before it even leaves the browser.
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    if (url.pathname === '/image') {
      return handleImageProxy(url);
    }

    if (url.pathname === '/anilist') {
      return handleAniListProxy(request);
    }

    return new Response('Not found. Use /image?url=... or POST /anilist.', {
      status: 404,
      headers: CORS_HEADERS,
    });
  },
};

async function handleImageProxy(url) {
  const target = url.searchParams.get('url');
  if (!target) {
    return new Response('Missing ?url= parameter', {
      status: 400,
      headers: CORS_HEADERS,
    });
  }

  let targetUrl;
  try {
    targetUrl = new URL(target);
  } catch {
    return new Response('Invalid url parameter', {
      status: 400,
      headers: CORS_HEADERS,
    });
  }

  // Only proxy MAL's CDN — this Worker is a fix for MAL's specific missing
  // CORS header, not a general-purpose open proxy. Keeping it scoped like
  // this means it can't be abused to fetch/relay arbitrary third-party
  // content through your Cloudflare account.
  if (!ALLOWED_IMAGE_HOSTS.has(targetUrl.hostname)) {
    return new Response(`Host not allowed: ${targetUrl.hostname}`, {
      status: 403,
      headers: CORS_HEADERS,
    });
  }

  const upstream = await fetch(targetUrl.toString(), {
    // MAL's CDN has occasionally been picky about default fetch headers
    // (see the 404s some public proxies returned) — a normal browser-like
    // User-Agent avoids that without needing anything MAL-specific.
    headers: {
      'User-Agent': 'Mozilla/5.0 (compatible; AniVerseProxy/1.0)',
    },
  });

  if (!upstream.ok) {
    return new Response(`Upstream returned ${upstream.status}`, {
      status: upstream.status,
      headers: CORS_HEADERS,
    });
  }

  const headers = new Headers(CORS_HEADERS);
  headers.set('Content-Type', upstream.headers.get('Content-Type') || 'image/jpeg');
  // Cache aggressively at Cloudflare's edge — MAL cover URLs are static
  // per anime, so there's no reason to re-fetch from MAL on every request
  // from every AniVerse user. This is the main thing a public proxy could
  // never do for you specifically: caching tuned to this app's own
  // traffic pattern instead of everyone else's.
  headers.set('Cache-Control', 'public, max-age=86400');

  return new Response(upstream.body, { status: 200, headers });
}

async function handleAniListProxy(request) {
  if (request.method !== 'POST') {
    return new Response('Only POST is supported for /anilist', {
      status: 405,
      headers: CORS_HEADERS,
    });
  }

  const body = await request.text();

  let upstream;
  try {
    upstream = await fetch('https://graphql.anilist.co', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body,
    });
  } catch (err) {
    // Surface the real failure instead of it turning into a mystery 403 —
    // if outbound fetch to AniList itself is being blocked at the
    // Cloudflare network layer (rather than by anything in this Worker's
    // own logic), this is where that would show up.
    return new Response(`Worker fetch to AniList failed: ${err.message || err}`, {
      status: 502,
      headers: CORS_HEADERS,
    });
  }

  const headers = new Headers(CORS_HEADERS);
  headers.set('Content-Type', upstream.headers.get('Content-Type') || 'application/json');

  return new Response(upstream.body, { status: upstream.status, headers });
}
