import { createServer } from 'node:http';
import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { handlerFor } from '../api/rooms.js';
import { MemoryStore, RedisStore } from '../server/store.mjs';
import { Rooms } from '../server/rooms.mjs';
import { iceConfiguration } from '../server/ice.mjs';

const root = fileURLToPath(new URL('../../build/ninja-clash/public/', import.meta.url));
const env = { ...process.env, NINJA_LOCAL_DEV: '1' };
const store = env.UPSTASH_REDIS_REST_URL ? new RedisStore(env) : new MemoryStore();
const rooms = new Rooms(store, () => iceConfiguration(env));
const api = handlerFor(() => rooms);
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = createServer(async (req, res) => {
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('Referrer-Policy', 'no-referrer');
  const url = new URL(req.url, 'http://localhost');
  if (url.pathname === '/api/rooms') {
    res.status = code => { res.statusCode = code; return res; };
    res.json = data => { res.setHeader('Content-Type', 'application/json'); res.end(JSON.stringify(data)); };
    const chunks = [];
    let size = 0;
    for await (const chunk of req) {
      size += chunk.length;
      if (size > 65536) { res.status(413).json({ error: 'REQUEST TOO LARGE' }); return; }
      chunks.push(chunk);
    }
    req.body = Buffer.concat(chunks).toString();
    await api(req, res);
    return;
  }
  try {
    const name = url.pathname === '/' ? 'index.html' : decodeURIComponent(url.pathname.slice(1));
    const file = path.resolve(root, name);
    if (!file.startsWith(root) || !(await stat(file)).isFile()) throw new Error('not found');
    res.setHeader('Content-Type', types[path.extname(file)] || 'application/octet-stream');
    createReadStream(file).pipe(res);
  } catch { res.writeHead(404).end('Not found'); }
});
server.listen(Number(process.env.PORT || 8787), '127.0.0.1', () => {
  console.log(`Ninja Clash local server: http://127.0.0.1:${server.address().port}`);
  console.log(`Rooms: ${store instanceof MemoryStore ? 'local memory (development only)' : 'Redis'}. TURN: ${env.TURN_URLS || env.CLOUDFLARE_TURN_KEY_ID ? 'configured' : 'not configured (direct local test only)'}.`);
});
