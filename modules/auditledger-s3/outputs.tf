# AuditLedger S3 Storage Module Outputs

output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.audit_logs.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.audit_logs.arn
}

output "bucket_region" {
  description = "AWS region of the S3 bucket"
  value       = aws_s3_bucket.audit_logs.region
}

output "bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.audit_logs.bucket_domain_name
}

output "iam_policy_arn" {
  description = "ARN of the IAM policy for AuditLedger access"
  value       = aws_iam_policy.auditledger_s3_access.arn
}

output "iam_policy_name" {
  description = "Name of the IAM policy"
  value       = aws_iam_policy.auditledger_s3_access.name
}

output "iam_role_arn" {
  description = "ARN of the IAM role (if created)"
  value       = var.create_iam_role ? aws_iam_role.auditledger_role[0].arn : null
}

output "iam_role_name" {
  description = "Name of the IAM role (if created)"
  value       = var.create_iam_role ? aws_iam_role.auditledger_role[0].name : null
}
