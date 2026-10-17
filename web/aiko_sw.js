// Aiko's service worker: after one online visit the web app opens, reloads
// and starts without a network connection. index.html registers it.
//
// Caches
// - aiko-precache-<version>: the files of one build (app shell, bundled
//   assets), listed with their SHA-256 by tool/web_precache.mjs and checked
//   on install. Files unchanged since the previous build are copied over
//   instead of downloaded again.
// - aiko-cdn: versioned files from Google's CDN (CanvasKit, the Firebase JS
//   SDK) and fallback fonts, cached the first time the app loads them.
// - aiko-runtime: other files from this site fetched while online (such as a
//   locally served CanvasKit), so they work offline too.
//
// Strategies
// - Navigations and files Hosting serves `no-cache` (everything outside
//   assets/assets/): network first; the cached copy when offline or when the
//   network takes longer than NETWORK_TIMEOUT_MS.
// - assets/assets/** (served with max-age): from the cache, refreshed in the
//   background when they aren't part of the build's precache.
// - CDN files: cache first; only successful CORS responses are stored.
// - Everything else is left to the browser: other hosts (Firebase and other
//   APIs), non-GET requests, range requests and Hosting's /__/ URLs.
//
// Updates: a new build changes the manifest below and so this file; the
// browser installs the new worker, which takes over right away and deletes
// the previous build's cache. Running tabs keep working: they load files
// network first, and nothing reloads them.
'use strict';

// tool/web_precache.mjs replaces `null` with the build's manifest:
// {version, engineRevision, firebaseSdkVersion, files: {path: sha256}}.
// Without one (development, or a build that skipped the script) the worker
// removes itself and its caches, so the app behaves as if it had none.
const PRECACHE = /* @aiko-precache */ null;

const CACHE_PREFIX = 'aiko-';
const PRECACHE_CACHE = PRECACHE && `${CACHE_PREFIX}precache-${PRECACHE.version}`;
const CDN_CACHE = `${CACHE_PREFIX}cdn`;
const RUNTIME_CACHE = `${CACHE_PREFIX}runtime`;
// Caches of Flutter's retired service worker, from builds before this one.
const LEGACY_CACHES = ['flutter-app-cache', 'flutter-temp-cache', 'flutter-app-manifest'];
// Where the precache keeps its file list, to reuse unchanged files later.
const MANIFEST_KEY = 'https://aiko.invalid/precache-manifest';

const NETWORK_TIMEOUT_MS = 3000;
// After a failed or timed-out request, use cached copies right away for a
// while instead of waiting for every file in turn on a dead connection.
const OFFLINE_HINT_MS = 10000;
const INSTALL_CONCURRENCY = 4;
const MAX_FONT_ENTRIES = 80;
const MAX_RUNTIME_ENTRIES = 40;
const MATCH = { ignoreVary: true };

const SCOPE = new URL(self.registration.scope);
const PRECACHE_URLS = new Set(
  PRECACHE ? Object.keys(PRECACHE.files).map((path) => new URL(path, SCOPE).href) : [],
);
// Versioned CDN files: https://www.gstatic.com/<kind>/<version>/<file>.
const CDN_VERSIONED = /^https:\/\/www\.gstatic\.com\/(flutter-canvaskit|firebasejs)\/([^/?#]+)\/([^?#]+)$/;

let offlineUntil = 0;

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      if (PRECACHE) {
        await precacheBuild();
        // Best effort: an offline start right after this update finds the
        // CDN files of the new build too.
        await Promise.all([prefetchCdnUpdates(), refreshRuntime()]);
      }
      await self.skipWaiting();
    })(),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      if (!PRECACHE) {
        await deleteCaches((name) => name.startsWith(CACHE_PREFIX) || LEGACY_CACHES.includes(name));
        await self.registration.unregister();
        return;
      }
      const keep = [PRECACHE_CACHE, CDN_CACHE, RUNTIME_CACHE];
      await deleteCaches(
        (name) => (name.startsWith(CACHE_PREFIX) && !keep.includes(name)) || LEGACY_CACHES.includes(name),
      );
      await pruneCdn();
      if (self.registration.navigationPreload) {
        await self.registration.navigationPreload.enable().catch(() => {});
      }
      await self.clients.claim();
    })(),
  );
});

