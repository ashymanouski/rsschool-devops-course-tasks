resource "aws_security_group" "k3s_master_node_sg" {
  name   = "${var.project}-ec2-k3s-master-node-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project}-ec2-k3s-master-node-sg"
  })
}

resource "aws_security_group" "k3s_worker_node_sg" {
  name   = "${var.project}-ec2-k3s-worker-node-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project}-ec2-k3s-worker-node-sg"
  })
}

resource "aws_instance" "k3s-master-node" {
  ami                    = var.k3s_ami_id
  instance_type          = var.k3s_master_instance_type
  key_name               = aws_key_pair.main.key_name
  subnet_id              = aws_subnet.private_1.id
  vpc_security_group_ids = [aws_security_group.k3s_master_node_sg.id]

  user_data = base64encode(templatefile("${path.module}/user-data/common.sh", {
    hostname = "${var.project}-k3s-master-node"
  }))

  tags = merge(var.tags, {
    Name = "${var.project}-k3s-master-node"
  })
}

resource "aws_instance" "k3s_worker_node_01" {
  ami                    = var.k3s_ami_id
  instance_type          = var.k3s_worker_instance_type
  key_name               = aws_key_pair.main.key_name
  subnet_id              = aws_subnet.private_2.id
  vpc_security_group_ids = [aws_security_group.k3s_worker_node_sg.id]

  user_data = base64encode(templatefile("${path.module}/user-data/common.sh", {
    hostname = "${var.project}-k3s-worker-node-01"
  }))

  tags = merge(var.tags, {
    Name = "${var.project}-k3s-worker-node-01"
  })
}