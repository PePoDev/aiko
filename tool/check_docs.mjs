// Checks docs/*.md: relative links and #anchors must resolve, and backticked
// repository paths (lib/…, test/…, firebase/…) must exist or be gitignored
// outputs. README.md is checked only for its links into docs/.
// Run: npm run docs:check
import { execFileSync } from 'node:child_process';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { dirname, join, normalize, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const pathPrefixes = ['lib/', 'test/', 'firebase/', 'docs/', 'tool/', 'web/', 'assets/', 'android/', 'ios/', '.github/', 'landing/', 'screenshots/'];
const files = ['README.md', ...readdirSync(join(root, 'docs')).filter((f) => f.endsWith('.md')).map((f) => `docs/${f}`)];

// GitHub heading slugs, including -1, -2 suffixes for repeated headings.
const anchorCache = new Map();
function anchorsOf(file) {
  if (anchorCache.has(file)) return anchorCache.get(file);
  const seen = new Map();
  const anchors = new Set();
  let fenced = false;
  for (const line of readFileSync(join(root, file), 'utf8').split('\n')) {
    if (line.startsWith('```')) fenced = !fenced;
    const heading = !fenced && line.match(/^#{1,6}\s+(.*)$/);
    if (!heading) continue;
    const base = heading[1].trim().toLowerCase().replace(/[^\p{L}\p{N}\s_-]/gu, '').replace(/\s/g, '-');
    const count = seen.get(base) ?? 0;
    seen.set(base, count + 1);
    anchors.add(count ? `${base}-${count}` : base);
  }
  anchorCache.set(file, anchors);
  return anchors;
}

const ignored = (path) => {
  try {
    execFileSync('git', ['check-ignore', '-q', path], { cwd: root });
    return true;
  } catch {
    return false;
  }
};

const errors = [];
for (const file of files) {
  const text = readFileSync(join(root, file), 'utf8');
  const prose = text.replace(/```[\s\S]*?```/g, '');
  for (const [, target] of prose.matchAll(/\]\(([^)\s]+)\)/g)) {
    if (/^(https?:|mailto:)/.test(target)) continue;
    if (file === 'README.md' && !target.startsWith('docs/')) continue;
    const [path, anchor] = target.split('#');
    const resolved = path ? normalize(relative(root, join(root, dirname(file), path))) : file;
    if (path && !existsSync(join(root, resolved))) {
      errors.push(`${file}: broken link ${target}`);
    } else if (anchor && resolved.endsWith('.md') && !anchorsOf(resolved).has(anchor)) {
      errors.push(`${file}: missing anchor ${target}`);
    }
  }
  if (file === 'README.md') continue;
  for (const [, code] of prose.matchAll(/`([^`\n]+)`/g)) {
    const path = code.replace(/[.,:;]+$/, '');
    if (!pathPrefixes.some((prefix) => path.startsWith(prefix))) continue;
    if (/[\s{}<>*…|]/.test(path)) continue;
    if (!existsSync(join(root, path)) && !ignored(path)) errors.push(`${file}: missing path ${path}`);
  }
}

if (errors.length) {
  console.error(errors.join('\n'));
  console.error(`\n${errors.length} documentation problem(s). Update the docs to match the code.`);
  process.exit(1);
}
console.log(`Docs OK: ${files.length} files checked.`);
