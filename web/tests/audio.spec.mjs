import { test, expect } from '@playwright/test';

test('browser music and menu effects produce audio through separate buses', async ({ page }) => {
  const errors = [];
  let state = '';
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    const screen = message.text().match(/\[STATE\] -> (\w+)/);
    if (screen) state = screen[1];
    if (/SCRIPT ERROR:|Failed to load script/.test(message.text())) errors.push(message.text());
  });
  await page.addInitScript(() => {
    window.__audioMeters = [];
    const connect = AudioNode.prototype.connect;
    AudioNode.prototype.connect = function (destination, ...args) {
      const result = connect.call(this, destination, ...args);
      if (destination instanceof AudioDestinationNode) {
        const meter = this.context.createAnalyser();
        connect.call(this, meter);
        window.__audioMeters.push(meter);
      }
      return result;
    };
  });
  const base = process.env.NINJA_AUDIO_TEST_URL || (process.env.NINJA_TEST_TURN ? 'http://127.0.0.1:8788' : 'http://127.0.0.1:8787');
  await page.goto(base);
  await expect.poll(() => state).toBe('PROLOGUE');
  async function click(x, y) {
    const box = await page.locator('canvas').boundingBox();
    const scale = Math.min(box.width / 800, box.height / 450);
    await page.mouse.click(box.x + (box.width - 800 * scale) / 2 + x * scale, box.y + (box.height - 450 * scale) / 2 + y * scale);
  }
  async function peak() {
    return page.evaluate(async () => {
      let value = 0;
      for (let i = 0; i < 25; i++) {
        for (const meter of window.__audioMeters) {
          const samples = new Float32Array(meter.fftSize);
          meter.getFloatTimeDomainData(samples);
          for (const sample of samples) value = Math.max(value, Math.abs(sample));
        }
        await new Promise(resolve => setTimeout(resolve, 20));
      }
      return value;
    });
  }
  expect(await peak(), 'The start screen stays silent until the player begins').toBeLessThan(0.001);
  await click(400, 342);
  await page.waitForTimeout(500);
  expect(await peak(), 'Music must reach the browser audio output after interaction').toBeGreaterThan(0.01);
  await page.keyboard.press('Escape');
  await expect.poll(() => state).toBe('TITLE');
  await page.waitForTimeout(1300);
  await click(190, 262);
  await page.waitForTimeout(300);
  await page.keyboard.press('ArrowDown');
  for (let i = 0; i < 11; i++) {
    await page.keyboard.press('ArrowLeft');
    await page.waitForTimeout(60);
  }
  await page.waitForTimeout(300);
  expect(await peak(), 'Muting Music must silence the background track').toBeLessThan(0.001);
  await page.keyboard.press('ArrowDown');
  expect(await peak(), 'Menu SFX must still work when Music is muted').toBeGreaterThan(0.01);
  expect(errors).toEqual([]);
});
