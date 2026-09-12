import { RedisStore } from '../server/store.mjs';
import { iceConfiguration } from '../server/ice.mjs';

try {
  console.log('Checking Redis credentials…');
  const store = new RedisStore();
  if (await store.command('PING') !== 'PONG') throw new Error('Unexpected Redis response');
  console.log('Redis: OK');
  console.log('Checking temporary TURN credential generation…');
  const rtc = await iceConfiguration();
  if (!rtc.iceServers.some(s => [].concat(s.urls ?? []).some(u => /^turns?:/.test(u)))) throw new Error('No TURN server returned');
  console.log('TURN credential generation: OK. A browser relay test is still required.');
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
