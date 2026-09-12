import { spawn } from 'node:child_process';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import { randomBytes } from 'node:crypto';
import { tmpdir } from 'node:os';
import path from 'node:path';
import net from 'node:net';
import { setTimeout as delay } from 'node:timers/promises';

const dir = await mkdtemp(path.join(tmpdir(), 'ninja-turn-'));
const secret = randomBytes(32).toString('hex');
const config = path.join(dir, 'turnserver.conf');
await writeFile(config, `listening-ip=127.0.0.1
relay-ip=127.0.0.1
listening-port=34790
min-port=34800
max-port=34830
realm=ninja-local-test
use-auth-secret
static-auth-secret=${secret}
fingerprint
allow-loopback-peers
no-multicast-peers
no-cli
no-tls
no-dtls
no-rfc5780
relay-threads=1
pidfile=${dir}/turn.pid
log-file=${dir}/turn.log
`, { mode: 0o600 });
const turn = spawn(process.env.TURN_SERVER || 'turnserver', ['-c', config], { stdio: ['ignore', 'ignore', 'pipe'] });
let child;
let stopping = false;
async function stop(code = 0) {
  if (stopping) return;
  stopping = true;
  if (child && child.exitCode === null) { const exited = new Promise(resolve => child.once('exit', resolve)); child.kill('SIGTERM'); await exited; }
  if (turn.exitCode === null) { const exited = new Promise(resolve => turn.once('exit', resolve)); turn.kill('SIGTERM'); await exited; }
  await rm(dir, { recursive: true, force: true });
  process.exit(code);
}
process.on('SIGTERM', () => stop());
process.on('SIGINT', () => stop());
turn.on('error', error => { console.error(`Install coturn or set TURN_SERVER: ${error.message}`); stop(1); });
turn.on('exit', code => { if (!stopping) { console.error(`Local TURN exited with ${code}`); stop(1); } });
let ready = false;
for (let attempt = 0; attempt < 50; attempt++) {
  ready = await new Promise(resolve => {
    const socket = net.connect(34790, '127.0.0.1');
    socket.once('connect', () => { socket.destroy(); resolve(true); });
    socket.once('error', () => resolve(false));
  });
  if (ready) break;
  await delay(100);
}
if (!ready) { console.error('Local TURN did not start'); await stop(1); }
child = spawn(process.execPath, ['tools/serve.mjs'], {
  stdio: 'inherit', env: { ...process.env, PORT: '8788', TURN_URLS: 'turn:127.0.0.1:34790?transport=udp', TURN_SHARED_SECRET: secret },
});
child.on('exit', code => { if (!stopping) stop(code ?? 1); });
