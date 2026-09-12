import { test, expect } from '@playwright/test';

const base = process.env.NINJA_TEST_TURN ? 'http://127.0.0.1:8788' : 'http://127.0.0.1:8787';
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
    if (message.text().includes('[STATE]')) console.log(message.text());
    if (message.type() === 'error' && /SCRIPT ERROR|Parse Error|RPC|WebRTC/i.test(message.text())) { errors.push(message.text()); console.log(message.text()); }
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
  return { page, errors };
}

async function createRoom(page) {
  await screen(page, 'TITLE');
  // A first click can skip the title entrance without selecting an item.
  await click(page, 190, 220);
  if ((await state(page)).state === 'TITLE') {
    await page.waitForTimeout(400);
    await click(page, 190, 220);
  }
  await screen(page, 'ONLINE_MENU');
  await click(page, 400, 138);
  await expect.poll(async () => (await state(page)).room).toMatch(/^[A-F0-9]{12}$/);
  return (await state(page)).room;
}

async function playMatch(browser, testInfo, forceRelay) {
  const hostContext = await browser.newContext();
  const guestContext = await browser.newContext();
  try {
    const host = await openGame(hostContext, base, forceRelay);
    const room = await createRoom(host.page);
    await host.page.screenshot({ path: testInfo.outputPath('room.png') });
    const guest = await openGame(guestContext, `${base}/#room=${room}`, forceRelay);
    await screen(guest.page, 'ONLINE_MENU');
    await click(guest.page, 400, 196);
    await Promise.all([screen(host.page, 'CLAN_SELECT'), screen(guest.page, 'CLAN_SELECT')]);
    await host.page.waitForTimeout(400);
    await Promise.all([host.page.keyboard.press('Enter'), guest.page.keyboard.press('Enter')]);
    await Promise.all([screen(host.page, 'MAP_SELECT'), screen(guest.page, 'MAP_SELECT')]);
    await host.page.waitForTimeout(400);
    await click(host.page, 698, 396);
    await Promise.all([screen(host.page, 'MATCH_INTRO'), screen(guest.page, 'MATCH_INTRO')]);
    await host.page.waitForTimeout(600);
    await Promise.all([host.page.keyboard.press('Enter'), guest.page.keyboard.press('Enter')]);
    await Promise.all([screen(host.page, 'ROUND'), screen(guest.page, 'ROUND')]);
    await expect.poll(async () => (await state(host.page)).signalingDone && (await state(guest.page)).signalingDone).toBe(true);
    const before = (await state(guest.page)).fighters.find(p => p.slot === 2).x;
    await guest.page.keyboard.down('d');
    await expect.poll(async () => (await state(host.page)).remoteHeld).not.toBe(0);
    await expect.poll(async () => Math.abs((await state(guest.page)).fighters.find(p => p.slot === 2).x - before)).toBeGreaterThan(20);
    await guest.page.keyboard.up('d');
    await expect.poll(async () => (await state(host.page)).remoteHeld).toBe(0);
    await host.page.keyboard.down('w');
    await host.page.keyboard.down('l');
    await host.page.waitForTimeout(200);
    await host.page.keyboard.up('l');
    await host.page.keyboard.up('w');
    await expect.poll(async () => (await state(guest.page)).puppets).toBeGreaterThan(0);
    await guest.page.screenshot({ path: testInfo.outputPath('guest-round.png') });
    const routes = await guest.page.evaluate(async () => {
      const pc = window.__ninjaConnections.find(connection => connection.connectionState === 'connected');
      if (!pc) return null;
      const stats = await pc.getStats();
      const transport = [...stats.values()].find(s => s.type === 'transport' && s.selectedCandidatePairId);
      const pair = transport && stats.get(transport.selectedCandidatePairId);
      return pair ? { local: stats.get(pair.localCandidateId)?.candidateType, remote: stats.get(pair.remoteCandidateId)?.candidateType } : null;
    });
    expect(routes).not.toBeNull();
    if (forceRelay) expect(routes.local).toBe('relay');
    await testInfo.attach('connection.json', { body: JSON.stringify({ routes, host: await state(host.page), guest: await state(guest.page) }, null, 2), contentType: 'application/json' });
    await host.page.close();
    await screen(guest.page, 'ONLINE_MENU');
    expect((await state(guest.page)).status).toMatch(/LOST|LEFT/);
    expect(host.errors).toEqual([]);
    expect(guest.errors).toEqual([]);
  } finally {
    await hostContext.close();
    await guestContext.close();
  }
}

test('two browsers play through a direct WebRTC connection', async ({ browser }, testInfo) => {
  await playMatch(browser, testInfo, false);
});

test('two browsers play with TURN forced on both peers', async ({ browser }, testInfo) => {
  test.skip(!process.env.NINJA_TEST_TURN, 'Run with local coturn or configured TURN credentials');
  await playMatch(browser, testInfo, true);
});

test('invalid and closed invitations show an error and let the player recover', async ({ browser }) => {
  const context = await browser.newContext();
  try {
    const { page, errors } = await openGame(context, `${base}/#room=000000000000`);
    await click(page, 400, 196);
    await expect.poll(async () => (await state(page)).status).toMatch(/NOT FOUND|EXPIRED/);
    expect((await state(page)).mode).toBe(0);
    await click(page, 400, 138);
    await expect.poll(async () => (await state(page)).room).toMatch(/^[A-F0-9]{12}$/);
    const room = (await state(page)).room;
    await page.keyboard.press('Escape');
    await expect.poll(async () => (await state(page)).mode).toBe(0);
    const other = await openGame(context, `${base}/#room=${room}`);
    await click(other.page, 400, 196);
    await expect.poll(async () => (await state(other.page)).status).toMatch(/CLOSED|EXPIRED/);
    expect(errors).toEqual([]);
    expect(other.errors).toEqual([]);
  } finally { await context.close(); }
});
