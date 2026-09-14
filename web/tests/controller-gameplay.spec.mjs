import { test, expect as baseExpect } from '@playwright/test';

const expect = baseExpect.configure({ timeout: 10000 });

// These emulate browser-normalized input, not physical hardware or its drivers.
const profiles = [
  { name: 'Xbox standard mapping', id: 'Xbox Wireless Controller (STANDARD GAMEPAD)', buttons: 17, axes: 4 },
  { name: 'PlayStation standard mapping', id: 'Wireless Controller (STANDARD GAMEPAD Vendor: 054c Product: 0ce6)', buttons: 18, axes: 4 },
  { name: 'generic standard mapping', id: 'USB Gamepad (STANDARD GAMEPAD)', buttons: 17, axes: 6 },
];

for (const profile of profiles) {
  test(`${profile.name}: full match controls and reconnect`, async ({ page }, testInfo) => {
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('console', message => {
      if (/SCRIPT ERROR:|Failed to load script/.test(message.text())) errors.push(message.text());
    });
    await page.addInitScript(() => {
      window.__ninjaTest = true;
      window.__pads = [];
      Object.defineProperty(navigator, 'getGamepads', { configurable: true, value: () => window.__pads });
    });
    await page.goto(process.env.NINJA_TEST_URL || 'http://127.0.0.1:8787');
    const state = () => page.evaluate(() => window.__ninjaState);
    const fighter = async slot => (await state()).fighters.find(p => p.slot === slot);
    const screen = name => expect.poll(async () => (await state())?.state).toBe(name);
    async function connect(device, details = profile) {
      await page.evaluate(({ device, details }) => {
        const pad = { index: device, id: details.id, connected: true, mapping: 'standard',
          timestamp: performance.now(), axes: Array(details.axes).fill(0),
          buttons: Array.from({ length: details.buttons }, () => ({ pressed: false, touched: false, value: 0 })) };
        while (window.__pads.length <= device) window.__pads.push(null);
        window.__pads[device] = pad;
        const event = new Event('gamepadconnected');
        Object.defineProperty(event, 'gamepad', { value: pad });
        window.dispatchEvent(event);
      }, { device, details });
      await page.waitForTimeout(200);
    }
    async function button(device, index, value) {
      await page.evaluate(({ device, index, value }) => {
        const pad = window.__pads[device];
        pad.buttons[index] = { pressed: value > 0.5, touched: value > 0, value };
        pad.timestamp = performance.now();
      }, { device, index, value });
    }
    async function tap(device, index) {
      await button(device, index, 1);
      await page.waitForTimeout(120);
      await button(device, index, 0);
      await page.waitForTimeout(220);
    }
    async function axis(device, index, value) {
      await page.evaluate(({ device, index, value }) => {
        window.__pads[device].axes[index] = value;
        window.__pads[device].timestamp = performance.now();
      }, { device, index, value });
    }
    await screen('WELCOME');
    await connect(0);
    await connect(2, profiles[2]); // Mixed models and a gap in browser device indices.
    await tap(0, 0);
    await screen('TITLE');
    await page.waitForTimeout(1400);
    await tap(0, 0);
    await screen('MODE_SELECT');
    await tap(0, 0); // Party size.
    await tap(0, 0); // Two humans.
    await screen('CLAN_SELECT');
    await tap(0, 0);
    await tap(2, 0);
    await screen('MAP_SELECT');
    await tap(0, 0); // Focus Fight.
    await tap(0, 0);
    await screen('ROUND');
    for (const [device, slot] of [[0, 1], [2, 2]]) {
      await expect.poll(async () => (await fighter(slot)).grounded).toBe(true);
      const start = await fighter(slot);
      const otherSlot = slot === 1 ? 2 : 1;
      const other = await fighter(otherSlot);
      await axis(device, 0, 0.15);
      await page.waitForTimeout(250);
      expect((await fighter(slot)).x).toBeCloseTo(start.x, 0); // Ignore stick drift.
      await axis(device, 0, slot === 1 ? -0.9 : 0.9);
      await expect.poll(async () => Math.abs((await fighter(slot)).x - start.x)).toBeGreaterThan(12);
      await axis(device, 0, 0);
      expect((await fighter(otherSlot)).x).toBeCloseTo(other.x, 0);
      await tap(device, slot === 1 ? 15 : 14); // D-pad returns towards the arena.
      await expect.poll(async () => (await fighter(slot)).grounded).toBe(true);
      const groundY = (await fighter(slot)).y;
      await button(device, 0, 1);
      await expect.poll(async () => (await fighter(slot)).y, { intervals: [20] }).toBeLessThan(groundY - 8);
      await button(device, 0, 0);
      await expect.poll(async () => (await fighter(slot)).grounded).toBe(true);
      await button(device, 6, 0.8); // Browser LT/L2 becomes Godot's left trigger axis.
      await expect.poll(async () => (await fighter(slot)).guard).toBe(true);
      await button(device, 6, 0);
      await expect.poll(async () => (await fighter(slot)).guard).toBe(false);
      const throws = (await fighter(slot)).throws;
      await button(device, 2, 1);
      await expect.poll(async () => (await fighter(slot)).aiming).toBe(true);
      await button(device, 2, 0);
      await expect.poll(async () => (await fighter(slot)).throws).toBe(throws + 1);
      const strikes = (await fighter(slot)).strikes;
      await tap(device, 3);
      await expect.poll(async () => (await fighter(slot)).strikes).toBe(strikes + 1);
      await button(device, 7, 0.9); // RT/R2 dash.
      await expect.poll(async () => (await fighter(slot)).dashing, { intervals: [20] }).toBe(true);
      await button(device, 7, 0);
      await expect.poll(async () => (await fighter(slot)).dashing).toBe(false);
    }
    await tap(0, 9); // Menu/Options pauses.
    await expect.poll(async () => (await state()).paused).toBe(true);
    await page.screenshot({ path: testInfo.outputPath('controller-pause.png') });
    await tap(2, 1); // Another controller can resume with B/Circle.
    await expect.poll(async () => (await state()).paused).toBe(false);
    await axis(2, 0, 0.9);
    await page.waitForTimeout(150);
    await page.evaluate(() => {
      const pad = window.__pads[2];
      pad.connected = false;
      window.__pads[2] = null;
      const event = new Event('gamepaddisconnected');
      Object.defineProperty(event, 'gamepad', { value: pad });
      window.dispatchEvent(event);
    });
    await expect.poll(async () => (await state()).controllers.length).toBe(1);
    await connect(3, profiles[2]);
    await expect.poll(async () => (await state()).controllers.length).toBe(2);
    const reconnected = await fighter(2);
    await page.waitForTimeout(250);
    expect((await fighter(2)).x).toBeCloseTo(reconnected.x, 0); // No stale held direction.
    await axis(3, 0, -0.9);
    await expect.poll(async () => Math.abs((await fighter(2)).x - reconnected.x)).toBeGreaterThan(12);
    await axis(3, 0, 0);
    expect(errors).toEqual([]);
  });
}
