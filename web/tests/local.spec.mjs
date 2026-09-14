import { test, expect } from '@playwright/test';

for (const count of [2, 3, 4]) {
  test(`${count} local players choose clans and play without a tutorial`, async ({ page }, testInfo) => {
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
    const screen = expected => expect.poll(async () => (await state())?.state, { timeout: 15000 }).toBe(expected);
    async function click(x, y) {
      const box = await page.locator('canvas').boundingBox();
      const scale = Math.min(box.width / 800, box.height / 450);
      await page.mouse.click(box.x + (box.width - 800 * scale) / 2 + x * scale,
        box.y + (box.height - 450 * scale) / 2 + y * scale);
      await page.waitForTimeout(160);
    }
    await screen('WELCOME');
    await page.keyboard.press('Enter');
    await screen('TITLE');
    await page.waitForTimeout(1600);
    await page.screenshot({ path: testInfo.outputPath('title.png') });
    await page.keyboard.press('Enter');
    await screen('MODE_SELECT');
    await page.waitForTimeout(300);
    await page.screenshot({ path: testInfo.outputPath('modes.png') });
    await page.keyboard.press('Enter');
    await page.waitForTimeout(250);
    // Cancelling party size returns to the cards, preserving the local mode.
    await page.keyboard.press('Escape');
    expect((await state()).state).toBe('MODE_SELECT');
    await page.waitForTimeout(250);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(250);
    await click(400, 179 + (count - 2) * 51);
    await screen('CLAN_SELECT');
    await page.waitForTimeout(350);
    // Two keyboard layouts plus enough controllers for the remaining people.
    await page.evaluate(count => {
      for (let index = 0; index < count - 2; index++) {
        const pad = { index, id: `Local controller ${index}`, connected: true, mapping: 'standard',
          timestamp: 0, axes: [0, 0, 0, 0],
          buttons: Array.from({ length: 17 }, () => ({ pressed: false, touched: false, value: 0 })) };
        window.__pads.push(pad);
        const event = new Event('gamepadconnected');
        Object.defineProperty(event, 'gamepad', { value: pad });
        window.dispatchEvent(event);
      }
    }, count);
    await page.waitForTimeout(250);
    expect((await state()).clanSelection.clans).toHaveLength(count);
    const width = (736 - 16 * (count - 1)) / count;
    for (let index = 0; index < count; index++) {
      await click(118 + index * 188, 225);
      if (index === count - 1) await page.screenshot({ path: testInfo.outputPath('clan-selection.png') });
      const x = 32 + index * (width + 16);
      await click(count > 2 ? x + width - 38 : x + 279, count > 2 ? 386 : 375);
    }
    await screen('MAP_SELECT');
    await page.waitForTimeout(400);
    await click(699, 396);
    await screen('MATCH_INTRO');
    expect((await state()).tutorial).toBe(false);
    await screen('ROUND');
    const fighters = (await state()).fighters;
    expect(fighters).toHaveLength(count);
    for (const fighter of fighters) {
      expect(fighter.isBot).toBe(false);
      expect([fighter.hp, fighter.stash, fighter.katanaCharges]).toEqual([5, 3, 3]);
    }
    if (count > 2) {
      // The first controller must move P3, without moving the keyboard players.
      await expect.poll(async () => (await state()).fighters.find(p => p.slot === 3).grounded).toBe(true);
      const before = (await state()).fighters;
      await page.evaluate(() => { window.__pads[0].axes[0] = 0.9; window.__pads[0].timestamp = performance.now(); });
      await expect.poll(async () => Math.abs((await state()).fighters.find(p => p.slot === 3).x - before.find(p => p.slot === 3).x)).toBeGreaterThan(10);
      for (const slot of [1, 2]) expect((await state()).fighters.find(p => p.slot === slot).x).toBeCloseTo(before.find(p => p.slot === slot).x, 0);
      await page.evaluate(() => { window.__pads[0].axes[0] = 0; window.__pads[0].timestamp = performance.now(); });
    }
    await page.screenshot({ path: testInfo.outputPath('local-round.png') });
    expect(errors).toEqual([]);
  });
}
