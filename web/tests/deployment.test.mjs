import test from 'node:test';
import assert from 'node:assert/strict';
import { chmod, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { execFileSync, spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../../', import.meta.url));

test('build rejects Godot script errors even when the engine exits with status zero', async () => {
  const directory = await mkdtemp(path.join(tmpdir(), 'ninja-build-failure-'));
  try {
    const engine = path.join(directory, 'godot.mjs');
    await writeFile(engine, '#!/usr/bin/env node\nif (process.argv.includes("--import")) process.stderr.write("SCRIPT ERROR: missing game resource\\n");\n');
    await chmod(engine, 0o700);
    const result = spawnSync(process.execPath, [path.join(root, 'web/tools/build-vercel.mjs')], {
      cwd: root, env: { ...process.env, GODOT: engine }, encoding: 'utf8', timeout: 10000,
    });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /failed \(script errors\)/);
    assert.doesNotMatch(result.stdout, /Prepared release web game/);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test('deployment filtering retains game resources while excluding local files and secrets', async () => {
  const directory = await mkdtemp(path.join(tmpdir(), 'ninja-deployment-filter-'));
  try {
    execFileSync('git', ['init', '-q', directory]);
    await writeFile(path.join(directory, '.gitignore'), await readFile(path.join(root, '.vercelignore')));
    const sourceFiles = execFileSync('git', ['ls-files', '-z', 'ninja_clash', 'api', 'web/server', 'web/api', 'web/tools'], { cwd: root }).toString().split('\0').filter(Boolean);
    const privateFiles = ['web/.env.local', '.env', 'levels/Screenshot.png', 'backups/local.zip', 'artifacts/test.png'];
    const result = spawnSync('git', ['-c', 'core.excludesFile=', 'check-ignore', '--no-index', '-z', '--stdin'], {
      cwd: directory, input: [...sourceFiles, ...privateFiles].join('\0') + '\0', encoding: 'utf8',
    });
    assert.ok(result.status === 0 || result.status === 1, result.stderr);
    const ignored = new Set(result.stdout.split('\0').filter(Boolean));
    assert.deepEqual(sourceFiles.filter(file => ignored.has(file)), [], 'Required game and server files must reach the build');
    assert.deepEqual(privateFiles.filter(file => !ignored.has(file)), [], 'Local files and secrets must remain excluded');
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});
