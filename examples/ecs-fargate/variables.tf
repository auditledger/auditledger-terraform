variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
}

variable "team" {
  description = "Team name"
  type        = string
  default     = "platform"
}

variable "retention_days" {
  description = "Number of days to retain audit logs"
  type        = number
  default     = 2555 # 7 years for HIPAA/SOX compliance
}

variable "app_image" {
  description = "Docker image for the application"
  type        = string
}

variable "task_cpu" {
  description = "CPU units for ECS task"
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Memory for ECS task"
  type        = string
  default     = "512"
}
