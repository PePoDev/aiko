// Tests for tool/web_precache.mjs (the build step that writes the service
// worker's precache manifest). Run: npm run test:web
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { after, test } from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  buildManifest,
  findFirebaseJsFiles,
  findFirebaseSdkVersion,
  injectManifest,
  isPrecached,
  SW_FILE,
  withBuildMeta,
} from '../web_precache.mjs';

const ROOT = fileURLToPath(new URL('../..', import.meta.url));
const SCRIPT = join(ROOT, 'tool', 'web_precache.mjs');
const temp = mkdtempSync(join(tmpdir(), 'aiko-precache-'));
after(() => rmSync(temp, { recursive: true, force: true }));

const sha256 = (data) => createHash('sha256').update(data).digest('hex');
const INDEX = '<html>\n<head>\n  <title>Aiko</title>\n</head>\n<body></body>\n</html>\n';
const tagged = (version) => INDEX.replace('</head>', `  <meta name="aiko-build" content="${version}">\n</head>`);
let builds = 0;

/** A fake Flutter web build with the files the real one has. */
function fakeBuild(overrides = {}) {
  const dir = join(temp, `build${builds++}`);
  const files = {
    'index.html': INDEX,
    'main.dart.js': 'main();',
    'flutter_bootstrap.js':
      'loader();\nif (!window._flutter) {\n  window._flutter = {};\n}\n' +
      '_flutter.buildConfig = {"engineRevision":"abc123","builds":[{"compileTarget":"dart2js"},{}],"useLocalCanvasKit":true};\n\n' +
      '_flutter.loader.load();\n',
    'flutter_service_worker.js': 'unregister();',
    '.last_build_id': 'x',
    'assets/NOTICES': 'licenses',
    'assets/AssetManifest.bin.json': '"x"',
    'assets/assets/images/aiko happy.png': 'png',
    'canvaskit/canvaskit.wasm': 'wasm',
    'canvaskit/chromium/canvaskit.js.symbols': 'symbols',
    'main.dart.js.map': '{}',
    'sqlite3.wasm': 'sqlite',
    ...overrides,
  };
  for (const [path, body] of Object.entries(files)) {
    mkdirSync(dirname(join(dir, path)), { recursive: true });
    writeFileSync(join(dir, path), body);
  }
  cpSync(join(ROOT, 'web', SW_FILE), join(dir, SW_FILE));
  return dir;
}

test('lists the app files with their SHA-256, leaving out what the worker must not precache', () => {
  const firebaseJsFiles = ['firebase-app.js', 'firebase-auth.js'];
  const manifest = buildManifest(fakeBuild(), { firebaseSdkVersion: '12.19.0', firebaseJsFiles });
  assert.match(manifest.version, /^[0-9a-f]{16}$/);
  assert.deepEqual(manifest.files, {
    'assets/AssetManifest.bin.json': sha256('"x"'),
    'assets/assets/images/aiko%20happy.png': sha256('png'),
    'flutter_bootstrap.js': sha256(readFileSync(join(temp, 'build0', 'flutter_bootstrap.js'))),
    // As main() writes it: tagged with the build's version.
    'index.html': sha256(tagged(manifest.version)),
    'main.dart.js': sha256('main();'),
    'sqlite3.wasm': sha256('sqlite'),
  });
  assert.equal(manifest.engineRevision, 'abc123');
  assert.equal(manifest.firebaseSdkVersion, '12.19.0');
  assert.deepEqual(manifest.cdnFiles, { firebasejs: firebaseJsFiles });
});

test('isPrecached keeps the shell and assets, drops CanvasKit, symbols, maps and the workers', () => {
  for (const path of ['index.html', 'main.dart.js', 'icons/Icon-192.png', 'assets/packages/pdfrx/assets/pdfium.wasm']) {
    assert.equal(isPrecached(path), true, path);
  }
  for (const path of [SW_FILE, 'flutter_service_worker.js', 'canvaskit/skwasm.wasm', 'assets/NOTICES', '.last_build_id', 'a/.hidden', 'flutter.js.map', 'canvaskit.js.symbols']) {
    assert.equal(isPrecached(path), false, path);
  }
});

test('the version changes with any precached file and only then', () => {
  const base = buildManifest(fakeBuild()).version;
  assert.equal(buildManifest(fakeBuild()).version, base);
  assert.notEqual(buildManifest(fakeBuild({ 'main.dart.js': 'main(2);' })).version, base);
  assert.notEqual(buildManifest(fakeBuild({ 'assets/assets/new.png': 'new' })).version, base);
  assert.equal(buildManifest(fakeBuild({ 'canvaskit/canvaskit.wasm': 'other' })).version, base);
  assert.notEqual(buildManifest(fakeBuild(), { firebaseSdkVersion: '13.0.0' }).version, base);
  assert.notEqual(buildManifest(fakeBuild(), { firebaseJsFiles: ['firebase-app.js'] }).version, base);
  assert.notEqual(buildManifest(fakeBuild({ 'index.html': INDEX.replace('Aiko', 'Aiko 2') })).version, base);
  // index.html's own build tag doesn't count.
  assert.equal(buildManifest(fakeBuild({ 'index.html': tagged('0123456789abcdef') })).version, base);
});

test('tags index.html with the build, replacing an earlier tag', () => {
  const once = withBuildMeta(INDEX, 'v1');
  assert.equal(once, tagged('v1'));
  assert.equal(withBuildMeta(once, 'v1'), once);
  assert.equal(withBuildMeta(once, 'v2'), tagged('v2'));
  assert.equal(withBuildMeta(once, null), INDEX);
  assert.throws(() => withBuildMeta('<html></html>', 'v1'), /no <\/head>/);
});

