// Logic tests for the web service worker (web/aiko_sw.js): routing, precache
// install and update, cache strategies and cleanup. Run: npm run test:web
import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  dispatch,
  dispatchFetch,
  FakeCacheStorage,
  FakeNetwork,
  loadWorker,
  manifestFor,
  navigation,
  SCOPE,
  typed,
} from './sw_harness.mjs';

const BUILD = {
  'index.html': '<html>app v1</html>',
  'main.dart.js': 'main v1',
  'assets/assets/images/aiko/aiko_happy.png': 'png',
};
const CANVASKIT = 'https://www.gstatic.com/flutter-canvaskit/rev2/chromium/canvaskit.wasm';

function serve(network, files) {
  for (const [path, body] of Object.entries(files)) network.routes[SCOPE + path] = body;
}

async function installed(files = BUILD, extra) {
  const network = new FakeNetwork();
  serve(network, files);
  const worker = loadWorker({ manifest: manifestFor(files, extra), network });
  await dispatch(worker, 'install');
  await dispatch(worker, 'activate');
  return worker;
}

const text = async (response) => (response ? await response.text() : response);

test('routes app files and versioned Google CDN files, nothing else', () => {
  const { context } = loadWorker({ manifest: manifestFor(BUILD) });
  const route = (url, init) => context.routeFor(new Request(url, init));
  assert.equal(context.routeFor(navigation(`${SCOPE}?utm=1`)), 'navigate');
  assert.equal(route(`${SCOPE}main.dart.js`), 'network-first');
  assert.equal(route(`${SCOPE}sqlite3.wasm`), 'network-first');
  assert.equal(route(`${SCOPE}canvaskit/chromium/canvaskit.wasm`), 'network-first');
  assert.equal(route(`${SCOPE}assets/assets/images/aiko/aiko_happy.png`), 'stale-while-revalidate');
  assert.equal(route(CANVASKIT), 'cdn');
  assert.equal(route('https://www.gstatic.com/firebasejs/12.19.0/firebase-firestore-pipelines.js'), 'cdn');
  assert.equal(route('https://fonts.gstatic.com/s/notocoloremoji/v1/a.0.woff2'), 'cdn');

  for (const url of [
    'https://firestore.googleapis.com/google.firestore.v1.Firestore/Listen/channel?VER=8',
    'https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=k',
    'https://securetoken.googleapis.com/v1/token?key=k',
    'https://firebasestorage.googleapis.com/v0/b/bucket/o/users%2Fu%2Fr.png?alt=media',
    'https://asia-southeast1-aiko-prod.cloudfunctions.net/aikoChat',
    'https://aikochat-abc123-as.a.run.app/',
    'https://open.er-api.com/v6/latest/THB',
    'https://accounts.google.com/gsi/client',
    'https://www.gstatic.com/recaptcha/releases/x/recaptcha__en.js',
    'http://www.gstatic.com/firebasejs/12.19.0/firebase-app.js',
    'https://cdn.example.com/lib.js',
    `${SCOPE}__/auth/handler`,
    `${SCOPE}__/firebase/init.json`,
  ]) {
    assert.equal(route(url), null, url);
  }
  assert.equal(context.routeFor(navigation(`${SCOPE}__/auth/handler?apiKey=k`)), null);
  assert.equal(route(`${SCOPE}main.dart.js`, { method: 'POST', body: 'x' }), null);
  assert.equal(route(`${SCOPE}assets/assets/video.mp4`, { headers: { range: 'bytes=0-' } }), null);
});

test('without a manifest the worker handles nothing and removes itself', async () => {
  const caches = new FakeCacheStorage();
  await caches.open('aiko-precache-old');
  await caches.open('aiko-cdn');
  await caches.open('flutter-app-cache');
  await caches.open('someone-else');
  const worker = loadWorker({ caches });
  assert.equal(worker.context.routeFor(navigation(SCOPE)), null);
  assert.equal(await dispatchFetch(worker, new Request(`${SCOPE}main.dart.js`)), null);
  await dispatch(worker, 'install');
  await dispatch(worker, 'activate');
  assert.deepEqual(await caches.keys(), ['someone-else']);
  assert.equal(worker.state.unregistered, true);
  assert.equal(worker.state.claimed, false);
});

