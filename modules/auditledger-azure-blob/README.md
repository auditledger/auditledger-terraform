# AuditLedger Azure Immutable Blob Storage Terraform Module

This Terraform module provisions Azure Blob Storage with **mandatory immutability enforcement** for AuditLedger audit log storage. Versioning and retention policies are enforced and cannot be disabled.

## 🔒 Immutability Enforcement

**⚠️ CRITICAL: This module enforces immutability that CANNOT be disabled**

- ✅ **Versioning** always enabled (mandatory)
- ✅ **Change Feed** enabled for audit trail
- ✅ **Soft Delete** protects against accidental deletion
- ✅ **Point-in-Time Restore** enabled
- ✅ **Retention policies** enforce minimum 365 days (7 years default)
- ✅ **Management policies** automate lifecycle and retention

## Features

- 🔐 **Mandatory Immutability**: Versioning and retention policies always enforced
- 🔒 **Secure Storage Account**: TLS 1.2+ and HTTPS-only traffic
- 🔑 **Managed Identity**: Keyless authentication (recommended over connection strings)
- 🚫 **Private Container**: No public access
- 📊 **Audit Trail**: Change feed and diagnostic logging
- ♻️ **Lifecycle Management**: Automatic tiering to Cool and Archive storage
- 🌍 **Geo-Redundancy**: GRS replication by default
- 🛡️ **Threat Protection**: Advanced threat detection

## Usage

### Production Deployment

```hcl
module "auditledger_storage" {
  source = "./modules/auditledger-azure-blob"

  storage_account_name = "acmeauditlogsprod"
  resource_group_name  = "auditledger-rg"
  location             = "eastus"
  container_name       = "audit-logs"

  # Immutability settings
  retention_days   = 2555  # 7 years (SOC 2)
  replication_type = "GRS" # Geo-redundant storage

  # Security: Managed identity only
  enable_managed_identity       = true
  managed_identity_principal_id = azurerm_linux_web_app.app.identity[0].principal_id
  enable_shared_key_access      = false

  # Network security
  network_default_action = "Deny"
  allowed_ip_ranges      = ["203.0.113.0/24"]
  allowed_subnet_ids     = [azurerm_subnet.app_subnet.id]

  # Monitoring
  enable_threat_protection   = true
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  tags = {
    Environment        = "production"
    Application        = "AuditLedger"
    DataClassification = "highly-confidential"
    Compliance         = "SOC2-HIPAA-PCIDSS"
  }
}
```

### With App Service Managed Identity

```hcl
# App Service with system-assigned managed identity
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

module "auditledger_storage" {
  source = "./modules/auditledger-azure-blob"

  storage_account_name          = "auditlogsstorage"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  retention_days                = 2555
  enable_managed_identity       = true
  managed_identity_principal_id = azurerm_linux_web_app.auditledger.identity[0].principal_id
  enable_shared_key_access      = false
}
```

### Minimal Configuration

```hcl
module "auditledger_storage" {
  source = "./modules/auditledger-azure-blob"

  storage_account_name = "myauditlogsstorage"
  resource_group_name  = "my-resource-group"
  location             = "eastus"
}
```

## Input Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `storage_account_name` | Storage account name (3-24 chars, lowercase) | `string` | - | yes |
| `resource_group_name` | Resource group name | `string` | - | yes |
| `create_resource_group` | Create new resource group | `bool` | `true` | no |
| `location` | Azure region | `string` | `"eastus"` | no |
| `container_name` | Blob container name | `string` | `"audit-logs"` | no |
| `account_tier` | Standard or Premium | `string` | `"Standard"` | no |
| `replication_type` | LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS | `string` | `"GRS"` | no |
| `retention_days` | Days to retain audit logs (min 365) | `number` | `2555` | no |
| `network_default_action` | Allow or Deny | `string` | `"Deny"` | no |
| `network_bypass` | Services to bypass network rules | `list(string)` | `["AzureServices"]` | no |
| `allowed_ip_ranges` | Allowed IP ranges (CIDR) | `list(string)` | `[]` | no |
| `allowed_subnet_ids` | Allowed VNet subnet IDs | `list(string)` | `[]` | no |
| `enable_shared_key_access` | Allow shared key access | `bool` | `false` | no |
| `enable_managed_identity` | Enable system-assigned identity | `bool` | `true` | no |
| `managed_identity_principal_id` | Principal ID for role assignment | `string` | `null` | no |
| `enable_threat_protection` | Enable Advanced Threat Protection | `bool` | `true` | no |
| `log_analytics_workspace_id` | Log Analytics workspace ID | `string` | `null` | no |
| `tags` | Resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `storage_account_id` | ID of the storage account |
| `storage_account_name` | Name of the storage account |
| `primary_blob_endpoint` | Primary blob endpoint URL |
| `container_name` | Name of the blob container |
| `resource_group_name` | Name of the resource group |
| `managed_identity_principal_id` | Principal ID of managed identity |
| `immutability_configuration` | Immutability configuration details |
| `immutability_verified` | Confirmation that immutability is enforced (always `true`) |