self.addEventListener('fetch', (event) => {
  switch (routeFor(event.request)) {
    case 'navigate':
      event.respondWith(handleNavigation(event));
      break;
    case 'network-first':
      event.respondWith(handleNetworkFirst(event));
      break;
    case 'stale-while-revalidate':
      event.respondWith(handleStaleWhileRevalidate(event));
      break;
    case 'cdn':
      event.respondWith(handleCdn(event));
      break;
  }
});

// The page lists the files it loaded before this worker controlled it (the
// first visit), so they are cached as well.
self.addEventListener('message', (event) => {
  const data = event.data;
  if (!PRECACHE || !data || data.type !== 'aiko-cache-urls' || !Array.isArray(data.urls)) return;
  event.waitUntil(cacheLoadedUrls(data.urls.slice(0, 300)));
});

/**
 * How the worker answers [request]: 'navigate', 'network-first',
 * 'stale-while-revalidate', 'cdn', or null to leave it to the browser.
 */
function routeFor(request) {
  if (!PRECACHE || request.method !== 'GET' || request.headers.has('range')) return null;
  // Chrome DevTools can issue these; answering them throws.
  if (request.cache === 'only-if-cached' && request.mode !== 'same-origin') return null;
  let url;
  try {
    url = new URL(request.url);
  } catch (_) {
    return null;
  }
  if (url.origin !== SCOPE.origin) return isCdnUrl(url) ? 'cdn' : null;
  // Firebase Hosting's reserved URLs (Auth handler, SDK config) stay live.
  if (!url.pathname.startsWith(SCOPE.pathname) || url.pathname.startsWith('/__/')) return null;
  if (request.mode === 'navigate') return 'navigate';
  const path = url.pathname.slice(SCOPE.pathname.length);
  return path.startsWith('assets/assets/') ? 'stale-while-revalidate' : 'network-first';
}

function isCdnUrl(url) {
  return url.protocol === 'https:' && (url.hostname === 'fonts.gstatic.com' || CDN_VERSIONED.test(url.href));
}

async function handleNavigation(event) {
  const preload = event.preloadResponse;
  if (preload) extend(event, Promise.resolve(preload).catch(() => {}));
  const network = Promise.resolve(preload)
    .catch(() => undefined)
    .then((response) => response || fetch(event.request));
  // Every route is the single-page app, so any navigation can fall back to it.
  return networkFirst(network, () => matchPrecache(new URL('index.html', SCOPE).href));
}

function handleNetworkFirst(event) {
  const url = event.request.url;
  const network = fetch(event.request).then((response) => {
    if (!precacheKey(url) && isCacheableSameOrigin(response)) {
      extend(event, putRuntime(url, response.clone()));
    }
    return response;
  });
  return networkFirst(network, () => matchCached(url));
}

async function handleStaleWhileRevalidate(event) {
  const url = event.request.url;
  // Precached files change only with a new build, which brings a new cache.
  const precached = await matchPrecache(url);
  if (precached) return precached;
  const cached = await (await caches.open(RUNTIME_CACHE)).match(url, MATCH);
  const network = fetch(event.request).then(async (response) => {
    if (isCacheableSameOrigin(response)) await putRuntime(url, response.clone());
    return response;
  });
  if (!cached) return network;
  extend(event, network.catch(() => {}));
  return cached;
}

async function handleCdn(event) {
  const url = event.request.url;
  const cache = await caches.open(CDN_CACHE);
  const cached = await cache.match(url, MATCH);
  if (cached) return cached;
  let response;
  try {
    // A CORS request even for <script>/<img> loads, which would otherwise
    // give an opaque response that can't be checked and wastes quota.
    response = await fetch(url, { mode: 'cors', credentials: 'omit' });
  } catch (_) {
    // Offline, or the host doesn't allow CORS: the page's own request decides.
    return fetch(event.request);
  }
  if (isCacheableCors(response)) extend(event, putCdn(cache, url, response.clone()));
  return response;
}

/**
 * Resolves with the network response, unless it fails or takes longer than
 * NETWORK_TIMEOUT_MS and [fallback] finds a cached copy. Without a cached
 * copy it waits for the network.
 */
