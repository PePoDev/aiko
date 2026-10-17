#!/usr/bin/env node
// Writes the service worker's precache manifest into a Flutter web build, so
// the app opens offline after one online visit (see web/aiko_sw.js).
//
// Usage, after `flutter build web`:  node tool/web_precache.mjs [build/web]
//
// Lists every file the app needs with its SHA-256 and puts the list into the
// build's aiko_sw.js. Any changed file changes the manifest version and so
// the worker's bytes, which is how browsers notice a new build.
import { createHash } from 'node:crypto';
import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

export const SW_FILE = 'aiko_sw.js';
const MARKER = /\/\* @aiko-precache \*\/ .*;/g;

/**
 * Whether a build file (path relative to the build folder, `/`-separated)
 * belongs in the precache. Left out: the worker itself and Flutter's retired
 * one; CanvasKit (the variant depends on the browser, and deployed builds
 * load it from Google's CDN; the worker caches what the page loads); debug
 * symbols and source maps; license notices the app doesn't show.
 */
export function isPrecached(path) {
  const name = path.split('/').pop();
  return !(
    path === SW_FILE ||
    path === 'flutter_service_worker.js' ||
    path === 'assets/NOTICES' ||
    path.startsWith('canvaskit/') ||
    name.startsWith('.') ||
    name.endsWith('.symbols') ||
    name.endsWith('.map')
  );
}

/** The manifest for the build in [dir]. */
export function buildManifest(dir, { firebaseSdkVersion = null } = {}) {
  const files = {};
  for (const path of listFiles(dir).sort()) {
    if (!isPrecached(path)) continue;
    files[path.split('/').map(encodeURIComponent).join('/')] = sha256(readFileSync(join(dir, path)));
  }
  const engineRevision = readEngineRevision(dir);
  const version = sha256(JSON.stringify({ files, engineRevision, firebaseSdkVersion })).slice(0, 16);
  return { version, engineRevision, firebaseSdkVersion, files };
}

/** [source] (aiko_sw.js) with [manifest] in place of its placeholder. */
export function injectManifest(source, manifest) {
  const found = source.match(MARKER)?.length ?? 0;
  if (found !== 1) {
    throw new Error(`${SW_FILE} must contain exactly one "/* @aiko-precache */ …;" placeholder (found ${found})`);
  }
  return source.replace(MARKER, () => `/* @aiko-precache */ ${JSON.stringify(manifest)};`);
}

/** The Flutter engine revision (names the CanvasKit CDN folder), or null. */
export function readEngineRevision(dir) {
  try {
    const bootstrap = readFileSync(join(dir, 'flutter_bootstrap.js'), 'utf8');
    const config = /_flutter\.buildConfig\s*=\s*(\{.*?\});\s*$/m.exec(bootstrap);
    return JSON.parse(config[1]).engineRevision ?? null;
  } catch {
    return null;
  }
}

/**
 * The Firebase JS SDK version FlutterFire loads from the CDN, read from the
 * resolved firebase_core_web package, or null when it can't be found.
 */
export function findFirebaseSdkVersion(projectDir) {
  try {
    const configPath = join(projectDir, '.dart_tool', 'package_config.json');
    const config = JSON.parse(readFileSync(configPath, 'utf8'));
    const core = config.packages.find((p) => p.name === 'firebase_core_web');
    const root = new URL(core.rootUri.endsWith('/') ? core.rootUri : `${core.rootUri}/`, pathToFileURL(configPath));
    const source = readFileSync(new URL('lib/src/firebase_sdk_version.dart', root), 'utf8');
    return /supportedFirebaseJsSdkVersion\s*=\s*'([^']+)'/.exec(source)?.[1] ?? null;
  } catch {
    return null;
  }
}

function listFiles(dir, prefix = '') {
  return readdirSync(join(dir, prefix), { withFileTypes: true }).flatMap((entry) => {
    const path = prefix ? `${prefix}/${entry.name}` : entry.name;
    return entry.isDirectory() ? listFiles(dir, path) : entry.isFile() ? [path] : [];
  });
}

function sha256(data) {
  return createHash('sha256').update(data).digest('hex');
}

function main() {
  const dir = resolve(process.argv[2] ?? 'build/web');
  const swPath = join(dir, SW_FILE);
  if (!existsSync(swPath)) {
    console.error(`${swPath} not found. Run \`flutter build web\` first (web/${SW_FILE} is copied into the build).`);
    process.exit(1);
  }
  const project = fileURLToPath(new URL('..', import.meta.url));
  const manifest = buildManifest(dir, { firebaseSdkVersion: findFirebaseSdkVersion(project) });
  writeFileSync(swPath, injectManifest(readFileSync(swPath, 'utf8'), manifest));
  const paths = Object.keys(manifest.files);
  const bytes = paths.reduce((sum, path) => sum + readFileSync(join(dir, decodeURIComponent(path))).length, 0);
  console.log(
    `${SW_FILE}: precache ${manifest.version}, ${paths.length} files, ${(bytes / 1e6).toFixed(1)} MB` +
      ` (engine ${manifest.engineRevision ?? 'unknown'}, Firebase JS SDK ${manifest.firebaseSdkVersion ?? 'unknown'})`,
  );
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