test('install precaches every build file and activates right away', async () => {
  const worker = await installed();
  const [name] = await worker.caches.keys();
  assert.match(name, /^aiko-precache-[0-9a-f]{16}$/);
  const cache = await worker.caches.open(name);
  assert.deepEqual(
    cache.urls().filter((url) => url.startsWith(SCOPE)).sort(),
    Object.keys(BUILD).map((path) => SCOPE + path).sort(),
  );
  assert.equal(await text(await cache.match(`${SCOPE}main.dart.js`)), 'main v1');
  assert.equal(worker.state.skippedWaiting, true);
  assert.equal(worker.state.claimed, true);
  assert.equal(worker.state.preloadEnabled, true);
  // Revalidates against the HTTP cache instead of downloading again.
  assert.equal(worker.network.log.find((entry) => entry.url === `${SCOPE}main.dart.js`).cache, 'no-cache');
});

test('install fails rather than cache a file from another build', async () => {
  const network = new FakeNetwork();
  serve(network, { ...BUILD, 'main.dart.js': 'main v2 (deployed mid-install)' });
  const worker = loadWorker({ manifest: manifestFor(BUILD), network });
  await assert.rejects(dispatch(worker, 'install'), /content differs from this build/);
  assert.deepEqual(
    network.log.filter((entry) => entry.url === `${SCOPE}main.dart.js`).map((entry) => entry.cache),
    ['no-cache', 'reload'],
  );
  assert.equal(worker.state.skippedWaiting, false);
});

test('install fails on a missing file', async () => {
  const network = new FakeNetwork();
  serve(network, BUILD);
  network.routes[`${SCOPE}main.dart.js`] = new Response('gone', { status: 404 });
  const worker = loadWorker({ manifest: manifestFor(BUILD), network });
  await assert.rejects(dispatch(worker, 'install'), /HTTP 404/);
});

test('an update downloads only changed files and drops the old build', async () => {
  const v1 = await installed();
  const v2Files = { ...BUILD, 'main.dart.js': 'main v2', 'new.js': 'new' };
  const network = new FakeNetwork();
  serve(network, v2Files);
  const v2 = loadWorker({ manifest: manifestFor(v2Files), caches: v1.caches, network });
  await dispatch(v2, 'install');
  assert.deepEqual(network.log.map((entry) => entry.url).sort(), [`${SCOPE}main.dart.js`, `${SCOPE}new.js`]);
  await dispatch(v2, 'activate');
  const names = await v1.caches.keys();
  assert.equal(names.filter((name) => name.startsWith('aiko-precache-')).length, 1);
  const response = await dispatchFetch(v2, new Request(`${SCOPE}assets/assets/images/aiko/aiko_happy.png`));
  assert.equal(await text(response), 'png');
});

test('activate deletes old and legacy caches but keeps CDN, runtime and others', async () => {
  const caches = new FakeCacheStorage();
  for (const name of ['aiko-precache-0000', 'aiko-cdn', 'aiko-runtime', 'aiko-unknown', 'flutter-temp-cache', 'other']) {
    await caches.open(name);
  }
  const network = new FakeNetwork();
  serve(network, BUILD);
  const worker = loadWorker({ manifest: manifestFor(BUILD), caches, network });
  await dispatch(worker, 'install');
  await dispatch(worker, 'activate');
  const names = (await caches.keys()).sort();
  assert.deepEqual(names.filter((name) => !name.startsWith('aiko-precache-')), ['aiko-cdn', 'aiko-runtime', 'other']);
  assert.equal(names.filter((name) => name.startsWith('aiko-precache-')).length, 1);
});

test('navigations are network first and fall back to the cached app', async () => {
  const worker = await installed();
  worker.network.routes[SCOPE] = '<html>fresh</html>';
  assert.equal(await text(await dispatchFetch(worker, navigation(SCOPE))), '<html>fresh</html>');

  delete worker.network.routes[SCOPE];
  const offline = `${SCOPE}?source=pwa`;
  assert.equal(await text(await dispatchFetch(worker, navigation(offline))), '<html>app v1</html>');

  // Navigation preload: the browser's response is used, no second request.
  worker.network.log = [];
  const preloaded = typed(new Response('<html>preloaded</html>'), 'basic');
  const response = await dispatchFetch(worker, navigation(SCOPE), { preloadResponse: Promise.resolve(preloaded) });
  assert.equal(await text(response), '<html>preloaded</html>');
  assert.equal(worker.network.log.length, 0);
});