async function networkFirst(network, fallback) {
  const wait = Date.now() < offlineUntil ? 0 : NETWORK_TIMEOUT_MS;
  const outcome = await settleWithin(network, wait);
  if (outcome.response) {
    offlineUntil = 0;
    return outcome.response;
  }
  network.then(
    () => (offlineUntil = 0),
    () => {},
  );
  const cached = await fallback();
  if (cached) {
    if (wait > 0) offlineUntil = Date.now() + OFFLINE_HINT_MS;
    return cached;
  }
  return network;
}

function settleWithin(promise, ms) {
  return new Promise((resolve) => {
    const timer = setTimeout(() => resolve({ timedOut: true }), ms);
    promise.then(
      (response) => {
        clearTimeout(timer);
        resolve({ response });
      },
      (error) => {
        clearTimeout(timer);
        resolve({ error });
      },
    );
  });
}

async function precacheBuild() {
  const cache = await caches.open(PRECACHE_CACHE);
  const previous = await previousPrecaches();
  await forEachLimit(Object.entries(PRECACHE.files), INSTALL_CONCURRENCY, async ([path, hash]) => {
    const url = new URL(path, SCOPE).href;
    // Entries are stored only once verified, so a retried install keeps them.
    if (await cache.match(url, MATCH)) return;
    for (const old of previous) {
      if (old.files[path] !== hash) continue;
      const response = await old.cache.match(url, MATCH);
      if (response) return cache.put(url, response);
    }
    return cache.put(url, await fetchVerified(url, hash));
  });
  await cache.put(MANIFEST_KEY, new Response(JSON.stringify(PRECACHE.files)));
}

/** Earlier builds' precaches with their file lists, newest first. */
async function previousPrecaches() {
  const result = [];
  const names = (await caches.keys()).filter(
    (name) => name.startsWith(`${CACHE_PREFIX}precache-`) && name !== PRECACHE_CACHE,
  );
  for (const name of names.reverse()) {
    const cache = await caches.open(name);
    const manifest = await cache.match(MANIFEST_KEY);
    if (!manifest) continue;
    try {
      result.push({ cache, files: await manifest.json() });
    } catch (_) {
      // An unreadable list only means downloading those files again.
    }
  }
  return result;
}

/**
 * Downloads a build file and checks it against the manifest, so a deploy that
 * lands mid-install can't mix two builds in one cache: the install fails and
 * the newer worker takes over.
 */
async function fetchVerified(url, hash) {
  for (const cacheMode of ['no-cache', 'reload']) {
    const response = await fetch(url, { cache: cacheMode, credentials: 'same-origin' });
    if (!response.ok) throw new Error(`Precache ${url}: HTTP ${response.status}`);
    const body = await response.arrayBuffer();
    if ((await sha256Hex(body)) === hash) {
      return new Response(body, {
        status: response.status,
        statusText: response.statusText,
        headers: response.headers,
      });
    }
  }
  throw new Error(`Precache ${url}: content differs from this build`);
}

/**
 * Fetches the new build's CanvasKit and Firebase SDK files for every variant
 * this browser cached of the previous versions (the CDN URL names the
 * version; which files a browser loads depends on the browser).
 */
async function prefetchCdnUpdates() {
  try {
    const cache = await caches.open(CDN_CACHE);
    const wanted = new Set();
    for (const request of await cache.keys()) {
      const match = CDN_VERSIONED.exec(request.url);
      if (!match) continue;
      const [, kind, version, file] = match;
      const current = currentCdnVersion(kind);
      if (current && current !== version) wanted.add(`https://www.gstatic.com/${kind}/${current}/${file}`);
    }
    for (const url of wanted) {
      if (!(await cache.match(url, MATCH))) await cacheCdnUrl(cache, url).catch(() => {});
    }
  } catch (_) {
    // Loaded on the next online start instead.
  }
}

