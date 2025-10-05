# AuditLedger S3 Storage Module Variables

variable "bucket_name" {
  description = "Name of the S3 bucket for audit logs"
  type        = string
}

variable "force_destroy" {
  description = "Allow bucket to be destroyed even if it contains objects (use with caution)"
  type        = bool
  default     = false
}

variable "enable_versioning" {
  description = "Enable versioning for the S3 bucket (recommended for audit logs)"
  type        = bool
  default     = true
}

variable "enable_mfa_delete" {
  description = "Enable MFA delete for the S3 bucket (requires versioning)"
  type        = bool
  default     = false
}

variable "kms_key_id" {
  description = "KMS key ID for bucket encryption (if null, uses AES256)"
  type        = string
  default     = null
}

variable "retention_days" {
  description = "Number of days to retain audit logs (null for no expiration)"
  type        = number
  default     = null
}

variable "transition_to_ia_days" {
  description = "Days before transitioning to Infrequent Access storage class"
  type        = number
  default     = 90
}

variable "transition_to_glacier_days" {
  description = "Days before transitioning to Glacier storage class"
  type        = number
  default     = 180
}

variable "logging_bucket" {
  description = "S3 bucket name for access logs (null to disable)"
  type        = string
  default     = null
}

variable "iam_policy_name" {
  description = "Name of the IAM policy for AuditLedger access"
  type        = string
  default     = "AuditLedgerS3AccessPolicy"
}

variable "iam_policy_path" {
  description = "Path for the IAM policy"
  type        = string
  default     = "/"
}

variable "create_iam_role" {
  description = "Whether to create an IAM role for the application"
  type        = bool
  default     = false
}

variable "iam_role_name" {
  description = "Name of the IAM role (if create_iam_role is true)"
  type        = string
  default     = "AuditLedgerS3AccessRole"
}

variable "iam_role_trust_policy" {
  description = "IAM role trust policy (assume role policy)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