test('shell files use the cache when the network stalls, then right away', async () => {
  const worker = await installed();
  worker.network.routes[`${SCOPE}main.dart.js`] = () => new Promise(() => {});
  let started = Date.now();
  assert.equal(await text(await dispatchFetch(worker, new Request(`${SCOPE}main.dart.js`))), 'main v1');
  const waited = Date.now() - started;
  assert.ok(waited >= 2900 && waited < 6000, `waited ${waited} ms`);

  started = Date.now();
  assert.equal(await text(await dispatchFetch(worker, new Request(`${SCOPE}main.dart.js?v=2`))), 'main v1');
  assert.ok(Date.now() - started < 500, 'answers from the cache while the network looks down');
});

test('shell files: network response wins and is never written to the precache', async () => {
  const worker = await installed();
  worker.network.routes[`${SCOPE}main.dart.js`] = 'main v2';
  assert.equal(await text(await dispatchFetch(worker, new Request(`${SCOPE}main.dart.js`))), 'main v2');
  delete worker.network.routes[`${SCOPE}main.dart.js`];
  assert.equal(await text(await dispatchFetch(worker, new Request(`${SCOPE}main.dart.js`))), 'main v1');
});

test('other files from this site are cached at runtime for offline use', async () => {
  const worker = await installed();
  const url = `${SCOPE}canvaskit/chromium/canvaskit.wasm`;
  worker.network.routes[url] = 'wasm';
  assert.equal(await text(await dispatchFetch(worker, new Request(url))), 'wasm');
  delete worker.network.routes[url];
  assert.equal(await text(await dispatchFetch(worker, new Request(url))), 'wasm');
  // Error responses are not kept.
  const missing = `${SCOPE}missing.js`;
  worker.network.routes[missing] = typed(new Response('no', { status: 404 }), 'basic');
  assert.equal((await dispatchFetch(worker, new Request(missing))).status, 404);
  assert.equal(await (await worker.caches.open('aiko-runtime')).match(missing), undefined);
});

test('assets outside the build are served stale while revalidating', async () => {
  const worker = await installed();
  const url = `${SCOPE}assets/assets/images/extra.png`;
  worker.network.routes[url] = 'old';
  assert.equal(await text(await dispatchFetch(worker, new Request(url))), 'old');
  worker.network.routes[url] = 'new';
  assert.equal(await text(await dispatchFetch(worker, new Request(url))), 'old');
  assert.equal(await text(await dispatchFetch(worker, new Request(url))), 'new');
});

test('CDN files are cache first and only successful CORS responses are kept', async () => {
  const worker = await installed();
  worker.network.routes[CANVASKIT] = 'canvaskit';
  // A <script> or <img> load (no-cors) is still fetched with CORS.
  const response = await dispatchFetch(worker, new Request(CANVASKIT, { mode: 'no-cors' }));
  assert.equal(await text(response), 'canvaskit');
  assert.equal(worker.network.log.at(-1).mode, 'cors');
  delete worker.network.routes[CANVASKIT];
  assert.equal(await text(await dispatchFetch(worker, new Request(CANVASKIT))), 'canvaskit');
  assert.equal(worker.network.fetched(CANVASKIT), 1);

  const font = 'https://fonts.gstatic.com/s/roboto/v1/a.woff2';
  worker.network.routes[font] = (_, init) =>
    init.mode === 'cors' ? new TypeError('CORS blocked') : typed(new Response(''), 'opaque');
  assert.equal((await dispatchFetch(worker, new Request(font, { mode: 'no-cors' }))).type, 'opaque');
  const opaque = 'https://fonts.gstatic.com/s/roboto/v1/b.woff2';
  worker.network.routes[opaque] = () => typed(new Response('font'), 'opaque');
  assert.equal((await dispatchFetch(worker, new Request(opaque))).type, 'opaque');
  const sdk = 'https://www.gstatic.com/firebasejs/12.19.0/firebase-app.js';
  worker.network.routes[sdk] = typed(new Response('err', { status: 503 }), 'cors');
  assert.equal((await dispatchFetch(worker, new Request(sdk))).status, 503);
  const cdn = await worker.caches.open('aiko-cdn');
  assert.deepEqual(cdn.urls(), [CANVASKIT]);
});

