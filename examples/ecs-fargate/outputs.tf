output "bucket_name" {
  description = "Name of the audit logs S3 bucket"
  value       = module.auditledger_s3.bucket_name
}

output "bucket_arn" {
  description = "ARN of the audit logs S3 bucket"
  value       = module.auditledger_s3.bucket_arn
}

output "iam_role_arn" {
  description = "ARN of the ECS task IAM role"
  value       = module.auditledger_s3.iam_role_arn
}

output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.auditledger_app.arn
}
