output "alb_dns_name" {
  description = "ALB DNS name — use this to access Backstage"
  value       = aws_lb.main.dns_name
}

output "alb_url" {
  description = "Backstage URL"
  value       = local.use_https ? "https://${var.domain_name}" : "http://${aws_lb.main.dns_name}"
}

output "route53_name_servers" {
  description = "NS records to configure at your DNS provider for domain delegation"
  value       = local.use_https ? aws_route53_zone.main[0].name_servers : []
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_login_url" {
  description = "Cognito hosted UI login URL"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${local.region}.amazoncognito.com"
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.main.endpoint
}

output "techdocs_bucket_name" {
  description = "S3 bucket name for TechDocs"
  value       = aws_s3_bucket.techdocs.bucket
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.backstage.name
}

output "cloudtrail_bucket_name" {
  description = "S3 bucket name for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.bucket
}
