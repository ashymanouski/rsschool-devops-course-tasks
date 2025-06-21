# Security Group for Bastion Host
resource "aws_security_group" "bastion" {
  name = "${var.project}-ec2-bastion-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project}-ec2-bastion-sg"
  })
}

# Bastion Host with NAT functionality
resource "aws_instance" "bastion" {
  ami                     = var.bastion_ami_id
  instance_type           = var.instance_type
  key_name                = aws_key_pair.main.key_name
  subnet_id               = aws_subnet.public_1.id
  vpc_security_group_ids  = [aws_security_group.bastion.id, aws_security_group.private.id]
  source_dest_check       = false

  user_data = base64encode(templatefile("${path.module}/user-data/bastion.sh", {}))

  tags = merge(var.tags, {
    Name = "${var.project}-bastion"
    Role = "Bastion-NAT"
  })
}