terraform {
  backend "s3" {
    bucket         = "aws-devops-2025q2-shymanouski-terraform-states"
    key            = "task-1/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
    use_lockfile   = true
  }
} 