## Compliance Retention Guidelines

### SOC 2 / HIPAA (7 years)
```hcl
retention_days = 2555  # 7 years
```

### PCI-DSS (1 year minimum)
```hcl
retention_days = 365  # 1 year
```

### SOX (7 years)
```hcl
retention_days = 2555  # 7 years
```

### GDPR (6 years recommended)
```hcl
retention_days = 2190  # 6 years
```

## Security Architecture

### Immutability Features

1. **Versioning**: Always enabled (cannot be disabled)
2. **Change Feed**: Tracks all blob modifications
3. **Soft Delete**: Protects against accidental deletion for retention period
4. **Point-in-Time Restore**: Can restore up to 365 days
5. **Lifecycle Policies**: Automatic retention enforcement

### Authentication

**Recommended: Managed Identity (Keyless)**
```hcl
enable_managed_identity       = true
enable_shared_key_access      = false  # No connection strings
managed_identity_principal_id = "<app-principal-id>"
```

**Not Recommended: Connection Strings**
- Avoid `enable_shared_key_access = true` in production
- Use managed identity instead

### Network Security

```hcl
network_default_action = "Deny"           # Block all by default
network_bypass         = ["AzureServices"] # Allow Azure services
allowed_ip_ranges      = ["your-ip/32"]   # Whitelist specific IPs
allowed_subnet_ids     = [subnet.id]      # Allow VNet subnets
```

### Encryption

- **At Rest**: Automatic encryption with Microsoft-managed keys
- **In Transit**: HTTPS only, TLS 1.2 minimum
- **Customer-Managed Keys**: Optional (add via Key Vault)

## Cost Optimization

Lifecycle policies automatically tier older logs to cheaper storage:

1. **Hot → Cool**: After 90 days (50% cost savings)
2. **Cool → Archive**: After 180 days (95% cost savings)
3. **Deletion**: After retention period (e.g., 2555 days)

Example monthly costs (per GB):
- Hot: $0.0184/GB
- Cool: $0.01/GB
- Archive: $0.00099/GB

### Replication Strategy

Choose based on requirements:
- **LRS**: Lowest cost, single datacenter
- **ZRS**: Multiple zones in region
- **GRS**: Cross-region replication (recommended) ⭐
- **GZRS**: Highest durability

## Monitoring & Compliance

### Enable Diagnostics

```hcl
log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
```

Logs captured:
- StorageRead
- StorageWrite
- StorageDelete
- Transactions
- Capacity

### Enable Threat Protection

```hcl
enable_threat_protection = true
```

Detects:
- Unusual access patterns
- Potential malware uploads
- Suspicious activities

## Validation

After deployment, validate immutability enforcement:

```bash
# Check versioning status
az storage account blob-service-properties show \
  --account-name <account-name> \
  --query "isVersioningEnabled"

# Check management policy
az storage account management-policy show \
  --account-name <account-name> \
  --resource-group <resource-group>
```

## Important Notes

⚠️ **Versioning is always enabled**: Cannot be disabled for audit logs

⚠️ **Soft delete uses retention period**: Matches your configured retention_days

⚠️ **Point-in-Time Restore limited**: Maximum 365 days (Azure limitation)

