# Example: AuditLedger S3 Immutable Storage for AWS Lambda Deployment
# This example uses Python as Lambda's best-supported runtime

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

# IAM Role for Lambda Function
resource "aws_iam_role" "auditledger_lambda" {
  name = "${var.environment}-auditledger-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = var.environment
    Application = "AuditLedger"
    ManagedBy   = "Terraform"
  }
}

# AuditLedger S3 Bucket with Immutability Enforcement
module "auditledger_s3" {
  source = "../../modules/auditledger-s3"

  bucket_name            = "${var.environment}-auditledger-logs"
  retention_days         = var.retention_days
  object_lock_mode       = var.environment == "production" ? "COMPLIANCE" : "GOVERNANCE"
  auditledger_role_arns  = [aws_iam_role.auditledger_lambda.arn]
  enable_lifecycle_rules = true

  tags = {
    Environment = var.environment
    Application = "AuditLedger"
    ManagedBy   = "Terraform"
  }
}

# Attach S3 access policy to Lambda role
resource "aws_iam_role_policy_attachment" "auditledger_s3_access" {
  role       = aws_iam_role.auditledger_lambda.name
  policy_arn = module.auditledger_s3.iam_policy_arn
}

# Attach Lambda basic execution role
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.auditledger_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach X-Ray tracing permissions
resource "aws_iam_role_policy_attachment" "lambda_xray" {
  role       = aws_iam_role.auditledger_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Lambda Function with Python runtime
resource "aws_lambda_function" "auditledger" {
  filename         = var.lambda_zip_path
  function_name    = "${var.environment}-auditledger"
  role             = aws_iam_role.auditledger_lambda.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = filebase64sha256(var.lambda_zip_path)
  runtime          = "python3.12" # Latest Python runtime
  memory_size      = var.lambda_memory_size
  timeout          = var.lambda_timeout

  # Enable X-Ray tracing for observability
  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      AUDITLEDGER_STORAGE_PROVIDER = "AwsS3"
      AUDITLEDGER_S3_BUCKET_NAME   = module.auditledger_s3.bucket_id
      AUDITLEDGER_S3_REGION        = var.aws_region
      ENVIRONMENT                  = var.environment
    }
  }

  tags = {
    Environment = var.environment
    Application = "AuditLedger"
  }
}

# CloudWatch Log Group for Lambda
# tfsec:ignore:aws-cloudwatch-log-group-customer-key - Example uses default encryption
resource "aws_cloudwatch_log_group" "auditledger" {
  name              = "/aws/lambda/${aws_lambda_function.auditledger.function_name}"
  retention_in_days = 30

  tags = {
    Environment = var.environment
    Application = "AuditLedger"
  }
}

# Optional: API Gateway for HTTP access
resource "aws_apigatewayv2_api" "auditledger" {
  count         = var.create_api_gateway ? 1 : 0
  name          = "${var.environment}-auditledger-api"
  protocol_type = "HTTP"

  tags = {
    Environment = var.environment
    Application = "AuditLedger"
  }
}

resource "aws_apigatewayv2_integration" "auditledger" {
  count              = var.create_api_gateway ? 1 : 0
  api_id             = aws_apigatewayv2_api.auditledger[0].id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.auditledger.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "auditledger" {
  count     = var.create_api_gateway ? 1 : 0
  api_id    = aws_apigatewayv2_api.auditledger[0].id
  route_key = "POST /audit"
  target    = "integrations/${aws_apigatewayv2_integration.auditledger[0].id}"
}

resource "aws_apigatewayv2_stage" "auditledger" {
  count       = var.create_api_gateway ? 1 : 0
  api_id      = aws_apigatewayv2_api.auditledger[0].id
  name        = "$default"
  auto_deploy = true

  tags = {
    Environment = var.environment
    Application = "AuditLedger"
  }
}

resource "aws_lambda_permission" "api_gateway" {
  count         = var.create_api_gateway ? 1 : 0
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auditledger.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.auditledger[0].execution_arn}/*/*"
}
