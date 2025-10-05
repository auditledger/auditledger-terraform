# AuditLedger Azure App Service Deployment Example

This example deploys AuditLedger on Azure App Service with Azure Blob Storage for audit log persistence.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Azure Resource Group                     │
│                                                               │
│  ┌──────────────────┐         ┌──────────────────────────┐  │
│  │   App Service    │────────▶│  Azure Blob Storage      │  │
│  │  (Linux, .NET 9) │         │  - audit-logs container  │  │
│  │                  │         │  - Versioning enabled    │  │
│  │  Managed Identity│         │  - Soft delete enabled   │  │
│  └────────┬─────────┘         │  - Lifecycle policies    │  │
│           │                   └──────────────────────────┘  │
│           │                                                  │
│           ▼                                                  │
│  ┌──────────────────┐         ┌──────────────────────────┐  │
│  │ App Insights     │────────▶│  Log Analytics           │  │
│  │ (Monitoring)     │         │  (Diagnostics)           │  │
│  └──────────────────┘         └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Features

- ✅ **App Service** with .NET 9.0 runtime
- ✅ **Managed Identity** for secure, keyless authentication
- ✅ **Blob Storage** with versioning, soft delete, and lifecycle management
- ✅ **Application Insights** for monitoring and telemetry
- ✅ **Log Analytics** for centralized logging
- ✅ **HTTPS-only** with TLS 1.2+
- ✅ **Auto-tiering** to Cool/Archive storage for cost optimization

## Prerequisites

1. **Azure CLI** installed and authenticated:
   ```bash
   az login
   az account set --subscription "your-subscription-id"
   ```

2. **Terraform** >= 1.5.0:
   ```bash
   terraform --version
   ```

3. **Unique storage account name** (globally unique across Azure):
   ```bash
   # Check availability
   az storage account check-name --name auditlogsstorage
   ```

## Quick Start

### 1. Copy and customize variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your configuration
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review the plan

```bash
terraform plan
```

### 4. Deploy

```bash
terraform apply
```

### 5. Get deployment outputs

```bash
terraform output app_service_url
```

## Configuration

### Minimum Required Variables

```hcl
app_name             = "auditledger-app"
resource_group_name  = "auditledger-rg"
storage_account_name = "auditlogsstorage"  # Must be globally unique
organization_id      = "your-org-id"
```

### Production Configuration

For production deployments, consider:

```hcl
# App Service
app_service_sku = "P1v3"  # Premium tier with better performance

# Network Security
network_default_action = "Deny"
allowed_ip_ranges = [
  "203.0.113.0/24",  # Office IP range
  "198.51.100.0/24"  # VPN IP range
]

# Compliance Retention
retention_days = 2555  # 7 years for HIPAA/PCIDSS

# Tags
tags = {
  Environment = "Production"
  Compliance  = "SOC2,HIPAA,PCIDSS"
  CostCenter  = "Engineering"
  Owner       = "platform-team@company.com"
}
```

## Deployment Validation

### 1. Verify App Service is running

```bash
APP_URL=$(terraform output -raw app_service_url)
curl -I $APP_URL/health
```

### 2. Test audit log storage

```bash
# The app will automatically use managed identity
# Check storage container
STORAGE_ACCOUNT=$(terraform output -raw storage_account_name)
CONTAINER=$(terraform output -raw container_name)

az storage blob list \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --auth-mode login
```

### 3. Monitor with Application Insights

```bash
# View in Azure Portal
az monitor app-insights component show \
  --app auditledger-app-insights \
  --resource-group auditledger-rg
```

## Cost Estimation

### Development Environment

| Resource | SKU | Est. Cost/Month |
|----------|-----|----------------|
| App Service (B1) | Basic | ~$13 |
| Storage (LRS, Hot) | Standard | ~$2 |
| Application Insights | Pay-as-you-go | ~$5 |
| **Total** | | **~$20/month** |

### Production Environment

