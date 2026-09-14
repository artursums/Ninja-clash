import { createHash, randomBytes } from 'node:crypto';

const PROTOCOL = 4;
const ROOM_TTL = 600;
const HOST_LEASE_MS = 30000;
const NEGOTIATION_MS = 45000;
const digest = value => createHash('sha256').update(value).digest('hex');
const keyFor = room => `ninja:v3:room:${room}`;
const peerIds = room => Object.keys(room.guests).map(Number).sort((a, b) => a - b);

export class RoomError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
function requireValue(condition, message = 'INVALID REQUEST', status = 400) {
  if (!condition) throw new RoomError(status, message);
}
function mailbox(auth, now) {
  return { auth, joined: now, messages: { host: [], guest: [] }, sequence: { host: 0, guest: 0 },
    description: { host: false, guest: false }, ready: { host: false, guest: false } };
}

export class Rooms {
  constructor(store, ice, now = Date.now) { this.store = store; this.ice = ice; this.now = now; }

  async update(id, apply) {
    for (let attempt = 0; attempt < 12; attempt++) {
      const raw = await this.store.get(keyFor(id));
      requireValue(raw, 'ROOM EXPIRED OR NOT FOUND', 404);
      const room = JSON.parse(raw);
      requireValue(!room.closed && room.expires > this.now(), 'ROOM CLOSED OR EXPIRED', 410);
      for (const [id, guest] of Object.entries(room.guests)) {
        if (!guest.ready.host && this.now() - guest.joined > NEGOTIATION_MS) delete room.guests[id];
      }
      const result = apply(room);
      const ttl = Math.max(1, Math.ceil((room.expires - this.now()) / 1000));
      if (await this.store.compareSet(keyFor(id), raw, JSON.stringify(room), ttl)) return result;
    }
    throw new RoomError(503, 'ROOM BUSY — TRY AGAIN');
  }

