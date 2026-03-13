import {
  createBackendModule,
  coreServices,
} from '@backstage/backend-plugin-api';

/**
 * Backend module that handles full Cognito logout by clearing ALB session
 * cookies server-side (they are HttpOnly and cannot be cleared via JavaScript)
 * and redirecting to the Cognito logout endpoint.
 *
 * Flow:
 *   1. User clicks Sign Out → frontend navigates to /oauth2/sign_out
 *   2. ALB forwards request to this handler (listener rule bypasses auth)
 *   3. This handler expires all AWSELBAuthSessionCookie-* cookies
 *   4. Redirects to Cognito /logout endpoint
 *   5. Cognito clears its session and redirects to logout_uri (the app)
 *   6. ALB sees no session cookie → triggers Cognito login
 */
export default createBackendModule({
  pluginId: 'app',
  moduleId: 'cognito-logout',
  register(reg) {
    reg.registerInit({
      deps: {
        rootHttpRouter: coreServices.rootHttpRouter,
        logger: coreServices.logger,
      },
      async init({ rootHttpRouter, logger }) {
        const cognitoDomain = process.env.COGNITO_DOMAIN;
        const cognitoClientId = process.env.COGNITO_CLIENT_ID;
        const cognitoRegion = process.env.COGNITO_REGION || 'us-east-1';
        const appDomain = process.env.APP_DOMAIN;

        if (!cognitoDomain || !cognitoClientId || !appDomain) {
          logger.info(
            'Cognito logout route not registered: COGNITO_DOMAIN, COGNITO_CLIENT_ID, or APP_DOMAIN env var missing',
          );
          return;
        }

        rootHttpRouter.use('/oauth2/sign_out', (_req, res) => {
          // Expire ALB session cookies (HttpOnly — can only be cleared server-side).
          // ALB may split the session across numbered cookies (0–9).
          for (let i = 0; i <= 9; i++) {
            res.append(
              'Set-Cookie',
              `AWSELBAuthSessionCookie-${i}=; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Secure; HttpOnly`,
            );
          }

          const logoutUrl =
            `https://${cognitoDomain}.auth.${cognitoRegion}.amazoncognito.com/logout` +
            `?client_id=${cognitoClientId}` +
            `&logout_uri=${encodeURIComponent(`https://${appDomain}`)}`;

          res.redirect(302, logoutUrl);
        });

        logger.info('Cognito logout route registered at /oauth2/sign_out');
      },
    });
  },
});