test('CDN files fail like the network does when offline and not cached', async () => {
  const worker = await installed();
  await assert.rejects(dispatchFetch(worker, new Request(CANVASKIT)));
});

test('API calls and non-GET requests are left to the browser', async () => {
  const worker = await installed();
  for (const request of [
    new Request('https://firestore.googleapis.com/v1/projects/p/databases/(default)/documents/users/u'),
    new Request('https://open.er-api.com/v6/latest/USD'),
    new Request(`${SCOPE}main.dart.js`, { method: 'POST', body: '{}' }),
  ]) {
    assert.equal(await dispatchFetch(worker, request), null, request.url);
  }
  assert.equal(worker.network.log.length, Object.keys(BUILD).length);
});

test('caches what the page loaded before the worker controlled it', async () => {
  const worker = await installed();
  const local = `${SCOPE}canvaskit/chromium/canvaskit.js`;
  const firebase = 'https://www.gstatic.com/firebasejs/12.19.0/firebase-auth.js';
  // From a page of the previous build that this worker took over.
  const older = 'https://www.gstatic.com/flutter-canvaskit/rev1/chromium/canvaskit.wasm';
  Object.assign(worker.network.routes, { [CANVASKIT]: 'wasm', [local]: 'js', [firebase]: 'auth', [older]: 'old' });
  worker.network.log = [];
  await dispatch(worker, 'message', {
    data: {
      type: 'aiko-cache-urls',
      urls: [
        CANVASKIT,
        CANVASKIT,
        older,
        local,
        firebase,
        `${SCOPE}main.dart.js`,
        'https://identitytoolkit.googleapis.com/v1/accounts:lookup',
        'blob:https://aiko.example/1234',
        'not a url',
        42,
      ],
    },
  });
  assert.deepEqual((await worker.caches.open('aiko-cdn')).urls().sort(), [firebase, CANVASKIT].sort());
  assert.deepEqual((await worker.caches.open('aiko-runtime')).urls(), [local]);
  assert.deepEqual(worker.network.log.map((entry) => entry.url).sort(), [CANVASKIT, firebase, local].sort());
});

test("an update prefetches the new build's CDN files and prunes old versions", async () => {
  const caches = new FakeCacheStorage();
  const cdn = await caches.open('aiko-cdn');
  const old = {
    'https://www.gstatic.com/flutter-canvaskit/rev1/chromium/canvaskit.js': 'js1',
    'https://www.gstatic.com/flutter-canvaskit/rev1/chromium/canvaskit.wasm': 'wasm1',
    'https://www.gstatic.com/firebasejs/12.0.0/firebase-app.js': 'app1',
    'https://fonts.gstatic.com/s/a.woff2': 'font',
  };
  for (const [url, body] of Object.entries(old)) await cdn.put(url, typed(new Response(body), 'cors'));
  const network = new FakeNetwork();
  serve(network, BUILD);
  Object.assign(network.routes, {
    'https://www.gstatic.com/flutter-canvaskit/rev2/chromium/canvaskit.js': 'js2',
    'https://www.gstatic.com/flutter-canvaskit/rev2/chromium/canvaskit.wasm': 'wasm2',
    'https://www.gstatic.com/firebasejs/12.19.0/firebase-app.js': 'app2',
  });
  const worker = loadWorker({ manifest: manifestFor(BUILD), caches, network });
  await dispatch(worker, 'install');
  await dispatch(worker, 'activate');
  assert.deepEqual(cdn.urls().sort(), [
    'https://fonts.gstatic.com/s/a.woff2',
    'https://www.gstatic.com/firebasejs/12.19.0/firebase-app.js',
    'https://www.gstatic.com/flutter-canvaskit/rev2/chromium/canvaskit.js',
    'https://www.gstatic.com/flutter-canvaskit/rev2/chromium/canvaskit.wasm',
  ]);
});

