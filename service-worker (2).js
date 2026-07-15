const CACHE_NAME = 'registre-asbl-cache-v1';
const PRECACHE_URLS = ['manifest.json'];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(PRECACHE_URLS)));
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k))))
  );
  self.clients.claim();
});

// Le fichier principal (index.html) n'est JAMAIS mis en cache : chaque mise à jour du code
// s'affiche donc immédiatement après un redéploiement, sans manipulation supplémentaire.
self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  const isMainDocument = event.request.mode === 'navigate' || url.pathname.endsWith('/') || url.pathname.endsWith('index.html');

  if (isMainDocument) {
    event.respondWith(fetch(event.request).catch(() => caches.match(event.request)));
    return;
  }

  event.respondWith(
    fetch(event.request)
      .then((response) => {
        const clone = response.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
        return response;
      })
      .catch(() => caches.match(event.request))
  );
});
