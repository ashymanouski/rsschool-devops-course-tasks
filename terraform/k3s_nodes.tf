resource "aws_security_group" "k3s_master_node_sg" {
  name   = "${var.project}-ec2-k3s-master-node-sg"
  vpc_id = aws_vpc.main.id

  # K3s API server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # All traffic from worker nodes
  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.k3s_worker_node_sg.id]
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

  # All traffic from master node
  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.k3s_master_node_sg.id]
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
  iam_instance_profile   = aws_iam_instance_profile.k3s_master.name

  user_data = base64encode(templatefile("${path.module}/user-data/k3s-master.sh", {
    hostname    = "${var.project}-k3s-master-node"
    project     = var.project
    aws_region  = var.aws_region
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
  iam_instance_profile   = aws_iam_instance_profile.k3s_worker.name

  user_data = base64encode(templatefile("${path.module}/user-data/k3s-worker.sh", {
    hostname       = "${var.project}-k3s-worker-node-01"
    project        = var.project
    aws_region     = var.aws_region
    master_ip      = aws_instance.k3s-master-node.private_ip
  }))

  depends_on = [aws_instance.k3s-master-node]

  tags = merge(var.tags, {
    Name = "${var.project}-k3s-worker-node-01"
  })
}

# IAM role for K3s master node (can put to SSM)
resource "aws_iam_role" "k3s_master" {
  name = "${var.project}-k3s-master-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "k3s_master_ssm" {
  name = "${var.project}-k3s-master-ssm-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:PutParameter",
          "ssm:GetParameter"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/edu/${var.project}/k3s/*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "k3s_master_ssm" {
  role       = aws_iam_role.k3s_master.name
  policy_arn = aws_iam_policy.k3s_master_ssm.arn
}

resource "aws_iam_instance_profile" "k3s_master" {
  name = "${var.project}-k3s-master-profile"
  role = aws_iam_role.k3s_master.name

  tags = var.tags
}

# IAM role for K3s worker nodes (can get from SSM)
resource "aws_iam_role" "k3s_worker" {
  name = "${var.project}-k3s-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "k3s_worker_ssm" {
  name = "${var.project}-k3s-worker-ssm-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/edu/${var.project}/k3s/*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "k3s_worker_ssm" {
  role       = aws_iam_role.k3s_worker.name
  policy_arn = aws_iam_policy.k3s_worker_ssm.arn
}

resource "aws_iam_instance_profile" "k3s_worker" {
  name = "${var.project}-k3s-worker-profile"
  role = aws_iam_role.k3s_worker.name

  tags = var.tags
}