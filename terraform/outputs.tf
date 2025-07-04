output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = aws_instance.bastion.public_ip
}

output "ssh_private_key_ssm_parameter" {
  description = "SSM parameter name for SSH private key"
  value       = aws_ssm_parameter.ssh_private_key.name
}

output "ssh_public_key_ssm_parameter" {
  description = "SSM parameter name for SSH public key"
  value       = aws_ssm_parameter.ssh_public_key.name
}

output "ssh_user_ssm_parameter" {
  description = "SSM parameter name for SSH user"
  value       = aws_ssm_parameter.ssh_user.name
}

output "k3s-master-node_private_ip" {
  description = "Private IP addresses of K3s maser node"
  value       = aws_instance.k3s-master-node.private_ip
}

output "k3s_worker_node_01_private_ip" {
  description = "Private IP address of K3s worker node 01"
  value       = aws_instance.k3s_worker_node_01.private_ip
}

output "k3s_node_token_ssm_parameter" {
  description = "SSM parameter name for K3s node token"
  value       = "/edu/${var.project}/k3s/node-token"
}

output "k3s_kubeconfig_ssm_parameter" {
  description = "SSM parameter name for K3s kubeconfig"
  value       = "/edu/${var.project}/k3s/kubeconfig"
}