// Tests for tool/web_precache.mjs (the build step that writes the service
// worker's precache manifest). Run: npm run test:web
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { after, test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { buildManifest, findFirebaseSdkVersion, injectManifest, isPrecached, SW_FILE } from '../web_precache.mjs';

const ROOT = fileURLToPath(new URL('../..', import.meta.url));
const SCRIPT = join(ROOT, 'tool', 'web_precache.mjs');
const temp = mkdtempSync(join(tmpdir(), 'aiko-precache-'));
after(() => rmSync(temp, { recursive: true, force: true }));

const sha256 = (data) => createHash('sha256').update(data).digest('hex');
let builds = 0;

/** A fake Flutter web build with the files the real one has. */
function fakeBuild(overrides = {}) {
  const dir = join(temp, `build${builds++}`);
  const files = {
    'index.html': '<html></html>',
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
  const manifest = buildManifest(fakeBuild(), { firebaseSdkVersion: '12.19.0' });
  assert.deepEqual(manifest.files, {
    'assets/AssetManifest.bin.json': sha256('"x"'),
    'assets/assets/images/aiko%20happy.png': sha256('png'),
    'flutter_bootstrap.js': sha256(readFileSync(join(temp, 'build0', 'flutter_bootstrap.js'))),
    'index.html': sha256('<html></html>'),
    'main.dart.js': sha256('main();'),
    'sqlite3.wasm': sha256('sqlite'),
  });
  assert.equal(manifest.engineRevision, 'abc123');
  assert.equal(manifest.firebaseSdkVersion, '12.19.0');
  assert.match(manifest.version, /^[0-9a-f]{16}$/);
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
  assert.match(run(), /aiko_sw\.js: precache [0-9a-f]{16}, 6 files/);
  const first = readFileSync(join(dir, SW_FILE), 'utf8');
  assert.ok(first.includes('"main.dart.js":"'));
  run();
  assert.equal(readFileSync(join(dir, SW_FILE), 'utf8'), first);
});

test('the CLI refuses a folder without the worker', () => {
  const dir = join(temp, 'empty');
  mkdirSync(dir);
  assert.throws(() => execFileSync(process.execPath, [SCRIPT, dir], { stdio: 'pipe' }), /not found/);
});

test('reads the Firebase JS SDK version from the resolved firebase_core_web', () => {
  const project = join(temp, 'project');
  const pkg = join(temp, 'pub-cache', 'firebase_core_web-3.12.0');
  mkdirSync(join(project, '.dart_tool'), { recursive: true });
  mkdirSync(join(pkg, 'lib', 'src'), { recursive: true });
  writeFileSync(
    join(pkg, 'lib', 'src', 'firebase_sdk_version.dart'),
    "/// The Firebase JS SDK version.\nconst String supportedFirebaseJsSdkVersion = '12.19.0';\n",
  );
  writeFileSync(
    join(project, '.dart_tool', 'package_config.json'),
    JSON.stringify({ packages: [{ name: 'firebase_core_web', rootUri: '../../pub-cache/firebase_core_web-3.12.0' }] }),
  );
  assert.equal(findFirebaseSdkVersion(project), '12.19.0');
  assert.equal(findFirebaseSdkVersion(join(temp, 'nowhere')), null);
});
