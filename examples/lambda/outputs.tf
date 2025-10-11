output "bucket_id" {
  description = "ID of the audit logs S3 bucket"
  value       = module.auditledger_s3.bucket_id
}

output "bucket_arn" {
  description = "ARN of the audit logs S3 bucket"
  value       = module.auditledger_s3.bucket_arn
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.auditledger.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.auditledger.function_name
}

output "lambda_role_arn" {
  description = "ARN of the Lambda IAM role"
  value       = aws_iam_role.auditledger_lambda.arn
}

output "api_gateway_endpoint" {
  description = "API Gateway endpoint URL"
  value       = var.create_api_gateway ? aws_apigatewayv2_api.auditledger[0].api_endpoint : null
}

output "immutability_verified" {
  description = "Confirmation that immutability is enforced"
  value       = module.auditledger_s3.immutability_verified
}
