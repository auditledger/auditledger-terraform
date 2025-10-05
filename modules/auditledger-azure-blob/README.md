# AuditLedger Azure Blob Storage Terraform Module

This Terraform module provisions Azure Blob Storage infrastructure for AuditLedger audit log storage with security best practices.

## Features

- **Secure Storage Account** with TLS 1.2+ and HTTPS-only traffic
- **Private Blob Container** with no public access
- **Versioning & Change Feed** for audit trail
- **Soft Delete Protection** for blobs and containers
- **Lifecycle Management** with automatic tiering and retention policies
- **Managed Identity Support** for secure, keyless authentication
- **Network Security** with firewall rules and VNet integration
- **Diagnostic Logging** integration with Log Analytics
- **GRS Replication** for geo-redundancy (configurable)

## Usage

### Basic Example

```hcl
module "auditledger_storage" {
  source = "../../modules/auditledger-azure-blob"

  storage_account_name = "auditlogsprodstorage"
  resource_group_name  = "auditledger-rg"
  location             = "eastus"
  container_name       = "audit-logs"

  tags = {
    Environment = "Production"
    Application = "AuditLedger"
  }
}
```

### Complete Example with All Features

```hcl
module "auditledger_storage" {
  source = "../../modules/auditledger-azure-blob"

  # Storage account configuration
  storage_account_name = "auditlogsprodstorage"
  resource_group_name  = "auditledger-rg"
  create_resource_group = false
  location             = "eastus"
  container_name       = "audit-logs"

  # Redundancy and tier
  account_tier     = "Standard"
  replication_type = "GRS" # Geo-redundant storage

  # Versioning and auditing
  enable_versioning   = true
  enable_change_feed  = true

  # Soft delete protection
  soft_delete_retention_days           = 30
  container_soft_delete_retention_days = 7

  # Lifecycle management
  retention_days               = 2555  # 7 years
  transition_to_cool_days      = 90
  transition_to_archive_days   = 365

  # Security: Network rules
  network_default_action = "Deny"
  network_bypass         = ["AzureServices"]
  allowed_ip_ranges      = ["203.0.113.0/24"]
  allowed_subnet_ids     = [azurerm_subnet.app_subnet.id]

  # Security: Managed identity
  enable_managed_identity       = true
  managed_identity_principal_id = azurerm_linux_web_app.app.identity[0].principal_id
  enable_shared_key_access      = false  # Disable key-based auth

  # Monitoring
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  tags = {
    Environment = "Production"
    Application = "AuditLedger"
    Compliance  = "SOC2,HIPAA,PCIDSS"
  }
}
```

### With App Service Managed Identity

