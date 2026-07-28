const CACHE_NAME = 'aniverse-admin-v1';
const urlsToCache = [
  './index.html',
  './style.css',
  './app.js',
  './manifest.json',
  './catalog_cloud.json'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(urlsToCache))
  );
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', event => {
  event.respondWith(
    fetch(event.request).catch(() => caches.match(event.request))
  );
});
