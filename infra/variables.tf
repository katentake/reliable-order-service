variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used to prefix resource names"
  type        = string
  default     = "palona-order-svc"
}

variable "alert_email" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for Lambda and API Gateway access logs"
  type        = number
  default     = 14
}

variable "github_repo" {
  description = "GitHub repo (owner/name) allowed to assume the CI/CD deploy role via OIDC"
  type        = string
  default     = "katentake/reliable-order-service"
}
