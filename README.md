# rsschool-devops-course-tasks
The Rolling Scopes School: AWS DevOps Course 2025 Q2

## Quick Navigation
- [Task 1: AWS Account Configuration](#task-1-documentation)
- [Task 2: Basic Infrastructure Configuration](#task-2-documentation)
- [Task 3: K8s Cluster Configuration and Creation](#task-3-documentation)
- [Task 4: Jenkins Installation and Configuration](#task-4-documentation)
- [Task 5: Simple Application Deployment with Helm](#task-5-documentation)
- [Task 6: Application Deployment via Jenkins Pipeline](#task-6-documentation)
- [Task 7: Prometheus Deployment on K8s](#task-7-documentation)

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

### 2. Update Helm Values
Before deployment, update the Docker image repository in `helm/application/flask/values.yaml` with your image that you pushed:
```yaml
image:
  repository: your-dockerhub-username/rsschool-devops-course-flask-app
  tag: latest
```

### 3. Helm Deployment
```bash
kubectl create namespace flask
helm install flask-app ./helm/application/flask -n flask
kubectl get all -n flask
```

### 4. Access the Application

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

---

# Task 6 Documentation

## Overview

Task 6: Application Deployment via Jenkins Pipeline

## Prerequisites

- K3s cluster from Task 3
- Jenkins from Task 4
- AWS ECR repository
- SonarCloud account
- Gmail account for notifications
- GitHub repository with webhook access

## Pipeline Features

### CI/CD Pipeline Components
- **Source Code Checkout**: GitHub webhook triggers
- **Application Build**: Python application compilation
- **Unit Tests**: Python pytest execution
- **Security Check**: SonarQube analysis
- **Docker Image Building**: Buildah for container creation
- **Registry Push**: AWS ECR integration
- **Kubernetes Deployment**: Helm deployment to K3s
- **Application Verification**: Health checks and connectivity tests
- **Email Notifications**: Success/failure alerts

### Pipeline Architecture
```
GitHub Webhook → Jenkins → Multi-container Pod
├── Python Container (build, tests, deployment)
├── Buildah Container (Docker build/push)
└── SonarScanner Container (security analysis)
```

## Setup Instructions

### 1. Install Jenkins with Helm Chart

```bash
# Add Jenkins Helm repository
helm repo add jenkinsci https://charts.jenkins.io
helm repo update

# Create namespace
kubectl create namespace jenkins

# Install/Re-install Jenkins with custom values
helm install jenkins jenkinsci/jenkins \
  --namespace jenkins \
  --values helm/jenkins/jenkins-values.yaml
```

### 2. Configure GitHub Webhook

Set up webhook in your GitHub repository:

```bash
# Get bastion IP from SSM
aws ssm get-parameter \
  --name "/edu/aws-devops-2025q2/bastion/eip" \
  --region us-east-2 \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text

# Configure webhook in GitHub repository:
# - URL: http://<bastion-ip>/github-webhook/
# - Content type: application/json
# - Events: Just the push event
# - Active: true
```

### 3. Update Jenkins Credentials

Before running the pipeline, update the following existing credentials in Jenkins:
```bash
# Access Jenkins UI
# Go to: Manage Jenkins → Credentials → System → Global credentials
```

#### SonarQube Token
```bash
# Update existing credential:
# - ID: sonarqube-token
# - Secret: [Your SonarCloud Token]
```

#### Email Recipients List
```bash
# Update existing credential:
# - ID: email-recipients
# - Secret: email1@gmail.com,email2@gmail.com
```

#### AWS Account ID
```bash
# Update existing credential:
# - ID: aws-account-id
# - Secret: [Your AWS Account ID]
```

### 4. Configure Email Notifications

Update the Jenkins configuration to set up Gmail SMTP:

```bash
# Go to: Manage Jenkins → Configure System → Extended E-mail Notification
# Configure SMTP settings:
# - SMTP server: smtp.gmail.com
# - SMTP Port: 587
# - Use TLS: true
# - Use SSL: false
# - Username: your-gmail@gmail.com
# - Password: [Your Gmail App Password]
```

## Pipeline Execution

### Pipeline Triggers

The pipeline is primarily triggered by GitHub webhooks on push events to the `task_6` branch:

```bash
# Automatic trigger via GitHub webhook
# - Push to task_6 branch triggers pipeline automatically
# - Webhook URL: http://<bastion-ip>/github-webhook/
# - No manual intervention required

# Manual trigger (if needed)
# - Go to Jenkins UI → flask-app-pipeline → Build Now
# - Useful for testing or re-running failed builds
```

### Expected Pipeline Flow
1. **Checkout**: Clone repository from GitHub
2. **Build**: Compile Python application
3. **Unit Tests**: Run pytest in Python container
4. **Security Check**: SonarQube analysis
5. **Build Docker**: Create Docker image with Buildah
6. **Push to ECR**: Upload image to AWS ECR
7. **Deploy**: Helm deployment to K3s cluster
8. **Verify**: Health checks and connectivity tests
9. **Notify**: Email success/failure notifications


## Troubleshooting

### Common Issues

#### Email Notifications Not Working
- Verify Gmail app password is correct
- Check SMTP settings in Jenkins configuration
- Ensure email recipients credential is properly set

#### SonarQube Analysis Failing
- Verify SonarCloud token is valid
- Check project key and organization settings
- Ensure source code path is correct

#### ECR Push Failing
- Verify AWS credentials and permissions
- Check ECR repository exists
- Ensure Buildah container has proper permissions

#### Helm Deployment Issues
- Ensure image pull secrets are configured

#### GitHub Webhook Issues
- Verify bastion IP is accessible
- Check webhook URL format: `http://<bastion-ip>/github-webhook/`
- Ensure repository has push permissions
- Verify nginx reverse proxy is configured on bastion

---

# Task 7 Documentation

## Overview

Task 7: Prometheus Deployment on K8s - Monitoring Stack Setup

## Prerequisites

- K3s cluster from Task 3
- Jenkins from Task 4
- kubectl configured
- Helm installed

## Architecture

```
Monitoring Stack
├── Prometheus Server (NodePort: 32002)
│   ├── Node Exporter (DaemonSet)
│   └── Kube State Metrics
├── Grafana (NodePort: 32004)
│   ├── Prometheus Data Source
│   ├── Cluster Monitoring Dashboard
│   └── Alert Rules (CPU/Memory)
└── smtp4dev (SMTP Server for Testing)
```

## Setup Instructions

### 1. Configure Jenkins Credentials

Before running the monitoring pipeline, configure Grafana admin credentials in Jenkins:

```bash
# Access Jenkins UI
# Go to: Manage Jenkins → Credentials → System → Global credentials
```

#### Grafana Admin Credentials
```bash
# The credential is already created by Jenkins JCasC configuration
# You need to update the existing credential in Jenkins dashboard:

# 1. Go to Jenkins → Manage Jenkins → Credentials → System → Global credentials
# 2. Find credential with ID: grafana-admin-credentials
# 3. Click on it and then "Update"
# 4. Replace SECRET_HAS_TO_BE_ADDED_MANUALLY_AFTER_JENKINS_PROVISIONING with your own password and username
# 5. Save the credential
```

### 2. Deploy Monitoring Stack via Jenkins Pipeline

The monitoring stack is deployed using a dedicated Jenkins pipeline:

```bash
# Access Jenkins UI
# Go to: Jenkins → Monitoring Stack Pipeline → Build Now
```

#### Pipeline Stages
1. **Setup Tools**: Configure Helm repositories
2. **Deploy Prometheus**: Install Prometheus with custom configuration
3. **Deploy Node Exporter**: Install node-level metrics collection
4. **Deploy Kube State Metrics**: Install Kubernetes object metrics
5. **Deploy Dashboards**: Configure Grafana dashboards and alerting
6. **Deploy SMTP Server**: Install smtp4dev for email testing
7. **Deploy Grafana**: Install Grafana with data sources and credentials

### 3. Verify Deployment

```bash
# Check all monitoring components
kubectl get all -n monitoring

# Verify pods are running
kubectl get pods -n monitoring

# Check services
kubectl get svc -n monitoring

# Check config maps
kubectl get configmaps -n monitoring
```

Expected output:
```bash
# kubectl get all -n monitoring
NAME                                      READY   STATUS    RESTARTS      AGE
pod/grafana-66bb6cdd89-gt4br              1/1     Running   0             62m
pod/kube-state-metrics-57984ff677-5l9gt   1/1     Running   0             62m
pod/node-exporter-fp869                   1/1     Running   0             62m
pod/node-exporter-j28sn                   1/1     Running   0             62m
pod/prometheus-alertmanager-0             1/1     Running   0             63m
pod/prometheus-server-67487745d-kggv7     1/1     Running   0             63m
pod/smtp4dev-7f6d8cd78-4h5jp              1/1     Running   3 (33m ago)   62m

NAME                              TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
service/grafana                   NodePort    10.43.xxx.xxx    <none>        3000:32004/TCP   62m
service/kube-state-metrics        ClusterIP   10.43.xxx.xxx    <none>        8080/TCP         62m
service/node-exporter             ClusterIP   10.43.xxx.xxx    <none>        9100/TCP         62m
service/prometheus-alertmanager   ClusterIP   10.43.xxx.xxx    <none>        80/TCP           63m
service/prometheus-server         NodePort    10.43.xxx.xxx    <none>        80:32002/TCP     63m
service/smtp4dev                  ClusterIP   10.43.xxx.xxx    <none>        25/TCP,80/TCP    62m

NAME                           DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
daemonset.apps/node-exporter   2         2         2       2            2           <none>          62m

NAME                                 READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/grafana              1/1     1            1           62m
deployment.apps/kube-state-metrics   1/1     1            1           62m
deployment.apps/prometheus-server    1/1     1            1           63m
deployment.apps/smtp4dev             1/1     1            1           62m

# kubectl get configmaps -n monitoring
NAME                           DATA   AGE
cluster-monitoring-dashboard   1      63m
grafana-alerting-config        3      62m
grafana-envvars                10     62m
grafana-provider               1      62m
kube-root-ca.crt               1      63m
prometheus-alertmanager        1      63m
prometheus-server              2      63m

# kubectl get secrets -n monitoring
NAME                                       TYPE                 DATA   AGE
grafana-admin                              Opaque               1      63m
grafana-datasources                        Opaque               1      63m
grafana-smtp                               Opaque               2      63m
sh.helm.release.v1.grafana.v1              helm.sh/release.v1   1      63m
sh.helm.release.v1.kube-state-metrics.v1   helm.sh/release.v1   1      63m
sh.helm.release.v1.node-exporter.v1        helm.sh/release.v1   1      63m
sh.helm.release.v1.prometheus.v1           helm.sh/release.v1   1      63m
sh.helm.release.v1.smtp4dev.v1             helm.sh/release.v1   1      63m
```

## Access Monitoring Services

### 1. External Access (NodePort)

If you have external access to your Kubernetes cluster:

```bash
# Get node IP
kubectl get nodes -o wide

# Access URLs
Prometheus: http://<node-ip>:32002
Grafana: http://<node-ip>:32004
```

### 2. Access via Bastion (Recommended)

Access monitoring services through the bastion host reverse proxy (same as Jenkins access):

```bash
# Get bastion IP from SSM
aws ssm get-parameter \
  --name "/edu/aws-devops-2025q2/bastion/eip" \
  --region us-east-2 \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text
```

Then access:
- **Jenkins**: http://<bastion-ip>/

### 3. Local Port Forwarding (Recommended)

For local development and testing:

```bash
# Prometheus
kubectl port-forward svc/prometheus-server 9090:80 -n monitoring

# Grafana (in another terminal)
kubectl port-forward svc/grafana 3000:3000 -n monitoring

# smtp4dev (in another terminal)
kubectl port-forward svc/smtp4dev 5000:80 -n monitoring
```

Then access:
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000
- **smtp4dev Web Interface**: http://localhost:5000


## Grafana Configuration

### Login Credentials
- **Username**: [Set via Jenkins credentials]
- **Password**: [Set via Jenkins credentials]

### Pre-configured Components

#### Data Sources
- **Prometheus**: Automatically configured
- **URL**: http://prometheus-server.monitoring.svc.cluster.local:80

#### Dashboards
1. **Cluster Monitoring Dashboard**: CPU, memory, storage metrics
   - Real-time metrics with 30-second refresh
   - Node-level resource utilization
   - Cluster health overview

#### Alert Rules
1. **High CPU Utilization**: >80% for 1 minute
2. **High Memory Utilization**: >85% for 1 minute

#### Contact Points
- **Email**: ashymanouski@student.com
- **SMTP**: smtp4dev.monitoring.svc.cluster.local:25

## Testing Alerts

### 1. CPU Stress Test

```bash
# SSH to any cluster node
ssh -i ~/.ssh/your-key.pem ubuntu@<node-ip>

# Install stress tool
sudo apt-get update
sudo apt-get install -y stress

# Run CPU stress test for 5 minutes (10 CPU workers)
sudo stress --cpu 10 --timeout 300s
```

### 2. Memory Stress Test

```bash
# Run memory stress test for 5 minutes (3 workers, 500MB each)
sudo stress --vm 3 --vm-bytes 500M --timeout 300s &
```

### 3. Monitor Alerts

During stress tests:
1. Check Grafana Alerting → Alert Rules
2. Verify alerts are firing
3. Check smtp4dev web interface for received emails
4. Verify email notifications are delivered

## Monitoring Components

### Prometheus
- **Purpose**: Metrics collection and storage
- **Port**: 32002 (NodePort)
- **Storage**: 10Gi persistent volume
- **Scraping**: Node Exporter, Kube State Metrics

### Grafana
- **Purpose**: Metrics visualization and alerting
- **Port**: 32004 (NodePort)
- **Storage**: 8Gi persistent volume
- **Features**: Dashboards, alerting, SMTP integration

### Node Exporter
- **Purpose**: Node-level metrics collection
- **Deployment**: DaemonSet (runs on all nodes)
- **Metrics**: CPU, memory, disk, network

### Kube State Metrics
- **Purpose**: Kubernetes object metrics
- **Metrics**: Pods, nodes, services, deployments

### smtp4dev
- **Purpose**: SMTP server for email testing
- **SMTP Port**: 25 (ClusterIP) - for email delivery
- **Web Interface Port**: 80 (ClusterIP) - for web UI
- **Web Interface**: http://localhost:5000 (via port-forward to port 80)


## Cleanup

To remove the monitoring stack:

```bash
# Delete monitoring namespace (removes all components)
kubectl delete namespace monitoring

# Or delete individual components
helm uninstall prometheus -n monitoring
helm uninstall grafana -n monitoring
helm uninstall node-exporter -n monitoring
helm uninstall kube-state-metrics -n monitoring
helm uninstall smtp4dev -n monitoring
```