/** Refreshes runtime-cached files from this site to the new build's copies. */
async function refreshRuntime() {
  try {
    const cache = await caches.open(RUNTIME_CACHE);
    for (const request of await cache.keys()) {
      if (precacheKey(request.url)) {
        await cache.delete(request);
        continue;
      }
      try {
        const response = await fetch(request.url, { cache: 'no-cache', credentials: 'same-origin' });
        if (isCacheableSameOrigin(response)) await cache.put(request.url, response);
      } catch (_) {
        // Keep the copy we have.
      }
    }
  } catch (_) {
    // Nothing to refresh.
  }
}

/** Drops CDN files of versions this build no longer uses and old fonts. */
async function pruneCdn() {
  const cache = await caches.open(CDN_CACHE);
  const fonts = [];
  for (const request of await cache.keys()) {
    const match = CDN_VERSIONED.exec(request.url);
    if (match) {
      const current = currentCdnVersion(match[1]);
      if (current && match[2] !== current) await cache.delete(request);
    } else {
      fonts.push(request);
    }
  }
  await deleteOldest(cache, fonts, MAX_FONT_ENTRIES);
}

function currentCdnVersion(kind) {
  return kind === 'flutter-canvaskit' ? PRECACHE.engineRevision : PRECACHE.firebaseSdkVersion;
}

async function cacheLoadedUrls(urls) {
  const cdn = await caches.open(CDN_CACHE);
  const runtime = await caches.open(RUNTIME_CACHE);
  for (const href of new Set(urls)) {
    try {
      const route = typeof href === 'string' ? routeFor(new Request(href)) : null;
      if (route === 'cdn') {
        if (!(await cdn.match(href, MATCH))) await cacheCdnUrl(cdn, href);
      } else if (route && !precacheKey(href) && !(await runtime.match(href, MATCH))) {
        const response = await fetch(href, { credentials: 'same-origin' });
        if (isCacheableSameOrigin(response)) await putRuntime(href, response);
      }
    } catch (_) {
      // Best effort: the file is cached the next time the page loads it.
    }
  }
}

async function cacheCdnUrl(cache, url) {
  const response = await fetch(url, { mode: 'cors', credentials: 'omit' });
  if (isCacheableCors(response)) await putCdn(cache, url, response);
}

async function putCdn(cache, url, response) {
  await cache.put(url, response);
  if (new URL(url).hostname !== 'fonts.gstatic.com') return;
  const fonts = (await cache.keys()).filter((request) => !CDN_VERSIONED.test(request.url));
  await deleteOldest(cache, fonts, MAX_FONT_ENTRIES);
}

async function putRuntime(url, response) {
  const cache = await caches.open(RUNTIME_CACHE);
  await cache.put(url, response);
  await deleteOldest(cache, await cache.keys(), MAX_RUNTIME_ENTRIES);
}

/** Deletes the oldest of [requests] (in insertion order) beyond [max]. */
async function deleteOldest(cache, requests, max) {
  for (const request of requests.slice(0, Math.max(0, requests.length - max))) {
    await cache.delete(request);
  }
}

async function matchCached(url) {
  return (await matchPrecache(url)) || (await (await caches.open(RUNTIME_CACHE)).match(url, MATCH));
}

async function matchPrecache(url) {
  const key = precacheKey(url);
  return key ? (await caches.open(PRECACHE_CACHE)).match(key, MATCH) : undefined;
}

/** The precache URL for [href] (ignoring query and fragment), or null. */
function precacheKey(href) {
  const url = new URL(href);
  url.search = '';
  url.hash = '';
  return PRECACHE_URLS.has(url.href) ? url.href : null;
}

function isCacheableSameOrigin(response) {
  return response.status === 200 && response.type === 'basic';
}

function isCacheableCors(response) {
  return response.status === 200 && response.type === 'cors';
}

async function deleteCaches(test) {
  await Promise.all((await caches.keys()).filter(test).map((name) => caches.delete(name)));
}

/** Keeps the worker alive for [promise] when the event still allows it. */
function extend(event, promise) {
  try {
    event.waitUntil(promise);
  } catch (_) {
    // The event already finished; the work continues while the worker lives.
  }
}

async function sha256Hex(buffer) {
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', buffer));
  return Array.from(digest, (byte) => byte.toString(16).padStart(2, '0')).join('');
}

async function forEachLimit(items, limit, task) {
  let next = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (next < items.length) await task(items[next++]);
  });
  await Promise.all(workers);
}
