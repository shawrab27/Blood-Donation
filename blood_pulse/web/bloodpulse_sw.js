// BloodPulse Service Worker — App Shell Cache Only
// Version bumped on each deploy to bust the cache.
const CACHE_VERSION = 'bloodpulse-shell-v1';

// App-shell assets to pre-cache (Flutter's built output files)
const SHELL_ASSETS = [
  './',
  './index.html',
  './manifest.json',
  './favicon.png',
  './icons/Icon-192.png',
  './icons/Icon-512.png',
  './icons/Icon-maskable-192.png',
  './icons/Icon-maskable-512.png',
  // Flutter build outputs (will exist after `flutter build web`)
  './main.dart.js',
  './flutter.js',
  './flutter_bootstrap.js',
  './assets/FontManifest.json',
  './assets/AssetManifest.json',
];

// API prefixes that MUST NEVER be cached by the service worker.
// Cache invalidation for API is handled by the app (Riverpod providers + SharedPreferences).
const NO_CACHE_PREFIXES = [
  '/api/',
  'cloudinary.com',
  'res.cloudinary.com',
];

function isApiRequest(url) {
  return NO_CACHE_PREFIXES.some((prefix) => url.includes(prefix));
}

// ---------- Install: pre-cache shell ----------
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_VERSION).then((cache) => {
      // Use individual adds so one missing file doesn't abort the whole install.
      return Promise.allSettled(
        SHELL_ASSETS.map((asset) => cache.add(asset).catch((e) => {
          console.warn('[SW] Pre-cache miss:', asset, e.message);
        }))
      );
    }).then(() => self.skipWaiting())
  );
});

// ---------- Activate: delete old caches ----------
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key !== CACHE_VERSION)
          .map((key) => caches.delete(key))
      )
    ).then(() => self.clients.claim())
  );
});

// ---------- Fetch: network-first for API, cache-first for shell ----------
self.addEventListener('fetch', (event) => {
  const url = event.request.url;

  // Never intercept non-GET or API calls
  if (event.request.method !== 'GET' || isApiRequest(url)) {
    return; // fall through to network
  }

  // For navigation requests (HTML): network-first, fall back to cached index.html
  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request).catch(() =>
        caches.match('./index.html').then((cached) => {
          if (cached) return cached;
          // Last resort: show offline page message embedded in a minimal HTML
          return new Response(
            `<!DOCTYPE html><html><head><meta charset="utf-8"><title>BloodPulse – Offline</title></head>
             <body style="font-family:sans-serif;background:#FDF3F3;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;flex-direction:column;">
             <div style="font-size:48px">🩸</div>
             <h1 style="color:#C30121;font-family:Georgia,serif">You're offline</h1>
             <p style="color:#555">Please check your connection and try again.</p>
             <button onclick="location.reload()" style="padding:12px 28px;background:#C30121;color:#fff;border:none;border-radius:50px;cursor:pointer;font-size:15px">Retry</button>
             </body></html>`,
            { headers: { 'Content-Type': 'text/html' } }
          );
        })
      )
    );
    return;
  }

  // For shell assets: cache-first, update in background
  event.respondWith(
    caches.match(event.request).then((cached) => {
      const fetchPromise = fetch(event.request).then((response) => {
        // Only cache same-origin successful responses
        if (response && response.status === 200 && response.type === 'basic') {
          const clone = response.clone();
          caches.open(CACHE_VERSION).then((cache) => cache.put(event.request, clone));
        }
        return response;
      }).catch(() => cached); // network failed — use cache

      return cached || fetchPromise;
    })
  );
});
