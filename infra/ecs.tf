################################################################################
# ECS Cluster
################################################################################

resource "aws_ecs_cluster" "main" {
  name = local.name_prefix

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = local.name_prefix }
}

################################################################################
# CloudWatch Log Group for ECS
################################################################################

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = 30

  tags = { Name = "${local.name_prefix}-ecs" }
}

################################################################################
# ECS Task Definition
################################################################################

resource "aws_ecs_task_definition" "backstage" {
  family                   = local.name_prefix
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name      = "backstage"
      image     = var.ecr_image_uri
      essential = true

      portMappings = [{
        containerPort = 7007
        protocol      = "tcp"
      }]

      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "NODE_OPTIONS", value = "--no-node-snapshot" },
        { name = "POSTGRES_HOST", value = aws_db_instance.main.address },
        { name = "POSTGRES_PORT", value = tostring(aws_db_instance.main.port) },
        { name = "POSTGRES_USER", value = var.db_username },
        { name = "PGSSLMODE", value = "require" },
        { name = "COGNITO_USER_POOL_ID", value = aws_cognito_user_pool.main.id },
        { name = "COGNITO_DOMAIN", value = aws_cognito_user_pool_domain.main.domain },
        { name = "COGNITO_CLIENT_ID", value = local.use_https ? aws_cognito_user_pool_client.alb[0].id : "" },
        { name = "COGNITO_REGION", value = var.aws_region },
        { name = "APP_DOMAIN", value = var.domain_name },
      ]

      secrets = concat(
        [
          {
            name      = "POSTGRES_PASSWORD"
            valueFrom = aws_secretsmanager_secret.db_password.arn
          },
          {
            name      = "BACKEND_SECRET"
            valueFrom = aws_secretsmanager_secret.backend_secret.arn
          },
        ],
        var.github_token != "" ? [
          {
            name      = "GITHUB_TOKEN"
            valueFrom = aws_secretsmanager_secret.github_token[0].arn
          }
        ] : []
      )

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = local.region
          "awslogs-stream-prefix" = "backstage"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "node -e \"require('http').get('http://localhost:7007/.backstage/health/v1/readiness', (r) => process.exit(r.statusCode === 200 ? 0 : 1))\""]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 120
      }
    }
  ])

  tags = { Name = local.name_prefix }
}

################################################################################
# ECS Service
################################################################################

resource "aws_ecs_service" "backstage" {
  name             = local.name_prefix
  cluster          = aws_ecs_cluster.main.id
  task_definition  = aws_ecs_task_definition.backstage.arn
  desired_count    = var.ecs_desired_count
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backstage.arn
    container_name   = "backstage"
    container_port   = 7007
  }

  health_check_grace_period_seconds = 120

  depends_on = [aws_lb_listener.http_redirect, aws_lb_listener.http_forward]

  tags = { Name = local.name_prefix }
}
