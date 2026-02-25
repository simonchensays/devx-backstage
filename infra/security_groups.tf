################################################################################
# ALB Security Group
################################################################################

resource "aws_security_group" "alb" {
  name_prefix = "${local.name_prefix}-alb-"
  description = "ALB - public HTTPS/HTTP ingress, egress to ECS only"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name_prefix}-alb" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "alb_ingress_https" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTPS from internet"
}

resource "aws_security_group_rule" "alb_ingress_http" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTP from internet (redirect to HTTPS or dev access)"
}

resource "aws_security_group_rule" "alb_egress_ecs" {
  security_group_id        = aws_security_group.alb.id
  type                     = "egress"
  protocol                 = "tcp"
  from_port                = 7007
  to_port                  = 7007
  source_security_group_id = aws_security_group.ecs.id
  description              = "Forward traffic to Backstage containers"
}

resource "aws_security_group_rule" "alb_egress_https" {
  security_group_id = aws_security_group.alb.id
  type              = "egress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTPS to internet (Cognito token exchange)"
}

################################################################################
# ECS Security Group
################################################################################

resource "aws_security_group" "ecs" {
  name_prefix = "${local.name_prefix}-ecs-"
  description = "ECS tasks - ingress from ALB, egress to RDS and VPC endpoints"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name_prefix}-ecs" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "ecs_ingress_alb" {
  security_group_id        = aws_security_group.ecs.id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 7007
  to_port                  = 7007
  source_security_group_id = aws_security_group.alb.id
  description              = "Receive traffic from ALB"
}

resource "aws_security_group_rule" "ecs_egress_rds" {
  security_group_id        = aws_security_group.ecs.id
  type                     = "egress"
  protocol                 = "tcp"
  from_port                = 5432
  to_port                  = 5432
  source_security_group_id = aws_security_group.rds.id
  description              = "Connect to PostgreSQL"
}

resource "aws_security_group_rule" "ecs_egress_endpoints" {
  security_group_id        = aws_security_group.ecs.id
  type                     = "egress"
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
  source_security_group_id = aws_security_group.vpc_endpoints.id
  description              = "Reach interface VPC endpoints"
}

resource "aws_security_group_rule" "ecs_egress_s3" {
  security_group_id = aws_security_group.ecs.id
  type              = "egress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_ids   = [aws_vpc_endpoint.s3.prefix_list_id]
  description       = "Reach S3 gateway endpoint"
}

resource "aws_security_group_rule" "ecs_egress_internet" {
  security_group_id = aws_security_group.ecs.id
  type              = "egress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTPS to internet via NAT (ALB JWT key verification, GitHub API)"
}

################################################################################
# RDS Security Group
################################################################################

resource "aws_security_group" "rds" {
  name_prefix = "${local.name_prefix}-rds-"
  description = "RDS - ingress from ECS only, no egress"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name_prefix}-rds" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "rds_ingress_ecs" {
  security_group_id        = aws_security_group.rds.id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 5432
  to_port                  = 5432
  source_security_group_id = aws_security_group.ecs.id
  description              = "Accept connections from ECS tasks"
}

################################################################################
# VPC Endpoints Security Group
################################################################################

resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${local.name_prefix}-vpce-"
  description = "VPC endpoints - HTTPS ingress from ECS only"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name_prefix}-vpce" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "vpce_ingress_ecs" {
  security_group_id        = aws_security_group.vpc_endpoints.id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
  source_security_group_id = aws_security_group.ecs.id
  description              = "Accept HTTPS from ECS tasks"
}
