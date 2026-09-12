import { createHash } from 'node:crypto';
import { createReadStream, createWriteStream } from 'node:fs';
import { chmod, mkdir, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { pipeline } from 'node:stream/promises';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../../', import.meta.url));
const version = '4.6.2';
const release = `https://github.com/godotengine/godot-builds/releases/download/${version}-stable`;
const editorName = `Godot_v${version}-stable_linux.x86_64`;
const editorHash = '30e6b6d141f0cd5bebd629ad1d0ef1324e60091bb20662d026b402ba58c59937';
const templatesHash = '942366dc4e27e7686a99da4d3cfb1b8ae8d3eb9444f6d8217eef16245b599ef2';

async function run(command, args, env = process.env) {
  await new Promise((resolve, reject) => {
    const child = spawn(command, args, { cwd: root, env, stdio: ['ignore', 'pipe', 'pipe'] });
    let scriptError = false;
    for (const [source, destination] of [[child.stdout, process.stdout], [child.stderr, process.stderr]]) {
      let tail = '';
      source.on('data', chunk => {
        destination.write(chunk);
        const output = tail + chunk.toString();
        scriptError ||= /SCRIPT ERROR:|Failed to load script/.test(output);
        tail = output.slice(-256);
      });
    }
    child.once('error', reject);
    // Godot can exit successfully even when a required GDScript failed to compile.
    child.once('close', (code, signal) => code === 0 && !scriptError ? resolve() : reject(new Error(`${path.basename(command)} failed (${scriptError ? 'script errors' : signal ?? code})`)));
  });
}

async function download(name, destination, expectedHash) {
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      console.log(`Downloading Godot ${name} (attempt ${attempt})`);
      const response = await fetch(`${release}/${name}`, { signal: AbortSignal.timeout(600_000) });
      if (!response.ok || !response.body) throw new Error(`Download returned HTTP ${response.status}`);
      await pipeline(response.body, createWriteStream(destination));
      const hash = createHash('sha256');
      for await (const chunk of createReadStream(destination)) hash.update(chunk);
      if (hash.digest('hex') !== expectedHash) throw new Error(`Checksum mismatch for ${name}`);
      return;
    } catch (error) {
      await rm(destination, { force: true });
      if (attempt === 3) throw error;
      console.warn(`Download did not complete: ${error.message}`);
    }
  }
}

let workspace;
try {
  let godot = process.env.GODOT;
  let env = { ...process.env };
  if (!godot) {
    if (process.platform !== 'linux' || process.arch !== 'x64') {
      throw new Error('Automatic Godot installation requires Linux x64. For a local build set GODOT to your installed Godot 4.6.2 executable.');
    }
    workspace = await mkdtemp(path.join(tmpdir(), 'ninja-godot-'));
    const editorZip = path.join(workspace, 'editor.zip');
    const templatesZip = path.join(workspace, 'templates.tpz');
    // Pin and verify official releases; never execute an unverified downloaded engine.
    const downloads = await Promise.allSettled([
      download(`${editorName}.zip`, editorZip, editorHash),
      download(`Godot_v${version}-stable_export_templates.tpz`, templatesZip, templatesHash),
    ]);
    for (const result of downloads) if (result.status === 'rejected') throw result.reason;
    const data = path.join(workspace, 'data');
    const templates = path.join(data, 'godot/export_templates', `${version}.stable`);
    await mkdir(templates, { recursive: true });
    await run('unzip', ['-q', editorZip, editorName, '-d', workspace]);
    await run('unzip', ['-q', '-j', templatesZip, 'templates/web_release.zip', 'templates/version.txt', '-d', templates]);
    godot = path.join(workspace, editorName);
    await chmod(godot, 0o755);
    env = { ...env, XDG_DATA_HOME: data };
  }
  env.GODOT = godot;
  await run(godot, ['--version'], env);
  // A Git checkout has no imported textures or global script class cache yet.
  await run(godot, ['--headless', '--path', path.join(root, 'ninja_clash'), '--editor', '--import'], env);
  await run(process.execPath, [path.join(root, 'web/tools/export.mjs')], env);
} finally {
  if (workspace) await rm(workspace, { recursive: true, force: true });
}
