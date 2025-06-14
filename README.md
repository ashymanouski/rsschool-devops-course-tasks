# rsschool-devops-course-tasks
The Rolling Scopes School: AWS DevOps Course 2025 Q2


# Task 1 Documentation

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

## Task 1 - AWS Account Configuration

1. **Task:** https://github.com/rolling-scopes-school/tasks/blob/master/devops/modules/1_basic-configuration/task_1.md

2. **What has been done:**
   - [x] 1.1 **AWS CLI and Terraform Installation**
     - AWS CLI 2 installed and configured
     - Terraform 1.12.2 installed via asdf version manager
   - [x] 1.2 **IAM User Configuration**
     - Created IAM user with required policies
     - Configured MFA for both IAM and root users
     - Generated Access Key ID and Secret Access Key
   - [x] 1.3 **AWS CLI Configuration**
     - Configured AWS CLI with user credentials
     - Verified configuration with EC2 instance type check
   - [x] 1.4 **GitHub Repository Setup**
     - Created repository `rsschool-devops-course-tasks`
   - [x] 1.5 **S3 Bucket Creation**
     - Created bucket for Terraform states
     - Implemented public access blocking
   - [x] 1.6 **IAM Role for GitHub Actions**
     - Created `GithubActionsRole` with required policies
     - Configured trust relationship for GitHub Actions
   - [x] 1.7 **GitHub Actions Workflow**
     - Implemented three-stage workflow:
       - `terraform-check` for format checking
       - `terraform-plan` for deployment planning
       - `terraform-apply` for infrastructure deployment
   - [x] 1.8 **Code Organization**
     - Separated variables into `variables.tf`
     - Organized resources into separate files
     - Created comprehensive README documentation

3. **Link to GitHub Actions Workflow:** https://github.com/ashymanouski/rsschool-devops-course-tasks/actions/runs/15654668635

4. **Done:** `15.03.2025` / **Deadline:** `15.03.2025`

5. **Screenshots:**
   5.1 **Software Versions**
   - AWS CLI version
   - Terraform version

   5.2 **MFA Configuration**
   - IAM User MFA setup
   - Root User MFA setup

   5.3 **AWS CLI Configuration**
   - AWS CLI credentials setup
   - EC2 instance type verification

   5.4 **S3 Bucket Configuration**
   - Bucket creation
   - Public access blocking
   - Tags configuration

   5.5 **IAM Role Configuration**
   - GithubActionsRole creation
   - Trust policy setup
   - Required policies attachment

   5.6 **GitHub Actions Workflow**
   - Workflow configuration
   - Successful run results
   - Terraform plan output

6. **Infrastructure Components**

   6.1 **S3 Bucket**
   ```hcl
   resource "aws_s3_bucket" "demo" {
     bucket = var.s3_bucket_name
     tags   = var.tags
   }
   ```

   6.2 **Public Access Block**
   ```hcl
   resource "aws_s3_bucket_public_access_block" "demo" {
     bucket = aws_s3_bucket.demo.id

     block_public_acls       = true
     block_public_policy     = true
     ignore_public_acls      = true
     restrict_public_buckets = true
   }
   ```

7. **GitHub Actions Workflow Structure**
   ```yaml
   jobs:
     terraform-check:
       # Format checking
     terraform-plan:
       # Deployment planning
     terraform-apply:
       # Infrastructure deployment
   ```

8. **Evaluation Criteria Coverage**

   - [x] MFA User configured (10 points)
   - [x] Bucket and GithubActionsRole IAM role configured (20 points)
   - [x] Github Actions workflow created (30 points)
   - [x] Code Organization (10 points)
   - [x] Verification (10 points)
   - [x] Additional Tasks (20 points)
     - [x] Documentation (5 points)
     - [x] Submission (5 points)
     - [x] Secure authorization (10 points)

9. **IMPORTANT**  
   If you notice any mistakes or issues, please don't rush with the evaluation. Instead, please contact me on Discord (@ashymanouski) so I have a chance to fix them.
