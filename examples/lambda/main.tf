# Example: AuditLedger S3 Storage for AWS Lambda Deployment

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

# AuditLedger S3 Bucket with IAM Role for Lambda
module "auditledger_s3" {
  source = "../../modules/auditledger-s3"

  bucket_name       = "${var.environment}-auditledger-logs"
  enable_versioning = true
  retention_days    = var.retention_days

  # Create IAM role for Lambda Function
  create_iam_role = true
  iam_role_name   = "${var.environment}-auditledger-lambda-role"

  iam_role_trust_policy = jsonencode({
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

# Attach Lambda basic execution role
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = module.auditledger_s3.iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Function
resource "aws_lambda_function" "auditledger" {
  filename         = var.lambda_zip_path
  function_name    = "${var.environment}-auditledger"
  role             = module.auditledger_s3.iam_role_arn
  handler          = "AuditLedger::AuditLedger.LambdaHandler::HandleRequest"
  source_code_hash = filebase64sha256(var.lambda_zip_path)
  runtime          = "dotnet6" # AWS Lambda doesn't support dotnet8 runtime yet
  memory_size      = var.lambda_memory_size
  timeout          = var.lambda_timeout

  environment {
    variables = {
      AuditLedger__Storage__Provider          = "AwsS3"
      AuditLedger__Storage__AwsS3__BucketName = module.auditledger_s3.bucket_name
      AuditLedger__Storage__AwsS3__Region     = var.aws_region
      ENVIRONMENT                             = var.environment
    }
  }

  tags = {
    Environment = var.environment
    Application = "AuditLedger"
  }
}

# CloudWatch Log Group for Lambda
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
