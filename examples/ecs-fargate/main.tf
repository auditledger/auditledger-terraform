# Example: AuditLedger S3 Storage for ECS Fargate Deployment

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

# AuditLedger S3 Bucket with IAM Role for ECS
module "auditledger_s3" {
  source = "../../modules/auditledger-s3"

  bucket_name       = "${var.environment}-auditledger-logs"
  enable_versioning = true
  enable_mfa_delete = var.environment == "production" ? true : false

  # Use KMS in production
  kms_key_id = var.environment == "production" ? aws_kms_key.audit_logs[0].id : null

  # Retention based on compliance requirements
  retention_days             = var.retention_days
  transition_to_ia_days      = 90
  transition_to_glacier_days = 365

  # Create IAM role for ECS Task
  create_iam_role = true
  iam_role_name   = "${var.environment}-auditledger-ecs-role"

  iam_role_trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = var.environment
    Application = "AuditLedger"
    ManagedBy   = "Terraform"
    Team        = var.team
  }
}

# Optional: KMS Key for Production
resource "aws_kms_key" "audit_logs" {
  count = var.environment == "production" ? 1 : 0

  description             = "KMS key for AuditLedger audit logs encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow S3 to use the key"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-auditledger-kms"
    Environment = var.environment
    Application = "AuditLedger"
  }
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

resource "aws_kms_alias" "audit_logs" {
  count = var.environment == "production" ? 1 : 0

  name          = "alias/${var.environment}-auditledger"
  target_key_id = aws_kms_key.audit_logs[0].key_id
}

# ECS Task Definition (example)
resource "aws_ecs_task_definition" "auditledger_app" {
  family                   = "${var.environment}-auditledger-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = module.auditledger_s3.iam_role_arn

  container_definitions = jsonencode([
    {
      name  = "auditledger"
      image = var.app_image

      environment = [
        {
          name  = "AuditLedger__Storage__Provider"
          value = "AwsS3"
        },
        {
          name  = "AuditLedger__Storage__AwsS3__BucketName"
          value = module.auditledger_s3.bucket_name
        },
        {
          name  = "AuditLedger__Storage__AwsS3__Region"
          value = var.aws_region
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.auditledger.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Environment = var.environment
    Application = "AuditLedger"
  }
}

# ECS Execution Role (for pulling images, logging)
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.environment}-auditledger-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = var.environment
    Application = "AuditLedger"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "auditledger" {
  name              = "/ecs/${var.environment}/auditledger"
  retention_in_days = 30

  tags = {
    Environment = var.environment
    Application = "AuditLedger"
  }
}
