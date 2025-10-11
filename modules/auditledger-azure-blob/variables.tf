# AuditLedger Azure Immutable Blob Storage Module Variables

variable "storage_account_name" {
  type        = string
  description = "Name of the storage account (must be globally unique, 3-24 lowercase letters/numbers)"

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account name must be 3-24 characters, lowercase letters and numbers only"
  }
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group"
}

variable "create_resource_group" {
  type        = bool
  description = "Whether to create a new resource group"
  default     = true
}

variable "location" {
  type        = string
  description = "Azure region for resources"
  default     = "eastus"
}

variable "container_name" {
  type        = string
  description = "Name of the blob container for audit logs"
  default     = "audit-logs"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{1,61}[a-z0-9])?$", var.container_name))
    error_message = "Container name must be 3-63 characters, lowercase letters, numbers, and hyphens only"
  }
}

variable "account_tier" {
  type        = string
  description = "Storage account tier (Standard or Premium)"
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.account_tier)
    error_message = "Account tier must be Standard or Premium"
  }
}

variable "replication_type" {
  type        = string
  description = "Storage replication type: LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS"
  default     = "GRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.replication_type)
    error_message = "Replication type must be one of: LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS"
  }
}

variable "retention_days" {
  type        = number
  description = "Number of days to retain audit logs (minimum 365 for compliance)"
  default     = 2555 # 7 years for SOC 2

  validation {
    condition     = var.retention_days >= 365
    error_message = "Retention period must be at least 365 days for compliance"
  }
}

variable "network_default_action" {
  type        = string
  description = "Default action for network rules (Allow or Deny)"
  default     = "Deny"

  validation {
    condition     = contains(["Allow", "Deny"], var.network_default_action)
    error_message = "Network default action must be Allow or Deny"
  }
}

variable "network_bypass" {
  type        = list(string)
  description = "Services to bypass network rules"
  default     = ["AzureServices"]

  validation {
    condition     = alltrue([for s in var.network_bypass : contains(["None", "Logging", "Metrics", "AzureServices"], s)])
    error_message = "Network bypass must contain valid values: None, Logging, Metrics, AzureServices"
  }
}

variable "allowed_ip_ranges" {
  type        = list(string)
  description = "List of IP ranges allowed to access the storage account"
  default     = []
}

variable "allowed_subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs allowed to access the storage account"
  default     = []
}

variable "enable_shared_key_access" {
  type        = bool
  description = "Allow access via shared access keys (set false for managed identity only)"
  default     = false
}

variable "enable_managed_identity" {
  type        = bool
  description = "Enable system-assigned managed identity for the storage account"
  default     = true
}

variable "managed_identity_principal_id" {
  type        = string
  description = "Principal ID of the managed identity to grant access (e.g., App Service, AKS)"
  default     = null
}

variable "enable_threat_protection" {
  type        = bool
  description = "Enable Advanced Threat Protection"
  default     = true
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics workspace ID for diagnostics"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Additional tags for resources"
  default     = {}
}
