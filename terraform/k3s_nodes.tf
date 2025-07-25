resource "aws_security_group" "k3s_nodes_sg" {
  name   = "${var.project}-ec2-k3s-nodes-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 6443
    to_port         = 6443
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    from_port       = 32000
    to_port         = 32000
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    from_port       = 32001
    to_port         = 32001
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

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
    Name = "${var.project}-ec2-k3s-nodes-sg"
  })
}



resource "aws_instance" "k3s-master-node" {
  ami                    = var.k3s_ami_id
  instance_type          = var.k3s_master_instance_type
  key_name               = aws_key_pair.main.key_name
  subnet_id              = aws_subnet.private_1.id
  vpc_security_group_ids = [aws_security_group.k3s_nodes_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.k3s_master.name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    tags = merge(var.tags, {
      Name = "${var.project}-k3s-master-node-root"
    })
  }

  user_data = base64encode(templatefile("${path.module}/user-data/k3s-master.sh", {
    hostname   = "${var.project}-k3s-master-node"
    project    = var.project
    aws_region = var.aws_region
  }))

  tags = merge(var.tags, {
    Name = "${var.project}-k3s-master-node"
  })
}


# Wait for master node to be ready by checking SSM parameter
resource "null_resource" "wait_for_master_ready" {
  depends_on = [aws_instance.k3s-master-node]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for k3s master to be ready..."
      for i in {1..30}; do
        if aws ssm get-parameter \
          --region ${var.aws_region} \
          --name "/edu/${var.project}/k3s/node-token" \
          --with-decryption \
          --query 'Parameter.Value' \
          --output text > /dev/null 2>&1; then
          echo "Master node is ready!"
          break
        fi
        echo "Attempt $i: Master not ready yet, waiting 10 seconds..."
        sleep 10
      done
    EOT
  }
}

resource "aws_instance" "k3s_worker_node_01" {
  ami                    = var.k3s_ami_id
  instance_type          = var.k3s_worker_instance_type
  key_name               = aws_key_pair.main.key_name
  subnet_id              = aws_subnet.private_2.id
  vpc_security_group_ids = [aws_security_group.k3s_nodes_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.k3s_worker.name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    tags = merge(var.tags, {
      Name = "${var.project}-k3s-worker-node-01-root"
    })
  }

  user_data = base64encode(templatefile("${path.module}/user-data/k3s-worker.sh", {
    hostname   = "${var.project}-k3s-worker-node-01"
    project    = var.project
    aws_region = var.aws_region
    master_ip  = aws_instance.k3s-master-node.private_ip
  }))

  depends_on = [null_resource.wait_for_master_ready]

  tags = merge(var.tags, {
    Name = "${var.project}-k3s-worker-node-01"
  })
}

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

resource "aws_iam_policy" "k3s_ecr" {
  name = "${var.project}-k3s-ecr-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "k3s_master_ssm" {
  role       = aws_iam_role.k3s_master.name
  policy_arn = aws_iam_policy.k3s_master_ssm.arn
}

resource "aws_iam_role_policy_attachment" "k3s_master_ecr" {
  role       = aws_iam_role.k3s_master.name
  policy_arn = aws_iam_policy.k3s_ecr.arn
}

resource "aws_iam_role_policy_attachment" "k3s_master_ebs_csi" {
  role       = aws_iam_role.k3s_master.name
  policy_arn = aws_iam_policy.ebs_csi_driver_policy.arn
}

resource "aws_iam_instance_profile" "k3s_master" {
  name = "${var.project}-k3s-master-profile"
  role = aws_iam_role.k3s_master.name

  tags = var.tags
}

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

resource "aws_iam_role_policy_attachment" "k3s_worker_ecr" {
  role       = aws_iam_role.k3s_worker.name
  policy_arn = aws_iam_policy.k3s_ecr.arn
}

resource "aws_iam_role_policy_attachment" "k3s_worker_ebs_csi" {
  role       = aws_iam_role.k3s_worker.name
  policy_arn = aws_iam_policy.ebs_csi_driver_policy.arn
}

resource "aws_iam_instance_profile" "k3s_worker" {
  name = "${var.project}-k3s-worker-profile"
  role = aws_iam_role.k3s_worker.name

  tags = var.tags
}