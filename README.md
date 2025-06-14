# AWS DevOps Course Task 1

This repository contains Terraform configurations for AWS infrastructure deployment.

## Prerequisites

- AWS CLI
- Terraform 1.12.2
- AWS account with appropriate permissions

## Setup Instructions

### 1. Install Terraform

Using asdf version manager (my option):
Follow the official installation guide to install ASDF: https://asdf-vm.com/guide/getting-started.html

```bash
# Install Terraform plugin
asdf plugin add terraform

# Option 1: Install Terraform 1.12.2 via declare version directly
asdf install terraform 1.12.2

# Option 2: Install Terraform 1.12.2 via using .tool-version from repository
# Clone repository, move to folder with code and run:
asdf install
```

### 2. Configure AWS CLI

Follow the official AWS CLI installation guide: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

### 3. Configure AWS Profile

```bash
# Import AWS profile
aws configure import --csv credentials.csv --profile my-aws-account-profile

# Set as default profile for current session
export AWS_PROFILE=my-aws-account-profile
```

### 4. Verify Setup

Check installed versions and AWS access:
```bash
# Check Terraform version
terraform version

# Check AWS CLI version
aws --version

# Verify AWS access without explicit profile
aws sts get-caller-identity

# Test AWS CLI functionality
aws ec2 describe-instance-types --instance-types t4g.nano

# Initialize Terraform
cd terraform/task-1
terraform init
```

## Infrastructure Components

### Demo S3 Bucket
- Name: aws-devops-2025q2-shymanouski-task-1-demo
- Features:
  - Public access blocked
  - Tags managed through variables

## Usage

1. Navigate to the Terraform directory:
```bash
cd terraform/task-1
```

2. Initialize Terraform:
```bash
terraform init
```

3. Plan the changes:
```bash
terraform plan -var-file="env/main.tfvars"
```

4. Apply the changes:
```bash
terraform apply -var-file="env/main.tfvars"
```

## CI/CD

This repository uses GitHub Actions for automated deployment. The workflow:
1. Checks Terraform formatting
2. Plans the infrastructure changes
3. Applies the changes

The workflow runs on:
- Push to main branch
- Pull requests to main branch