| Resource | SKU | Est. Cost/Month |
|----------|-----|----------------|
| App Service (P1v3) | Premium | ~$146 |
| Storage (GRS, with tiering) | Standard | ~$10 |
| Application Insights | Pay-as-you-go | ~$50 |
| Log Analytics | Pay-as-you-go | ~$10 |
| **Total** | | **~$216/month** |

*Prices are estimates and may vary by region and usage.*

## Security Best Practices

### 1. Use Managed Identity (Already Configured)

This example uses system-assigned managed identity, eliminating the need for connection strings:

```hcl
identity {
  type = "SystemAssigned"
}

app_settings = {
  "AuditLedger__Storage__AzureBlob__AccountName" = module.auditledger_storage.storage_account_name
  # No connection string needed!
}
```

### 2. Enable Network Restrictions

For production, restrict storage access:

```hcl
network_default_action = "Deny"
allowed_ip_ranges = ["your-app-ip/32"]
```

### 3. Enable Private Endpoints (Advanced)

For enhanced security, use Private Endpoints:

```hcl
# Add to storage module
enable_private_endpoint = true
private_endpoint_subnet_id = azurerm_subnet.private.id
```

### 4. Store Secrets in Key Vault

For sensitive configuration:

```bash
az keyvault create --name auditledger-kv --resource-group auditledger-rg
az keyvault secret set --vault-name auditledger-kv --name OrganizationId --value "your-org-id"
```

Then reference in App Service:

```hcl
app_settings = {
  "AuditLedger__Compliance__OrganizationId" = "@Microsoft.KeyVault(SecretUri=https://auditledger-kv.vault.azure.net/secrets/OrganizationId/)"
}
```

## Monitoring & Alerts

### View Logs

```bash
# Stream app logs
az webapp log tail --name auditledger-app --resource-group auditledger-rg

# Query Application Insights
az monitor app-insights query \
  --app auditledger-app-insights \
  --resource-group auditledger-rg \
  --analytics-query "traces | where message contains 'audit' | limit 10"
```

### Set Up Alerts

Create alerts for failures:

```bash
az monitor metrics alert create \
  --name "High Error Rate" \
  --resource-group auditledger-rg \
  --scopes $(az webapp show --name auditledger-app --resource-group auditledger-rg --query id -o tsv) \
  --condition "avg Http5xx > 10" \
  --window-size 5m \
  --evaluation-frequency 1m
```

## Scaling

### Manual Scaling

```bash
az appservice plan update \
  --name auditledger-app-plan \
  --resource-group auditledger-rg \
  --sku P2v3 \
  --number-of-workers 2
```

### Auto-scaling (Add to Terraform)

```hcl
resource "azurerm_monitor_autoscale_setting" "app_service" {
  name                = "autoscale-${var.app_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  target_resource_id  = azurerm_service_plan.main.id

  profile {
    name = "Auto scale based on CPU"

    capacity {
      default = 2
      minimum = 1
      maximum = 5
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.main.id
        operator           = "GreaterThan"
        threshold          = 70
        time_aggregation   = "Average"
        time_grain         = "PT1M"
        time_window        = "PT5M"
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning:** This will delete the storage account and all audit logs unless `force_destroy = false` (default).

## Troubleshooting

### Issue: Storage authentication fails

**Solution:** Verify managed identity has correct role:

```bash
PRINCIPAL_ID=$(terraform output -raw managed_identity_principal_id)
STORAGE_ID=$(az storage account show --name auditlogsstorage --resource-group auditledger-rg --query id -o tsv)

az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee $PRINCIPAL_ID \
  --scope $STORAGE_ID
```

### Issue: App fails to start

**Check logs:**

```bash
az webapp log tail --name auditledger-app --resource-group auditledger-rg
```

### Issue: Network connectivity issues

**Verify network rules:**

```bash
az storage account show \
  --name auditlogsstorage \
  --resource-group auditledger-rg \
  --query "networkRuleSet"
