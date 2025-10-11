# AuditLedger S3 Immutable Storage Module Variables

variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket for audit logs"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be between 3-63 characters, lowercase, and contain only letters, numbers, and hyphens"
  }
}

variable "retention_days" {
  type        = number
  description = "Number of days to retain audit logs (minimum 365 for compliance)"
  default     = 2555 # 7 years for SOC 2

  validation {
    condition     = var.retention_days >= 365
    error_message = "Retention period must be at least 365 days for compliance. Recommended: 2555 days (7 years) for SOC 2."
  }
}

variable "object_lock_mode" {
  type        = string
  description = "Object Lock mode: COMPLIANCE (strict) or GOVERNANCE (can be overridden with special permissions)"
  default     = "COMPLIANCE"

  validation {
    condition     = contains(["COMPLIANCE", "GOVERNANCE"], var.object_lock_mode)
    error_message = "Object Lock mode must be either COMPLIANCE or GOVERNANCE"
  }
}

variable "auditledger_role_arns" {
  type        = list(string)
  description = "ARNs of IAM roles that AuditLedger uses to write audit logs"

  validation {
    condition     = length(var.auditledger_role_arns) > 0
    error_message = "At least one AuditLedger role ARN must be provided"
  }
}

variable "admin_role_arns" {
  type        = list(string)
  description = "ARNs of IAM roles that can manage Object Lock configuration (extremely privileged)"
  default     = []
}

variable "governance_bypass_role_arns" {
  type        = list(string)
  description = "ARNs of IAM roles that can bypass GOVERNANCE mode retention (only if using GOVERNANCE mode)"
  default     = []
}

variable "kms_key_id" {
  type        = string
  description = "KMS key ID for encryption at rest (optional, uses S3 default encryption if not provided)"
  default     = null
}

variable "enable_lifecycle_rules" {
  type        = bool
  description = "Enable lifecycle rules for cost optimization (transitions to cheaper storage classes)"
  default     = true
}

variable "access_log_bucket" {
  type        = string
  description = "S3 bucket for access logging (optional but recommended for compliance)"
  default     = null
}

variable "replication_bucket_arn" {
  type        = string
  description = "ARN of destination bucket for cross-region replication (optional but recommended for DR)"
  default     = null
}

variable "replication_role_arn" {
  type        = string
  description = "ARN of IAM role for replication (required if replication_bucket_arn is set)"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Additional tags for the S3 bucket"
  default     = {}
}
