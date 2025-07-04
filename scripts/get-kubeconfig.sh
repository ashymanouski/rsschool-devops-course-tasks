#!/bin/bash

# Script to fetch kubeconfig from SSM and set up local kubectl access
# Usage: ./get-kubeconfig.sh [aws-region] [project-name]

AWS_REGION=${1:-"us-east-2"}
PROJECT=${2:-"aws-devops-2025q2"}
KUBECONFIG_PATH="$HOME/.kube/config"

echo "Fetching kubeconfig from SSM..."

# Create .kube directory if it doesn't exist
mkdir -p "$HOME/.kube"

# Get kubeconfig from SSM
aws ssm get-parameter \
  --region "$AWS_REGION" \
  --name "/edu/${PROJECT}/k3s/kubeconfig" \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text > "$KUBECONFIG_PATH"

if [ $? -eq 0 ]; then
  echo "Kubeconfig saved to: $KUBECONFIG_PATH"
  echo ""
  echo "Kubeconfig is now set as default. You can use standard kubectl commands:"
  echo "kubectl get nodes"
  echo "kubectl get pods --all-namespaces"
else
  echo "Failed to fetch kubeconfig from SSM"
  exit 1
fi