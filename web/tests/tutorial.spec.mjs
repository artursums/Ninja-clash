import { test, expect } from '@playwright/test';

test('field manual has separate controller diagrams and a focusable Start button', async ({ page }, testInfo) => {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (/SCRIPT ERROR:|Failed to load script/.test(message.text())) errors.push(message.text()); });
  await page.addInitScript(() => {
    window.__ninjaTest = true;
    window.__pads = [];
    Object.defineProperty(navigator, 'getGamepads', { configurable: true, value: () => window.__pads });
  });
  await page.goto(process.env.NINJA_TEST_URL || 'http://127.0.0.1:8787');
  const state = () => page.evaluate(() => window.__ninjaState);
  const screen = name => expect.poll(async () => (await state())?.state).toBe(name);
  async function click(x, y, wait = 220) {
    const box = await page.locator('canvas').boundingBox();
    const scale = Math.min(box.width / 800, box.height / 450);
    await page.mouse.click(box.x + (box.width - 800 * scale) / 2 + x * scale,
      box.y + (box.height - 450 * scale) / 2 + y * scale);
    if (wait) await page.waitForTimeout(wait);
  }
  await screen('WELCOME');
  await page.keyboard.press('Enter');
  await screen('TITLE');
  await page.waitForTimeout(1500);
  await click(190, 260); // Options.
  await click(350, 281); // Enable the optional tutorial.
  await click(350, 324); // Back.
  await click(190, 178);
  await screen('MODE_SELECT');
  await click(675, 380);
  await click(400, 178); // Two players.
  await screen('CLAN_SELECT');
  await page.waitForTimeout(200);
  await click(311, 375);
  await click(695, 375);
  await screen('MAP_SELECT');
  await page.waitForTimeout(250);
  // Poll each animation frame so the brief loading screen can be inspected.
  await page.evaluate(() => {
    window.__loadingObserved = false;
    const observe = () => {
      if (window.__ninjaState?.loading) window.__loadingObserved = true;
      requestAnimationFrame(observe);
    };
    observe();
  });
  const performance = await page.context().newCDPSession(page);
  await performance.send('Emulation.setCPUThrottlingRate', { rate: 4 });
  await click(699, 396, 0);
  await expect.poll(async () => (await state()).loading, { intervals: [16] }).toBe(true);
  await page.screenshot({ path: testInfo.outputPath('loading.png') });
  await performance.send('Emulation.setCPUThrottlingRate', { rate: 1 });
  await expect.poll(async () => (await state()).tutorial).toBe(true);
  expect(await page.evaluate(() => window.__loadingObserved)).toBe(true);
  expect((await state()).loading).toBe(false);
  await page.waitForTimeout(400);
  for (let tab = 0; tab < 4; tab++) {
    await click(128 + tab * 181, 94);
    await expect.poll(async () => (await state()).tutorialTab).toBe(tab);
    await page.screenshot({ path: testInfo.outputPath(['keyboard', 'numpad', 'playstation', 'xbox'][tab] + '.png') });
  }
  // A fourth controller must navigate the manual even when it has no fighter slot.
  await page.evaluate(() => {
    const pad = { index: 3, id: 'Xbox Wireless Controller', connected: true, mapping: 'standard',
      timestamp: 0, axes: [0, 0, 0, 0], buttons: Array.from({ length: 17 }, () => ({ pressed: false, touched: false, value: 0 })) };
    window.__pads = [null, null, null, pad];
    const event = new Event('gamepadconnected');
    Object.defineProperty(event, 'gamepad', { value: pad });
    window.dispatchEvent(event);
  });
  async function button(index) {
    await page.evaluate(index => { window.__pads[3].buttons[index] = { pressed: true, touched: true, value: 1 }; }, index);
    await page.waitForTimeout(120);
    await page.evaluate(index => { window.__pads[3].buttons[index] = { pressed: false, touched: false, value: 0 }; }, index);
    await page.waitForTimeout(220);
  }
  await button(14); // Left selects PlayStation.
  await expect.poll(async () => (await state()).tutorialTab).toBe(2);
  await button(0); // Confirming a tab does not accidentally start the match.
  expect((await state()).tutorial).toBe(true);
  await button(13); // Down moves to Start.
  await expect.poll(async () => (await state()).tutorialStartFocused).toBe(true);
  await expect.poll(async () => (await state()).menuSelection.focus).toBe('START');
  await page.screenshot({ path: testInfo.outputPath('start-focused.png') });
  await button(12); // Up returns to the selected tab.
  await expect.poll(async () => (await state()).tutorialStartFocused).toBe(false);
  await button(13);
  await button(0);
  await expect.poll(async () => (await state()).tutorial).toBe(false);
  await screen('ROUND');
  expect(errors).toEqual([]);
});
