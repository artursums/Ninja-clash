import { test, expect } from '@playwright/test';

const base = process.env.NINJA_TEST_URL || 'http://127.0.0.1:8787';
const state = page => page.evaluate(() => window.__ninjaState);

async function open(page, suffix = '') {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    if (/SCRIPT ERROR:|Failed to load script/.test(message.text())) errors.push(message.text());
  });
  await page.addInitScript(() => { window.__ninjaTest = true; });
  await page.goto(base + suffix);
  await expect.poll(async () => (await state(page))?.state).toBe('WELCOME');
  return errors;
}

test('welcome reveals the title and automatically enters the main menu', async ({ page }, testInfo) => {
  const errors = await open(page);
  await page.waitForTimeout(1200);
  await page.screenshot({ path: testInfo.outputPath('welcome.png') });
  await expect.poll(async () => (await state(page)).state, { timeout: 8000 }).toBe('TITLE');
  await page.waitForTimeout(1400);
  expect((await state(page)).state).toBe('TITLE');
  expect(errors).toEqual([]);
});

for (const action of ['Enter', 'Escape', 'click']) {
  test(`welcome can be skipped with ${action} without opening another menu`, async ({ page }) => {
    const errors = await open(page);
    if (action === 'click') await page.locator('canvas').click();
    else await page.keyboard.press(action);
    await expect.poll(async () => (await state(page)).state, { timeout: 3000 }).toBe('TITLE');
    await page.waitForTimeout(1500);
    expect((await state(page)).state).toBe('TITLE');
    expect(errors).toEqual([]);
  });
}

test('an invitation survives automatic welcome and opens the name dialog', async ({ page }) => {
  const errors = await open(page, '/#room=000000000000');
  await expect.poll(async () => (await state(page)).state, { timeout: 8000 }).toBe('ONLINE_MENU');
  await expect.poll(async () => (await state(page)).nameDialog).toBe(true);
  expect(errors).toEqual([]);
});
