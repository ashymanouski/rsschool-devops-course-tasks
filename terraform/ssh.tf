resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "main" {
  key_name   = "${var.project}-key"
  public_key = tls_private_key.ssh.public_key_openssh

  tags = merge(var.tags, {
    Name = "${var.project}-key-pair"
  })
}

resource "aws_ssm_parameter" "ssh_private_key" {
  name  = "/edu/${var.project}/ssh/private-key"
  type  = "SecureString"
  value = tls_private_key.ssh.private_key_pem

  tags = merge(var.tags, {
    Name = "${var.project}-ssh-private-key"
  })
}

resource "aws_ssm_parameter" "ssh_public_key" {
  name  = "/edu/${var.project}/ssh/public-key"
  type  = "String"
  value = tls_private_key.ssh.public_key_openssh

  tags = merge(var.tags, {
    Name = "${var.project}-ssh-public-key"
  })
}

resource "aws_ssm_parameter" "ssh_user" {
  name  = "/edu/${var.project}/ssh/user"
  type  = "String"
  value = var.ssh_user

  tags = merge(var.tags, {
    Name = "${var.project}-ssh-user"
  })
}