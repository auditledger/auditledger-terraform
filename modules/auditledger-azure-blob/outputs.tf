# AuditLedger Azure Blob Storage Module Outputs

output "resource_group_name" {
  description = "Name of the resource group"
  value       = var.create_resource_group ? azurerm_resource_group.audit_logs[0].name : var.resource_group_name
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.audit_logs.name
}

output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.audit_logs.id
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary blob endpoint of the storage account"
  value       = azurerm_storage_account.audit_logs.primary_blob_endpoint
}

output "storage_account_primary_connection_string" {
  description = "Primary connection string for the storage account (sensitive)"
  value       = azurerm_storage_account.audit_logs.primary_connection_string
  sensitive   = true
}

output "container_name" {
  description = "Name of the blob container"
  value       = azurerm_storage_container.audit_logs.name
}

output "container_id" {
  description = "ID of the blob container"
  value       = azurerm_storage_container.audit_logs.id
}

output "managed_identity_principal_id" {
  description = "Principal ID of the storage account's managed identity (if enabled)"
  value       = var.enable_managed_identity ? azurerm_storage_account.audit_logs.identity[0].principal_id : null
}

output "managed_identity_tenant_id" {
  description = "Tenant ID of the storage account's managed identity (if enabled)"
  value       = var.enable_managed_identity ? azurerm_storage_account.audit_logs.identity[0].tenant_id : null
}
