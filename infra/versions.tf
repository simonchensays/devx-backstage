terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket         = "devx-backstage-terraform-state-127325447618"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "devx-backstage-terraform-lock"
    encrypt        = true
    profile        = "devx-backstage"
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "devx-backstage"

  default_tags {
    tags = {
      owner       = var.owner
      environment = var.environment
      cost-center = var.cost_center
      managed-by  = "terraform"
      project     = "devx-backstage"
    }
  }
}
