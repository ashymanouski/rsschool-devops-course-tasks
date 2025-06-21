# Security Group for Public Instance
resource "aws_security_group" "public" {
  name = "${var.project}-ec2-public-sg"
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
    Name = "${var.project}-ec2-public-sg"
  })
}

# Security Group for Private Instances
resource "aws_security_group" "private" {
  name = "${var.project}-ec2-private-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project}-ec2-private-sg"
  })
}

# EC2 Instance in Public Subnet 2
resource "aws_instance" "public" {
  ami                    = var.bastion_ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.main.key_name
  subnet_id              = aws_subnet.public_2.id
  vpc_security_group_ids = [aws_security_group.public.id, aws_security_group.private.id]

  tags = merge(var.tags, {
    Name = "${var.project}-public-demo-instance"
  })
}

# EC2 Instance in Private Subnet 1
resource "aws_instance" "private_1" {
  ami                    = var.private_ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.main.key_name
  subnet_id              = aws_subnet.private_1.id
  vpc_security_group_ids = [aws_security_group.private.id]
  
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    ssh_user = var.ssh_user
  }))

  tags = merge(var.tags, {
    Name = "${var.project}-private-demo-instance-1"
  })
}

# EC2 Instance in Private Subnet 2
resource "aws_instance" "private_2" {
  ami                    = var.private_ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.main.key_name
  subnet_id              = aws_subnet.private_2.id
  vpc_security_group_ids = [aws_security_group.private.id]
  
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    ssh_user = var.ssh_user
  }))

  tags = merge(var.tags, {
    Name = "${var.project}-private-demo-instance-2"
  })
}