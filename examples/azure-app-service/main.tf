# AuditLedger Azure App Service Deployment Example
# This example deploys AuditLedger on Azure App Service with Immutable Blob Storage

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

# App Service Plan
resource "azurerm_service_plan" "main" {
  name                = "${var.app_name}-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.app_service_sku

  tags = var.tags
}

# Linux Web App (App Service)
resource "azurerm_linux_web_app" "auditledger" {
  name                = var.app_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id

  # Enable managed identity
  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = true

    application_stack {
      dotnet_version = "8.0" # Azure provider doesn't support 9.0 yet
    }

    ftps_state          = "FtpsOnly"
    http2_enabled       = true
    minimum_tls_version = "1.2"
  }

  app_settings = {
    "ASPNETCORE_ENVIRONMENT" = var.environment

    # AuditLedger Configuration
    "AuditLedger__Storage__Provider"                 = "AzureBlob"
    "AuditLedger__Storage__AzureBlob__ContainerName" = module.auditledger_storage.container_name
    "AuditLedger__Storage__AzureBlob__AccountName"   = module.auditledger_storage.storage_account_name
    "AuditLedger__Storage__AzureBlob__UseAzurite"    = "false"

    "AuditLedger__Compliance__OrganizationId" = var.organization_id
    "AuditLedger__Compliance__Environment"    = var.environment

    # Application Insights
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
  }

  https_only = true

  tags = var.tags
}

# AuditLedger Immutable Storage Module
module "auditledger_storage" {
  source = "../../modules/auditledger-azure-blob"

  storage_account_name = var.storage_account_name
  resource_group_name  = azurerm_resource_group.main.name
  location             = azurerm_resource_group.main.location
  container_name       = var.container_name

  # Immutability settings
  retention_days = var.retention_days

  # Security: Use managed identity (no connection strings)
  enable_managed_identity       = true
  managed_identity_principal_id = azurerm_linux_web_app.auditledger.identity[0].principal_id
  enable_shared_key_access      = false

  # Network security
  network_default_action = var.network_default_action
  network_bypass         = ["AzureServices"]
  allowed_ip_ranges      = var.allowed_ip_ranges

  # Monitoring
  enable_threat_protection   = true
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  tags = var.tags
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.app_name}-logs"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "${var.app_name}-insights"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  tags = var.tags
}
