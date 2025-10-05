# AuditLedger Azure Blob Storage Module Variables

variable "storage_account_name" {
  description = "Name of the Azure Storage Account (must be globally unique, 3-24 chars, lowercase letters and numbers only)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account name must be 3-24 characters, lowercase letters and numbers only."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "create_resource_group" {
  description = "Whether to create a new resource group (if false, uses existing)"
  type        = bool
  default     = false
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "container_name" {
  description = "Name of the blob container for audit logs"
  type        = string
  default     = "audit-logs"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{1,61}[a-z0-9])?$", var.container_name))
    error_message = "Container name must be 3-63 characters, lowercase letters, numbers, and hyphens only."
  }
}

variable "account_tier" {
  description = "Storage account tier (Standard or Premium)"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.account_tier)
    error_message = "Account tier must be Standard or Premium."
  }
}

variable "replication_type" {
  description = "Storage account replication type (LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS)"
  type        = string
  default     = "GRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.replication_type)
    error_message = "Replication type must be one of: LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS."
  }
}

variable "enable_versioning" {
  description = "Enable blob versioning (recommended for audit logs)"
  type        = bool
  default     = true
}

variable "enable_change_feed" {
  description = "Enable change feed for blob auditing"
  type        = bool
  default     = true
}

variable "soft_delete_retention_days" {
  description = "Number of days to retain soft-deleted blobs (null to disable)"
  type        = number
  default     = 30

  validation {
    condition     = var.soft_delete_retention_days == null || (var.soft_delete_retention_days >= 1 && var.soft_delete_retention_days <= 365)
    error_message = "Soft delete retention must be between 1 and 365 days."
  }
}

variable "container_soft_delete_retention_days" {
  description = "Number of days to retain soft-deleted containers (null to disable)"
  type        = number
  default     = 7

  validation {
    condition     = var.container_soft_delete_retention_days == null || (var.container_soft_delete_retention_days >= 1 && var.container_soft_delete_retention_days <= 365)
    error_message = "Container soft delete retention must be between 1 and 365 days."
  }
}

variable "retention_days" {
  description = "Number of days to retain audit logs before deletion (null for no expiration)"
  type        = number
  default     = null

  validation {
    condition     = var.retention_days == null || var.retention_days >= 1
    error_message = "Retention days must be at least 1 day."
  }
}

variable "transition_to_cool_days" {
  description = "Days before transitioning to Cool storage tier"
  type        = number
  default     = 90
}

variable "transition_to_archive_days" {
  description = "Days before transitioning to Archive storage tier"
  type        = number
  default     = 180
}

variable "network_default_action" {
  description = "Default action for network rules (Allow or Deny)"
  type        = string
  default     = "Deny"

  validation {
    condition     = contains(["Allow", "Deny"], var.network_default_action)
    error_message = "Network default action must be Allow or Deny."
  }
}

variable "network_bypass" {
  description = "Services to bypass network rules"
  type        = list(string)
  default     = ["AzureServices"]

  validation {
    condition     = alltrue([for s in var.network_bypass : contains(["None", "Logging", "Metrics", "AzureServices"], s)])
    error_message = "Network bypass must contain valid values: None, Logging, Metrics, AzureServices."
  }
}

variable "allowed_ip_ranges" {
  description = "List of allowed IP address ranges (CIDR notation)"
  type        = list(string)
  default     = []
}

variable "allowed_subnet_ids" {
  description = "List of allowed virtual network subnet IDs"
  type        = list(string)
  default     = []
}

variable "enable_shared_key_access" {
  description = "Allow access via shared access keys (set false for managed identity only)"
  type        = bool
  default     = false
}

variable "enable_managed_identity" {
  description = "Enable system-assigned managed identity for the storage account"
  type        = bool
  default     = true
}

variable "managed_identity_principal_id" {
  description = "Principal ID of the managed identity to grant access (e.g., App Service, AKS)"
  type        = string
  default     = null
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for diagnostic logs (null to disable)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
