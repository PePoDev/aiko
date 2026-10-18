// Runs web/aiko_sw.js in a Node vm with in-memory caches and a scripted
// network, for tool/test/web_sw.test.mjs.
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

import { injectManifest } from '../web_precache.mjs';

export const SCOPE = 'https://aiko.example/';
const SW_SOURCE = readFileSync(new URL('../../web/aiko_sw.js', import.meta.url), 'utf8');

export const sha256 = (text) => createHash('sha256').update(text).digest('hex');

/** A Response with the given `type` ('basic', 'cors', 'opaque'), kept by clone(). */
export function typed(response, type) {
  const clone = response.clone.bind(response);
  Object.defineProperty(response, 'type', { value: type });
  Object.defineProperty(response, 'clone', { value: () => typed(clone(), type) });
  return response;
}

export class FakeCache {
  entries = new Map();

  async match(request, options = {}) {
    const url = new URL(typeof request === 'string' ? request : request.url);
    for (const [key, entry] of this.entries) {
      const candidate = new URL(key);
      if (options.ignoreSearch) {
        candidate.search = '';
        url.search = '';
      }
      if (candidate.href === url.href) return entry();
    }
    return undefined;
  }

  async put(request, response) {
    const url = typeof request === 'string' ? request : request.url;
    const body = await response.arrayBuffer();
    const { status, statusText, type } = response;
    const headers = [...response.headers];
    this.entries.delete(url);
    this.entries.set(url, () => typed(new Response(status === 204 ? null : body.slice(0), { status, statusText, headers }), type));
  }

  async delete(request) {
    return this.entries.delete(typeof request === 'string' ? request : request.url);
  }

  async keys() {
    return [...this.entries.keys()].map((url) => new Request(url));
  }

  urls() {
    return [...this.entries.keys()];
  }
}

export class FakeCacheStorage {
  caches = new Map();

  async open(name) {
    if (!this.caches.has(name)) this.caches.set(name, new FakeCache());
    return this.caches.get(name);
  }

  async keys() {
    return [...this.caches.keys()];
  }

  async delete(name) {
    return this.caches.delete(name);
  }

  async has(name) {
    return this.caches.has(name);
  }
}

/**
 * A scripted network: `routes[url]` is a body string (200, 'basic' for this
 * site, 'cors' elsewhere), a Response, a function of the request returning
 * either, or an Error to reject with. Unknown URLs reject (offline).
 */
export class FakeNetwork {
  routes = {};
  log = [];

  fetch = async (input, init = {}) => {
    const url = typeof input === 'string' ? input : input.url;
    this.log.push({ url, mode: init.mode ?? input.mode, cache: init.cache });
    let route = this.routes[url];
    if (typeof route === 'function') route = await route(input, init);
    if (route === undefined || route instanceof Error) throw route ?? new TypeError(`Failed to fetch ${url}`);
    if (route instanceof Response) return route;
    return typed(new Response(route, { status: 200 }), url.startsWith(SCOPE) ? 'basic' : 'cors');
  };

  fetched(url) {
    return this.log.filter((entry) => entry.url === url).length;
  }
}

/** Loads the worker with [manifest] (or none) and returns its environment. */
export function loadWorker({ manifest = null, caches = new FakeCacheStorage(), network = new FakeNetwork() } = {}) {
  const listeners = {};
  const state = { skippedWaiting: false, claimed: false, unregistered: false, preloadEnabled: false };
  const self = {
    registration: {
      scope: SCOPE,
      navigationPreload: { enable: async () => (state.preloadEnabled = true) },
      unregister: async () => (state.unregistered = true),
    },
    clients: { claim: async () => (state.claimed = true) },
    skipWaiting: async () => (state.skippedWaiting = true),
    addEventListener: (type, listener) => (listeners[type] = listener),
  };
  const context = vm.createContext({
    self,
    caches,
    fetch: network.fetch,
    Request,
    Response,
    Headers,
    URL,
    crypto: globalThis.crypto,
    setTimeout,
    clearTimeout,
    console,
  });
  const source = manifest ? injectManifest(SW_SOURCE, manifest) : SW_SOURCE;
  vm.runInContext(source, context, { filename: 'aiko_sw.js' });
  return { context, listeners, state, caches, network };
}

/** Dispatches a lifecycle event and waits for its waitUntil work. */
export async function dispatch(worker, type, data = {}) {
  const waits = [];
  worker.listeners[type]({ ...data, waitUntil: (promise) => waits.push(promise) });
  await Promise.all(waits);
}

/**
 * Dispatches a fetch event; resolves with the response, or null if not
 * handled. [clientId] is the page that sends it; [resultingClientId] the
 * page (navigation) or worker (worker script) it creates.
 */
export async function dispatchFetch(worker, request, { preloadResponse, clientId = '', resultingClientId = '' } = {}) {
  let responded = null;
  const waits = [];
  worker.listeners.fetch({
    request,
    preloadResponse,
    clientId,
    resultingClientId,
    respondWith: (promise) => (responded = Promise.resolve(promise)),
    waitUntil: (promise) => waits.push(promise),
  });
  const response = responded ? await responded : null;
  await Promise.allSettled(waits);
  return response;
}

/** A navigation request (Node's Request can't be constructed in that mode). */
export function navigation(url) {
  return { url, method: 'GET', mode: 'navigate', cache: 'default', headers: new Headers() };
}

/** A manifest for the given {path: body} build files. */
export function manifestFor(files, extra = {}) {
  return {
    version: sha256(JSON.stringify(files)).slice(0, 16),
    engineRevision: 'rev2',
    firebaseSdkVersion: '12.19.0',
    cdnFiles: { firebasejs: null },
    files: Object.fromEntries(Object.entries(files).map(([path, body]) => [path, sha256(body)])),
    ...extra,
  };
}
