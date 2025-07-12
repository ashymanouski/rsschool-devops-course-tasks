#!/bin/bash
set -e

sudo hostnamectl set-hostname ${hostname}

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt update && sudo apt install -y unzip
unzip awscliv2.zip
sudo ./aws/install

curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

until sudo test -f /var/lib/rancher/k3s/server/node-token; do
  echo "Waiting for k3s to start..."
  sleep 5
done

K3S_TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)
aws ssm put-parameter \
  --region ${aws_region} \
  --name "/edu/${project}/k3s/node-token" \
  --value "$K3S_TOKEN" \
  --type "SecureString" \
  --overwrite

KUBECONFIG_CONTENT=$(sudo cat /etc/rancher/k3s/k3s.yaml)
aws ssm put-parameter \
  --region ${aws_region} \
  --name "/edu/${project}/k3s/kubeconfig" \
  --value "$KUBECONFIG_CONTENT" \
  --type "SecureString" \
  --overwrite