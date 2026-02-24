# Infrastructure Sub-Agent Guidance

## Overview

This directory contains Terraform infrastructure-as-code for deploying Backstage to AWS. The infrastructure deploys the Backstage Docker image from ECR to ECS Fargate with an ALB, RDS PostgreSQL, and S3 for TechDocs.

## Architecture

- **ECS Fargate** in private subnets (no direct internet access)
- **ALB** in public subnets with Cognito authentication (requires ACM cert)
- **RDS PostgreSQL** in isolated DB subnets
- **S3** for TechDocs static assets
- **VPC Endpoints** instead of NAT Gateway for AWS service access
- **Secrets Manager** for all credentials
- **CloudTrail + VPC Flow Logs** for SOC2 baseline

## Key Commands

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
| `vpc.tf` | VPC, subnets, route tables, IGW |
| `endpoints.tf` | VPC endpoints (ECR, S3, Logs, SM, STS) |
| `security_groups.tf` | Security groups |
| `alb.tf` | ALB, listeners, target group |
| `cognito.tf` | Cognito User Pool |
| `rds.tf` | RDS PostgreSQL |
| `s3.tf` | S3 buckets |
| `secrets.tf` | Secrets Manager |
| `iam.tf` | IAM roles and policies |
| `ecs.tf` | ECS cluster, task definition, service |
| `logs.tf` | CloudTrail, VPC Flow Logs |
| `outputs.tf` | Output values |
| `bootstrap/main.tf` | One-time state backend setup |
