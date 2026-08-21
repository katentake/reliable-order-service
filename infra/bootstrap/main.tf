# One-time bootstrap: creates the S3 bucket + DynamoDB lock table that the main
# infra config's Terraform state lives in. This has its own local state file and
# is applied manually, once, before `terraform init` is ever run in ../.
#
# See ../../docs/deployment.md for the exact commands.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region for the state bucket and lock table"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used to prefix bootstrap resource names"
  type        = string
  default     = "palona-order-svc"
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-tfstate-${random_id.suffix.hex}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "state_bucket" {
  value = aws_s3_bucket.terraform_state.bucket
}

output "init_command" {
  value = "terraform init -backend-config=\"bucket=${aws_s3_bucket.terraform_state.bucket}\" -backend-config=\"use_lockfile=true\" -backend-config=\"region=${var.aws_region}\""
}
