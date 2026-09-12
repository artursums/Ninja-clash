import { createHmac } from 'node:crypto';

export async function iceConfiguration(env = process.env, fetcher = fetch, now = Date.now()) {
  if (env.CLOUDFLARE_TURN_KEY_ID && env.CLOUDFLARE_TURN_API_TOKEN) {
    const id = encodeURIComponent(env.CLOUDFLARE_TURN_KEY_ID);
    const response = await fetcher(`https://rtc.live.cloudflare.com/v1/turn/keys/${id}/credentials/generate-ice-servers`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${env.CLOUDFLARE_TURN_API_TOKEN}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ ttl: 14400 }), signal: AbortSignal.timeout(7000),
    });
    if (!response.ok) throw new Error('TURN credentials unavailable');
    const data = await response.json();
    if (!Array.isArray(data.iceServers) || !data.iceServers.some(s => [].concat(s.urls ?? []).some(u => /^turns?:/.test(u)))) {
      throw new Error('Invalid TURN configuration');
    }
    return { iceServers: data.iceServers };
  }
  if (env.TURN_URLS && env.TURN_SHARED_SECRET) {
    const urls = env.TURN_URLS.split(',').map(s => s.trim());
    if (urls.some(url => !/^turns?:[^\s]+$/.test(url))) throw new Error('Invalid TURN URLs');
    const username = `${Math.floor(now / 1000) + 14400}:ninja`;
    const credential = createHmac('sha1', env.TURN_SHARED_SECRET).update(username).digest('base64');
    return { iceServers: [{ urls, username, credential }] };
  }
  if (env.NINJA_LOCAL_DEV === '1' && !env.VERCEL) return { iceServers: [] };
  throw new Error('TURN is not configured');
}
