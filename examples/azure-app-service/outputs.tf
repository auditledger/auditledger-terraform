# Azure App Service Example Outputs

output "app_service_url" {
  description = "URL of the deployed App Service"
  value       = "https://${azurerm_linux_web_app.auditledger.default_hostname}"
}

output "app_service_name" {
  description = "Name of the App Service"
  value       = azurerm_linux_web_app.auditledger.name
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = module.auditledger_storage.storage_account_name
}

output "container_name" {
  description = "Name of the blob container"
  value       = module.auditledger_storage.container_name
}

output "managed_identity_principal_id" {
  description = "Principal ID of the App Service managed identity"
  value       = azurerm_linux_web_app.auditledger.identity[0].principal_id
}

output "application_insights_key" {
  description = "Instrumentation key for Application Insights"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Connection string for Application Insights"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

output "immutability_verified" {
  description = "Confirmation that immutability is enforced"
  value       = module.auditledger_storage.immutability_verified
}
