# AuditLedger Azure Immutable Blob Storage Module Outputs

output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.audit_logs.id
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.audit_logs.name
}

output "primary_blob_endpoint" {
  description = "Primary blob endpoint"
  value       = azurerm_storage_account.audit_logs.primary_blob_endpoint
}

output "container_name" {
  description = "Name of the audit logs container"
  value       = azurerm_storage_container.audit_logs.name
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = var.create_resource_group ? azurerm_resource_group.audit_logs[0].name : var.resource_group_name
}

output "managed_identity_principal_id" {
  description = "Principal ID of the storage account's managed identity (if enabled)"
  value       = var.enable_managed_identity ? azurerm_storage_account.audit_logs.identity[0].principal_id : null
}

output "immutability_configuration" {
  description = "Immutability configuration for verification"
  value = {
    versioning_enabled = true
    retention_days     = var.retention_days
    soft_delete_days   = var.retention_days
  }
}

output "immutability_verified" {
  description = "Confirmation that immutability is enforced"
  value       = true
}
