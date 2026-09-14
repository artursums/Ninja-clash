import { test, expect } from '@playwright/test';

const base = process.env.NINJA_TEST_URL || (process.env.NINJA_TEST_TURN ? 'http://127.0.0.1:8788' : 'http://127.0.0.1:8787');
async function click(page, x, y) {
  const box = await page.locator('canvas').boundingBox();
  const scale = Math.min(box.width / 800, box.height / 450);
  await page.mouse.click(box.x + (box.width - 800 * scale) / 2 + x * scale, box.y + (box.height - 450 * scale) / 2 + y * scale);
}
const state = page => page.evaluate(() => window.__ninjaState);
const screen = (page, expected) => expect.poll(async () => (await state(page))?.state).toBe(expected);

async function openGame(context, url = base, forceRelay = false) {
  const page = await context.newPage();
  const errors = [];
  page.on('console', message => {
    if (message.text().includes('[STATE]') || message.type() === 'error') console.log(message.text());
    if (message.type() === 'error' && /^ERROR:|SCRIPT ERROR|Parse Error|RPC|WebRTC/i.test(message.text())) { errors.push(message.text()); console.log(message.text()); }
  });
  page.on('pageerror', error => errors.push(error.message));
  await page.addInitScript(forceRelay => {
    window.__ninjaTest = true;
    window.__ninjaConnections = [];
    const Original = window.RTCPeerConnection;
    window.RTCPeerConnection = class extends Original {
      constructor(config, ...args) {
        super(forceRelay ? { ...config, iceTransportPolicy: 'relay' } : config, ...args);
        window.__ninjaConnections.push(this);
      }
    };
  }, forceRelay);
  await page.goto(url);
  await expect.poll(async () => (await state(page))?.state).toBeTruthy();
  if ((await state(page)).state === 'PROLOGUE') {
    await page.keyboard.press('Enter');
    if (!url.includes('#room=')) {
      await page.waitForTimeout(400);
      await page.keyboard.press('Escape');
    }
    await expect.poll(async () => (await state(page))?.state).not.toBe('PROLOGUE');
    await page.waitForTimeout(1300);
  }
  return { page, errors };
}

async function enterName(page, name) {
  await expect.poll(async () => (await state(page)).nameDialog).toBe(true);
  await click(page, 400, 220);
  await page.keyboard.press('ControlOrMeta+A');
  await page.keyboard.type(name, { delay: 25 });
  await page.keyboard.press('Enter');
  await expect.poll(async () => (await state(page)).nameDialog).toBe(false);
  expect((await state(page)).playerName).toBe(name.trim().slice(0, 16));
  await page.waitForTimeout(350);
}

async function createRoom(page) {
  await screen(page, 'TITLE');
  await click(page, 190, 220);
  if ((await state(page)).state === 'TITLE') {
    await page.waitForTimeout(400);
    await click(page, 190, 220);
  }
  await screen(page, 'ONLINE_MENU');
  await enterName(page, 'Host');
  await click(page, 400, 138);
  await screen(page, 'ONLINE_LOBBY');
  await expect.poll(async () => (await state(page)).room).toMatch(/^[A-F0-9]{12}$/);
  return (await state(page)).room;
}

async function ready(page) {
  const slot = (await state(page)).localPlayer.slot;
  await click(page, 120 + (slot - 1) * 188, 324);
  await expect.poll(async () => (await state(page)).localPlayer.ready).toBe(true);
}

