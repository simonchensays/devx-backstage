import { test, expect } from '@playwright/test';

const COGNITO_USERNAME = process.env.COGNITO_USERNAME;
const COGNITO_PASSWORD = process.env.COGNITO_PASSWORD;

test.beforeEach(async ({}, testInfo) => {
  if (!COGNITO_USERNAME || !COGNITO_PASSWORD) {
    testInfo.skip(
      true,
      'COGNITO_USERNAME and COGNITO_PASSWORD env vars are required',
    );
  }
});

test('Login to Backstage via Cognito and verify app loads', async ({
  page,
  baseURL,
}) => {
  await test.step('Navigate to Backstage — expect Cognito redirect', async () => {
    await page.goto(baseURL!, { waitUntil: 'networkidle' });

    // ALB should redirect unauthenticated users to the Cognito hosted UI
    const url = page.url();
    console.log(`After initial navigation: ${url}`);

    expect(
      url,
      `Expected redirect to Cognito login but landed on: ${url}`,
    ).toContain('amazoncognito.com');
  });

  await test.step('Fill in Cognito credentials and submit', async () => {
    // Cognito hosted UI renders duplicate forms (mobile + desktop).
    // Use the visible form by scoping to the non-hidden container.
    const usernameInput = page.locator(
      'input[name="username"]:visible',
    );
    const passwordInput = page.locator(
      'input[name="password"]:visible',
    );

    await expect(usernameInput).toBeVisible({ timeout: 15_000 });
    await expect(passwordInput).toBeVisible();

    await usernameInput.fill(COGNITO_USERNAME!);
    await passwordInput.fill(COGNITO_PASSWORD!);

    const submitButton = page.locator(
      'input[name="signInSubmitButton"]:visible',
    );
    await expect(submitButton).toBeVisible();
    await submitButton.click();
  });

  await test.step('Wait for redirect back to Backstage', async () => {
    // After successful Cognito auth, ALB sets session cookie and forwards to Backstage
    await page.waitForURL(`${baseURL}/**`, { timeout: 30_000 });
    const url = page.url();
    console.log(`After login redirect: ${url}`);

    expect(url).toContain(new URL(baseURL!).hostname);

    // Check for server errors immediately after redirect
    const bodyText = await page.textContent('body');
    if (bodyText?.includes('Internal Server Error')) {
      const pageContent = bodyText.trim().slice(0, 500);
      throw new Error(
        `Server returned an error page after login redirect.\n` +
          `URL: ${url}\n` +
          `Page content: ${pageContent}`,
      );
    }
  });

  await test.step('Verify Backstage app loads', async () => {
    // Backstage guest auth auto-signs in. Look for either the Enter button
    // (guest sign-in page) or the catalog content.
    const enterButton = page.getByRole('button', { name: 'Enter' });
    const catalogText = page.getByText('Catalog');

    const visibleElement = await Promise.race([
      enterButton
        .waitFor({ state: 'visible', timeout: 30_000 })
        .then(() => 'enter' as const),
      catalogText
        .waitFor({ state: 'visible', timeout: 30_000 })
        .then(() => 'catalog' as const),
    ]);

    if (visibleElement === 'enter') {
      console.log('Found Enter button — clicking to complete guest sign-in');
      await enterButton.click();
      await expect(page.getByText('Catalog')).toBeVisible({ timeout: 15_000 });
    }

    console.log('Backstage app loaded successfully');
  });
});
