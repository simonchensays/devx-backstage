################################################################################
# Route 53 Hosted Zone
################################################################################

resource "aws_route53_zone" "main" {
  count = local.use_https ? 1 : 0

  name = var.domain_name

  tags = { Name = var.domain_name }
}

################################################################################
# ACM Certificate with DNS Validation
################################################################################

resource "aws_acm_certificate" "main" {
  count = local.use_https ? 1 : 0

  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = var.domain_name }
}

################################################################################
# DNS Validation Records
################################################################################

resource "aws_route53_record" "cert_validation" {
  for_each = local.use_https ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id         = aws_route53_zone.main[0].zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "main" {
  count = local.use_https ? 1 : 0

  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

################################################################################
# ALB Alias Record
################################################################################

resource "aws_route53_record" "alb" {
  count = local.use_https ? 1 : 0

  zone_id = aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