async function playMatch(browser, testInfo, count, forceRelay) {
  test.setTimeout(240000);
  const contexts = [], players = [];
  const open = async (url = base) => {
    const context = await browser.newContext();
    contexts.push(context);
    return openGame(context, url, forceRelay);
  };
  try {
    const host = await open();
    players.push(host);
    const room = await createRoom(host.page);
    expect((await state(host.page)).canStart).toBe(false);
    for (let index = 1; index < count; index++) {
      const guest = await open(`${base}/#room=${room}`);
      await enterName(guest.page, `Guest ${index}`);
      await click(guest.page, 400, 196);
      await screen(guest.page, 'ONLINE_LOBBY');
      players.push(guest);
      await expect.poll(async () => (await state(host.page)).players.length).toBe(index + 1);
    }
    for (const player of players) await expect.poll(async () => (await state(player.page)).players.length).toBe(count);
    if (count === 4) {
      const extra = await open(`${base}/#room=${room}`);
      await enterName(extra.page, 'Fifth');
      await click(extra.page, 400, 196);
      await expect.poll(async () => (await state(extra.page)).status).toMatch(/FULL/);
      expect((await state(extra.page)).mode).toBe(0);
      expect(extra.errors).toEqual([]);
      await extra.page.close();
    }
    await ready(host.page);
    expect((await state(host.page)).canStart).toBe(false);
    for (const player of players.slice(1)) await ready(player.page);
    await expect.poll(async () => (await state(host.page)).canStart).toBe(true);
    await host.page.waitForTimeout(600);
    await screen(host.page, 'ONLINE_LOBBY');
    await click(host.page, 172, 378);
    for (const player of players) await expect.poll(async () => (await state(player.page)).players.every(p => !p.ready)).toBe(true);
    if (count === 2) {
      const before = (await state(host.page)).rules.katana;
      await click(host.page, 414, 378);
      await screen(host.page, 'MATCH_SETUP');
      await host.page.waitForTimeout(300);
      await click(host.page, 410, 94);
      await click(host.page, 410, 346);
      await expect.poll(async () => (await state(host.page)).rules.roundTime).toBe(90);
      for (let i = 0; i < 3; i++) { await host.page.keyboard.press('ArrowLeft'); await host.page.waitForTimeout(100); }
      await expect.poll(async () => (await state(host.page)).rules.roundTime).toBe(0);
      await host.page.screenshot({ path: testInfo.outputPath('timer-disabled.png') });
      for (let i = 0; i < 3; i++) { await host.page.keyboard.press('ArrowRight'); await host.page.waitForTimeout(100); }
      await expect.poll(async () => (await state(host.page)).rules.roundTime).toBe(90);
      await host.page.keyboard.press('Escape');
      await screen(host.page, 'ONLINE_LOBBY');
      await expect.poll(async () => (await state(players[1].page)).rules.katana).toBe(!before);
      await expect.poll(async () => (await state(players[1].page)).rules.roundTime).toBe(90);
      await click(players[1].page, 414, 378);
      await players[1].page.screenshot({ path: testInfo.outputPath('shared-rules.png') });
      await players[1].page.keyboard.press('Escape');
    }
    for (const player of players) await ready(player.page);
    await host.page.screenshot({ path: testInfo.outputPath(`${count}-player-lobby.png`) });
    if (count === 2) await host.page.keyboard.press('f');
    else await click(host.page, 640, 378);
    for (const player of players) await screen(player.page, 'MATCH_INTRO');
    await host.page.waitForTimeout(600);
    if (count === 2) await host.page.screenshot({ path: testInfo.outputPath('controls-tutorial.png') });
    for (const player of players) await player.page.keyboard.press('Enter');
    for (const player of players) {
      await screen(player.page, 'ROUND');
      expect((await state(player.page)).fighters.length).toBe(count);
      expect((await state(player.page)).clock[1]).toBeGreaterThan(count === 2 ? 80 : 50);
    }
    await expect.poll(async () => (await state(host.page)).perks?.length, { timeout: 15000 }).toBeGreaterThan(0);
    const capsules = (await state(host.page)).perks.map(row => row.slice(0, 4));
    const hostClock = (await state(host.page)).clock[1];
    for (const guest of players.slice(1)) expect(Math.abs((await state(guest.page)).clock[1] - hostClock)).toBeLessThan(1);
    if (count === 2) expect(capsules.every(row => row[1] !== 3)).toBe(true);
    for (const guest of players.slice(1)) {
      await expect.poll(async () => (await state(guest.page)).perks.map(row => row.slice(0, 4))).toEqual(capsules);
    }
    await expect.poll(async () => (await state(host.page)).perks.some(row => row[4] === 0)).toBe(true);
    await players.at(-1).page.screenshot({ path: testInfo.outputPath(`${count}-player-perks.png`) });
    for (let index = 1; index < players.length; index++) {
      const guest = players[index];
      const peer = (await state(guest.page)).localPlayer.peer;
      const slot = (await state(guest.page)).localPlayer.slot;
      const before = (await state(guest.page)).fighters.find(p => p.slot === slot).x;
      await guest.page.keyboard.down('d');
      await guest.page.keyboard.press('Space');
      await expect.poll(async () => (await state(host.page)).remoteHeld[peer]?.held).toBeGreaterThan(0);
      await expect.poll(async () => Math.abs((await state(guest.page)).fighters.find(p => p.slot === slot).x - before)).toBeGreaterThan(20);
      await guest.page.keyboard.up('d');
      await expect.poll(async () => (await state(host.page)).remoteHeld[peer]?.held).toBe(0);
    }
    await host.page.keyboard.down('w');
    await host.page.keyboard.down('l');
    await host.page.waitForTimeout(200);
    await host.page.keyboard.up('l');
    await host.page.keyboard.up('w');
    for (const guest of players.slice(1)) await expect.poll(async () => (await state(guest.page)).puppets).toBeGreaterThan(0);
    await players.at(-1).page.screenshot({ path: testInfo.outputPath(`${count}-player-round.png`) });
    const routes = await players[1].page.evaluate(async () => {
      const pc = window.__ninjaConnections.find(connection => connection.connectionState === 'connected');
      if (!pc) return null;
      const stats = await pc.getStats();
      const transport = [...stats.values()].find(s => s.type === 'transport' && s.selectedCandidatePairId);
      const pair = transport && stats.get(transport.selectedCandidatePairId);
      return pair ? { local: stats.get(pair.localCandidateId)?.candidateType, remote: stats.get(pair.remoteCandidateId)?.candidateType } : null;
    });
    expect(routes).not.toBeNull();
    if (forceRelay) expect(routes.local).toBe('relay');
    await testInfo.attach('connection.json', { body: JSON.stringify({ routes, host: await state(host.page) }, null, 2), contentType: 'application/json' });
    if (count >= 3) {
      await players.at(-1).page.close();
      for (const player of players.slice(0, -1)) await screen(player.page, 'ONLINE_LOBBY');
      expect((await state(host.page)).players.length).toBe(count - 1);
      expect((await state(host.page)).players.every(p => !p.ready)).toBe(true);
      expect((await state(host.page)).playerName).toBe('Host');
      const replacement = await open(`${base}/#room=${room}`);
      await enterName(replacement.page, 'Replacement');
      await click(replacement.page, 400, 196);
      await screen(replacement.page, 'ONLINE_LOBBY');
      await expect.poll(async () => (await state(host.page)).players.length).toBe(count);
      expect((await state(replacement.page)).localPlayer.slot).toBe(count);
      expect(replacement.errors).toEqual([]);
    }
    await host.page.close();
    await screen(players[1].page, 'ONLINE_MENU');
    expect((await state(players[1].page)).status).toMatch(/LOST|LEFT/);
    expect((await state(players[1].page)).playerName).toBe('Guest 1');
    for (const player of players) expect(player.errors).toEqual([]);
  } finally {
    for (const context of contexts) await context.close();
  }
}

