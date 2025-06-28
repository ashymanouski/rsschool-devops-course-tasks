aws_region = "us-east-2"
project    = "aws-devops-2025q2"

tags = {
  Environment = "main"
  Project     = "aws-devops-2025q2"
  ManagedBy   = "terraform"
}

vpc_cidr = "10.0.0.0/16"

public_subnet_1_cidr  = "10.0.1.0/24"
public_subnet_2_cidr  = "10.0.2.0/24"
private_subnet_1_cidr = "10.0.10.0/24"
private_subnet_2_cidr = "10.0.11.0/24"

az_1 = "us-east-2a"
az_2 = "us-east-2b"

bastion_ami_id = "ami-0779fe5e56472b841" # Amazon Linux 2023 ARM64 in Ohio
k3s_ami_id = "ami-0d1b5a8c13042c939" # Ubuntu Server 24.04 LTS in Ohio
instance_type  = "t4g.nano"
k3s_master_instance_type = "t3.small"
k3s_worker_instance_type = "t3.nano"
ssh_user       = "ec2-user" 