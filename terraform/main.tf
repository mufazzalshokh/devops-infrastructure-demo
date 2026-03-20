# ---------------------------------------------------------------------------
# Main infrastructure definition
# Demonstrates: VPC, subnets, security groups, EC2, S3, IAM
# All resources tagged consistently for cost tracking and management
# ---------------------------------------------------------------------------

locals {
  common_tags = {
    Project     = var.app_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = "devops-infrastructure-demo"
  }
  name_prefix = "${var.app_name}-${var.environment}"
}

# ---------------------------------------------------------------------------
# VPC — isolated network for all our resources
# ---------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

# ---------------------------------------------------------------------------
# Subnets
# ---------------------------------------------------------------------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-subnet"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}a"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-subnet"
    Tier = "private"
  })
}

# ---------------------------------------------------------------------------
# Internet Gateway — allows public subnet to reach internet
# ---------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# ---------------------------------------------------------------------------
# Route table — direct internet traffic through IGW
# ---------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# Security Group — firewall rules for EC2
# ---------------------------------------------------------------------------
resource "aws_security_group" "api" {
  name        = "${local.name_prefix}-api-sg"
  description = "Security group for FastAPI application server"
  vpc_id      = aws_vpc.main.id

  # Allow HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP traffic"
  }

  # Allow app port
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "FastAPI application port"
  }

  # Allow SSH (restrict in production)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
    description = "SSH access"
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-api-sg"
  })
}

# ---------------------------------------------------------------------------
# IAM Role — EC2 instance role with minimal permissions
# ---------------------------------------------------------------------------
resource "aws_iam_role" "ec2_role" {
  name = "${local.name_prefix}-ec2-role"

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

  tags = local.common_tags
}

resource "aws_iam_role_policy" "ec2_s3_policy" {
  name = "${local.name_prefix}-s3-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# ---------------------------------------------------------------------------
# EC2 Instance — application server
# ---------------------------------------------------------------------------
resource "aws_instance" "api_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.api.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # Bootstrap script — installs Docker and starts the app
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker
    docker pull python:3.12-slim
    echo "Application server ready"
  EOF
  )

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-api-server"
    Role = "application"
  })
}

# ---------------------------------------------------------------------------
# S3 Bucket — artifacts, logs, backups
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.s3_bucket_name}-${var.environment}"

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-artifacts"
    Purpose = "application-artifacts"
  })
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}