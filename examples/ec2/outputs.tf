# EC2 Example Outputs

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.auditledger_app.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.auditledger_app.public_ip
}

output "bucket_id" {
  description = "ID of the S3 bucket for audit logs"
  value       = module.auditledger_s3.bucket_id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = module.auditledger_s3.bucket_arn
}

output "iam_role_arn" {
  description = "ARN of the IAM role for EC2 instance"
  value       = aws_iam_role.auditledger_ec2.arn
}

output "immutability_verified" {
  description = "Confirmation that immutability is enforced"
  value       = module.auditledger_s3.immutability_verified
}
