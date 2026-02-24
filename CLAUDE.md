# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a multi-agent project for customizing, building, and deploying [Backstage](https://backstage.io) (Spotify's open-source developer portal) to AWS. The repo is organized as three distinct workspaces with an orchestration layer at the root coordinating two sub-agents.

## Architecture

```
devx-backstage/
├── CLAUDE.md                  # Root orchestration guidance (this file)
├── backstage/                 # Sub-agent 1: Backstage dev/test workspace
│   ├── CLAUDE.md              # Backstage-specific agent guidance
│   ├── app-config.yaml        # Backstage app configuration
│   ├── packages/
│   │   ├── app/               # Frontend (React)
│   │   └── backend/           # Backend (Node.js)
│   ├── plugins/               # Custom Backstage plugins
│   ├── Dockerfile             # Multi-stage build for production image
│   └── catalog-info.yaml      # Software catalog entity definitions
└── infra/                     # Sub-agent 2: AWS deployment workspace
    ├── CLAUDE.md              # Infrastructure-specific agent guidance
    └── (Terraform/CDK modules for ECS/EKS deployment)
```

### Orchestration Agent (Root)

Coordinates the two sub-agents. Responsibilities:
- Trigger backstage build and test pipeline
- Pass built Docker image artifact to the infra deployment agent
- Manage cross-cutting concerns (secrets, environment config, CI/CD)

### Sub-Agent 1: Backstage Dev/Test (`backstage/`)

Owns the Backstage application source code cloned from the [backstage/backstage](https://github.com/backstage/backstage) upstream. Responsibilities:
- Develop and configure Backstage plugins and features
- Run Backstage locally for development and testing
- Produce a Docker image as the output artifact

**Tech stack:** TypeScript, React (frontend), Node.js/Express (backend), PostgreSQL, Yarn (package manager), Backstage CLI

**Key commands (run from `backstage/` directory):**
```bash
# Install dependencies
yarn install

# Start local dev server (frontend + backend with hot reload)
yarn dev

# Start only backend
yarn start-backend

# Start only frontend
yarn start

# Run all tests
yarn test

# Run tests for a specific package
yarn test --filter=<package-name>

# Run a single test file
yarn jest <path-to-test-file>

# Type checking
yarn tsc

# Lint
yarn lint

# Build all packages
yarn build

# Build Docker image
yarn build-image
# or
docker build -t backstage .
```

### Sub-Agent 2: AWS Infrastructure (`infra/`)

Owns the infrastructure-as-code for deploying the Backstage Docker image to AWS. Responsibilities:
- Provision AWS resources (networking, compute, database, load balancer)
- Deploy and manage the Backstage container
- Handle environment-specific configuration (dev, staging, prod)

**Tech stack:** To be determined — likely Terraform or AWS CDK

**Key commands (run from `infra/` directory):**
```bash
# If using Terraform:
terraform init
terraform plan
terraform apply

# If using AWS CDK:
npm install
cdk synth
cdk diff
cdk deploy
```

## Agent Boundaries

Each sub-agent operates independently with its own:
- **CLAUDE.md** — agent-specific instructions in its workspace directory
- **Tech stack** — Backstage agent uses TypeScript/Yarn; Infra agent uses Terraform or CDK
- **Design patterns** — Backstage follows plugin architecture; Infra follows IaC module patterns
- **Test strategy** — Backstage uses Jest/Playwright; Infra uses `terraform test` or CDK assertions

The orchestration agent at the root should delegate to the appropriate sub-agent based on the task. If a task involves Backstage application code, work in `backstage/`. If it involves AWS resources or deployment, work in `infra/`.

## AWS Environment

- **Account:** 127325447618 (prototypes)
- **Region:** us-east-1
- **AWS CLI profile:** `devx-backstage` (SSO via `https://d-90678d8a2c.awsapps.com/start`)
- **SSO role:** AdministratorAccess
- **ECR repository:** `127325447618.dkr.ecr.us-east-1.amazonaws.com/devx-backstage`

To authenticate: `aws sso login --profile devx-backstage`

## Artifact Flow

```
backstage/ (dev & test) → Docker image → ECR → infra/ (deploy to AWS)
```

The Docker image is the contract between the two sub-agents. The backstage agent produces it and pushes to ECR; the infra agent pulls from ECR and deploys.

**ECR image URI:** `127325447618.dkr.ecr.us-east-1.amazonaws.com/devx-backstage:latest`
