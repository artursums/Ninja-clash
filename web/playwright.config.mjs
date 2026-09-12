import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests', testMatch: '**/*.spec.mjs', workers: 1,
  timeout: 120000, expect: { timeout: 45000 },
  use: {
    channel: process.env.PLAYWRIGHT_CHANNEL || 'chrome',
    viewport: { width: 1000, height: 650 },
    launchOptions: { args: ['--disable-background-timer-throttling', '--disable-renderer-backgrounding', '--disable-backgrounding-occluded-windows'] },
    screenshot: 'only-on-failure', trace: 'retain-on-failure',
  },
  webServer: {
    command: process.env.NINJA_TEST_TURN ? 'node tools/turn-test-server.mjs' : 'node tools/serve.mjs',
    url: process.env.NINJA_TEST_TURN ? 'http://127.0.0.1:8788' : 'http://127.0.0.1:8787',
    reuseExistingServer: !process.env.CI && !process.env.NINJA_TEST_TURN,
  },
});