test('an update refreshes runtime-cached files from this site', async () => {
  const v1 = await installed();
  const local = `${SCOPE}canvaskit/canvaskit.js`;
  await (await v1.caches.open('aiko-runtime')).put(local, typed(new Response('ck v1'), 'basic'));
  const v2Files = { ...BUILD, 'main.dart.js': 'main v2' };
  const network = new FakeNetwork();
  serve(network, { ...v2Files, 'canvaskit/canvaskit.js': 'ck v2' });
  const v2 = loadWorker({ manifest: manifestFor(v2Files), caches: v1.caches, network });
  await dispatch(v2, 'install');
  assert.equal(await text(await (await v1.caches.open('aiko-runtime')).match(local)), 'ck v2');
});

test('unknown CDN versions are kept when the build does not name them', async () => {
  const caches = new FakeCacheStorage();
  const cdn = await caches.open('aiko-cdn');
  const sdk = 'https://www.gstatic.com/firebasejs/12.0.0/firebase-app.js';
  await cdn.put(sdk, typed(new Response('app'), 'cors'));
  const network = new FakeNetwork();
  serve(network, BUILD);
  const worker = loadWorker({ manifest: manifestFor(BUILD, { firebaseSdkVersion: null }), caches, network });
  await dispatch(worker, 'install');
  await dispatch(worker, 'activate');
  assert.deepEqual(cdn.urls(), [sdk]);
});

const GSTATIC = 'https://www.gstatic.com';

/** A cache storage whose CDN cache holds [urls] (as CORS responses). */
async function cdnCaches(urls) {
  const caches = new FakeCacheStorage();
  const cdn = await caches.open('aiko-cdn');
  for (const url of urls) await cdn.put(url, typed(new Response(`cached ${url}`), 'cors'));
  return { caches, cdn };
}

test('an update that cannot download a CDN file fails and keeps the current build', async () => {
  const old = [`${GSTATIC}/flutter-canvaskit/rev1/chromium/canvaskit.js`, `${GSTATIC}/flutter-canvaskit/rev1/chromium/canvaskit.wasm`];
  const failures = [
    new TypeError('connection reset'),
    typed(new Response('busy', { status: 503 }), 'cors'),
    typed(new Response(''), 'opaque'),
  ];
  for (const failure of failures) {
    const { caches, cdn } = await cdnCaches(old);
    const network = new FakeNetwork();
    serve(network, BUILD);
    network.routes[`${GSTATIC}/flutter-canvaskit/rev2/chromium/canvaskit.js`] = 'js2';
    network.routes[`${GSTATIC}/flutter-canvaskit/rev2/chromium/canvaskit.wasm`] = failure;
    const worker = loadWorker({ manifest: manifestFor(BUILD), caches, network });
    await assert.rejects(dispatch(worker, 'install'));
    assert.equal(worker.state.skippedWaiting, false);
    // The current build's CanvasKit stays for its offline starts.
    for (const url of old) assert.ok(cdn.urls().includes(url), url);
  }
});

test('an update caches every Firebase SDK file the build lists, also for an unchanged SDK version', async () => {
  const sdk = `${GSTATIC}/firebasejs/12.19.0`;
  const { caches, cdn } = await cdnCaches([
    `${sdk}/firebase-app.js`,
    `${sdk}/firebase-firestore.js`,
    `${GSTATIC}/firebasejs/12.0.0/firebase-auth.js`,
  ]);
  const network = new FakeNetwork();
  serve(network, BUILD);
  Object.assign(network.routes, {
    [`${sdk}/firebase-auth.js`]: 'auth',
    [`${sdk}/firebase-firestore-pipelines.js`]: 'pipelines',
  });
  const firebasejs = ['firebase-app.js', 'firebase-auth.js', 'firebase-firestore-pipelines.js'];
  const worker = loadWorker({ manifest: manifestFor(BUILD, { cdnFiles: { firebasejs } }), caches, network });
  await dispatch(worker, 'install');
  // Only the missing ones are downloaded, and not a file the build no longer loads.
  const downloaded = network.log.filter((entry) => entry.url.startsWith(GSTATIC)).map((entry) => entry.url);
  assert.deepEqual(downloaded.sort(), [`${sdk}/firebase-auth.js`, `${sdk}/firebase-firestore-pipelines.js`]);
  await dispatch(worker, 'activate');
  assert.deepEqual(cdn.urls().sort(), [
    `${sdk}/firebase-app.js`,
    `${sdk}/firebase-auth.js`,
    `${sdk}/firebase-firestore-pipelines.js`,
    `${sdk}/firebase-firestore.js`,
  ]);
});