```hcl
# App Service with managed identity
resource "azurerm_linux_web_app" "auditledger" {
  name                = "auditledger-app"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "AuditLedger__Storage__Provider"                 = "AzureBlob"
    "AuditLedger__Storage__AzureBlob__ContainerName" = module.auditledger_storage.container_name
    "AuditLedger__Storage__AzureBlob__AccountName"   = module.auditledger_storage.storage_account_name
    "AuditLedger__Storage__AzureBlob__UseAzurite"    = "false"
  }
}

# Storage module with managed identity access
module "auditledger_storage" {
  source = "../../modules/auditledger-azure-blob"

  storage_account_name          = "auditlogsstorage"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  enable_managed_identity       = true
  managed_identity_principal_id = azurerm_linux_web_app.auditledger.identity[0].principal_id
  enable_shared_key_access      = false
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| azurerm | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| azurerm | >= 3.0 |

## Resources

| Name | Type |
|------|------|
| azurerm_resource_group.audit_logs | resource |
| azurerm_storage_account.audit_logs | resource |
| azurerm_storage_container.audit_logs | resource |
| azurerm_storage_management_policy.audit_logs | resource |
| azurerm_role_assignment.storage_blob_data_contributor | resource |
| azurerm_monitor_diagnostic_setting.audit_logs | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| storage_account_name | Name of the Azure Storage Account (must be globally unique) | `string` | n/a | yes |
| resource_group_name | Name of the resource group | `string` | n/a | yes |
| create_resource_group | Whether to create a new resource group | `bool` | `false` | no |
| location | Azure region for resources | `string` | `"eastus"` | no |
| container_name | Name of the blob container for audit logs | `string` | `"audit-logs"` | no |
| account_tier | Storage account tier (Standard or Premium) | `string` | `"Standard"` | no |
| replication_type | Storage account replication type | `string` | `"GRS"` | no |
| enable_versioning | Enable blob versioning | `bool` | `true` | no |
| enable_change_feed | Enable change feed for blob auditing | `bool` | `true` | no |
| soft_delete_retention_days | Days to retain soft-deleted blobs | `number` | `30` | no |
| container_soft_delete_retention_days | Days to retain soft-deleted containers | `number` | `7` | no |
| retention_days | Days to retain audit logs before deletion | `number` | `null` | no |
| transition_to_cool_days | Days before transitioning to Cool tier | `number` | `90` | no |
| transition_to_archive_days | Days before transitioning to Archive tier | `number` | `180` | no |
| network_default_action | Default action for network rules | `string` | `"Deny"` | no |
| network_bypass | Services to bypass network rules | `list(string)` | `["AzureServices"]` | no |
| allowed_ip_ranges | List of allowed IP ranges (CIDR) | `list(string)` | `[]` | no |
| allowed_subnet_ids | List of allowed VNet subnet IDs | `list(string)` | `[]` | no |
| enable_shared_key_access | Allow access via shared keys | `bool` | `false` | no |
| enable_managed_identity | Enable system-assigned managed identity | `bool` | `true` | no |
| managed_identity_principal_id | Principal ID for role assignment | `string` | `null` | no |
| log_analytics_workspace_id | Log Analytics Workspace ID | `string` | `null` | no |
| tags | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| resource_group_name | Name of the resource group |
| storage_account_name | Name of the storage account |
| storage_account_id | ID of the storage account |
| storage_account_primary_blob_endpoint | Primary blob endpoint URL |
| storage_account_primary_connection_string | Primary connection string (sensitive) |
| container_name | Name of the blob container |
| container_id | ID of the blob container |
| managed_identity_principal_id | Principal ID of managed identity (if enabled) |
| managed_identity_tenant_id | Tenant ID of managed identity (if enabled) |

## Security Best Practices

### 1. Use Managed Identity (Recommended)

```hcl
enable_managed_identity       = true
managed_identity_principal_id = azurerm_linux_web_app.app.identity[0].principal_id
enable_shared_key_access      = false  # Disable connection strings
```

### 2. Network Security

```hcl
network_default_action = "Deny"
network_bypass         = ["AzureServices"]
allowed_ip_ranges      = ["your-app-ip/32"]
allowed_subnet_ids     = [azurerm_subnet.app_subnet.id]
```

### 3. Enable Versioning & Soft Delete

```hcl
enable_versioning                    = true
soft_delete_retention_days           = 30
container_soft_delete_retention_days = 7
```

### 4. Compliance Retention

For SOC2, HIPAA, and PCIDSS compliance:

```hcl
retention_days = 2555  # 7 years for HIPAA
enable_versioning = true
enable_change_feed = true
```

### 5. Monitoring & Auditing

```hcl
log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
enable_change_feed = true
```

## Cost Optimization

### Storage Tiering

Automatically tier older audit logs to reduce costs:

```hcl
transition_to_cool_days    = 90   # Move to Cool after 90 days (50% cheaper)
transition_to_archive_days = 365  # Move to Archive after 1 year (95% cheaper)
retention_days             = 2555 # Delete after 7 years
```

### Replication Strategy

Choose replication based on requirements:

- **LRS** (Locally Redundant) - Lowest cost, single datacenter
- **ZRS** (Zone Redundant) - Multiple zones in region
- **GRS** (Geo Redundant) - Cross-region replication (recommended)
- **GZRS** (Geo-Zone Redundant) - Highest durability

## Terraform Backend Configuration

Example for remote state storage:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstatestorage"
    container_name       = "tfstate"
    key                  = "auditledger.terraform.tfstate"
  }
}
```

## Complete Deployment Example

See [terraform/examples/azure-app-service](../../examples/azure-app-service) for a complete deployment example with App Service, Application Insights, and Key Vault integration.

## License

MIT License - See LICENSE file in the repository root.


<!-- BEGIN_TF_DOCS -->


## Requirements

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 3.0 |

## Providers

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 4.47.0 |

## Modules

## Modules

No modules.

## Resources

## Resources

| Name | Type |
|------|------|
| [azurerm_monitor_diagnostic_setting.audit_logs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) | resource |
| [azurerm_resource_group.audit_logs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.storage_blob_data_contributor](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_storage_account.audit_logs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_storage_container.audit_logs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container) | resource |
| [azurerm_storage_management_policy.audit_logs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_management_policy) | resource |

