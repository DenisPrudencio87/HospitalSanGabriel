import { defineConfig } from '@playwright/test';
export default defineConfig({
  testDir: './e2e',
  workers: 1,
  timeout: 60000,
  use: {
    baseURL: 'http://localhost:4200',
    channel: 'chrome',
    headless: true,
    actionTimeout: 10000,
    viewport: { width: 1366, height: 900 },
    screenshot: 'only-on-failure',
  },
});
