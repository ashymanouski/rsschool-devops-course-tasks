variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-2"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "aws-devops-2025q2"
}

variable "tags" {
  description = "Default tags for all resources"
  type        = map(string)
  default = {
    Project     = "aws-devops-2025q2"
    Environment = "main"
    ManagedBy   = "terraform"
  }
}