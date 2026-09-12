import { RedisStore } from '../server/store.mjs';
import { iceConfiguration } from '../server/ice.mjs';
import { Rooms, RoomError } from '../server/rooms.mjs';

export function handlerFor(getRooms) {
  return async function handler(req, res) {
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Referrer-Policy', 'no-referrer');
    if (req.method !== 'POST') {
      res.setHeader('Allow', 'POST');
      return res.status(405).json({ error: 'POST REQUIRED' });
    }
    if (req.headers.origin && req.headers.origin !== `https://${req.headers.host}` && req.headers.origin !== `http://${req.headers.host}`) {
      return res.status(403).json({ error: 'ORIGIN NOT ALLOWED' });
    }
    if (!req.headers['content-type']?.startsWith('application/json')) return res.status(415).json({ error: 'JSON REQUIRED' });
    try {
      const raw = typeof req.body === 'string' ? req.body : JSON.stringify(req.body);
      if (!raw || Buffer.byteLength(raw) > 65536) throw new RoomError(413, 'REQUEST TOO LARGE');
      const body = typeof req.body === 'string' ? JSON.parse(raw) : req.body;
      const ip = String(req.headers['x-forwarded-for'] ?? req.socket?.remoteAddress ?? 'unknown').split(',')[0].trim();
      const result = await getRooms().handle(body, ip);
      return res.status(200).json(result);
    } catch (error) {
      if (error instanceof RoomError) return res.status(error.status).json({ error: error.message });
      if (error instanceof SyntaxError) return res.status(400).json({ error: 'INVALID JSON' });
      // Never include upstream responses, room tokens or TURN secrets in client errors.
      return res.status(503).json({ error: 'ONLINE SERVICE UNAVAILABLE — TRY AGAIN LATER' });
    }
  };
}

let rooms;
export default handlerFor(() => rooms ??= new Rooms(new RedisStore(), () => iceConfiguration()));
