resource "aws_security_group" "public" {
  name   = "${var.project}-ec2-public-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project}-ec2-public-sg"
  })
}

resource "aws_instance" "public" {
  ami                    = var.bastion_ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.main.key_name
  subnet_id              = aws_subnet.public_2.id
  vpc_security_group_ids = [aws_security_group.public.id]

  user_data = base64encode(templatefile("${path.module}/user-data/common.sh", {
    hostname = "${var.project}-public-demo-instance"
  }))

  tags = merge(var.tags, {
    Name = "${var.project}-public-demo-instance"
  })
}