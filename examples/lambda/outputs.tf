output "bucket_name" {
  description = "Name of the audit logs S3 bucket"
  value       = module.auditledger_s3.bucket_name
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

output "api_gateway_endpoint" {
  description = "API Gateway endpoint URL"
  value       = var.create_api_gateway ? aws_apigatewayv2_api.auditledger[0].api_endpoint : null
}
