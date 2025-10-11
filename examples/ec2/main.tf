# Example: AuditLedger S3 Immutable Storage for EC2 Deployment

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

# IAM Role for EC2 Instance
resource "aws_iam_role" "auditledger_ec2" {
  name = "${var.environment}-auditledger-ec2-role"

  assume_role_policy = jsonencode({
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

# AuditLedger S3 Bucket with Immutability Enforcement
module "auditledger_s3" {
  source = "../../modules/auditledger-s3"

  bucket_name            = "${var.environment}-auditledger-logs"
  retention_days         = var.retention_days
  object_lock_mode       = var.environment == "production" ? "COMPLIANCE" : "GOVERNANCE"
  auditledger_role_arns  = [aws_iam_role.auditledger_ec2.arn]
  enable_lifecycle_rules = true

  tags = {
    Environment = var.environment
    Application = "AuditLedger"
    ManagedBy   = "Terraform"
  }
}

# Attach S3 access policy to EC2 role
resource "aws_iam_role_policy_attachment" "auditledger_s3_access" {
  role       = aws_iam_role.auditledger_ec2.name
  policy_arn = module.auditledger_s3.iam_policy_arn
}

# IAM Instance Profile for EC2
resource "aws_iam_instance_profile" "auditledger" {
  name = "${var.environment}-auditledger-instance-profile"
  role = aws_iam_role.auditledger_ec2.name
}

# Security Group for Application
# tfsec:ignore:aws-ec2-no-public-egress-sgr - Egress required for S3 API calls and package updates
resource "aws_security_group" "auditledger_app" {
  name        = "${var.environment}-auditledger-app"
  description = "Security group for AuditLedger application"
  vpc_id      = var.vpc_id

  # tfsec:ignore:aws-ec2-no-public-ingress-sgr - CIDR blocks are configurable via var.allowed_cidr_blocks
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # tfsec:ignore:aws-ec2-no-public-ingress-sgr - CIDR blocks are configurable via var.allowed_cidr_blocks
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

  # Enable IMDSv2 for enhanced security
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 1
  }

  # Enable EBS encryption
  root_block_device {
    encrypted = true
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    bucket_name = module.auditledger_s3.bucket_id
    region      = var.aws_region
    environment = var.environment
  })

  tags = {
    Name        = "${var.environment}-auditledger-app"
    Environment = var.environment
    Application = "AuditLedger"
  }
}
