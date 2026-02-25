import { defineConfig } from '@playwright/test';

const baseURL =
  process.env.SMOKE_TEST_URL ?? 'https://backstage.kenobiworks.com';

export default defineConfig({
  testDir: './smoke-tests',
  timeout: 120_000,

  expect: {
    timeout: 15_000,
  },

  retries: 0,
  forbidOnly: true,

  reporter: [
    ['list'],
    ['html', { open: 'never', outputFolder: 'smoke-test-report' }],
  ],

  use: {
    baseURL,
    screenshot: 'on',
    trace: 'on',
    video: 'on-first-retry',
  },

  outputDir: 'smoke-test-results',

  projects: [
    {
      name: 'smoke',
      use: { browserName: 'chromium' },
    },
  ],
});
