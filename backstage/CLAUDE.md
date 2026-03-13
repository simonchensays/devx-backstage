# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in the `backstage/` workspace.

## Role

This is the Backstage dev/test sub-agent. It owns the Backstage application source code, scaffolded from `@backstage/create-app`. The output artifact is a Docker image consumed by the `infra/` deployment agent.

## Tech Stack

- **Language:** TypeScript
- **Frontend:** React 18, Material UI 4, React Router 6
- **Backend:** Node.js with `@backstage/backend-defaults`
- **Package manager:** Yarn 4.4.1 (via corepack — run `corepack enable` if yarn commands fail)
- **Monorepo:** Yarn workspaces (`packages/*`, `plugins/*`)
- **Build tooling:** `@backstage/cli` (wraps Rspack for frontend, Node for backend)
- **Testing:** Jest 30, Playwright (e2e), Testing Library (React)
- **Node version:** 22 or 24

## Project Structure

```
backstage/
├── app-config.yaml            # App configuration (ports, auth, catalog, integrations)
├── app-config.production.yaml # Production overrides
├── package.json               # Root workspace — all scripts run from here
├── packages/
│   ├── app/                   # Frontend (role: frontend)
│   └── backend/               # Backend (role: backend)
├── plugins/                   # Custom Backstage plugins (currently empty)
├── examples/                  # Sample catalog entities, templates, org data
└── Dockerfile                 # Multi-stage production image build
```

## Commands

All commands run from the `backstage/` directory:

```bash
yarn install                  # Install dependencies
yarn start                    # Dev server: frontend (port 3000) + backend (port 7007)
yarn workspace backend start  # Backend only (port 7007)
yarn workspace app start      # Frontend only (port 3000)
yarn test                     # Run tests (changed since origin/main)
yarn test:all                 # Run all tests with coverage
yarn test:e2e                 # Playwright end-to-end tests
yarn tsc                      # Type check (incremental)
yarn tsc:full                 # Type check (full, no incremental)
yarn lint                     # Lint (changed since origin/main)
yarn lint:all                 # Lint everything
yarn prettier:check           # Check formatting
yarn fix                      # Auto-fix lint issues
yarn build:all                # Build all packages
yarn build:backend            # Build backend only
yarn build-image              # Build production Docker image
yarn new                      # Scaffold new plugin or package
yarn clean                    # Clean build artifacts
yarn test:smoke               # Smoke test against deployed Backstage (needs .env)
```

## Local Development

### Ports
- **Frontend:** http://localhost:3000 (Rspack dev server with HMR)
- **Backend:** http://localhost:7007 (Node.js, serves `/api/*`)

### IPv6 Binding Issue (Node.js 24)
On Node.js v24, the frontend dev server binds to IPv6 `[::1]` instead of IPv4 `127.0.0.1`. Fix by setting:
```bash
NODE_OPTIONS='--dns-result-order=ipv4first' yarn start
```

### Authentication
Guest auth is enabled by default (`auth.providers.guest: {}` in app-config.yaml). No setup needed for local dev.

**Production** uses ALB + Cognito authentication (see `infra/CLAUDE.md` for the infra side):
- `@backstage/plugin-auth-backend-module-aws-alb-provider` registered in `packages/backend/src/index.ts`
- `ProxiedSignInPage` with provider `awsalb` rendered in production (`packages/app/src/App.tsx`)
- `app-config.production.yaml` configures the `awsalb` provider with Cognito issuer URL and `emailMatchingUserEntityProfileEmail` resolver
- ALB injects `x-amzn-oidc-*` headers after Cognito auth; the provider verifies the JWT and extracts user identity
- `COGNITO_USER_POOL_ID` env var is passed from the ECS task definition to construct the issuer URL

**Logout** uses a three-layer flow to fully clear all sessions:
1. Frontend capture-phase click handler on `[data-testid="sign-out"]` redirects to `/oauth2/sign_out` (`packages/app/src/components/Root/Root.tsx`)
2. Backend `cognitoLogout` module (`packages/backend/src/modules/cognitoLogout.ts`) expires ALB `HttpOnly` session cookies via `Set-Cookie` headers and redirects to Cognito `/logout` endpoint
3. Cognito clears its session and redirects back to the app → ALB triggers re-authentication

**Important:** ALB session cookies (`AWSELBAuthSessionCookie-*`) are `HttpOnly` — they cannot be cleared via JavaScript. Cookie clearing must happen server-side via response headers.

