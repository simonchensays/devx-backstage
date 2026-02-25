# Infrastructure Sub-Agent Guidance

## Overview

This directory contains Terraform infrastructure-as-code for deploying Backstage to AWS. The infrastructure deploys the Backstage Docker image from ECR to ECS Fargate with an ALB, RDS PostgreSQL, and S3 for TechDocs.

## Architecture

- **ECS Fargate** in private subnets with internet access via NAT Gateway
- **ALB** in public subnets with Cognito authentication (when HTTPS enabled)
- **RDS PostgreSQL** in isolated DB subnets
- **S3** for TechDocs static assets
- **NAT Gateway** (single AZ) for ECS tasks to reach public endpoints (ALB JWT key verification, GitHub API)
- **VPC Endpoints** for AWS service access (ECR, S3, Logs, SM, STS)
- **Secrets Manager** for all credentials
- **CloudTrail + VPC Flow Logs** for SOC2 baseline

## Authentication (Cognito)

Cognito is integrated at the **ALB level**, not in the Backstage app itself. Unauthenticated users are redirected to the Cognito hosted UI before reaching Backstage.

- **Master control:** the `domain_name` variable enables the entire HTTPS + Cognito stack (Route 53, ACM cert, Cognito client, HTTPS listener)
- **Without `domain_name`:** ALB runs HTTP-only with no auth (dev bootstrapping mode)
- **Self-registration disabled:** `allow_admin_create_user_only = true` — admins must create users manually
- **Cognito client** is conditional on HTTPS (`count = local.use_https ? 1 : 0`)
- **HTTPS listener (443):** authenticates via Cognito → forwards to ECS target group
- **HTTP listener (80):** redirects to HTTPS when domain is set; forwards directly otherwise
- **OAuth scopes:** `openid`, `email`, `profile` (email and profile required by ALB auth provider)
- **Session timeout:** 1 hour
- **Output:** `cognito_login_url` provides the hosted UI login URL

### Backstage-side integration
The Backstage app uses `@backstage/plugin-auth-backend-module-aws-alb-provider` to consume the `x-amzn-oidc-*` headers injected by the ALB after Cognito auth. The `COGNITO_USER_POOL_ID` env var is passed from the ECS task definition for the provider's issuer URL. See `backstage/CLAUDE.md` for app-level details.

## Networking

- **Public subnets:** ALB, NAT Gateway, Internet Gateway
- **Private subnets:** ECS Fargate tasks — outbound internet via NAT Gateway (single AZ, sufficient for dev)
- **DB subnets:** RDS PostgreSQL — fully isolated, no internet route
- **Security groups follow default-deny:**
  - **ALB SG:** ingress 80/443 from internet; egress 7007 to ECS, 443 to internet (Cognito token exchange)
  - **ECS SG:** ingress 7007 from ALB; egress 5432 to RDS, 443 to VPC endpoints, 443 to S3 prefix list, 443 to internet via NAT (ALB JWT key verification, GitHub API)
  - **RDS SG:** ingress 5432 from ECS only
  - **VPC Endpoints SG:** ingress 443 from ECS only

## Deployment Details

- **Platform:** ARM64 (Docker image built on Apple Silicon)
- **Health check:** `/.backstage/health/v1/readiness` with 120s `startPeriod` for cold starts
- **DB SSL:** `PGSSLMODE=require` env var injected into ECS task; `app-config.production.yaml` sets `ssl.rejectUnauthorized: false`

## Key Commands

**Preferred: use the `/infra-apply` skill** for plan and apply operations — it handles init, fmt, validate, plan, and apply in one step:
```bash
/infra-apply                 # Full plan + apply workflow
/infra-apply plan            # Plan only (dry-run)
```

Manual commands (reference):
```bash
# First-time setup: create state backend
cd bootstrap && terraform init && terraform apply

# Initialize main infrastructure
terraform init

# Preview changes
terraform plan -var-file=terraform.tfvars

# Apply changes
terraform apply -var-file=terraform.tfvars

# Format check
terraform fmt -check -recursive

# Validate
terraform validate
```

## AWS Environment

- **Account:** 127325447618 (prototypes)
- **Region:** us-east-1
- **Profile:** `devx-backstage`
- **ECR Image:** `127325447618.dkr.ecr.us-east-1.amazonaws.com/devx-backstage:latest`

## Conventions

- All resources use `local.name_prefix` (`devx-backstage-{environment}`) for naming
- All resources tagged via provider `default_tags`: owner, environment, cost-center, managed-by, project
- Security groups follow default-deny with explicit allow rules
- No hardcoded secrets — all credentials in Secrets Manager
- IAM follows least-privilege — resource-level ARN restrictions on all policies

## File Layout

| File | Purpose |
|---|---|
| `versions.tf` | Terraform version, providers, S3 backend |
| `variables.tf` | Input variables |
| `locals.tf` | Computed values, naming, subnet CIDRs |
| `data.tf` | Data sources |
| `vpc.tf` | VPC, subnets, route tables, IGW, NAT Gateway |
| `endpoints.tf` | VPC endpoints (ECR, S3, Logs, SM, STS) |
| `security_groups.tf` | Security groups |
| `alb.tf` | ALB, listeners, target group |
| `cognito.tf` | Cognito User Pool, domain, ALB client |
| `dns.tf` | Route 53 hosted zone, ACM certificate |
| `rds.tf` | RDS PostgreSQL |
| `s3.tf` | S3 buckets |
| `secrets.tf` | Secrets Manager |
| `iam.tf` | IAM roles and policies |
| `ecs.tf` | ECS cluster, task definition, service |
| `logs.tf` | CloudTrail, VPC Flow Logs |
| `outputs.tf` | Output values |
| `bootstrap/main.tf` | One-time state backend setup |

## Skills

- **`/infra-apply`** — plans and applies Terraform changes. Pass `plan` argument for dry-run only. Defined in `.claude/skills/infra-apply/SKILL.md`.
- **`/build-and-push`** — builds the Backstage Docker image and pushes to ECR (run from `backstage/`). Use before `/infra-apply` when deploying app changes. Defined in `.claude/skills/build-and-push/SKILL.md`.
