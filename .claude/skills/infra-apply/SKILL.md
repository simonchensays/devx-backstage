---
name: infra-apply
description: Plan and apply Terraform infrastructure changes
disable-model-invocation: true
argument-hint: "[plan-only] (pass 'plan' to only preview changes)"
allowed-tools: Bash(terraform *), Bash(aws *)
---

Plan and apply Terraform infrastructure changes from the `infra/` directory.

**Mode:** If `$ARGUMENTS` is `plan`, only run `terraform plan`. Otherwise run plan and apply.

## Steps

1. Ensure AWS SSO session is active:
```bash
aws sts get-caller-identity --profile devx-backstage
```
If credentials are expired, run `aws sso login --profile devx-backstage` and wait for the user to complete browser auth.

2. Initialize Terraform (from `infra/` directory):
```bash
cd infra && terraform init
```

3. Format check:
```bash
cd infra && terraform fmt -check -recursive
```
If formatting issues are found, run `terraform fmt -recursive` to fix them, then report what changed.

4. Validate configuration:
```bash
cd infra && terraform validate
```

5. Plan changes:
```bash
cd infra && terraform plan -var-file=terraform.tfvars -out=tfplan
```
Show the user a summary of the planned changes (resources to add, change, destroy).

6. If `$ARGUMENTS` is `plan`, stop here and report the plan summary.

7. Apply changes (requires user confirmation):
```bash
cd infra && terraform apply tfplan
```
Wait for the apply to complete and report the results.

8. Clean up the plan file:
```bash
rm -f infra/tfplan
```

9. Show key outputs:
```bash
cd infra && terraform output
```
