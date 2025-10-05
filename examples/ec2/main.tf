# Example: AuditLedger S3 Storage for EC2 Deployment

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# AuditLedger S3 Bucket with IAM Role for EC2
module "auditledger_s3" {
  source = "../../modules/auditledger-s3"

  bucket_name       = "${var.environment}-auditledger-logs"
  enable_versioning = true
  retention_days    = var.retention_days

  # Create IAM role for EC2 Instance
  create_iam_role = true
  iam_role_name   = "${var.environment}-auditledger-ec2-role"

  iam_role_trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = var.environment
    Application = "AuditLedger"
    ManagedBy   = "Terraform"
  }
}

# IAM Instance Profile for EC2
resource "aws_iam_instance_profile" "auditledger" {
  name = "${var.environment}-auditledger-instance-profile"
  role = module.auditledger_s3.iam_role_name
}

# Security Group for Application
resource "aws_security_group" "auditledger_app" {
  name        = "${var.environment}-auditledger-app"
  description = "Security group for AuditLedger application"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-auditledger-app"
    Environment = var.environment
    Application = "AuditLedger"
  }
}

# EC2 Instance (example)
resource "aws_instance" "auditledger_app" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.auditledger.name
  vpc_security_group_ids = [aws_security_group.auditledger_app.id]
  subnet_id              = var.subnet_id

  user_data = templatefile("${path.module}/user_data.sh", {
    bucket_name = module.auditledger_s3.bucket_name
    region      = var.aws_region
    environment = var.environment
  })

  tags = {
    Name        = "${var.environment}-auditledger-app"
    Environment = var.environment
    Application = "AuditLedger"
  }
}