test('an update downloads no Firebase SDK in a browser that never loaded it', async () => {
  const { caches } = await cdnCaches([`${GSTATIC}/flutter-canvaskit/rev2/chromium/canvaskit.wasm`]);
  const network = new FakeNetwork();
  serve(network, BUILD);
  const manifest = manifestFor(BUILD, { cdnFiles: { firebasejs: ['firebase-app.js'] } });
  const worker = loadWorker({ manifest, caches, network });
  await dispatch(worker, 'install');
  assert.equal(worker.state.skippedWaiting, true);
  assert.deepEqual(network.log.filter((entry) => !entry.url.startsWith(SCOPE)), []);
});

test('old CDN versions are kept until all of the current ones are cached', async () => {
  const canvaskit = (rev, file) => `${GSTATIC}/flutter-canvaskit/${rev}/chromium/${file}`;
  const oldSdk = `${GSTATIC}/firebasejs/12.0.0/firebase-app.js`;
  const { caches, cdn } = await cdnCaches([
    canvaskit('rev1', 'canvaskit.js'),
    canvaskit('rev1', 'canvaskit.wasm'),
    canvaskit('rev2', 'canvaskit.wasm'),
    oldSdk,
  ]);
  const worker = loadWorker({ manifest: manifestFor(BUILD), caches });
  await worker.context.pruneCdn();
  assert.equal(cdn.urls().length, 4);
  await cdn.put(canvaskit('rev2', 'canvaskit.js'), typed(new Response('js'), 'cors'));
  await worker.context.pruneCdn();
  assert.deepEqual(cdn.urls().filter((url) => url.includes('canvaskit')).sort(), [
    canvaskit('rev2', 'canvaskit.js'),
    canvaskit('rev2', 'canvaskit.wasm'),
  ]);
  // The SDK at 12.19.0 was never cached: the old version stays.
  assert.ok(cdn.urls().includes(oldSdk));
});

test('an update that cannot refresh a runtime-cached file fails and keeps the old copies', async () => {
  const v1 = await installed();
  const runtime = await v1.caches.open('aiko-runtime');
  const js = `${SCOPE}canvaskit/canvaskit.js`;
  const wasm = `${SCOPE}canvaskit/canvaskit.wasm`;
  const gone = `${SCOPE}old.js`;
  for (const url of [js, wasm, gone]) await runtime.put(url, typed(new Response('v1'), 'basic'));
  const v2Files = { ...BUILD, 'main.dart.js': 'main v2' };
  const network = new FakeNetwork();
  serve(network, { ...v2Files, 'canvaskit/canvaskit.js': 'js v2' });
  network.routes[gone] = typed(new Response('', { status: 404 }), 'basic');
  const v2 = loadWorker({ manifest: manifestFor(v2Files), caches: v1.caches, network });
  await assert.rejects(dispatch(v2, 'install'), /Failed to fetch/);
  for (const url of [js, wasm, gone]) assert.equal(await text(await runtime.match(url)), 'v1', url);

  network.routes[wasm] = 'wasm v2';
  const retry = loadWorker({ manifest: manifestFor(v2Files), caches: v1.caches, network });
  await dispatch(retry, 'install');
  assert.equal(await text(await runtime.match(js)), 'js v2');
  assert.equal(await text(await runtime.match(wasm)), 'wasm v2');
  assert.equal(await runtime.match(gone), undefined);
});

/** index.html as tool/web_precache.mjs tags it with its build's version. */
const tagged = (version, body = 'app') => `<html><head><meta name="aiko-build" content="${version}"></head>${body}</html>`;

/** A worker with [files] installed whose network then serves [served]. */
async function installedServing(files, served, extra) {
  const worker = await installed(files, extra);
  worker.network.routes = {};
  serve(worker.network, served);
  if (served['index.html']) worker.network.routes[SCOPE] = served['index.html'];
  worker.network.log = [];
  return worker;
}

