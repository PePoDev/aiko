#!/usr/bin/env node
// Writes the service worker's precache manifest into a Flutter web build, so
// the app opens offline after one online visit (see web/aiko_sw.js).
//
// Usage, after `flutter build web`:  node tool/web_precache.mjs [build/web]
//
// Lists every file the app needs with its SHA-256 and puts the list into the
// build's aiko_sw.js. Any changed file changes the manifest version and so
// the worker's bytes, which is how browsers notice a new build. The version
// also goes into the build's index.html, so the worker can tell which build
// a page loaded from the network runs.
import { createHash } from 'node:crypto';
import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

export const SW_FILE = 'aiko_sw.js';
const MARKER = /\/\* @aiko-precache \*\/ .*;/g;
const BUILD_META = /[ \t]*<meta name="aiko-build" content="[^"]*">\r?\n?/g;

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

/**
 * The manifest for the build in [dir]. [firebaseJsFiles] are the Firebase JS
 * SDK files the app imports from the CDN (see [findFirebaseJsFiles]); the
 * worker caches them before a new build takes over.
 *
 * The version comes from the build without the aiko-build tag in index.html;
 * the file list has index.html's hash with the tag set to that version
 * (main() writes it so).
 */
export function buildManifest(dir, { firebaseSdkVersion = null, firebaseJsFiles = null } = {}) {
  const files = {};
  for (const path of listFiles(dir).sort()) {
    if (!isPrecached(path)) continue;
    let data = readFileSync(join(dir, path));
    if (path === 'index.html') data = withBuildMeta(data.toString('utf8'), null);
    files[path.split('/').map(encodeURIComponent).join('/')] = sha256(data);
  }
  const engineRevision = readEngineRevision(dir);
  const cdnFiles = { firebasejs: firebaseJsFiles };
  const version = sha256(JSON.stringify({ files, engineRevision, firebaseSdkVersion, cdnFiles })).slice(0, 16);
  if (files['index.html']) {
    files['index.html'] = sha256(withBuildMeta(readFileSync(join(dir, 'index.html'), 'utf8'), version));
  }
  return { version, engineRevision, firebaseSdkVersion, cdnFiles, files };
}

/**
 * [html] (index.html) with `<meta name="aiko-build" content="[version]">`
 * in place of any earlier one, or without one when [version] is null.
 */
export function withBuildMeta(html, version) {
  const stripped = html.replace(BUILD_META, '');
  if (version === null) return stripped;
  const head = stripped.indexOf('</head>');
  if (head < 0) throw new Error('index.html has no </head> for the aiko-build tag');
  return `${stripped.slice(0, head)}  <meta name="aiko-build" content="${version}">\n${stripped.slice(head)}`;
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
    const source = readFileSync(join(firebaseCoreWebDir(projectDir), 'lib', 'src', 'firebase_sdk_version.dart'), 'utf8');
    return /supportedFirebaseJsSdkVersion\s*=\s*'([^']+)'/.exec(source)?.[1] ?? null;
  } catch {
    return null;
  }
}

/**
 * The Firebase JS SDK files FlutterFire imports from the CDN when the app
 * starts (firebase_core_web's `_initializeCore`): firebase-app.js and one
 * file per service the app's web plugins register, such as firebase-auth.js
 * for `registerService('auth')`. Firestore's is
 * firebase-firestore-pipelines.js when firebase_core_web names that file.
 * Sorted; null when the plugin list can't be read.
 */
export function findFirebaseJsFiles(projectDir) {
  try {
    const plugins = JSON.parse(readFileSync(join(projectDir, '.flutter-plugins-dependencies'), 'utf8')).plugins.web;
    const core = readDartSources(firebaseCoreWebDir(projectDir));
    const files = new Set(['firebase-app.js']);
    for (const plugin of plugins) {
      // Release builds don't register dev dependencies.
      if (plugin.dev_dependency) continue;
      for (const [, service] of readDartSources(plugin.path).matchAll(/FirebaseCoreWeb\.registerService\(\s*'([^']+)'/g)) {
        const pipelines = service === 'firestore' && core.includes('firebase-firestore-pipelines.js');
        files.add(pipelines ? 'firebase-firestore-pipelines.js' : `firebase-${service}.js`);
      }
    }
    return [...files].sort();
  } catch {
    return null;
  }
}

/** Where the resolved firebase_core_web package is (throws if it isn't). */
function firebaseCoreWebDir(projectDir) {
  const configPath = join(projectDir, '.dart_tool', 'package_config.json');
  const config = JSON.parse(readFileSync(configPath, 'utf8'));
  const core = config.packages.find((p) => p.name === 'firebase_core_web');
  const root = new URL(core.rootUri.endsWith('/') ? core.rootUri : `${core.rootUri}/`, pathToFileURL(configPath));
  return fileURLToPath(root);
}

/** The Dart sources under [packageDir]/lib, joined. */
function readDartSources(packageDir) {
  const lib = join(packageDir, 'lib');
  return listFiles(lib)
    .filter((path) => path.endsWith('.dart'))
    .map((path) => readFileSync(join(lib, path), 'utf8'))
    .join('\n');
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
  const firebaseSdkVersion = findFirebaseSdkVersion(project);
  const firebaseJsFiles = findFirebaseJsFiles(project);
  if (firebaseSdkVersion && !firebaseJsFiles) {
    // The worker could then let a build take over before its SDK files are cached.
    console.error('Could not list the Firebase JS SDK files: .flutter-plugins-dependencies is missing. Run `flutter pub get`.');
    process.exit(1);
  }
  const manifest = buildManifest(dir, { firebaseSdkVersion, firebaseJsFiles });
  const indexPath = join(dir, 'index.html');
  if (existsSync(indexPath)) {
    writeFileSync(indexPath, withBuildMeta(readFileSync(indexPath, 'utf8'), manifest.version));
  }
  writeFileSync(swPath, injectManifest(readFileSync(swPath, 'utf8'), manifest));
  const paths = Object.keys(manifest.files);
  const bytes = paths.reduce((sum, path) => sum + readFileSync(join(dir, decodeURIComponent(path))).length, 0);
  const firebase = manifest.cdnFiles.firebasejs;
  console.log(
    `${SW_FILE}: precache ${manifest.version}, ${paths.length} files, ${(bytes / 1e6).toFixed(1)} MB` +
      ` (engine ${manifest.engineRevision ?? 'unknown'}, Firebase JS SDK ${manifest.firebaseSdkVersion ?? 'unknown'}:` +
      ` ${firebase ? firebase.join(' ') : 'files unknown'})`,
  );
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
