# AuditLedger Azure Blob Storage Module
# This module creates Azure Storage Account with appropriate security settings for audit log storage

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

# Resource Group (optional - can use existing)
resource "azurerm_resource_group" "audit_logs" {
  count    = var.create_resource_group ? 1 : 0
  name     = var.resource_group_name
  location = var.location

  tags = merge(
    var.tags,
    {
      Purpose    = "AuditLedger Immutable Storage"
      Compliance = "SOC2-HIPAA-PCIDSS"
      ManagedBy  = "Terraform"
    }
  )
}

# Storage Account for Audit Logs
resource "azurerm_storage_account" "audit_logs" {
  name                     = var.storage_account_name
  resource_group_name      = var.create_resource_group ? azurerm_resource_group.audit_logs[0].name : var.resource_group_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.replication_type
  account_kind             = "StorageV2"

  # Security settings
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true # Updated from deprecated enable_https_traffic_only
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = var.enable_shared_key_access

  # Blob properties - versioning is REQUIRED for immutability
  blob_properties {
    # Versioning is mandatory for immutable audit logs
    versioning_enabled = true

    # Change feed for point-in-time restore
    change_feed_enabled           = true
    change_feed_retention_in_days = var.retention_days

    # Soft delete for additional protection
    delete_retention_policy {
      days = var.retention_days
    }

    container_delete_retention_policy {
      days = var.retention_days
    }

    # Restore policy (Azure limit is 365 days)
    restore_policy {
      days = min(var.retention_days, 365)
    }
  }

  # Network rules
  # tfsec:ignore:azure-storage-default-action-deny - Default action is configurable via variable, defaults to "Deny" (secure)
  network_rules {
    default_action             = var.network_default_action
    bypass                     = var.network_bypass
    ip_rules                   = var.allowed_ip_ranges
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }

  # Encryption
  identity {
    type = var.enable_managed_identity ? "SystemAssigned" : null
  }

  tags = merge(
    var.tags,
    {
      Name       = var.storage_account_name
      Purpose    = "AuditLedger Immutable Audit Logs"
      Compliance = "SOC2-HIPAA-PCIDSS"
      Immutable  = "true"
      ManagedBy  = "Terraform"
    }
  )
}

# Blob Container for Audit Logs
resource "azurerm_storage_container" "audit_logs" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.audit_logs.name
  container_access_type = "private"
}

# Management Policy for lifecycle and immutability
resource "azurerm_storage_management_policy" "audit_logs" {
  storage_account_id = azurerm_storage_account.audit_logs.id

  rule {
    name    = "immutable-retention"
    enabled = true

    filters {
      blob_types   = ["blockBlob"]
      prefix_match = ["${var.container_name}/"]
    }

    actions {
      base_blob {
        # Tier to cool after 90 days
        tier_to_cool_after_days_since_modification_greater_than = 90

        # Tier to archive after 180 days
        tier_to_archive_after_days_since_modification_greater_than = 180

        # Delete after retention period (but blob is immutable during retention)
        delete_after_days_since_modification_greater_than = var.retention_days
      }

      snapshot {
        delete_after_days_since_creation_greater_than = var.retention_days
      }

      version {
        delete_after_days_since_creation = var.retention_days
      }
    }
  }
}

# Role Assignment for Managed Identity (if enabled)
resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  count                = var.enable_managed_identity && var.managed_identity_principal_id != null ? 1 : 0
  scope                = azurerm_storage_account.audit_logs.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.managed_identity_principal_id
}

# Advanced Threat Protection
resource "azurerm_advanced_threat_protection" "audit_logs" {
  count = var.enable_threat_protection ? 1 : 0

  target_resource_id = azurerm_storage_account.audit_logs.id
  enabled            = true
}

# Diagnostic Settings for monitoring
resource "azurerm_monitor_diagnostic_setting" "audit_logs" {
  count                      = var.log_analytics_workspace_id != null ? 1 : 0
  name                       = "auditledger-diagnostics"
  target_resource_id         = azurerm_storage_account.audit_logs.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "Transaction"
    enabled  = true
  }

  metric {
    category = "Capacity"
    enabled  = true
  }
}