test('a page from the precache loads all its files from the precache', async () => {
  const worker = await installedServing(BUILD, {});
  // Offline: the page comes from the cache...
  assert.equal(await text(await dispatchFetch(worker, navigation(SCOPE), { resultingClientId: 'page' })), '<html>app v1</html>');
  // ...and so does every file it loads, even once the network is back.
  serve(worker.network, { 'main.dart.js': 'main v2', 'assets/assets/images/aiko/aiko_happy.png': 'png v2' });
  worker.network.log = [];
  const png = `${SCOPE}assets/assets/images/aiko/aiko_happy.png`;
  assert.equal(await text(await dispatchFetch(worker, new Request(`${SCOPE}main.dart.js`), { clientId: 'page' })), 'main v1');
  assert.equal(await text(await dispatchFetch(worker, new Request(png), { clientId: 'page' })), 'png');
  assert.deepEqual(worker.network.log, []);
});

test('a page of the precached build from the network loads its files from the precache', async () => {
  const version = '0123456789abcdef';
  const files = { ...BUILD, 'index.html': tagged(version) };
  const worker = await installedServing(files, files, { version });
  assert.equal(await text(await dispatchFetch(worker, navigation(SCOPE), { resultingClientId: 'page' })), files['index.html']);
  worker.network.log = [];
  assert.equal(await text(await dispatchFetch(worker, new Request(`${SCOPE}main.dart.js`), { clientId: 'page' })), 'main v1');
  assert.deepEqual(worker.network.log, []);
});

test('a page of a newer build loads every file from the network, however slow', async () => {
  const v2 = {
    'index.html': tagged('newer-build'),
    'flutter_bootstrap.js': 'boot rev3',
    'main.dart.js': 'main v2',
    'assets/assets/images/aiko/aiko_happy.png': 'png v2',
  };
  const worker = await installedServing({ ...BUILD, 'flutter_bootstrap.js': 'boot rev2' }, v2);
  // Slower than the 3 s fallback to the cache, which has the other build.
  worker.network.routes[`${SCOPE}main.dart.js`] = () =>
    new Promise((resolve) => setTimeout(() => resolve(typed(new Response('main v2'), 'basic')), 3500));
  const loaded = [await text(await dispatchFetch(worker, navigation(SCOPE), { resultingClientId: 'page' }))];
  for (const path of ['flutter_bootstrap.js', 'main.dart.js', 'assets/assets/images/aiko/aiko_happy.png']) {
    loaded.push(await text(await dispatchFetch(worker, new Request(SCOPE + path), { clientId: 'page' })));
  }
  assert.deepEqual(loaded, Object.values(v2));

  // Offline now: the other build's copies are never used instead.
  worker.network.routes = {};
  await assert.rejects(dispatchFetch(worker, new Request(`${SCOPE}main.dart.js`), { clientId: 'page' }));
  await assert.rejects(
    dispatchFetch(worker, new Request(`${SCOPE}assets/assets/images/aiko/aiko_happy.png`), { clientId: 'page' }),
  );
  assert.deepEqual((await worker.caches.open('aiko-runtime')).urls(), []);
});

test('a page from the network without a build tag counts as another build', async () => {
  const worker = await installedServing(BUILD, { ...BUILD, 'index.html': '<html>untagged</html>', 'main.dart.js': 'main v2' });
  await dispatchFetch(worker, navigation(SCOPE), { resultingClientId: 'page' });
  assert.equal(await text(await dispatchFetch(worker, new Request(`${SCOPE}main.dart.js`), { clientId: 'page' })), 'main v2');
});

test('a worker the page starts loads its files from where the page does', async () => {
  const worker = await installedServing({ ...BUILD, 'sqflite_sw.js': 'sqflite v1', 'sqlite3.wasm': 'wasm v1' }, {});
  await dispatchFetch(worker, navigation(SCOPE), { resultingClientId: 'page' });
  serve(worker.network, { 'sqflite_sw.js': 'sqflite v2', 'sqlite3.wasm': 'wasm v2' });
  const script = await dispatchFetch(worker, new Request(`${SCOPE}sqflite_sw.js`), {
    clientId: 'page',
    resultingClientId: 'db-worker',
  });
  assert.equal(await text(script), 'sqflite v1');
  assert.equal(await text(await dispatchFetch(worker, new Request(`${SCOPE}sqlite3.wasm`), { clientId: 'db-worker' })), 'wasm v1');
});
