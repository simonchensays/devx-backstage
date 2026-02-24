################################################################################
# VPC Flow Logs
################################################################################

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/vpc/${local.name_prefix}/flow-logs"
  retention_in_days = 30

  tags = { Name = "${local.name_prefix}-flow-logs" }
}

resource "aws_flow_log" "main" {
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn

  tags = { Name = local.name_prefix }
}

################################################################################
# CloudTrail
################################################################################

resource "aws_cloudtrail" "main" {
  name                          = local.name_prefix
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  is_multi_region_trail         = false
  include_global_service_events = true
  enable_logging                = true

  tags = { Name = local.name_prefix }

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}
