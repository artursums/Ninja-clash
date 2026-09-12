// Compare-and-set keeps guest admission and signaling atomic across Vercel instances.
export class RedisStore {
  constructor(env = process.env, fetcher = fetch) {
    this.url = env.UPSTASH_REDIS_REST_URL || env.KV_REST_API_URL;
    this.token = env.UPSTASH_REDIS_REST_TOKEN || env.KV_REST_API_TOKEN;
    this.fetcher = fetcher;
    if (!this.url || !this.token) throw new Error('Redis is not configured');
  }

  async command(...args) {
    const response = await this.fetcher(this.url, {
      method: 'POST',
      headers: { Authorization: `Bearer ${this.token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(args), signal: AbortSignal.timeout(5000),
    });
    if (!response.ok) throw new Error('Redis request failed');
    const data = await response.json();
    if (data.error) throw new Error('Redis command failed');
    return data.result;
  }

  get(key) { return this.command('GET', key); }

  async compareSet(key, previous, next, ttl) {
    return Number(await this.command('EVAL', `
      local current = redis.call('GET', KEYS[1])
      if (ARGV[1] == '' and not current) or current == ARGV[1] then
        redis.call('SET', KEYS[1], ARGV[2], 'EX', ARGV[3])
        return 1
      end
      return 0`, 1, key, previous ?? '', next, ttl)) === 1;
  }

  async limit(key, maximum, seconds) {
    return Number(await this.command('EVAL', `
      local n = redis.call('INCR', KEYS[1])
      if n == 1 then redis.call('EXPIRE', KEYS[1], ARGV[1]) end
      return n`, 1, key, seconds)) <= maximum;
  }
}

// Only the explicit localhost development server uses this store.
export class MemoryStore {
  constructor(now = Date.now) { this.entries = new Map(); this.now = now; }
  purge() {
    for (const [key, item] of this.entries) if (item.expires <= this.now()) this.entries.delete(key);
  }
  async get(key) { this.purge(); return this.entries.get(key)?.value ?? null; }
  async compareSet(key, previous, next, ttl) {
    this.purge();
    if ((this.entries.get(key)?.value ?? null) !== previous) return false;
    this.entries.set(key, { value: next, expires: this.now() + ttl * 1000 });
    return true;
  }
  async limit(key, maximum, seconds) {
    this.purge();
    const entry = this.entries.get(key) ?? { value: 0, expires: this.now() + seconds * 1000 };
    entry.value += 1;
    this.entries.set(key, entry);
    return entry.value <= maximum;
  }
}
