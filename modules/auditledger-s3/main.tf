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

# S3 Bucket for Audit Logs with mandatory Object Lock
# Object Lock MUST be enabled at bucket creation - this is IRREVERSIBLE
# tfsec:ignore:aws-s3-enable-bucket-logging - Bucket logging is optional, configured via logging_bucket variable
resource "aws_s3_bucket" "audit_logs" {
  bucket = var.bucket_name

  # Object Lock enforcement for immutability - cannot be disabled after creation
  object_lock_enabled = true

  tags = merge(
    var.tags,
    {
      Name       = var.bucket_name
      Purpose    = "AuditLedger Immutable Audit Logs"
      Compliance = "SOC2-HIPAA-PCIDSS"
      Immutable  = "true"
      ManagedBy  = "Terraform"
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

# Object Lock Configuration - enforces immutability
# COMPLIANCE mode: No one (not even root) can delete objects during retention
# GOVERNANCE mode: Users with special permissions can override retention
resource "aws_s3_bucket_object_lock_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    default_retention {
      mode = var.object_lock_mode
      days = var.retention_days
    }
  }
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

# Versioning is REQUIRED for Object Lock
resource "aws_s3_bucket_versioning" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Lifecycle Policy for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "audit_logs" {
  count = var.enable_lifecycle_rules ? 1 : 0

  bucket = aws_s3_bucket.audit_logs.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 180
      storage_class = "GLACIER_IR"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }
  }

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.retention_days
    }
  }
}

# Bucket Policy - Enforce immutability, encryption and TLS
resource "aws_s3_bucket_policy" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyDeleteObject"
        Effect    = "Deny"
        Principal = "*"
        Action = [
          "s3:DeleteObject",
          "s3:DeleteObjectVersion"
        ]
        Resource = "${aws_s3_bucket.audit_logs.arn}/*"
      },
      {
        Sid       = "DenyBypassGovernanceRetention"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:BypassGovernanceRetention"
        Resource  = "${aws_s3_bucket.audit_logs.arn}/*"
        Condition = {
          StringNotEquals = {
            "aws:PrincipalArn" : var.governance_bypass_role_arns
          }
        }
      },
      {
        Sid       = "DenyDisableObjectLock"
        Effect    = "Deny"
        Principal = "*"
        Action = [
          "s3:PutBucketObjectLockConfiguration",
          "s3:PutObjectLegalHold",
          "s3:PutObjectRetention"
        ]
        Resource = [
          aws_s3_bucket.audit_logs.arn,
          "${aws_s3_bucket.audit_logs.arn}/*"
        ]
        Condition = {
          StringNotEquals = {
            "aws:PrincipalArn" : var.admin_role_arns
          }
        }
      },
      {
        Sid    = "AllowAuditLedgerWrite"
        Effect = "Allow"
        Principal = {
          AWS = var.auditledger_role_arns
        }
        Action = [
          "s3:PutObject",
          "s3:PutObjectLegalHold",
          "s3:PutObjectRetention"
        ]
        Resource = "${aws_s3_bucket.audit_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-object-lock-mode" : var.object_lock_mode
          }
        }
      },
      {
        Sid    = "AllowAuditLedgerRead"
        Effect = "Allow"
        Principal = {
          AWS = var.auditledger_role_arns
        }
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket",
          "s3:ListBucketVersions"
        ]
        Resource = [
          aws_s3_bucket.audit_logs.arn,
          "${aws_s3_bucket.audit_logs.arn}/*"
        ]
      },
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
  count  = var.access_log_bucket != null ? 1 : 0
  bucket = aws_s3_bucket.audit_logs.id

  target_bucket = var.access_log_bucket
  target_prefix = "audit-logs-access/"
}

# Replication for disaster recovery (optional)
resource "aws_s3_bucket_replication_configuration" "audit_logs" {
  count = var.replication_bucket_arn != null ? 1 : 0

  depends_on = [aws_s3_bucket_versioning.audit_logs]

  bucket = aws_s3_bucket.audit_logs.id
  role   = var.replication_role_arn

  rule {
    id     = "replicate-all"
    status = "Enabled"

    destination {
      bucket        = var.replication_bucket_arn
      storage_class = "STANDARD_IA"

      replication_time {
        status = "Enabled"
        time {
          minutes = 15
        }
      }

      metrics {
        status = "Enabled"
        event_threshold {
          minutes = 15
        }
      }
    }
  }
}
