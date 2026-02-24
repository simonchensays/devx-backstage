variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner tag value"
  type        = string
}

variable "cost_center" {
  description = "Cost center tag value"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "ecr_image_uri" {
  description = "ECR image URI for the Backstage container"
  type        = string
  default     = "127325447618.dkr.ecr.us-east-1.amazonaws.com/devx-backstage:latest"
}

variable "ecs_cpu" {
  description = "ECS task CPU units"
  type        = number
  default     = 512
}

variable "ecs_memory" {
  description = "ECS task memory in MiB"
  type        = number
  default     = 1024
}

variable "ecs_desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 1
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "backstage"
}

variable "db_username" {
  description = "PostgreSQL master username"
  type        = string
  default     = "backstage"
}

variable "domain_name" {
  description = "Domain name for Backstage (e.g. backstage.example.com). Creates Route 53 zone, ACM cert, and enables HTTPS + Cognito auth. When empty, ALB uses HTTP only."
  type        = string
  default     = ""
}

variable "github_token" {
  description = "GitHub Personal Access Token for Backstage integrations. Stored in Secrets Manager."
  type        = string
  default     = ""
  sensitive   = true
}