for (const count of [2, 3, 4]) {
  test(`${count} browsers share a ready lobby and play through WebRTC`, async ({ browser }, testInfo) => {
    await playMatch(browser, testInfo, count, false);
  });
}

test('four browsers play with TURN forced on every peer', async ({ browser }, testInfo) => {
  test.skip(!process.env.NINJA_TEST_TURN, 'Run with local coturn or configured TURN credentials');
  await playMatch(browser, testInfo, 4, true);
});

test('name is mandatory, retained on failed join and cleared on leaving multiplayer', async ({ browser }, testInfo) => {
  const context = await browser.newContext();
  try {
    const { page, errors } = await openGame(context, `${base}/#room=000000000000`);
    await expect.poll(async () => (await state(page)).nameDialog).toBe(true);
    await page.screenshot({ path: testInfo.outputPath('player-name.png') });
    await page.keyboard.type('   ');
    await page.keyboard.press('Enter');
    await page.waitForTimeout(350);
    expect((await state(page)).nameDialog).toBe(true);
    await enterName(page, 'Mari');
    await click(page, 400, 196);
    await expect.poll(async () => (await state(page)).status).toMatch(/NOT FOUND|EXPIRED/);
    expect((await state(page)).mode).toBe(0);
    expect((await state(page)).playerName).toBe('Mari');
    expect((await state(page)).nameDialog).toBe(false);
    await click(page, 400, 138);
    await screen(page, 'ONLINE_LOBBY');
    await page.waitForTimeout(350);
    await click(page, 720, 54);
    await screen(page, 'TITLE');
    expect((await state(page)).playerName).toBe('');
    expect(errors).toEqual([]);
  } finally { await context.close(); }
});
