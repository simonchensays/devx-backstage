locals {
  name_prefix = "devx-backstage-${var.environment}"
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.name
  use_https   = var.acm_certificate_arn != ""

  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
  db_subnet_cidrs      = ["10.0.20.0/24", "10.0.21.0/24"]
}
