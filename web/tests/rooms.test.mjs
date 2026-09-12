import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Rooms } from '../server/rooms.mjs';
import { MemoryStore, RedisStore } from '../server/store.mjs';
import { iceConfiguration } from '../server/ice.mjs';
import { handlerFor } from '../api/rooms.js';

const host = 'a'.repeat(64), guest = 'b'.repeat(64), third = 'c'.repeat(64);
function setup() {
  let time = 100000;
  const now = () => time;
  const store = new MemoryStore(now);
  let iceCalls = 0;
  const rooms = new Rooms(store, async () => { iceCalls++; return { iceServers: [] }; }, now);
  return { rooms, store, tick: ms => { time += ms; }, iceCalls: () => iceCalls };
}
const create = rooms => rooms.handle({ action: 'create', token: host, protocol: 2 });
const join = (rooms, room, token = guest) => rooms.handle({ action: 'join', token, room, protocol: 2 });
const exchange = (rooms, room, token, messages = [], cursor = 0, ready = false) => rooms.handle({ action: 'exchange', room, token, cursor, messages, ready });

test('a room admits exactly one guest across concurrent requests', async () => {
  const { rooms, store } = setup();
  const { room } = await create(rooms);
  assert.match(room, /^[A-F0-9]{12}$/);
  const results = await Promise.allSettled([join(rooms, room), join(rooms, room, third)]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal(results.find(r => r.status === 'rejected').reason.status, 409);
  const stored = await store.get(`ninja:v2:room:${room}`);
  assert.ok(!stored.includes(host) && !stored.includes(guest) && !stored.includes(third));
});

test('joining is idempotent, outsiders cannot read or close, full rooms do not issue TURN credentials', async () => {
  const { rooms, iceCalls } = setup();
  const { room } = await create(rooms);
  await join(rooms, room);
  await join(rooms, room);
  const calls = iceCalls();
  await assert.rejects(join(rooms, room, third), { status: 409 });
  assert.equal(iceCalls(), calls);
  await assert.rejects(exchange(rooms, room, third), { status: 403 });
  await assert.rejects(rooms.handle({ action: 'leave', room, token: third }), { status: 403 });
});

test('signaling survives lost responses, duplicate batches, concurrent polls, and acknowledged message removal', async () => {
  const { rooms } = setup();
  const { room } = await create(rooms);
  await join(rooms, room);
  const offer = { seq: 1, type: 'offer', sdp: 'test-offer' };
  const candidate = { seq: 2, type: 'ice', media: '0', index: 0, candidate: 'test-candidate' };
  await Promise.all([exchange(rooms, room, host, [offer, candidate]), exchange(rooms, room, guest)]);
  await exchange(rooms, room, host, [offer, candidate]);
  const read = await exchange(rooms, room, guest);
  assert.deepEqual(read.messages, [offer, candidate]);
  assert.deepEqual((await exchange(rooms, room, guest)).messages, read.messages);
  assert.deepEqual((await exchange(rooms, room, guest, [], 2)).messages, []);
  await exchange(rooms, room, guest, [{ seq: 1, type: 'answer', sdp: 'test-answer' }], 2, true);
  const reply = await exchange(rooms, room, host, [], 0, true);
  assert.equal(reply.peerReady, true);
  assert.equal(reply.messages[0].type, 'answer');
  assert.equal((await exchange(rooms, room, guest, [], 2)).peerReady, true);
});

test('closed, expired, abandoned, and incompatible rooms fail clearly', async () => {
  const { rooms, tick } = setup();
  const { room } = await create(rooms);
  await assert.rejects(rooms.handle({ action: 'join', token: guest, room, protocol: 1 }), { status: 409 });
  await assert.rejects(join(rooms, room, host), { status: 409 });
  tick(31000);
  await assert.rejects(join(rooms, room), { status: 410 });
  await exchange(rooms, room, host);
  await join(rooms, room);
  await rooms.handle({ action: 'leave', room, token: guest });
  await assert.rejects(exchange(rooms, room, host), { status: 410 });
  const next = await create(rooms);
  tick(601000);
  await assert.rejects(join(rooms, next.room), { status: 404 });
});

test('invalid signaling, tokens, and rate exhaustion are rejected', async () => {
  const { rooms } = setup();
  await assert.rejects(rooms.handle({ action: 'create', token: 'guess', protocol: 2 }), { status: 400 });
  const { room } = await create(rooms);
  await join(rooms, room);
  await assert.rejects(exchange(rooms, room, guest, [{ seq: 1, type: 'offer', sdp: 'bad' }]), { status: 400 });
  await assert.rejects(exchange(rooms, room, host, [{ seq: 2, type: 'offer', sdp: 'gap' }]), { status: 409 });
  await assert.rejects(exchange(rooms, room, host, [{ seq: 1, type: 'offer', sdp: 'x'.repeat(16001) }]), { status: 400 });
  await assert.rejects(exchange(rooms, room, guest, [], 50), { status: 400 });
  for (let i = 0; i < 29; i++) await create(rooms);
  await assert.rejects(create(rooms), { status: 429 });
});

test('response batches stay bounded and each peer can send only one description', async () => {
  const { rooms } = setup();
  const { room } = await create(rooms);
  await join(rooms, room);
  await exchange(rooms, room, host, [{ seq: 1, type: 'offer', sdp: 'offer' }]);
  await assert.rejects(exchange(rooms, room, host, [{ seq: 2, type: 'offer', sdp: 'another-offer' }]), { status: 409 });
  const candidates = Array.from({ length: 20 }, (_, i) => ({ seq: i + 2, type: 'ice', media: '0', index: 0, candidate: 'candidate', extra: 'discard' }));
  await exchange(rooms, room, host, candidates.slice(0, 16));
  await exchange(rooms, room, host, candidates.slice(16));
  const first = await exchange(rooms, room, guest);
  assert.equal(first.messages.length, 16);
  assert.ok(!JSON.stringify(first).includes('discard'));
  const next = await exchange(rooms, room, guest, [], 16);
  assert.deepEqual(next.messages.map(m => m.seq), [17, 18, 19, 20, 21]);
});

test('production requires Redis and TURN; local development is explicitly separate', async () => {
  assert.throws(() => new RedisStore({}), /Redis is not configured/);
  await assert.rejects(iceConfiguration({}), /TURN is not configured/);
  await assert.rejects(iceConfiguration({ NINJA_LOCAL_DEV: '1', VERCEL: '1' }), /TURN is not configured/);
  assert.deepEqual(await iceConfiguration({ NINJA_LOCAL_DEV: '1' }), { iceServers: [] });
});

test('TURN keys stay server-side and temporary credentials use the documented Cloudflare endpoint', async () => {
  const env = { CLOUDFLARE_TURN_KEY_ID: 'key-id', CLOUDFLARE_TURN_API_TOKEN: 'private-key' };
  const result = await iceConfiguration(env, async (url, options) => {
    assert.equal(url, 'https://rtc.live.cloudflare.com/v1/turn/keys/key-id/credentials/generate-ice-servers');
    assert.equal(options.headers.Authorization, 'Bearer private-key');
    assert.equal(JSON.parse(options.body).ttl, 14400);
    return Response.json({ iceServers: [{ urls: ['turn:example.com:3478'], username: 'temporary-user', credential: 'temporary-password' }] });
  });
  assert.ok(!JSON.stringify(result).includes('private-key'));
  const coturn = await iceConfiguration({ TURN_URLS: 'turn:127.0.0.1:3478', TURN_SHARED_SECRET: 'test-secret' }, fetch, 100000);
  assert.equal(coturn.iceServers[0].username, '14500:ninja');
  assert.ok(!JSON.stringify(coturn).includes('test-secret'));
  await assert.rejects(iceConfiguration(env, async () => Response.json({ iceServers: [] })), /Invalid TURN/);
});

async function request(handler, body, options = {}) {
  const res = { headers: {}, setHeader(k, v) { this.headers[k] = v; }, status(n) { this.code = n; return this; }, json(value) { this.body = value; return this; } };
  await handler({ method: 'POST', headers: { host: 'game.example', origin: 'https://game.example', 'content-type': 'application/json', ...options.headers }, body, ...options.request }, res);
  return res;
}

test('HTTP boundary rejects cross-origin requests and never exposes service secrets', async () => {
  const { rooms } = setup();
  const handler = handlerFor(() => rooms);
  const body = { action: 'create', token: host, protocol: 2 };
  assert.equal((await request(handler, body, { headers: { origin: 'https://attacker.example' } })).code, 403);
  assert.equal((await request(handler, body, { request: { method: 'GET' } })).code, 405);
  assert.equal((await request(handler, '{broken')).code, 400);
  assert.equal((await request(handler, 'x'.repeat(65537))).code, 413);
  const good = await request(handler, body);
  assert.equal(good.code, 200);
  assert.equal(good.headers['Cache-Control'], 'no-store');
  const failed = await request(handlerFor(() => { throw new Error('secret-credential'); }), body);
  assert.equal(failed.code, 503);
  assert.ok(!JSON.stringify(failed).includes('secret-credential'));
});
