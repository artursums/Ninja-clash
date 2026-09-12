import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import net from 'node:net';
import { createServer } from 'node:http';
import { RedisStore } from '../server/store.mjs';
import { Rooms } from '../server/rooms.mjs';

const redis = process.env.REDIS_SERVER || 'redis-server';
const available = spawnSync(redis, ['--version']).status === 0;

function command(socketPath, args) {
  return new Promise((resolve, reject) => {
    const socket = net.createConnection(socketPath);
    let buffer = Buffer.alloc(0);
    socket.on('error', reject);
    socket.on('connect', () => socket.write(`*${args.length}\r\n` + args.map(a => `$${Buffer.byteLength(String(a))}\r\n${a}\r\n`).join('')));
    socket.on('data', chunk => {
      buffer = Buffer.concat([buffer, chunk]);
      const eol = buffer.indexOf('\r\n');
      if (eol < 0) return;
      const head = buffer.subarray(1, eol).toString();
      if (buffer[0] === 36 && Number(head) >= 0 && buffer.length < eol + 4 + Number(head)) return;
      socket.end();
      if (buffer[0] === 45) { reject(new Error(head)); return; }
      resolve(buffer[0] === 58 ? Number(head) : buffer[0] === 36 ? Number(head) < 0 ? null : buffer.subarray(eol + 2, eol + 2 + Number(head)).toString() : head);
    });
  });
}

test('real Redis executes CAS scripts, expiry and rate limiting through the REST adapter', { skip: !available }, async () => {
  const dir = await mkdtemp(path.join(tmpdir(), 'ninja-redis-'));
  const socketPath = path.join(dir, 'redis.sock');
  const child = spawn(redis, ['--port', '0', '--unixsocket', socketPath, '--save', '', '--appendonly', 'no'], { stdio: 'pipe' });
  let server;
  try {
    await new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('Redis startup timed out')), 5000);
      child.stdout.on('data', chunk => { if (chunk.toString().includes('ready to accept connections') || chunk.toString().includes('Ready to accept connections')) { clearTimeout(timeout); resolve(); } });
      child.on('error', reject);
    });
    server = createServer(async (req, res) => {
      assert.equal(req.headers.authorization, 'Bearer test-rest-token');
      const chunks = [];
      for await (const chunk of req) chunks.push(chunk);
      try { res.end(JSON.stringify({ result: await command(socketPath, JSON.parse(Buffer.concat(chunks))) })); }
      catch (error) { res.end(JSON.stringify({ error: error.message })); }
    });
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    const store = new RedisStore({ UPSTASH_REDIS_REST_URL: `http://127.0.0.1:${server.address().port}`, UPSTASH_REDIS_REST_TOKEN: 'test-rest-token' });
    assert.equal(await store.compareSet('sample', null, 'first', 10), true);
    assert.equal(await store.compareSet('sample', null, 'bad', 10), false);
    assert.equal(await store.compareSet('sample', 'first', 'second', 10), true);
    assert.equal(await store.get('sample'), 'second');
    assert.ok(await command(socketPath, ['TTL', 'sample']) > 0);
    assert.equal(await store.limit('limit', 1, 60), true);
    assert.equal(await store.limit('limit', 1, 60), false);
    const rooms = new Rooms(store, async () => ({ iceServers: [] }));
    const { room } = await rooms.handle({ action: 'create', protocol: 2, token: 'a'.repeat(64) });
    const joins = await Promise.allSettled(['b', 'c'].map(c => rooms.handle({ action: 'join', protocol: 2, room, token: c.repeat(64) })));
    assert.equal(joins.filter(r => r.status === 'fulfilled').length, 1);
    assert.equal(joins.find(r => r.status === 'rejected').reason.status, 409);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    const stopped = new Promise(resolve => child.once('exit', resolve));
    child.kill('SIGTERM');
    await stopped;
    await rm(dir, { recursive: true, force: true });
  }
});
