# AuditLedger S3 Storage Module
# This module creates an S3 bucket with appropriate security settings for audit log storage

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# S3 Bucket for Audit Logs
# tfsec:ignore:aws-s3-enable-bucket-logging - Bucket logging is optional, configured via logging_bucket variable
resource "aws_s3_bucket" "audit_logs" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = merge(
    var.tags,
    {
      Name      = var.bucket_name
      Purpose   = "AuditLedger Storage"
      ManagedBy = "Terraform"
    }
  )
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = var.kms_key_id != null ? true : false
  }
}

# Versioning (recommended for audit logs)
resource "aws_s3_bucket_versioning" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  versioning_configuration {
    status     = var.enable_versioning ? "Enabled" : "Disabled"
    mfa_delete = var.enable_mfa_delete ? "Enabled" : "Disabled"
  }
}

# Lifecycle Policy (optional retention)
resource "aws_s3_bucket_lifecycle_configuration" "audit_logs" {
  count  = var.retention_days != null ? 1 : 0
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    id     = "audit-log-retention"
    status = "Enabled"

    transition {
      days          = var.transition_to_ia_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.transition_to_glacier_days
      storage_class = "GLACIER"
    }

    expiration {
      days = var.retention_days
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.retention_days
    }
  }
}

# Bucket Policy - Enforce encryption and TLS
resource "aws_s3_bucket_policy" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyUnencryptedObjectUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.audit_logs.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = var.kms_key_id != null ? "aws:kms" : "AES256"
          }
        }
      },
      {
        Sid       = "EnforceTLSRequestsOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.audit_logs.arn,
          "${aws_s3_bucket.audit_logs.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# Access Logging (optional)
resource "aws_s3_bucket_logging" "audit_logs" {
  count  = var.logging_bucket != null ? 1 : 0
  bucket = aws_s3_bucket.audit_logs.id

  target_bucket = var.logging_bucket
  target_prefix = "audit-logs-access/"
}

# IAM Policy for AuditLedger Application
# tfsec:ignore:aws-iam-no-policy-wildcards - Wildcard required for audit log writes to any path in bucket
resource "aws_iam_policy" "auditledger_s3_access" {
  name        = var.iam_policy_name
  description = "IAM policy for AuditLedger to access S3 audit logs bucket"
  path        = var.iam_policy_path

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AuditLedgerS3Access"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning"
        ]
        Resource = [
          aws_s3_bucket.audit_logs.arn,
          "${aws_s3_bucket.audit_logs.arn}/*"
        ]
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name      = var.iam_policy_name
      ManagedBy = "Terraform"
    }
  )
}

# Optional: IAM Role for ECS/EC2/Lambda
resource "aws_iam_role" "auditledger_role" {
  count              = var.create_iam_role ? 1 : 0
  name               = var.iam_role_name
  assume_role_policy = var.iam_role_trust_policy

  tags = merge(
    var.tags,
    {
      Name      = var.iam_role_name
      ManagedBy = "Terraform"
    }
  )
}

resource "aws_iam_role_policy_attachment" "auditledger_s3_access" {
  count      = var.create_iam_role ? 1 : 0
  role       = aws_iam_role.auditledger_role[0].name
  policy_arn = aws_iam_policy.auditledger_s3_access.arn
}