## Inputs

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_tier"></a> [account\_tier](#input\_account\_tier) | Storage account tier (Standard or Premium) | `string` | `"Standard"` | no |
| <a name="input_allowed_ip_ranges"></a> [allowed\_ip\_ranges](#input\_allowed\_ip\_ranges) | List of allowed IP address ranges (CIDR notation) | `list(string)` | `[]` | no |
| <a name="input_allowed_subnet_ids"></a> [allowed\_subnet\_ids](#input\_allowed\_subnet\_ids) | List of allowed virtual network subnet IDs | `list(string)` | `[]` | no |
| <a name="input_container_name"></a> [container\_name](#input\_container\_name) | Name of the blob container for audit logs | `string` | `"audit-logs"` | no |
| <a name="input_container_soft_delete_retention_days"></a> [container\_soft\_delete\_retention\_days](#input\_container\_soft\_delete\_retention\_days) | Number of days to retain soft-deleted containers (null to disable) | `number` | `7` | no |
| <a name="input_create_resource_group"></a> [create\_resource\_group](#input\_create\_resource\_group) | Whether to create a new resource group (if false, uses existing) | `bool` | `false` | no |
| <a name="input_enable_change_feed"></a> [enable\_change\_feed](#input\_enable\_change\_feed) | Enable change feed for blob auditing | `bool` | `true` | no |
| <a name="input_enable_managed_identity"></a> [enable\_managed\_identity](#input\_enable\_managed\_identity) | Enable system-assigned managed identity for the storage account | `bool` | `true` | no |
| <a name="input_enable_shared_key_access"></a> [enable\_shared\_key\_access](#input\_enable\_shared\_key\_access) | Allow access via shared access keys (set false for managed identity only) | `bool` | `false` | no |
| <a name="input_enable_versioning"></a> [enable\_versioning](#input\_enable\_versioning) | Enable blob versioning (recommended for audit logs) | `bool` | `true` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region for resources | `string` | `"eastus"` | no |
| <a name="input_log_analytics_workspace_id"></a> [log\_analytics\_workspace\_id](#input\_log\_analytics\_workspace\_id) | Log Analytics Workspace ID for diagnostic logs (null to disable) | `string` | `null` | no |
| <a name="input_managed_identity_principal_id"></a> [managed\_identity\_principal\_id](#input\_managed\_identity\_principal\_id) | Principal ID of the managed identity to grant access (e.g., App Service, AKS) | `string` | `null` | no |
| <a name="input_network_bypass"></a> [network\_bypass](#input\_network\_bypass) | Services to bypass network rules | `list(string)` | <pre>[<br/>  "AzureServices"<br/>]</pre> | no |
| <a name="input_network_default_action"></a> [network\_default\_action](#input\_network\_default\_action) | Default action for network rules (Allow or Deny) | `string` | `"Deny"` | no |
| <a name="input_replication_type"></a> [replication\_type](#input\_replication\_type) | Storage account replication type (LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS) | `string` | `"GRS"` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group | `string` | n/a | yes |
| <a name="input_retention_days"></a> [retention\_days](#input\_retention\_days) | Number of days to retain audit logs before deletion (null for no expiration) | `number` | `null` | no |
| <a name="input_soft_delete_retention_days"></a> [soft\_delete\_retention\_days](#input\_soft\_delete\_retention\_days) | Number of days to retain soft-deleted blobs (null to disable) | `number` | `30` | no |
| <a name="input_storage_account_name"></a> [storage\_account\_name](#input\_storage\_account\_name) | Name of the Azure Storage Account (must be globally unique, 3-24 chars, lowercase letters and numbers only) | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_transition_to_archive_days"></a> [transition\_to\_archive\_days](#input\_transition\_to\_archive\_days) | Days before transitioning to Archive storage tier | `number` | `180` | no |
| <a name="input_transition_to_cool_days"></a> [transition\_to\_cool\_days](#input\_transition\_to\_cool\_days) | Days before transitioning to Cool storage tier | `number` | `90` | no |

## Outputs

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_container_id"></a> [container\_id](#output\_container\_id) | ID of the blob container |
| <a name="output_container_name"></a> [container\_name](#output\_container\_name) | Name of the blob container |
| <a name="output_managed_identity_principal_id"></a> [managed\_identity\_principal\_id](#output\_managed\_identity\_principal\_id) | Principal ID of the storage account's managed identity (if enabled) |
| <a name="output_managed_identity_tenant_id"></a> [managed\_identity\_tenant\_id](#output\_managed\_identity\_tenant\_id) | Tenant ID of the storage account's managed identity (if enabled) |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | Name of the resource group |
| <a name="output_storage_account_id"></a> [storage\_account\_id](#output\_storage\_account\_id) | ID of the storage account |
| <a name="output_storage_account_name"></a> [storage\_account\_name](#output\_storage\_account\_name) | Name of the storage account |
| <a name="output_storage_account_primary_blob_endpoint"></a> [storage\_account\_primary\_blob\_endpoint](#output\_storage\_account\_primary\_blob\_endpoint) | Primary blob endpoint of the storage account |
| <a name="output_storage_account_primary_connection_string"></a> [storage\_account\_primary\_connection\_string](#output\_storage\_account\_primary\_connection\_string) | Primary connection string for the storage account (sensitive) |
<!-- END_TF_DOCS -->
