import { cp, mkdir, writeFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = fileURLToPath(new URL('../../', import.meta.url));
const destination = path.join(root, 'build/ninja-clash');
const godot = process.env.GODOT || (process.platform === 'darwin' ? '/Applications/Godot.app/Contents/MacOS/Godot' : 'godot');
await mkdir(path.join(destination, 'public'), { recursive: true });
const debug = process.argv.includes('--debug');
const child = spawn(godot, ['--headless', '--path', path.join(root, 'ninja_clash'),
  debug ? '--export-debug' : '--export-release', 'Web', path.join(destination, 'public/index.html')], { stdio: 'inherit' });
const code = await new Promise(resolve => { child.on('error', () => resolve(1)); child.on('exit', resolve); });
if (code !== 0) process.exit(code ?? 1);
for (const entry of ['api', 'server', 'vercel.json', '.vercelignore']) {
  await cp(path.join(root, 'web', entry), path.join(destination, entry), { recursive: true });
}
await writeFile(path.join(destination, 'package.json'), JSON.stringify({ private: true, type: 'module', engines: { node: '22.x' } }, null, 2) + '\n');
console.log(`Prepared ${debug ? 'debug' : 'release'} web game and room API in ${destination}`);
