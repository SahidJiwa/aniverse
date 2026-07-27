// AniVerse video-stream proxy — Cloudflare Worker
// ─────────────────────────────────────────────────────────────────────────
// WHY THIS EXISTS
// The app's scraping providers (gogoanime, zoro, hianime, shirayuki) return
// video URLs that point DIRECTLY at their own CDN (e.g. gogo-cdn.com). Those
// CDN domains are commonly blocked by Indonesian ISPs, so playback fails on
// networks that block them — even though the app's own metadata calls (via
// this same worker, or Vercel-hosted Consumet mirrors) succeed, since those
// look like generic API domains and aren't blocked.
//
// This worker re-fetches the actual video bytes server-side (Cloudflare's
// network is essentially never ISP-blocked) and streams them back to the
// browser under THIS worker's own domain. For HLS (.m3u8) sources, it also
// rewrites every segment URL inside the playlist to route through this same
// worker — otherwise the master playlist loads fine but every individual
// .ts segment still points at the blocked CDN and playback stalls.
//
// DEPLOY
//   cd worker && npx wrangler deploy
//
// USAGE (called from streaming_service.dart, not directly by users)
//   https://<your-worker>.workers.dev/stream?url=<url-encoded original video URL>
// ─────────────────────────────────────────────────────────────────────────

// Upstream CDN hostnames this worker is allowed to fetch from. This is an
// allowlist, not a blocklist — any host NOT listed here is rejected with
// 403, so the worker can't be abused as a general-purpose open proxy for
// arbitrary URLs (which would rack up bandwidth cost and could get the
// worker flagged/suspended by Cloudflare).
//
// Add a new hostname here whenever a scraping provider starts returning
// video URLs from a domain not yet listed — the 403 response body will
// tell you exactly which host was rejected so you know what to add.
const ALLOWED_HOSTS = [
  'gogo-cdn.com',
  'ajax.gogo-cdn.com',
  'gogoanime.gg',
  'gogoanime.lu',
  'gogoanime.sx',
  'gogoanime.pe',
  // HiAnime / Zoro / Consumet-family CDNs commonly seen in the wild.
  // Uncomment / add more as you discover them from 403 rejections.
  'rapid-cloud.co',
  'megacloud.tv',
  'vidstreaming.io',
  'streamtape.com',
];

function isAllowedHost(hostname) {
  return ALLOWED_HOSTS.some(
    (h) => hostname === h || hostname.endsWith('.' + h)
  );
}

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
    'Access-Control-Allow-Headers': 'Range, Content-Type',
    'Access-Control-Expose-Headers':
      'Content-Length, Content-Range, Accept-Ranges',
  };
}

function jsonError(message, status) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders() },
  });
}

function proxyUrlFor(workerOrigin, absoluteTargetUrl) {
  return (
    `${workerOrigin}/stream?url=` + encodeURIComponent(absoluteTargetUrl)
  );
}

/// Rewrites an HLS (.m3u8) playlist's segment/sub-playlist references so
/// every URI inside — relative or absolute — routes back through this
/// worker, keeping the ISP-blocked CDN entirely out of the browser's
/// network requests from here on.
function rewriteM3u8(playlistText, baseUrl, workerOrigin) {
  const lines = playlistText.split('\n');
  const rewritten = lines.map((line) => {
    const trimmed = line.trim();
    // Leave blank lines and playlist tags (#EXTM3U, #EXT-X-...) alone,
    // EXCEPT tags that themselves embed a URI attribute (e.g. key/media
    // references), which some HLS streams use for AES-128 decryption
    // keys or alternate audio tracks.
    if (trimmed === '' ) return line;

    if (trimmed.startsWith('#')) {
      const uriMatch = trimmed.match(/URI="([^"]+)"/);
      if (!uriMatch) return line;
      const resolved = new URL(uriMatch[1], baseUrl).toString();
      const proxied = proxyUrlFor(workerOrigin, resolved);
      return line.replace(uriMatch[1], proxied);
    }

    // A bare line that isn't a comment/tag is a media segment or
    // sub-playlist URI (relative or absolute) — resolve then proxy it.
    const resolved = new URL(trimmed, baseUrl).toString();
    return proxyUrlFor(workerOrigin, resolved);
  });
  return rewritten.join('\n');
}

export default {
  async fetch(request) {
    const incomingUrl = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }

    if (incomingUrl.pathname !== '/stream') {
      return jsonError('Unknown path — use /stream?url=...', 404);
    }

    const target = incomingUrl.searchParams.get('url');
    if (!target) {
      return jsonError('Missing "url" query parameter', 400);
    }

    let targetUrl;
    try {
      targetUrl = new URL(target);
    } catch (e) {
      return jsonError('Invalid "url" parameter', 400);
    }

    if (!isAllowedHost(targetUrl.hostname)) {
      return jsonError(
        `Host not allowed: ${targetUrl.hostname}. Add it to ALLOWED_HOSTS in the worker if this is a legitimate video CDN.`,
        403
      );
    }

    const forwardHeaders = new Headers();
    const range = request.headers.get('Range');
    if (range) forwardHeaders.set('Range', range);
    // Several CDNs (gogo-cdn included) reject requests with no UA/Referer,
    // since they expect requests to originate from a real browser session
    // on their own site.
    forwardHeaders.set(
      'User-Agent',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    );
    forwardHeaders.set('Referer', targetUrl.origin + '/');

    let upstream;
    try {
      upstream = await fetch(targetUrl.toString(), {
        headers: forwardHeaders,
        cf: { cacheEverything: false },
      });
    } catch (e) {
      return jsonError('Upstream fetch failed: ' + e.message, 502);
    }

    const contentType = upstream.headers.get('Content-Type') || '';
    const looksLikeM3u8 =
      targetUrl.pathname.endsWith('.m3u8') ||
      contentType.includes('mpegurl') ||
      contentType.includes('vnd.apple.mpegurl');

    if (looksLikeM3u8) {
      // Playlists are small text files — safe to buffer, parse, and
      // rewrite in memory (unlike segments/full video files, which are
      // streamed through untouched below).
      const text = await upstream.text();
      const rewritten = rewriteM3u8(
        text,
        targetUrl.toString(),
        incomingUrl.origin
      );
      return new Response(rewritten, {
        status: upstream.status,
        headers: {
          'Content-Type': 'application/vnd.apple.mpegurl',
          ...corsHeaders(),
        },
      });
    }

    // Binary passthrough (segments, direct MP4, etc.) — stream the body
    // straight through without buffering, and preserve Content-Range /
    // Accept-Ranges so the player can still seek.
    const responseHeaders = new Headers(upstream.headers);
    for (const [k, v] of Object.entries(corsHeaders())) {
      responseHeaders.set(k, v);
    }
    responseHeaders.set('Cache-Control', 'public, max-age=3600');

    return new Response(upstream.body, {
      status: upstream.status,
      statusText: upstream.statusText,
      headers: responseHeaders,
    });
  },
};
