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

test('Login to Backstage via Cognito then sign out', async ({
  page,
  baseURL,
}) => {
  await test.step('Login via Cognito', async () => {
    await page.goto(baseURL!, { waitUntil: 'networkidle' });

    const url = page.url();
    expect(
      url,
      `Expected redirect to Cognito login but landed on: ${url}`,
    ).toContain('amazoncognito.com');

    const usernameInput = page.locator('input[name="username"]:visible');
    const passwordInput = page.locator('input[name="password"]:visible');

    await expect(usernameInput).toBeVisible({ timeout: 15_000 });
    await expect(passwordInput).toBeVisible();

    await usernameInput.fill(COGNITO_USERNAME!);
    await passwordInput.fill(COGNITO_PASSWORD!);

    const submitButton = page.locator(
      'input[name="signInSubmitButton"]:visible',
    );
    await expect(submitButton).toBeVisible();
    await submitButton.click();

    await page.waitForURL(`${baseURL}/**`, { timeout: 30_000 });

    const bodyText = await page.textContent('body');
    if (bodyText?.includes('Internal Server Error')) {
      const pageContent = bodyText.trim().slice(0, 500);
      throw new Error(
        `Server returned an error page after login redirect.\n` +
          `URL: ${page.url()}\n` +
          `Page content: ${pageContent}`,
      );
    }
  });

  await test.step('Verify Backstage app loads', async () => {
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
      await enterButton.click();
      await expect(page.getByText('Catalog')).toBeVisible({ timeout: 15_000 });
    }
  });

  await test.step('Sign out via UI', async () => {
    await page.goto(`${baseURL}/settings`, { waitUntil: 'networkidle' });
    await expect(
      page.getByRole('heading', { name: 'Settings' }),
    ).toBeVisible({ timeout: 15_000 });

    // The profile card has a three-dot menu containing the Sign Out action
    const profileMenu = page.getByRole('button', { name: /more/i }).or(
      page.locator('[aria-label="more"]'),
    ).or(
      page.locator('[data-testid="user-settings-menu"]'),
    ).or(
      page.locator('.MuiCardContent-root button[aria-haspopup="true"]'),
    );
    await expect(profileMenu.first()).toBeVisible({ timeout: 10_000 });
    await profileMenu.first().click();

    const signOutItem = page.getByRole('menuitem', { name: /sign out/i }).or(
      page.getByText(/sign out/i),
    );
    await expect(signOutItem.first()).toBeVisible({ timeout: 5_000 });
    await signOutItem.first().click();
  });

  await test.step('Verify full logout — redirected to Cognito login', async () => {
    // After clicking Sign Out, the frontend redirects to /oauth2/sign_out.
    // The backend clears ALB cookies via Set-Cookie headers and redirects to
    // the Cognito logout endpoint. Cognito clears its session and redirects
    // back to the app. Without a valid ALB cookie, the user is sent to the
    // Cognito login page.
    await page.waitForURL(/amazoncognito\.com/, {
      timeout: 30_000,
    });

    const url = page.url();
    console.log(`After sign-out, landed on: ${url}`);

    expect(
      url,
      `Expected redirect to Cognito login after sign-out but landed on: ${url}`,
    ).toContain('amazoncognito.com');

    // Verify the Cognito login form is visible
    const usernameInput = page.locator('input[name="username"]:visible');
    await expect(usernameInput).toBeVisible({ timeout: 15_000 });

    console.log('Full logout completed — user must re-authenticate');
  });
});
