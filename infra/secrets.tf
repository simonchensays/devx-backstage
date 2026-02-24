################################################################################
# Random Passwords
################################################################################

resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "backend_secret" {
  length  = 64
  special = false
}

################################################################################
# Secrets Manager — DB Password
################################################################################

resource "aws_secretsmanager_secret" "db_password" {
  name        = "${local.name_prefix}/db-password"
  description = "Backstage RDS PostgreSQL master password"

  tags = { Name = "${local.name_prefix}-db-password" }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}

################################################################################
# Secrets Manager — GitHub Token (conditional)
################################################################################

resource "aws_secretsmanager_secret" "github_token" {
  count = var.github_token != "" ? 1 : 0

  name        = "${local.name_prefix}/github-token"
  description = "GitHub Personal Access Token for Backstage integrations"

  tags = { Name = "${local.name_prefix}-github-token" }
}

resource "aws_secretsmanager_secret_version" "github_token" {
  count = var.github_token != "" ? 1 : 0

  secret_id     = aws_secretsmanager_secret.github_token[0].id
  secret_string = var.github_token
}

################################################################################
# Secrets Manager — Backend Secret
################################################################################

resource "aws_secretsmanager_secret" "backend_secret" {
  name        = "${local.name_prefix}/backend-secret"
  description = "Backstage backend service-to-service authentication secret"

  tags = { Name = "${local.name_prefix}-backend-secret" }
}

resource "aws_secretsmanager_secret_version" "backend_secret" {
  secret_id     = aws_secretsmanager_secret.backend_secret.id
  secret_string = random_password.backend_secret.result
}
