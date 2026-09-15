import { test, expect } from '@playwright/test';

test('a controller starts the web game and selects visible menu buttons', async ({ page }, testInfo) => {
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
  await expect.poll(async () => (await state())?.state).toBe('WELCOME');
  // Hot-plug four standard controllers after the game has already loaded.
  await page.evaluate(() => {
    for (let index = 0; index < 4; index++) {
      const pad = { index, id: `Test controller ${index}`, connected: true, mapping: 'standard',
        timestamp: 0, axes: [0, 0, 0, 0],
        buttons: Array.from({ length: 17 }, () => ({ pressed: false, touched: false, value: 0 })) };
      window.__pads.push(pad);
      const event = new Event('gamepadconnected');
      Object.defineProperty(event, 'gamepad', { value: pad });
      window.dispatchEvent(event);
    }
  });
  async function button(index, device = 3) {
    await page.evaluate(({ index, device }) => {
      const pad = window.__pads[device];
      pad.buttons[index] = { pressed: true, touched: true, value: 1 };
      pad.timestamp = performance.now();
    }, { index, device });
    await page.waitForTimeout(150);
    await page.evaluate(({ index, device }) => {
      const pad = window.__pads[device];
      pad.buttons[index] = { pressed: false, touched: false, value: 0 };
      pad.timestamp = performance.now();
    }, { index, device });
    await page.waitForTimeout(180);
  }
  async function axis(index, value) {
    await page.evaluate(({ index, value }) => {
      window.__pads[3].axes[index] = value;
      window.__pads[3].timestamp = performance.now();
    }, { index, value });
    await page.waitForTimeout(180);
  }
  await button(0); // Confirm skips the welcome without activating a menu item.
  await expect.poll(async () => (await state()).state).toBe('TITLE');
  await page.waitForTimeout(1400);
  await axis(1, 0.15);
  expect((await state()).menuSelection.title).toBe(0);
  await axis(1, 0.9);
  await expect.poll(async () => (await state()).menuSelection.title).toBe(1);
  await page.waitForTimeout(500);
  expect((await state()).menuSelection.title).toBe(1); // Holding does not skip several choices.
  await axis(1, 0);
  await button(12);
  await expect.poll(async () => (await state()).menuSelection.title).toBe(0);
  await button(0);
  await expect.poll(async () => (await state()).state).toBe('MODE_SELECT');
  await button(1);
  await expect.poll(async () => (await state()).state).toBe('TITLE');
  await button(13);
  await page.screenshot({ path: testInfo.outputPath('controller-title-online.png') });
  await button(0);
  await expect.poll(async () => (await state()).nameDialog).toBe(true);
  await button(0);
  expect((await state()).nameDialog).toBe(true); // A name remains required.
  await page.keyboard.type('Pad Player');
  await button(13);
  await expect.poll(async () => (await state()).menuSelection.focus).toBe('CONTINUE');
  await button(14);
  await expect.poll(async () => (await state()).menuSelection.focus).toBe('BACK');
  await button(15);
  await page.screenshot({ path: testInfo.outputPath('controller-name-continue.png') });
  await button(0);
  await expect.poll(async () => (await state()).nameDialog).toBe(false);
  expect((await state()).playerName).toBe('Pad Player');
  await button(13);
  await expect.poll(async () => (await state()).menuSelection.online).toBe(1);
  await expect.poll(async () => (await state()).menuSelection.focus).toBe('field');
  await button(0);
  await expect.poll(async () => (await state()).status).toBe("TYPE THE HOST'S ADDRESS FIRST");
  expect((await state()).state).toBe('ONLINE_MENU');
  await button(13);
  await expect.poll(async () => (await state()).menuSelection.online).toBe(2);
  await button(0);
  await expect.poll(async () => (await state()).state).toBe('TITLE');
  await button(12);
  await button(12);
  await expect.poll(async () => (await state()).menuSelection.title).toBe(4);
  await page.screenshot({ path: testInfo.outputPath('controller-title-quit.png') });
  await page.evaluate(() => {
    window.__pads[3].buttons[0] = { pressed: true, touched: true, value: 1 };
  });
  await expect(page).toHaveURL(/\/exit\.html$/);
  await expect(page.locator('canvas')).toHaveCount(0);
  await expect(page.getByText('The game is closed. You can close this tab.')).toBeVisible();
  await page.screenshot({ path: testInfo.outputPath('game-closed.png') });
  await page.getByRole('link', { name: 'PLAY AGAIN' }).click();
  await expect.poll(async () => (await state())?.state).toBe('WELCOME');
  expect(errors).toEqual([]);
});