  async handle(body, ip = 'unknown') {
    requireValue(body && typeof body === 'object' && !Array.isArray(body));
    const { action, token } = body;
    requireValue(['create', 'join', 'exchange', 'leave', 'lock', 'reopen', 'remove'].includes(action));
    requireValue(typeof token === 'string' && /^[a-f0-9]{64}$/.test(token));
    const maximum = action === 'exchange' ? 900 : 30;
    requireValue(await this.store.limit(`ninja:v3:rate:${digest(ip)}:${action}`, maximum, 60), 'TOO MANY REQUESTS — WAIT A MINUTE', 429);
    const auth = digest(token);
    if (action === 'create') {
      requireValue(body.protocol === PROTOCOL, 'UPDATE THE GAME AND TRY AGAIN', 409);
      const rtc = await this.ice();
      for (let attempt = 0; attempt < 3; attempt++) {
        const id = randomBytes(6).toString('hex').toUpperCase();
        const room = { protocol: PROTOCOL, host: auth, guests: {}, nextPeer: 2, locked: false,
          seen: this.now(), expires: this.now() + ROOM_TTL * 1000 };
        if (await this.store.compareSet(keyFor(id), null, JSON.stringify(room), ROOM_TTL)) {
          return { room: id, peer: 1, rtc, expiresIn: ROOM_TTL };
        }
      }
      throw new RoomError(503, 'COULD NOT CREATE ROOM');
    }

    requireValue(typeof body.room === 'string' && /^[A-F0-9]{12}$/.test(body.room), 'INVALID ROOM CODE');
    if (action === 'join') {
      const validate = room => {
        requireValue(room.protocol === body.protocol, 'YOU HAVE DIFFERENT GAME VERSIONS — RELOAD', 409);
        requireValue(room.host !== auth, 'OPEN THE INVITE ON ANOTHER DEVICE', 409);
        requireValue(!room.locked, 'MATCH ALREADY STARTED', 409);
        requireValue(Object.values(room.guests).some(g => g.auth === auth) || peerIds(room).length < 3, 'ROOM IS FULL', 409);
        requireValue(this.now() - room.seen < HOST_LEASE_MS, 'HOST IS NO LONGER WAITING', 410);
      };
      await this.update(body.room, validate);
      const rtc = await this.ice();
      return this.update(body.room, room => {
        validate(room);
        let peer = peerIds(room).find(id => room.guests[id].auth === auth);
        if (!peer) {
          peer = room.nextPeer++;
          room.guests[peer] = mailbox(auth, this.now());
        }
        return { room: body.room, peer, rtc };
      });
    }

    return this.update(body.room, room => {
      const host = room.host === auth;
      const ownPeer = peerIds(room).find(id => room.guests[id].auth === auth);
      requireValue(host || ownPeer, 'INVALID ROOM SESSION', 403);
      if (action === 'leave') {
        if (host) room.closed = true;
        else delete room.guests[ownPeer];
        return { ok: true };
      }
      if (['lock', 'reopen', 'remove'].includes(action)) {
        requireValue(host, 'HOST ONLY', 403);
        if (action === 'lock') {
          requireValue(Array.isArray(body.peers) && body.peers.length >= 1 && body.peers.length <= 3);
          requireValue(JSON.stringify([...body.peers].sort((a, b) => a - b)) === JSON.stringify(peerIds(room)), 'A PLAYER IS STILL CONNECTING — TRY AGAIN', 409);
          requireValue(Object.values(room.guests).every(g => g.ready.host && g.ready.guest), 'A PLAYER IS STILL CONNECTING — TRY AGAIN', 409);
          room.locked = true;
        } else if (action === 'reopen') room.locked = false;
        else {
          requireValue(Number.isInteger(body.peer) && body.peer > 1);
          delete room.guests[body.peer];
        }
        room.seen = this.now();
        room.expires = this.now() + ROOM_TTL * 1000;
        return { ok: true, locked: room.locked };
      }
      requireValue(Array.isArray(body.links) && body.links.length <= (host ? 3 : 1));
      if (host) {
        room.seen = this.now();
        room.expires = this.now() + ROOM_TTL * 1000;
      } else requireValue(room.guests[ownPeer].ready.host || this.now() - room.seen < HOST_LEASE_MS, 'HOST IS NO LONGER WAITING', 410);
      const seen = new Set();
      for (const link of body.links) {
        requireValue(link && Number.isInteger(link.peer) && !seen.has(link.peer));
        seen.add(link.peer);
        requireValue(host || link.peer === ownPeer, 'INVALID ROOM SESSION', 403);
        const guest = room.guests[link.peer];
        if (!guest && host) continue; // An acknowledged disconnect may race the last ICE batch.
        requireValue(guest, 'INVALID ROOM SESSION', 403);
        this.exchange(guest, host ? 'host' : 'guest', link);
      }
      const peers = host ? peerIds(room) : [ownPeer];
      return { peers, locked: room.locked, links: peers.map(peer => {
        const guest = room.guests[peer], role = host ? 'host' : 'guest', other = host ? 'guest' : 'host';
        return { peer, peerReady: guest.ready[other], ack: guest.sequence[role], messages: guest.messages[other].slice(0, 16) };
      }) };
    });
  }

  exchange(guest, role, link) {
    const other = role === 'host' ? 'guest' : 'host';
    requireValue(Number.isInteger(link.cursor) && link.cursor >= 0 && link.cursor <= guest.sequence[other]);
    requireValue(Array.isArray(link.messages) && link.messages.length <= 16);
    for (const message of link.messages) {
      requireValue(message && Number.isInteger(message.seq) && message.seq > 0 && message.seq <= 256);
      if (message.seq <= guest.sequence[role]) continue;
      requireValue(message.seq === guest.sequence[role] + 1, 'SIGNAL OUT OF ORDER', 409);
      if (message.type === 'offer' || message.type === 'answer') {
        requireValue(message.type === (role === 'host' ? 'offer' : 'answer'));
        requireValue(!guest.description[role], 'HANDSHAKE ALREADY SENT', 409);
        requireValue(typeof message.sdp === 'string' && message.sdp.length > 0 && message.sdp.length <= 16000);
        guest.description[role] = true;
      } else {
        requireValue(message.type === 'ice');
        requireValue(typeof message.media === 'string' && message.media.length <= 64);
        requireValue(Number.isInteger(message.index) && message.index >= 0 && message.index < 16);
        requireValue(typeof message.candidate === 'string' && message.candidate.length <= 2048);
      }
      const clean = message.type === 'ice'
        ? { seq: message.seq, type: message.type, media: message.media, index: message.index, candidate: message.candidate }
        : { seq: message.seq, type: message.type, sdp: message.sdp };
      guest.messages[role].push(clean);
      guest.sequence[role] = message.seq;
    }
    if (link.ready === true) guest.ready[role] = true;
    guest.messages[other] = guest.messages[other].filter(message => message.seq > link.cursor);
  }
}
