# Azure App Service Example Variables

variable "app_name" {
  description = "Name of the App Service application"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment name (Development, Staging, Production)"
  type        = string
  default     = "Production"
}

variable "organization_id" {
  description = "Organization identifier for audit logs"
  type        = string
}

variable "storage_account_name" {
  description = "Name of the storage account (3-24 chars, lowercase letters and numbers only)"
  type        = string
}

variable "container_name" {
  description = "Name of the blob container for audit logs"
  type        = string
  default     = "audit-logs"
}

variable "app_service_sku" {
  description = "SKU for the App Service Plan (e.g., B1, S1, P1v3)"
  type        = string
  default     = "B1"
}

variable "retention_days" {
  description = "Number of days to retain audit logs (null for no expiration)"
  type        = number
  default     = 2555 # 7 years for compliance
}

variable "transition_to_cool_days" {
  description = "Days before transitioning to Cool storage tier"
  type        = number
  default     = 90
}

variable "transition_to_archive_days" {
  description = "Days before transitioning to Archive storage tier"
  type        = number
  default     = 365
}

variable "network_default_action" {
  description = "Default action for network rules (Allow or Deny)"
  type        = string
  default     = "Allow" # Set to "Deny" for production with specific IP rules
}

variable "allowed_ip_ranges" {
  description = "List of allowed IP address ranges (CIDR notation)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy   = "Terraform"
    Application = "AuditLedger"
  }
}
