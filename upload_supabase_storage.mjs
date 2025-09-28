import { stat, readdir, readFile } from 'node:fs/promises';
import { join, relative } from 'node:path';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE;
const BUCKET = process.env.BUCKET || 'web';
const SRC_DIR = process.env.SRC_DIR || 'build/web';

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE in env');
  process.exit(1);
}

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.webp': 'image/webp',
  '.wasm': 'application/wasm',
  '.map': 'application/octet-stream',
  '.txt': 'text/plain; charset=utf-8',
};
function extname(p){ const i=p.lastIndexOf('.'); return i>=0?p.slice(i):''; }
function guessType(p){ return MIME[extname(p).toLowerCase()] || 'application/octet-stream'; }

async function* walk(dir) {
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) yield* walk(full);
    else yield full;
  }
}

let ok = 0, fail = 0;

for await (const fullpath of walk(SRC_DIR)) {
  const key = relative(SRC_DIR, fullpath).replaceAll('\\','/');
  const url = `${SUPABASE_URL}/storage/v1/object/${encodeURIComponent(BUCKET)}/${encodeURI(key)}?overwrite=true`;
  const body = await readFile(fullpath);
  const ct = guessType(fullpath);

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${SERVICE_KEY}`,
      'Content-Type': ct,
      'x-upsert': 'true',
    },
    body
  });

  if (res.ok) {
    ok++;
    process.stdout.write(`✓ ${key}\n`);
  } else {
    fail++;
    const text = await res.text();
    console.error(`✗ ${key} — ${res.status} ${res.statusText}\n${text}`);
  }
}

console.log(`\nDone. Uploaded ${ok}, failed ${fail}.`);
if (fail > 0) process.exit(1);
