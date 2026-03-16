# devx-backstage

An experiment in **agentic AI workflows** — using [Claude Code](https://claude.ai/code) agents to develop, test, and deploy software end-to-end with minimal human intervention.

The target application is [Backstage](https://backstage.io) (Spotify's open-source developer portal), deployed to AWS on ECS Fargate. But the real focus is the **multi-agent orchestration pattern**: each phase of the software lifecycle — development, infrastructure, and coordination — is owned by a dedicated AI agent defined as a `CLAUDE.md` file.

## How it works

Three agents collaborate through a shared artifact (a Docker image):

```
┌─────────────────────────────────────────────────────┐
│  Orchestrator Agent (root CLAUDE.md)                │
│  Coordinates builds, deploys, and cross-cutting     │
│  concerns like secrets and CI/CD                    │
├──────────────────────┬──────────────────────────────┤
│  Backstage Agent     │  Infrastructure Agent        │
│  backstage/CLAUDE.md │  infra/CLAUDE.md             │
│                      │                              │
│  Develops & tests    │  Provisions & deploys        │
│  the application     │  to AWS                      │
│  TypeScript, React   │  OpenTofu (Terraform)        │
│  Node.js, Yarn       │  ECS, ALB, RDS, Cognito      │
└──────────┬───────────┴───────────────┬──────────────┘
           │                           │
           ▼                           ▼
     Docker image ──────► ECR ──────► ECS Fargate
```

Each agent has its own workspace, tech stack, tools, and instructions. The orchestrator delegates tasks to the appropriate sub-agent based on context.

## Project structure

```
devx-backstage/
├── CLAUDE.md                 # Orchestrator agent — coordinates sub-agents
├── README.md                 # This file
├── backstage/                # Backstage application workspace
│   ├── CLAUDE.md             # Backstage agent — dev, test, build
│   ├── app-config.yaml       # Application configuration
│   ├── packages/
│   │   ├── app/              # Frontend (React + Material UI)
│   │   └── backend/          # Backend (Node.js + Express)
│   ├── plugins/              # Custom Backstage plugins
│   ├── smoke-tests/          # Playwright E2E tests
│   └── Dockerfile            # Multi-stage production build
└── infra/                    # AWS infrastructure workspace
    ├── CLAUDE.md             # Infra agent — provision, deploy
    ├── *.tf                  # OpenTofu modules (VPC, ECS, ALB, RDS, Cognito, etc.)
    └── bootstrap/            # One-time state backend setup
```

## Agents

### Orchestrator (`CLAUDE.md`)

The root agent coordinates the two sub-agents. It understands the full artifact flow and delegates tasks to the right workspace. It also manages cross-cutting concerns like AWS authentication, secrets, and environment configuration.

### Backstage agent (`backstage/CLAUDE.md`)

Owns the Backstage application source code. Responsibilities:
- Develop and configure plugins and features
- Run the app locally for development and testing
- Execute unit tests (Jest) and smoke tests (Playwright)
- Build and push Docker images to ECR

### Infrastructure agent (`infra/CLAUDE.md`)

Owns the infrastructure-as-code for AWS deployment. Responsibilities:
- Provision networking (VPC, subnets, NAT, security groups)
- Deploy the Backstage container on ECS Fargate behind an ALB
- Manage Cognito authentication, RDS PostgreSQL, and S3 storage
- Handle DNS, certificates, and secrets

## Skills

Agents can invoke reusable **skills** — automated multi-step workflows:

| Skill | Description |
|-------|-------------|
| `/build-and-push` | Builds the Backstage Docker image and pushes it to ECR |
| `/infra-apply` | Runs `tofu plan` and `tofu apply` for infrastructure changes |

## Getting started

### Prerequisites

- Node.js 22+
- Yarn 4.x
- Docker
- OpenTofu (`tofu`)
- AWS CLI with SSO configured

### Development

```bash
cd backstage
yarn install
yarn dev          # Start frontend + backend with hot reload
```

### Testing

```bash
cd backstage
yarn test         # Unit tests
yarn test:smoke   # E2E smoke tests (requires .env with Cognito credentials)
```

### Deploy

```bash
# Build and push the Docker image
cd backstage && /build-and-push

# Apply infrastructure changes
cd infra && /infra-apply
```

## Architecture decisions

- **Agent boundaries** are defined by workspace directories. Each `CLAUDE.md` file scopes an agent's knowledge, tools, and responsibilities.
- **Docker image** is the contract between agents. The Backstage agent produces it; the infra agent consumes it.
- **OpenTofu** (not Terraform) is used for infrastructure provisioning.
- **Cognito + ALB** handle authentication in production, with a three-layer logout flow (Backstage session → ALB cookies → Cognito session).
- **ARM64** is the target platform (built on Apple Silicon, deployed to Graviton).
