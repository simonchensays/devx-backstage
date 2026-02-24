################################################################################
# Application Load Balancer
################################################################################

resource "aws_lb" "main" {
  name               = local.name_prefix
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  drop_invalid_header_fields = true

  tags = { Name = local.name_prefix }
}

################################################################################
# Target Group — ECS tasks on port 7007
################################################################################

resource "aws_lb_target_group" "backstage" {
  name        = local.name_prefix
  port        = 7007
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/healthcheck"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }

  tags = { Name = local.name_prefix }
}

################################################################################
# HTTPS Listener (when ACM cert is provided) — Cognito auth + forward
################################################################################

resource "aws_lb_listener" "https" {
  count = local.use_https ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type  = "authenticate-cognito"
    order = 1

    authenticate_cognito {
      user_pool_arn       = aws_cognito_user_pool.main.arn
      user_pool_client_id = aws_cognito_user_pool_client.alb[0].id
      user_pool_domain    = aws_cognito_user_pool_domain.main.domain
      session_cookie_name = "AWSELBAuthSessionCookie"
      session_timeout     = 3600

      on_unauthenticated_request = "authenticate"
    }
  }

  default_action {
    type             = "forward"
    order            = 2
    target_group_arn = aws_lb_target_group.backstage.arn
  }

  tags = { Name = "${local.name_prefix}-https" }
}

################################################################################
# HTTP Listener
# - With HTTPS: redirect HTTP → HTTPS
# - Without HTTPS: forward directly (dev bootstrapping only, no Cognito auth)
################################################################################

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = local.use_https ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = local.use_https ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    target_group_arn = local.use_https ? null : aws_lb_target_group.backstage.arn
  }

  tags = { Name = "${local.name_prefix}-http" }
}
