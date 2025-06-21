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

output "private_instance_ips" {
  description = "Private IP addresses of instances in private subnets"
  value       = [aws_instance.private_1.private_ip, aws_instance.private_2.private_ip]
}