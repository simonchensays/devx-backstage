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

### Database
Local dev uses in-memory SQLite (`better-sqlite3`). Production uses PostgreSQL (configured in `app-config.production.yaml`).

### Catalog
Example entities are loaded from `examples/` directory. Catalog locations are defined in `app-config.yaml` under `catalog.locations`.

## Configuration

`app-config.yaml` is the primary config file. Key sections:
- `app` — frontend base URL, title
- `backend` — API base URL, listen port, CORS, CSP, database
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

## Building the Docker Image

```bash
yarn build-image
# equivalent to: docker build ../.. -f Dockerfile --tag backstage
```

This is the output artifact consumed by the `infra/` deployment agent.
