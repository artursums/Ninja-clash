import { createHash, randomBytes } from 'node:crypto';

const PROTOCOL = 2;
const ROOM_TTL = 600;
const HOST_LEASE_MS = 30000;
const digest = value => createHash('sha256').update(value).digest('hex');
const keyFor = room => `ninja:v2:room:${room}`;

export class RoomError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
function requireValue(condition, message = 'INVALID REQUEST', status = 400) {
  if (!condition) throw new RoomError(status, message);
}

export class Rooms {
  constructor(store, ice, now = Date.now) { this.store = store; this.ice = ice; this.now = now; }

  async update(id, apply) {
    for (let attempt = 0; attempt < 12; attempt++) {
      const raw = await this.store.get(keyFor(id));
      requireValue(raw, 'ROOM EXPIRED OR NOT FOUND', 404);
      const room = JSON.parse(raw);
      requireValue(!room.closed && room.expires > this.now(), 'ROOM CLOSED OR EXPIRED', 410);
      const result = apply(room);
      const ttl = Math.max(1, Math.ceil((room.expires - this.now()) / 1000));
      if (await this.store.compareSet(keyFor(id), raw, JSON.stringify(room), ttl)) return result;
    }
    throw new RoomError(503, 'ROOM BUSY — TRY AGAIN');
  }

  async handle(body, ip = 'unknown') {
    requireValue(body && typeof body === 'object' && !Array.isArray(body));
    const { action, token } = body;
    requireValue(['create', 'join', 'exchange', 'leave'].includes(action));
    requireValue(typeof token === 'string' && /^[a-f0-9]{64}$/.test(token));
    const maximum = action === 'exchange' ? 240 : 30;
    requireValue(await this.store.limit(`ninja:v2:rate:${digest(ip)}:${action}`, maximum, 60), 'TOO MANY REQUESTS — WAIT A MINUTE', 429);
    const auth = digest(token);
    if (action === 'create') {
      requireValue(body.protocol === PROTOCOL, 'UPDATE THE GAME AND TRY AGAIN', 409);
      const rtc = await this.ice();
      for (let attempt = 0; attempt < 3; attempt++) {
        const id = randomBytes(6).toString('hex').toUpperCase();
        const room = { protocol: PROTOCOL, host: auth, guest: '', seen: this.now(), expires: this.now() + ROOM_TTL * 1000,
          messages: { host: [], guest: [] }, sequence: { host: 0, guest: 0 },
          description: { host: false, guest: false }, ready: { host: false, guest: false } };
        if (await this.store.compareSet(keyFor(id), null, JSON.stringify(room), ROOM_TTL)) {
          return { room: id, rtc, expiresIn: ROOM_TTL };
        }
      }
      throw new RoomError(503, 'COULD NOT CREATE ROOM');
    }

    requireValue(typeof body.room === 'string' && /^[A-F0-9]{12}$/.test(body.room), 'INVALID ROOM CODE');
    if (action === 'join') {
      // Validate before requesting paid TURN credentials, then atomically reserve the slot.
      const validate = room => {
        requireValue(room.protocol === body.protocol, 'YOU HAVE DIFFERENT GAME VERSIONS — RELOAD', 409);
        requireValue(room.host !== auth, 'OPEN THE INVITE ON ANOTHER DEVICE', 409);
        requireValue(!room.guest || room.guest === auth, 'ROOM IS FULL', 409);
        requireValue(this.now() - room.seen < HOST_LEASE_MS, 'HOST IS NO LONGER WAITING', 410);
      };
      await this.update(body.room, validate);
      const rtc = await this.ice();
      return this.update(body.room, room => { validate(room); room.guest = auth; return { room: body.room, rtc }; });
    }

    return this.update(body.room, room => {
      const role = room.host === auth ? 'host' : room.guest === auth ? 'guest' : '';
      requireValue(role, 'INVALID ROOM SESSION', 403);
      const other = role === 'host' ? 'guest' : 'host';
      if (action === 'leave') { room.closed = true; return { ok: true }; }
      requireValue(Number.isInteger(body.cursor) && body.cursor >= 0 && body.cursor <= room.sequence[other]);
      requireValue(Array.isArray(body.messages) && body.messages.length <= 16);
      if (role === 'host') room.seen = this.now();
      else requireValue(room.ready.host || this.now() - room.seen < HOST_LEASE_MS, 'HOST IS NO LONGER WAITING', 410);
      for (const message of body.messages) {
        requireValue(message && Number.isInteger(message.seq) && message.seq > 0 && message.seq <= 256);
        if (message.seq <= room.sequence[role]) continue;
        requireValue(message.seq === room.sequence[role] + 1, 'SIGNAL OUT OF ORDER', 409);
        if (message.type === 'offer' || message.type === 'answer') {
          requireValue(message.type === (role === 'host' ? 'offer' : 'answer'));
          requireValue(!room.description[role], 'HANDSHAKE ALREADY SENT', 409);
          requireValue(typeof message.sdp === 'string' && message.sdp.length > 0 && message.sdp.length <= 16000);
          room.description[role] = true;
        } else {
          requireValue(message.type === 'ice');
          requireValue(typeof message.media === 'string' && message.media.length <= 64);
          requireValue(Number.isInteger(message.index) && message.index >= 0 && message.index < 16);
          requireValue(typeof message.candidate === 'string' && message.candidate.length <= 2048);
        }
        const clean = message.type === 'ice'
          ? { seq: message.seq, type: message.type, media: message.media, index: message.index, candidate: message.candidate }
          : { seq: message.seq, type: message.type, sdp: message.sdp };
        room.messages[role].push(clean);
        room.sequence[role] = message.seq;
      }
      if (body.ready === true) room.ready[role] = true;
      room.messages[other] = room.messages[other].filter(message => message.seq > body.cursor);
      return { joined: !!room.guest, peerReady: room.ready[other], ack: room.sequence[role], messages: room.messages[other].slice(0, 16) };
    });
  }
}