⚠️ **Change feed retention**: Matches your configured retention_days

## Requirements

- Terraform >= 1.5.0
- Azure Provider >= 3.0

## License

MIT
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
README.md updated successfully
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

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
| [azurerm_advanced_threat_protection.audit_logs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/advanced_threat_protection) | resource |
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
| <a name="input_allowed_ip_ranges"></a> [allowed\_ip\_ranges](#input\_allowed\_ip\_ranges) | List of IP ranges allowed to access the storage account | `list(string)` | `[]` | no |
| <a name="input_allowed_subnet_ids"></a> [allowed\_subnet\_ids](#input\_allowed\_subnet\_ids) | List of subnet IDs allowed to access the storage account | `list(string)` | `[]` | no |
| <a name="input_container_name"></a> [container\_name](#input\_container\_name) | Name of the blob container for audit logs | `string` | `"audit-logs"` | no |
| <a name="input_create_resource_group"></a> [create\_resource\_group](#input\_create\_resource\_group) | Whether to create a new resource group | `bool` | `true` | no |
| <a name="input_enable_managed_identity"></a> [enable\_managed\_identity](#input\_enable\_managed\_identity) | Enable system-assigned managed identity for the storage account | `bool` | `true` | no |
| <a name="input_enable_shared_key_access"></a> [enable\_shared\_key\_access](#input\_enable\_shared\_key\_access) | Allow access via shared access keys (set false for managed identity only) | `bool` | `false` | no |
| <a name="input_enable_threat_protection"></a> [enable\_threat\_protection](#input\_enable\_threat\_protection) | Enable Advanced Threat Protection | `bool` | `true` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region for resources | `string` | `"eastus"` | no |
| <a name="input_log_analytics_workspace_id"></a> [log\_analytics\_workspace\_id](#input\_log\_analytics\_workspace\_id) | Log Analytics workspace ID for diagnostics | `string` | `null` | no |
| <a name="input_managed_identity_principal_id"></a> [managed\_identity\_principal\_id](#input\_managed\_identity\_principal\_id) | Principal ID of the managed identity to grant access (e.g., App Service, AKS) | `string` | `null` | no |
| <a name="input_network_bypass"></a> [network\_bypass](#input\_network\_bypass) | Services to bypass network rules | `list(string)` | <pre>[<br/>  "AzureServices"<br/>]</pre> | no |
| <a name="input_network_default_action"></a> [network\_default\_action](#input\_network\_default\_action) | Default action for network rules (Allow or Deny) | `string` | `"Deny"` | no |
| <a name="input_replication_type"></a> [replication\_type](#input\_replication\_type) | Storage replication type: LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS | `string` | `"GRS"` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group | `string` | n/a | yes |
| <a name="input_retention_days"></a> [retention\_days](#input\_retention\_days) | Number of days to retain audit logs (minimum 365 for compliance) | `number` | `2555` | no |
| <a name="input_storage_account_name"></a> [storage\_account\_name](#input\_storage\_account\_name) | Name of the storage account (must be globally unique, 3-24 lowercase letters/numbers) | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags for resources | `map(string)` | `{}` | no |

## Outputs

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_container_name"></a> [container\_name](#output\_container\_name) | Name of the audit logs container |
| <a name="output_immutability_configuration"></a> [immutability\_configuration](#output\_immutability\_configuration) | Immutability configuration for verification |
| <a name="output_immutability_verified"></a> [immutability\_verified](#output\_immutability\_verified) | Confirmation that immutability is enforced |
| <a name="output_managed_identity_principal_id"></a> [managed\_identity\_principal\_id](#output\_managed\_identity\_principal\_id) | Principal ID of the storage account's managed identity (if enabled) |
| <a name="output_primary_blob_endpoint"></a> [primary\_blob\_endpoint](#output\_primary\_blob\_endpoint) | Primary blob endpoint |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | Name of the resource group |
| <a name="output_storage_account_id"></a> [storage\_account\_id](#output\_storage\_account\_id) | ID of the storage account |
| <a name="output_storage_account_name"></a> [storage\_account\_name](#output\_storage\_account\_name) | Name of the storage account |
<!-- END_TF_DOCS -->
