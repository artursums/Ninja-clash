import { test, expect } from '@playwright/test';

test('guarding keeps the katana raised while the legs run in both directions', async ({ page }, testInfo) => {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    if (/SCRIPT ERROR:|Failed to load script/.test(message.text())) errors.push(message.text());
  });
  await page.addInitScript(() => { window.__ninjaTest = true; });
  await page.goto(process.env.NINJA_TEST_URL || 'http://127.0.0.1:8787');
  const state = () => page.evaluate(() => window.__ninjaState);
  const screen = expected => expect.poll(async () => (await state())?.state).toBe(expected);
  const fighter = async () => (await state()).fighters.find(p => p.slot === 1);
  async function click(x, y) {
    const box = await page.locator('canvas').boundingBox();
    const scale = Math.min(box.width / 800, box.height / 450);
    await page.mouse.click(box.x + (box.width - 800 * scale) / 2 + x * scale,
      box.y + (box.height - 450 * scale) / 2 + y * scale);
  }
  await screen('WELCOME');
  await page.keyboard.press('Enter');
  await page.waitForTimeout(400);
  await page.keyboard.press('Escape');
  await screen('TITLE');
  await page.waitForTimeout(1400);
  await page.keyboard.press('Enter');
  await screen('MODE_SELECT');
  await page.waitForTimeout(300);
  await page.keyboard.press('Enter');
  await page.waitForTimeout(250);
  await page.keyboard.press('Enter');
  await screen('CLAN_SELECT');
  await page.waitForTimeout(300);
  await click(311, 375);
  await click(695, 375);
  await screen('MAP_SELECT');
  await page.waitForTimeout(400);
  await click(699, 396);
  await screen('MATCH_INTRO');
  await page.waitForTimeout(700);
  await page.keyboard.press('Enter');
  await screen('ROUND');
  await expect.poll(async () => (await fighter()).grounded).toBe(true);
  for (const direction of ['d', 'a']) {
    await page.keyboard.down('j');
    await expect.poll(async () => (await fighter()).guard).toBe(true);
    expect((await fighter()).frame).toBe(60); // Stationary guard.
    await page.keyboard.down(direction);
    await expect.poll(async () => Math.floor((await fighter()).frame / 12)).toBe(8);
    const startX = (await fighter()).x;
    const frames = new Set();
    for (let sample = 0; sample < 5; sample++) {
      await page.waitForTimeout(100);
      const p = await fighter();
      expect(p.guard && p.bladeVisible).toBe(true);
      if (p.grounded) frames.add(p.frame);
    }
    expect(frames.size).toBeGreaterThan(1);
    expect(Math.abs((await fighter()).x - startX)).toBeGreaterThan(10);
    await page.screenshot({ path: testInfo.outputPath(`guard-run-${direction}.png`) });
    await page.keyboard.up(direction);
    await expect.poll(async () => (await fighter()).frame).toBe(60);
    expect((await fighter()).bladeVisible).toBe(true);
    await page.keyboard.up('j');
    await expect.poll(async () => (await fighter()).guard).toBe(false);
    expect((await fighter()).bladeVisible).toBe(false);
  }
  expect(errors).toEqual([]);
});
