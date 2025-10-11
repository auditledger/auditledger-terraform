output "bucket_id" {
  description = "ID of the audit logs S3 bucket"
  value       = module.auditledger_s3.bucket_id
}

output "bucket_arn" {
  description = "ARN of the audit logs S3 bucket"
  value       = module.auditledger_s3.bucket_arn
}

output "iam_task_role_arn" {
  description = "ARN of the ECS task IAM role"
  value       = aws_iam_role.auditledger_ecs_task.arn
}

output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.auditledger_app.arn
}

output "immutability_verified" {
  description = "Confirmation that immutability is enforced"
  value       = module.auditledger_s3.immutability_verified
}
