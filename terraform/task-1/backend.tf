terraform {
  required_version = "~> 1.12.0"

  backend "s3" {
    bucket         = "aws-devops-2025q2-shymanouski-terraform-states"
    key            = "task-1/terraform.tfstate"
    region         = "us-east-2"
    use_lockfile   = true
  }
} 