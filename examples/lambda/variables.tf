variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "retention_days" {
  description = "Number of days to retain audit logs (minimum 365 days for compliance)"
  type        = number
  default     = 2555 # 7 years for SOC 2
}

variable "lambda_zip_path" {
  description = "Path to Lambda deployment package (Python .zip file)"
  type        = string
}

variable "lambda_memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 512
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "create_api_gateway" {
  description = "Whether to create API Gateway for HTTP access"
  type        = bool
  default     = false
}
