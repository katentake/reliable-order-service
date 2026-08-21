terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  # bucket / region are supplied at `terraform init` time via -backend-config,
  # since the bucket is created by infra/bootstrap and can't be known before
  # that runs. use_lockfile=true enables S3's native state locking (no
  # DynamoDB table needed). See docs/deployment.md.
  backend "s3" {
    key     = "reliable-order-service/terraform.tfstate"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}
