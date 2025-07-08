resource "aws_security_group" "bastion" {
  name   = "${var.project}-ec2-bastion-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
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

resource "aws_instance" "bastion" {
  ami                    = var.bastion_ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.main.key_name
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  source_dest_check      = false

  user_data = base64encode(templatefile("${path.module}/user-data/bastion.sh", {
    hostname          = "${var.project}-bastion"
    master_private_ip = aws_instance.k3s-master-node.private_ip
  }))

  depends_on = [aws_instance.k3s-master-node]

  tags = merge(var.tags, {
    Name = "${var.project}-bastion"
    Role = "Bastion-NAT"
  })
}

resource "aws_eip" "bastion" {
  instance = aws_instance.bastion.id
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "${var.project}-bastion-eip"
  })
}