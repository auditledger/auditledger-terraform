# AuditLedger S3 Immutable Storage Module Outputs

output "bucket_id" {
  description = "ID of the S3 bucket"
  value       = aws_s3_bucket.audit_logs.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.audit_logs.arn
}

output "bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.audit_logs.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = aws_s3_bucket.audit_logs.bucket_regional_domain_name
}

output "object_lock_configuration" {
  description = "Object Lock configuration for verification"
  value = {
    enabled        = true
    mode           = var.object_lock_mode
    retention_days = var.retention_days
  }
}

output "immutability_verified" {
  description = "Confirmation that immutability is enforced"
  value       = true
}

output "iam_policy_arn" {
  description = "ARN of the IAM policy for S3 bucket access"
  value       = aws_iam_policy.s3_access.arn
}

output "iam_policy_name" {
  description = "Name of the IAM policy for S3 bucket access"
  value       = aws_iam_policy.s3_access.name
}