Required ECS env vars for logout: `COGNITO_DOMAIN`, `COGNITO_CLIENT_ID`, `COGNITO_REGION`, `APP_DOMAIN`

### Database
Local dev uses in-memory SQLite (`better-sqlite3`). Production uses PostgreSQL (configured in `app-config.production.yaml`) with SSL required (`ssl.rejectUnauthorized: false` + `PGSSLMODE=require`).

### Catalog
Example entities are loaded from `examples/` directory. Catalog locations are defined in `app-config.yaml` under `catalog.locations`.

## Smoke Tests

End-to-end smoke tests verify the deployed Backstage instance works with Cognito authentication.

### Setup
Create a `.env` file (gitignored) in the `backstage/` directory:
```
COGNITO_USERNAME=<your-cognito-username>
COGNITO_PASSWORD=<your-cognito-password>
```

### Running
```bash
yarn test:smoke               # Runs Playwright against https://backstage.kenobiworks.com
SMOKE_TEST_URL=https://other.example.com yarn test:smoke  # Override target URL
```

### Details
- Config: `playwright.smoke.config.ts` (separate from e2e tests)
- Tests: `smoke-tests/login.test.ts`
- Artifacts: screenshots, traces, and videos saved to `smoke-test-results/` (gitignored)
- Report: `smoke-test-report/` (gitignored)
- Tests skip gracefully when `COGNITO_USERNAME`/`COGNITO_PASSWORD` are not set
- Uses `:visible` selectors to handle Cognito hosted UI's duplicate mobile/desktop forms

## Configuration

`app-config.yaml` is the primary config file. Key sections:
- `app` — frontend base URL, title
- `backend` — API base URL, listen port, CORS, CSP, database, logging level (warn)
- `auth` — authentication providers
- `catalog` — entity sources and import rules
- `integrations` — GitHub PAT via `${GITHUB_TOKEN}` env var
- `techdocs` — local builder/publisher for dev
- `kubernetes` — K8s plugin config
- `permission` — permission framework (enabled)

## Plugin Architecture

Backstage uses a plugin-based architecture. To add a new plugin:
```bash
yarn new                      # Interactive scaffolder for plugins/packages
```
Plugins go in `plugins/` and are registered in:
- **Frontend:** `packages/app/src/App.tsx` (routes) and `packages/app/src/components/Root/Root.tsx` (sidebar)
- **Backend:** `packages/backend/src/index.ts` (backend plugin registration)

## Building and Publishing the Docker Image

**Preferred: use the `/build-and-push` skill**, which handles the full build → ECR push pipeline in one step:
```bash
/build-and-push              # Build and push with tag "latest"
/build-and-push v1.2.3       # Build and push with custom tag
```

After pushing, use `/infra-apply` (from the `infra/` agent) to deploy the new image to ECS.

### Manual Steps (reference)

The Dockerfile is at `packages/backend/Dockerfile` (multi-stage build on `node:24-trixie-slim`).

#### Prerequisites
```bash
yarn install --immutable
yarn tsc
yarn build:backend            # Must run before build-image
```

#### Build
```bash
yarn build-image              # Runs: docker build ../.. -f Dockerfile --tag backstage
```

#### Push to ECR
```bash
# Authenticate Docker to ECR (requires AWS CLI + devx-backstage profile)
aws ecr get-login-password --region us-east-1 --profile devx-backstage \
  | docker login --username AWS --password-stdin 127325447618.dkr.ecr.us-east-1.amazonaws.com

# Tag and push
docker tag backstage:latest 127325447618.dkr.ecr.us-east-1.amazonaws.com/devx-backstage:latest
docker push 127325447618.dkr.ecr.us-east-1.amazonaws.com/devx-backstage:latest
```

### ECR Details
- **Repository:** `devx-backstage`
- **URI:** `127325447618.dkr.ecr.us-east-1.amazonaws.com/devx-backstage`
- **Region:** us-east-1
- **AWS Account:** 127325447618 (prototypes)
- **AWS Profile:** `devx-backstage` (SSO via `https://d-90678d8a2c.awsapps.com/start`)

## Skills

- **`/build-and-push`** — builds the Backstage Docker image and pushes to ECR. Accepts optional `[tag]` argument (default: `latest`). Defined in `.claude/skills/build-and-push/SKILL.md`.
- **`/infra-apply`** — plans and applies infrastructure changes (run from `infra/`). Use after pushing a new image to deploy it. Defined in `.claude/skills/infra-apply/SKILL.md`.
