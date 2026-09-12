import { test, expect } from '@playwright/test';

test('the opening waits for the player, tells all three chapters, then opens the menu', async ({ page }, testInfo) => {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    if (/SCRIPT ERROR:|Failed to load script/.test(message.text())) errors.push(message.text());
  });
  await page.addInitScript(() => { window.__ninjaTest = true; });
  await page.goto('http://127.0.0.1:8787');
  const state = () => page.evaluate(() => window.__ninjaState);
  await expect.poll(async () => (await state())?.state).toBe('PROLOGUE');
  await page.waitForTimeout(1500);
  expect((await state()).prologueChapter).toBe(-1);
  await page.screenshot({ path: testInfo.outputPath('begin.png') });
  await page.keyboard.press('Enter');
  for (let chapter = 0; chapter < 3; chapter++) {
    await expect.poll(async () => (await state()).prologueChapter).toBe(chapter);
    await page.waitForTimeout(900);
    await page.screenshot({ path: testInfo.outputPath(`chapter-${chapter + 1}.png`) });
  }
  await expect.poll(async () => (await state()).state).toBe('TITLE');
  await page.waitForTimeout(1300);
  expect((await state()).state).toBe('TITLE');
  expect(errors).toEqual([]);
});
