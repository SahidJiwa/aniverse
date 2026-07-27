const cheerio = require('cheerio');

const GOGO_DOMAINS = [
  'https://gogoanime.gg',
  'https://gogoanime.lu',
  'https://gogoanime.sx',
  'https://gogoanime.pe',
  'https://gogoanime.fi',
  'https://gogoanime.vc',
];
const AJAX_CDN = 'https://ajax.gogo-cdn.com';
const AJAX_ALT = 'https://gogo-cdn.com';
const TIMEOUT = 15000;

async function fetchText(url) {
  try {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), TIMEOUT);
    const res = await fetch(url, {
      signal: ctrl.signal,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      },
    });
    clearTimeout(timer);
    if (!res.ok) return null;
    return await res.text();
  } catch {
    return null;
  }
}

async function fetchJSON(url) {
  try {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), TIMEOUT);
    const res = await fetch(url, {
      signal: ctrl.signal,
      headers: { 'User-Agent': 'Mozilla/5.0', 'Accept': 'application/json' },
    });
    clearTimeout(timer);
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}

async function search(query) {
  for (const domain of GOGO_DOMAINS) {
    const html = await fetchText(`${domain}/search.html?keyword=${encodeURIComponent(query)}`);
    if (!html) continue;
    const $ = cheerio.load(html);
    const results = [];
    $('.items li, .last_episodes ul.items li, .listing li').each((i, el) => {
      const link = $(el).find('a').first();
      const img = $(el).find('img').first();
      const href = link.attr('href') || '';
      const title = link.attr('title') || link.text().trim();
      if (!href.includes('/category/')) return;
      const id = href.split('/category/')[1]?.split('/')[0] || href.replace('/category/', '');
      const image = img.attr('src') || img.attr('data-src') || null;
      results.push({ id, title, image, url: null });
    });
    if (results.length > 0) return { results };
  }
  return { results: [] };
}

async function info(id) {
  for (const domain of GOGO_DOMAINS) {
    const html = await fetchText(`${domain}/category/${id}`);
    if (!html) continue;
    const $ = cheerio.load(html);
    const idMatch = html.match(/var\s+id\s*=\s*['"]([^'"]+)['"]/);
    if (!idMatch) continue;
    const dataId = idMatch[1];
    let json = await fetchJSON(`${AJAX_CDN}/ajax/load-list-episodes?ep_start=0&ep_end=9999&id=${dataId}`);
    if (!json) json = await fetchJSON(`${AJAX_ALT}/ajax/load-list-episodes?ep_start=0&ep_end=9999&id=${dataId}`);
    if (!json || !json.html) continue;
    const $ep = cheerio.load(json.html);
    const thumbMap = {};
    $('a[href*="' + id + '-episode-"]').each((i, el) => {
      const href = $(el).attr('href') || '';
      const epMatch = href.match(new RegExp(id + '-episode-(\\d+)'));
      const img = $(el).find('img').attr('src');
      if (epMatch && img) thumbMap[parseInt(epMatch[1])] = img;
    });
    const episodes = [];
    $ep('a').each((i, el) => {
      const href = $ep(el).attr('href') || '';
      const numStr = $ep(el).text().trim();
      if (!href.startsWith('/') || !numStr) return;
      const num = parseInt(numStr.replace(/[^0-9]/g, ''));
      if (isNaN(num)) return;
      episodes.push({
        id: href.replace(/^\//, ''),
        number: num,
        title: `Episode ${num}`,
        image: thumbMap[num] || null,
      });
    });
    if (episodes.length > 0) return { episodes };
  }
  return { episodes: [] };
}

async function watch(episodeId) {
  for (const domain of GOGO_DOMAINS) {
    const html = await fetchText(`${domain}/${episodeId}`);
    if (!html) continue;
    const dataIdMatch = html.match(/data-id\s*=\s*['"]([^'"]+)['"]/);
    if (!dataIdMatch) continue;
    const dataId = dataIdMatch[1];
    let data = await fetchJSON(`${AJAX_CDN}/ajax/get-video-sources/${dataId}`);
    if (!data) data = await fetchJSON(`${AJAX_ALT}/ajax/get-video-sources/${dataId}`);
    if (!data || !data.sources || !Array.isArray(data.sources)) continue;
    if ((data.sourceType || '').includes('encrypt')) continue;
    const sources = data.sources.filter(s => s.url).map(s => ({
      url: s.url,
      quality: s.quality || 'default',
    }));
    if (sources.length > 0) return { sources };
  }
  return { sources: [] };
}

async function debug() {
  const targets = {
    'Gogoanime.gg': 'https://gogoanime.gg',
    'Gogoanime.sx': 'https://gogoanime.sx',
    'Gogoanime.pe': 'https://gogoanime.pe',
    'AniPub.xyz': 'https://api.anipub.xyz',
    'AniPub search': 'https://api.anipub.xyz/search/naruto',
  };
  const out = [];
  for (const [label, base] of Object.entries(targets)) {
    try {
      const ctrl = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), 10000);
      const res = await fetch(base, {
        signal: ctrl.signal,
        headers: { 'User-Agent': 'Mozilla/5.0' },
      });
      clearTimeout(timer);
      const text = await res.text();
      out.push({ label, status: res.status, len: text.length, preview: text.slice(0, 150) });
    } catch (e) {
      out.push({ label, error: e.message || 'timeout' });
    }
  }
  return out;
}

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', '*');
  if (req.method === 'OPTIONS') return res.status(200).end();
  const path = req.url.split('?')[0].replace(/\/+$/, '');
  const parts = path.split('/').filter(Boolean);
  try {
    let result;
    if (parts[2] === 'debug') result = await debug();
    else if (parts.length >= 3 && parts[2] === 'info') result = await info(parts[3]);
    else if (parts.length >= 3 && parts[2] === 'watch') result = await watch(parts[3]);
    else if (parts.length >= 3) result = await search(parts[2]);
    else result = { docs: 'https://consumet.org' };
    res.json(result);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
};