test('injects the manifest into the worker, repeatably', () => {
  const source = readFileSync(join(ROOT, 'web', SW_FILE), 'utf8');
  const manifest = { version: 'v1', engineRevision: null, firebaseSdkVersion: null, files: { 'a$&.js': 'h' } };
  const once = injectManifest(source, manifest);
  assert.ok(once.includes(`const PRECACHE = /* @aiko-precache */ ${JSON.stringify(manifest)};`));
  assert.equal(injectManifest(once, manifest), once);
  assert.notEqual(injectManifest(once, { ...manifest, version: 'v2' }), once);
  assert.throws(() => injectManifest('const PRECACHE = null;', manifest), /placeholder/);
});

test('the CLI writes the manifest into the build and is idempotent', () => {
  const dir = fakeBuild();
  const run = () => execFileSync(process.execPath, [SCRIPT, dir], { cwd: temp, encoding: 'utf8' });
  const version = /precache ([0-9a-f]{16}), 6 files/.exec(run())?.[1];
  assert.ok(version);
  const first = readFileSync(join(dir, SW_FILE), 'utf8');
  assert.ok(first.includes('"main.dart.js":"'));
  assert.ok(first.includes(`"version":"${version}"`));
  const index = readFileSync(join(dir, 'index.html'), 'utf8');
  assert.equal(index, tagged(version));
  assert.ok(first.includes(`"index.html":"${sha256(index)}"`));
  run();
  assert.equal(readFileSync(join(dir, SW_FILE), 'utf8'), first);
  assert.equal(readFileSync(join(dir, 'index.html'), 'utf8'), index);
});

test('the CLI refuses a folder without the worker', () => {
  const dir = join(temp, 'empty');
  mkdirSync(dir);
  assert.throws(() => execFileSync(process.execPath, [SCRIPT, dir], { stdio: 'pipe' }), /not found/);
});

/** A project resolved against fake FlutterFire packages; returns its folder. */
function fakeProject(name, { pipelines = true } = {}) {
  const project = join(temp, name);
  const pubCache = join(temp, `${name}-pub-cache`);
  const write = (path, text) => {
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, text);
  };
  const core = join(pubCache, 'firebase_core_web-3.12.0');
  write(
    join(core, 'lib', 'src', 'firebase_sdk_version.dart'),
    "/// The Firebase JS SDK version.\nconst String supportedFirebaseJsSdkVersion = '12.19.0';\n",
  );
  write(
    join(core, 'lib', 'src', 'firebase_core_web.dart'),
    pipelines ? "injectSrcScript('https://www.gstatic.com/firebasejs/$version/firebase-firestore-pipelines.js');\n" : '',
  );
  const plugin = (pkg, source, extra = {}) => {
    write(join(pubCache, pkg, 'lib', `${pkg}.dart`), source);
    return { name: pkg.replace(/-.*/, ''), path: `${join(pubCache, pkg)}/`, dependencies: [], dev_dependency: false, ...extra };
  };
  const web = [
    plugin('firebase_auth_web-6.3.0', "FirebaseCoreWeb.registerService(\n      'auth',\n      ensurePluginInitialized: (app) async {},\n    );\n"),
    plugin('cloud_firestore_web-5.7.3', "FirebaseCoreWeb.registerService('firestore');\n"),
    plugin('firebase_storage_web-3.11.13', "    FirebaseCoreWeb.registerService('storage');\n"),
    plugin('firebase_analytics_web-1.0.0', "FirebaseCoreWeb.registerService('analytics');\n", { dev_dependency: true }),
    plugin('url_launcher_web-2.4.0', 'class UrlLauncherPlugin {}\n'),
  ];
  write(join(project, '.flutter-plugins-dependencies'), JSON.stringify({ plugins: { web } }));
  write(
    join(project, '.dart_tool', 'package_config.json'),
    JSON.stringify({ packages: [{ name: 'firebase_core_web', rootUri: `../../${name}-pub-cache/firebase_core_web-3.12.0` }] }),
  );
  return project;
}

test('reads the Firebase JS SDK version from the resolved firebase_core_web', () => {
  assert.equal(findFirebaseSdkVersion(fakeProject('project')), '12.19.0');
  assert.equal(findFirebaseSdkVersion(join(temp, 'nowhere')), null);
});

test('lists the Firebase JS SDK files the web plugins load', () => {
  assert.deepEqual(findFirebaseJsFiles(fakeProject('plugins')), [
    'firebase-app.js',
    'firebase-auth.js',
    'firebase-firestore-pipelines.js',
    'firebase-storage.js',
  ]);
  assert.deepEqual(findFirebaseJsFiles(fakeProject('plugins-old', { pipelines: false })), [
    'firebase-app.js',
    'firebase-auth.js',
    'firebase-firestore.js',
    'firebase-storage.js',
  ]);
  assert.equal(findFirebaseJsFiles(join(temp, 'nowhere')), null);
});

test("this project's list matches what FlutterFire loads", { skip: !existsSync(join(ROOT, '.flutter-plugins-dependencies')) }, () => {
  const files = findFirebaseJsFiles(ROOT);
  for (const file of ['firebase-app.js', 'firebase-auth.js', 'firebase-firestore-pipelines.js', 'firebase-storage.js', 'firebase-functions.js']) {
    assert.ok(files.includes(file), `${file} in ${files}`);
  }
});
