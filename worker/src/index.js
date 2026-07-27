const GOGO_DOMAINS = [
  'https://gogoanime.gg',
  'https://gogoanime.lu',
  'https://gogoanime.sx',
  'https://gogoanime.pe',
];
const HI_ANIME = 'https://hianime.to';
const AJAX_CDN = 'https://ajax.gogo-cdn.com';
const AJAX_ALT = 'https://gogo-cdn.com';

async function fetchText(url) {
  try {
    const res = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
      },
    });
    if (!res.ok) return null;
    return await res.text();
  } catch (e) {
    return null;
  }
}

async function fetchJSON(url) {
  try {
    const res = await fetch(url, {
      headers: { 'User-Agent': 'Mozilla/5.0', 'Accept': 'application/json' },
    });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}

function extractAll(html, pattern) {
  const regex = new RegExp(pattern, 'gi');
  const results = [];
  let m;
  while ((m = regex.exec(html)) !== null) {
    for (let i = 1; i < m.length; i++) {
      results.push(m[i]);
    }
  }
  return results;
}

async function search(query) {
  for (const domain of GOGO_DOMAINS) {
    const html = await fetchText(`${domain}/search.html?keyword=${encodeURIComponent(query)}`);
    if (!html) continue;
    const links = extractAll(html, `<a\\s+href\\s*=\\s*"([^"]*)"\\s+title\\s*=\\s*"([^"]*)"`);
    const results = [];
    for (let i = 0; i + 1 < links.length; i += 2) {
      const href = links[i];
      const title = links[i + 1];
      if (!href.startsWith('/category/')) continue;
      const id = href.replace('/category/', '');
      const imgMatch = new RegExp(`<img\\s+src\\s*=\\s*"([^"]*)"[^>]*>\\s*<a\\s+href\\s*=\\s*"/category/${escapeRegex(id)}"`).exec(html);
      const image = imgMatch ? imgMatch[1] : null;
      results.push({ id, title, image, url: null });
    }
    if (results.length > 0) return { results };
  }
  return { results: [] };
}

function escapeRegex(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

async function info(id) {
  for (const domain of GOGO_DOMAINS) {
    const html = await fetchText(`${domain}/category/${id}`);
    if (!html) continue;
    const idMatch = new RegExp(
      `var\\s+ep_start\\s*=\\s*\\d+;\\s*var\\s+ep_end\\s*=\\s*\\d+;\\s*var\\s+id\\s*=\\s*['"]([^'"]+)['"]`,
    ).exec(html);
    if (!idMatch) continue;
    const dataId = idMatch[1];
    let json = await fetchJSON(`${AJAX_CDN}/ajax/load-list-episodes?ep_start=0&ep_end=9999&id=${dataId}`);
    if (!json) json = await fetchJSON(`${AJAX_ALT}/ajax/load-list-episodes?ep_start=0&ep_end=9999&id=${dataId}`);
    if (!json) continue;
    const epHtml = json.html;
    if (!epHtml) continue;
    const epImages = extractAll(
      html,
      `<a\\s+href\\s*=\\s*"/${escapeRegex(id)}-episode-(\\d+)"[^>]*>\\s*<img\\s+src\\s*=\\s*"([^"]*)"`,
    );
    const thumbMap = {};
    for (let i = 0; i + 1 < epImages.length; i += 2) {
      thumbMap[parseInt(epImages[i])] = epImages[i + 1];
    }
    const epLinks = extractAll(epHtml, `href\\s*=\\s*"([^"]*)"[^>]*>\\s*([^<]+)`);
    const episodes = [];
    for (let i = 0; i + 1 < epLinks.length; i += 2) {
      const href = epLinks[i].trim();
      const numStr = epLinks[i + 1].trim();
      if (!href.startsWith('/')) continue;
      const num = parseInt(numStr.replace(/[^0-9]/g, ''));
      if (isNaN(num)) continue;
      episodes.push({
        id: href.replace(/^\//, ''),
        number: num,
        title: `Episode ${num}`,
        image: thumbMap[num] || null,
      });
    }
    if (episodes.length > 0) return { episodes };
  }
  return { episodes: [] };
}

async function watch(episodeId) {
  for (const domain of GOGO_DOMAINS) {
    const html = await fetchText(`${domain}/${episodeId}`);
    if (!html) continue;
    const dataIdMatch = new RegExp(`data-id\\s*=\\s*['"]([^'"]+)['"]`).exec(html);
    if (!dataIdMatch) continue;
    const dataId = dataIdMatch[1];
    let data = await fetchJSON(`${AJAX_CDN}/ajax/get-video-sources/${dataId}`);
    if (!data) data = await fetchJSON(`${AJAX_ALT}/ajax/get-video-sources/${dataId}`);
    if (!data) continue;
    const sourceType = (data.sourceType || '').toString();
    const sources = data.sources || [];
    if (sourceType.includes('encrypt')) continue;
    if (!Array.isArray(sources)) continue;
    const mapped = sources.map(s => ({
      url: s.url,
      quality: s.quality || 'default',
    }));
    if (mapped.length > 0) return { sources: mapped };
  }
  return { sources: [] };
}

async function debugFetch(targetUrl) {
  const results = [];
  for (const domain of GOGO_DOMAINS) {
    const url = targetUrl.replace('{domain}', domain);
    try {
      const res = await fetch(url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      });
      const text = await res.text();
      results.push({
        domain,
        status: res.status,
        statusText: res.statusText,
        length: text.length,
        preview: text.substring(0, 500),
      });
    } catch (e) {
      results.push({ domain, error: e.message });
    }
  }
  return results;
}

async function checkConsumet() {
  const instances = [
    'https://api.consumet.org/anime/gogoanime/naruto',
    'https://consumet-phi.vercel.app/anime/gogoanime/naruto',
    'https://consumet-xi.vercel.app/anime/gogoanime/naruto',
    'https://animxer-api.vercel.app/anime/gogoanime/naruto',
    'https://api-anime-rouge.vercel.app/gogoanime/naruto',
  ];
  const results = [];
  for (const url of instances) {
    try {
      const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
      const text = await res.text();
      results.push({ url, status: res.status, length: text.length, preview: text.substring(0, 300) });
    } catch (e) {
      results.push({ url, error: e.message });
    }
  }
  return results;
}

const ROUTES = [
  { pattern: /^\/debug\/consumet\/?$/i, handler: () => checkConsumet() },
  { pattern: /^\/debug\/test\/?$/i, handler: () => fetch('https://httpbin.org/ip').then(r => r.json()) },
  { pattern: /^\/debug\/hianime\/?$/i, handler: async () => {
    const urls = [HI_ANIME, HI_ANIME + '/search?keyword=naruto', 'https://hianimez.to'];
    const out = [];
    for (const url of urls) {
      try {
        const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
        const text = await res.text();
        out.push({ url, status: res.status, length: text.length, preview: text.substring(0, 200) });
      } catch (e) { out.push({ url, error: e.message }); }
    }
    return out;
  } },
  { pattern: /^\/debug\/?$/i, handler: () => debugFetch('{domain}/search.html?keyword=naruto') },
  { pattern: /^\/debug\/(.+)/i, handler: ([, slug]) => debugFetch('{domain}/category/' + slug) },
  { pattern: /^\/anime\/gogoanime\/info\/(.+)/i, handler: ([, id]) => info(id) },
  { pattern: /^\/anime\/gogoanime\/watch\/(.+)/i, handler: ([, id]) => watch(id) },
  { pattern: /^\/anime\/gogoanime\/(.+)/i, handler: ([, query]) => search(query) },
  { pattern: /^\/anime\/gogoanime\/?$/i, handler: () => new Response(JSON.stringify({ docs: 'https://consumet.org' }), { headers: { 'content-type': 'application/json' } }) },
];

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': '*',
    };
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }
    for (const route of ROUTES) {
      const match = path.match(route.pattern);
      if (match) {
        try {
          const result = await route.handler(match);
          const body = JSON.stringify(result);
          return new Response(body, {
            headers: { ...corsHeaders, 'content-type': 'application/json' },
          });
        } catch (e) {
          return new Response(JSON.stringify({ error: e.message }), {
            status: 500,
            headers: { ...corsHeaders, 'content-type': 'application/json' },
          });
        }
      }
    }
    return new Response('Not Found', { status: 404, headers: corsHeaders });
  },
};
