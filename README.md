# rsschool-devops-course-tasks
The Rolling Scopes School: AWS DevOps Course 2025 Q2

## Quick Navigation
- [Task 1: AWS Account Configuration](#task-1-documentation)
- [Task 2: Basic Infrastructure Configuration](#task-2-documentation)
- [Task 3: K8s Cluster Configuration and Creation](#task-3-documentation)
- [Task 4: Jenkins Installation and Configuration](#task-4-documentation)
- [Task 5: Simple Application Deployment with Helm](#task-5-documentation)

# Task 1 Documentation

Task 1: AWS Account Configuration

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

---

# Task 2 Documentation

## Overview

Task 2: Basic Infrastructure Configuration

## File Organization

```
terraform/
├── networking.tf          # VPC, subnets, routing, NAT Gateway, Network ACLs
├── compute-demo-workload.tf # Security groups and demo instances
├── bastion.tf             # Bastion host configuration
├── ssh.tf                 # SSH key pair and SSM parameters
├── variables.tf           # Variable definitions
├── outputs.tf             # Output values
├── provider.tf            # AWS provider configuration
├── backend.tf             # S3 backend configuration
├── env/
│   └── main.tfvars        # Environment-specific variables
└── user-data/
    └── common.sh          # Common user data script
```

## Network Architecture

```
Internet Gateway
├── Public Subnet 1 (us-east-2a, 10.0.1.0/24)
│   ├── NAT Gateway (with Elastic IP)
│   └── Bastion Host (t4g.nano)
├── Public Subnet 2 (us-east-2b, 10.0.2.0/24)
│   └── Public Demo Instance
├── Private Subnet 1 (us-east-2a, 10.0.10.0/24)
│   └── Private Demo Instance 1
└── Private Subnet 2 (us-east-2b, 10.0.11.0/24)
    └── Private Demo Instance 2
```

## Infrastructure Components

### VPC Configuration
- **CIDR**: 10.0.0.0/16
- **DNS**: Enabled (hostnames and support)
- **Region**: us-east-2

### Subnets
- **Public Subnet 1**: 10.0.1.0/24 (us-east-2a) - NAT Gateway, Bastion, Demo Instance
- **Public Subnet 2**: 10.0.2.0/24 (us-east-2b) - Demo Instance
- **Private Subnet 1**: 10.0.10.0/24 (us-east-2a) - Demo Instance
- **Private Subnet 2**: 10.0.11.0/24 (us-east-2b) - Demo Instance

### Routing
- **Public Subnets**: Route to Internet Gateway (0.0.0.0/0)
- **Private Subnets**: Route to NAT Gateway (0.0.0.0/0)
- **Internal**: All subnets can reach each other

### Security
- **Security Groups**: Instance-level filtering
  - Public SG: HTTP (80) and HTTPS (443) from anywhere, all outbound (attached to public instances)
  - Private SG: All traffic from same SG, all outbound (attached to private instances and public instances)
  - Bastion SG: SSH (22) from anywhere, all outbound (attached to bastion)
- **Network ACLs**: Subnet-level filtering
  - Public NACL: All traffic allowed (with test deny rule for 8.8.8.8)
  - Private NACL: All traffic allowed

## Connectivity Instructions

### Access Bastion Host
```bash
# Get bastion public IP
terraform output bastion_public_ip

# SSH to bastion (replace with your key and IP)
ssh -i ~/.ssh/your-key.pem ec2-user@<bastion-public-ip>
```

### Direct SSH to Private Instances (via Bastion)
```bash
# Get bastion public IP
terraform output bastion_public_ip

# Get private instance IPs
terraform output private_instance_ips

# Connect directly to private instance through bastion
ssh -i ~/.ssh/your-key.pem -o "ProxyCommand=ssh -i ~/.ssh/your-key.pem -W %h:%p ec2-user@<bastion-public-ip>" ec2-user@<private-instance-private-ip>
```

### Test Connectivity
```bash
# From private instance - test internet access
ping 8.8.8.8
curl google.com

# Test VPC internal communication
ping <other-instance-private-ip>

# Test traceroute to see NAT path
traceroute google.com
```


# Task 3 Documentation

## Overview

Task 3: K3s Cluster Configuration and Creation.

## Architecture

```
Internet Gateway
├── Public Subnet 1 (us-east-2a, 10.0.1.0/24)
│   ├── NAT Gateway (with Elastic IP)
│   └── Bastion Host (t4g.nano)
├── Private Subnet 1 (us-east-2a, 10.0.10.0/24)
│   └── K3s Master Node (t4g.small)
└── Private Subnet 2 (us-east-2b, 10.0.11.0/24)
    └── K3s Worker Node (t4g.small)
```

## Deployment

### Initial Setup
```bash
cd terraform
terraform init
terraform plan -var-file="env/main.tfvars"
terraform apply -var-file="env/main.tfvars"
```

## Cluster Access

### 1. Get Kubeconfig
```bash
# Fetch kubeconfig from SSM
aws ssm get-parameter \
  --region us-east-2 \
  --name "/edu/aws-devops-2025q2/k3s/kubeconfig" \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text > ~/.kube/config
```

### 2. Establish SSH Tunnel (for connection from local computer)
```bash
# SSH tunnel via bastion to master node
ssh -i ~/.ssh/your-key.pem -o "ProxyCommand=ssh -i ~/.ssh/your-key.pem -W %h:%p ubuntu@<bastion-public-ip>" -L 6443:localhost:6443 ubuntu@<master-private-ip>
```

### 3. Test Cluster Access
```bash
# Test from local machine
kubectl get nodes
kubectl get pods --all-namespaces

# Deploy test workload
kubectl apply -f https://k8s.io/examples/pods/simple-pod.yaml
kubectl get pods
```

## Expected Output
```bash
# kubectl get nodes
NAME                    STATUS   ROLES                  AGE   VERSION
ip-10-0-10-xxx.ec2.internal   Ready    control-plane,master   5m   v1.28.5+k3s1
ip-10-0-11-xxx.ec2.internal   Ready    <none>                 3m   v1.28.5+k3s1

# kubectl get all --all-namespaces
NAMESPACE     NAME        READY   STATUS    RESTARTS   AGE
default       pod/nginx   1/1     Running   0          2m
........
........
```

## Cleanup
```bash
terraform destroy -var-file="env/main.tfvars"
```

---

# Task 4 Documentation

## Overview

Task 4: Jenkins Installation and Configuration

## Prerequisites

- K3s cluster from Task 3
- Helm installed
- kubectl configured

## Installation Steps

### 1. Create Jenkins Namespace
```bash
kubectl create namespace jenkins
```

### 2. Apply Volume Configuration
```bash
kubectl apply -f manifests/jenkins-01-volume.yaml
```

### 3. Fix Volume Permissions
```bash
kubectl apply -f manifests/fix-permissions-pod.yaml
kubectl wait --for=condition=ready pod/jenkins-permissions-fix -n jenkins --timeout=300s
kubectl logs jenkins-permissions-fix -n jenkins
kubectl delete pod jenkins-permissions-fix -n jenkins
```

### 4. Apply Service Account
```bash
kubectl apply -f manifests/jenkins-02-sa.yaml
```

### 5. Install Jenkins via Helm
```bash
helm repo add jenkinsci https://charts.jenkins.io
helm repo update
helm install jenkins jenkinsci/jenkins --namespace jenkins --values manifests/jenkins-values.yaml
```

## Access Jenkins

### Get Admin Password
```bash
kubectl exec -n jenkins jenkins-0 -- cat /run/secrets/additional/chart-admin-password
```

### Access Options

#### Option 1: Port Forwarding
```bash
kubectl port-forward svc/jenkins 8080:8080 -n jenkins
```
Then access: http://localhost:8080

#### Option 2: Direct Access via Bastion Reverse Proxy
```bash
# Get bastion IP from SSM
aws ssm get-parameter \
  --name "/edu/aws-devops-2025q2/bastion/eip" \
  --region us-east-2 \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text
```
Then access: `http://<bastion-ip>`

---

# Task 5 Documentation

## Overview

Task 5: Simple Application Deployment with Helm

## Prerequisites

- K3s cluster from Task 3
- Docker installed
- Helm installed
- kubectl configured

## Quick Deployment

### 1. Docker Build and Push
```bash
docker login
cd app
docker build -t your-dockerhub-username/rsschool-devops-course-flask-app:latest .
docker push your-dockerhub-username/rsschool-devops-course-flask-app:latest
```

**Docker Hub**: https://hub.docker.com/r/your-dockerhub-username/rsschool-devops-course-flask-app

### 2. Helm Deployment
```bash
kubectl create namespace flask
helm install flask-app ./helm/application/flask -n flask
kubectl get all -n flask
```

### 3. Access the Application

#### Option 1: Via Bastion Reverse Proxy (Recommended)
```bash
# Get bastion IP from SSM
aws ssm get-parameter \
  --name "/edu/aws-devops-2025q2/bastion/eip" \
  --region us-east-2 \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text
```

Then access: `http://<bastion-ip>/flask/`

#### Option 2: Port Forwarding
```bash
kubectl port-forward svc/flask-app 8080:8080 -n flask
```
Then access: http://localhost:8080

**Note**: Jenkins is still accessible at `http://<bastion-ip>/` (root path)