```

## Next Steps

- [ ] Set up CI/CD pipeline (GitHub Actions, Azure DevOps)
- [ ] Configure custom domain and SSL certificate
- [ ] Implement Private Endpoints for enhanced security
- [ ] Set up backup and disaster recovery
- [ ] Enable Azure Security Center recommendations

## Support

For issues specific to this deployment, please check:
- [Azure App Service Documentation](https://docs.microsoft.com/azure/app-service/)
- [Azure Storage Documentation](https://docs.microsoft.com/azure/storage/)
- [AuditLedger GitHub Issues](https://github.com/auditledger/auditledger-dotnet/issues)


<!-- BEGIN_TF_DOCS -->


## Requirements

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 3.0 |

## Providers

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 3.117.1 |

## Modules

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_auditledger_storage"></a> [auditledger\_storage](#module\_auditledger\_storage) | ../../modules/auditledger-azure-blob | n/a |

## Resources

## Resources

| Name | Type |
|------|------|
| [azurerm_application_insights.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_insights) | resource |
| [azurerm_linux_web_app.auditledger](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_web_app) | resource |
| [azurerm_log_analytics_workspace.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace) | resource |
| [azurerm_resource_group.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_service_plan.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/service_plan) | resource |

## Inputs

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_ip_ranges"></a> [allowed\_ip\_ranges](#input\_allowed\_ip\_ranges) | List of allowed IP address ranges (CIDR notation) | `list(string)` | `[]` | no |
| <a name="input_app_name"></a> [app\_name](#input\_app\_name) | Name of the App Service application | `string` | n/a | yes |
| <a name="input_app_service_sku"></a> [app\_service\_sku](#input\_app\_service\_sku) | SKU for the App Service Plan (e.g., B1, S1, P1v3) | `string` | `"B1"` | no |
| <a name="input_container_name"></a> [container\_name](#input\_container\_name) | Name of the blob container for audit logs | `string` | `"audit-logs"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (Development, Staging, Production) | `string` | `"Production"` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region for resources | `string` | `"eastus"` | no |
| <a name="input_network_default_action"></a> [network\_default\_action](#input\_network\_default\_action) | Default action for network rules (Allow or Deny) | `string` | `"Allow"` | no |
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | Organization identifier for audit logs | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group | `string` | n/a | yes |
| <a name="input_retention_days"></a> [retention\_days](#input\_retention\_days) | Number of days to retain audit logs (null for no expiration) | `number` | `2555` | no |
| <a name="input_storage_account_name"></a> [storage\_account\_name](#input\_storage\_account\_name) | Name of the storage account (3-24 chars, lowercase letters and numbers only) | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | <pre>{<br/>  "Application": "AuditLedger",<br/>  "ManagedBy": "Terraform"<br/>}</pre> | no |
| <a name="input_transition_to_archive_days"></a> [transition\_to\_archive\_days](#input\_transition\_to\_archive\_days) | Days before transitioning to Archive storage tier | `number` | `365` | no |
| <a name="input_transition_to_cool_days"></a> [transition\_to\_cool\_days](#input\_transition\_to\_cool\_days) | Days before transitioning to Cool storage tier | `number` | `90` | no |

## Outputs

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_app_service_name"></a> [app\_service\_name](#output\_app\_service\_name) | Name of the App Service |
| <a name="output_app_service_url"></a> [app\_service\_url](#output\_app\_service\_url) | URL of the deployed App Service |
| <a name="output_application_insights_connection_string"></a> [application\_insights\_connection\_string](#output\_application\_insights\_connection\_string) | Connection string for Application Insights |
| <a name="output_application_insights_key"></a> [application\_insights\_key](#output\_application\_insights\_key) | Instrumentation key for Application Insights |
| <a name="output_container_name"></a> [container\_name](#output\_container\_name) | Name of the blob container |
| <a name="output_managed_identity_principal_id"></a> [managed\_identity\_principal\_id](#output\_managed\_identity\_principal\_id) | Principal ID of the App Service managed identity |
| <a name="output_storage_account_name"></a> [storage\_account\_name](#output\_storage\_account\_name) | Name of the storage account |
<!-- END_TF_DOCS -->
