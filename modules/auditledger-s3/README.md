# AuditLedger S3 Immutable Storage Terraform Module

This Terraform module creates AWS S3 buckets with **mandatory immutability enforcement** for AuditLedger audit log storage. Immutability is enforced via S3 Object Lock and cannot be disabled.

## 🔒 Immutability Enforcement

**⚠️ CRITICAL: This module enforces immutability that CANNOT be disabled**

- ✅ **S3 Object Lock** enabled at bucket creation (irreversible)
- ✅ **Versioning** mandatory (required for Object Lock)
- ✅ **Retention policies** enforce minimum 365 days (7 years default)
- ✅ **Delete operations** denied via bucket policy
- ✅ **COMPLIANCE mode** default (strictest protection)

Once deployed, audit logs are **immutable for the retention period** - not even root users can delete or modify them.

## Features

- 🔐 **Mandatory Immutability**: S3 Object Lock with COMPLIANCE or GOVERNANCE mode
- 🔒 **Secure by Default**: Enforces encryption at rest (AES256 or KMS)
- 🔑 **TLS Only**: Denies unencrypted connections
- 🚫 **Public Access Blocked**: All public access explicitly blocked
- 📦 **Versioning**: Always enabled (required for Object Lock)
- ♻️ **Lifecycle Management**: Automatic transitions to cheaper storage classes
- 📊 **Access Logging**: Optional S3 access logging
- 🌍 **Replication**: Optional cross-region replication for disaster recovery

## Usage

### Production Deployment (COMPLIANCE Mode)

```hcl
# Create IAM role for AuditLedger application
resource "aws_iam_role" "auditledger_app" {
  name = "auditledger-application-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"  # Or ECS, EKS, Lambda, etc.
      }
      Action = "sts:AssumeRole"
    }]
  })
}

module "auditledger_s3" {
  source = "./modules/auditledger-s3"

  bucket_name            = "acme-corp-audit-logs-prod"
  retention_days         = 2555  # 7 years (SOC 2)
  object_lock_mode       = "COMPLIANCE"  # Strictest immutability
  auditledger_role_arns  = [aws_iam_role.auditledger_app.arn]
  enable_lifecycle_rules = true

  tags = {
    Environment        = "production"
    CostCenter         = "security"
    DataClassification = "highly-confidential"
  }
}
```

### With Cross-Region Replication

```hcl
module "auditledger_s3" {
  source = "./modules/auditledger-s3"

  bucket_name           = "acme-audit-logs-primary"
  retention_days        = 2555
  object_lock_mode      = "COMPLIANCE"
  auditledger_role_arns = [aws_iam_role.auditledger_app.arn]

  # Disaster recovery replication
  replication_bucket_arn = aws_s3_bucket.audit_logs_dr.arn
  replication_role_arn   = aws_iam_role.replication.arn

  tags = {
    Environment = "production"
  }
}
```

### With KMS Encryption

```hcl
module "auditledger_s3" {
  source = "./modules/auditledger-s3"

  bucket_name           = "acme-audit-logs-prod"
  retention_days        = 2555
  object_lock_mode      = "COMPLIANCE"
  auditledger_role_arns = [aws_iam_role.auditledger_app.arn]
  kms_key_id            = aws_kms_key.audit_logs.id

  tags = {
    Environment = "production"
  }
}
```

## Input Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `bucket_name` | Name of the S3 bucket (3-63 chars, lowercase) | `string` | - | yes |
| `retention_days` | Days to retain audit logs (min 365) | `number` | `2555` | no |
| `object_lock_mode` | COMPLIANCE or GOVERNANCE | `string` | `"COMPLIANCE"` | no |
| `auditledger_role_arns` | ARNs of IAM roles for AuditLedger | `list(string)` | - | yes |
| `admin_role_arns` | ARNs of roles that can manage Object Lock | `list(string)` | `[]` | no |
| `governance_bypass_role_arns` | ARNs of roles that can bypass GOVERNANCE retention | `list(string)` | `[]` | no |
| `kms_key_id` | KMS key ID for encryption | `string` | `null` | no |
| `enable_lifecycle_rules` | Enable cost optimization rules | `bool` | `true` | no |
| `access_log_bucket` | Bucket for access logs | `string` | `null` | no |
| `replication_bucket_arn` | ARN of DR replication bucket | `string` | `null` | no |
| `replication_role_arn` | ARN of replication IAM role | `string` | `null` | no |
| `tags` | Resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `bucket_id` | ID of the S3 bucket |
| `bucket_arn` | ARN of the S3 bucket |
| `bucket_domain_name` | Domain name of the bucket |
| `bucket_regional_domain_name` | Regional domain name of the bucket |
| `object_lock_configuration` | Object Lock configuration details |
| `immutability_verified` | Confirmation that immutability is enforced (always `true`) |

## Object Lock Modes

### COMPLIANCE Mode (Recommended for Production)

```hcl
object_lock_mode = "COMPLIANCE"
```

- **Strictest protection**: No one (not even root) can delete objects during retention
- **Cannot be overridden**: Retention period cannot be shortened
- **Audit compliance**: Required for SOC 2, HIPAA, PCIDSS
- **Recommended for**: Production audit logs

### GOVERNANCE Mode (For Testing)

```hcl
object_lock_mode = "GOVERNANCE"
```

- **Flexible protection**: Special IAM permissions can override retention
- **Can be bypassed**: With `s3:BypassGovernanceRetention` permission
- **Use case**: Testing, development environments only

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

### Immutability Enforcement

1. **S3 Object Lock**: Enabled at bucket creation (cannot be disabled)
2. **Bucket Policy**: Denies `s3:DeleteObject` and `s3:DeleteObjectVersion`
3. **Bypass Protection**: Denies `s3:BypassGovernanceRetention` (except authorized roles)
4. **Configuration Lock**: Denies changes to Object Lock configuration

### Encryption

- **At Rest**: AES256 or AWS KMS
- **In Transit**: TLS enforced via bucket policy
- **Bucket Key**: Enabled for KMS cost optimization

### Access Control

Access is managed through bucket policy with explicit allow/deny rules:
- ✅ AuditLedger roles can write and read
- ❌ All delete operations denied
- ❌ Public access completely blocked
- ❌ Unencrypted uploads denied

## Cost Optimization

Lifecycle rules automatically tier older logs to cheaper storage:

1. **Standard → IA**: After 90 days (46% cost savings)
2. **IA → Glacier IR**: After 180 days (71% savings)
3. **Glacier IR → Glacier**: After 365 days (83% savings)

Example monthly costs (per GB):
- Standard: $0.023/GB
- IA: $0.0125/GB
- Glacier IR: $0.0063/GB
- Glacier: $0.004/GB

## Validation

After deployment, validate immutability enforcement:

```bash
# Check Object Lock configuration
aws s3api get-object-lock-configuration --bucket <bucket-name>

# Verify versioning
aws s3api get-bucket-versioning --bucket <bucket-name>

# Test immutability (should fail)
aws s3 rm s3://<bucket-name>/test-object.json
# Expected: Access Denied
```

## Important Notes

⚠️ **Object Lock is irreversible**: Once enabled, the bucket will always have Object Lock

⚠️ **Retention cannot be shortened**: You can only extend retention periods

⚠️ **Bucket cannot be deleted**: Until all objects pass their retention period

⚠️ **Use COMPLIANCE mode carefully**: Test thoroughly in non-production first

## Requirements

- Terraform >= 1.5.0
- AWS Provider >= 5.0

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
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.15.0 |

## Modules

## Modules

No modules.

## Resources

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.s3_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_s3_bucket.audit_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.audit_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.audit_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_object_lock_configuration.audit_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_object_lock_configuration) | resource |
| [aws_s3_bucket_policy.audit_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.audit_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_replication_configuration.audit_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_replication_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.audit_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.audit_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |

## Inputs

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_log_bucket"></a> [access\_log\_bucket](#input\_access\_log\_bucket) | S3 bucket for access logging (optional but recommended for compliance) | `string` | `null` | no |
| <a name="input_admin_role_arns"></a> [admin\_role\_arns](#input\_admin\_role\_arns) | ARNs of IAM roles that can manage Object Lock configuration (extremely privileged) | `list(string)` | `[]` | no |
| <a name="input_auditledger_role_arns"></a> [auditledger\_role\_arns](#input\_auditledger\_role\_arns) | ARNs of IAM roles that AuditLedger uses to write audit logs | `list(string)` | n/a | yes |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | Name of the S3 bucket for audit logs | `string` | n/a | yes |
| <a name="input_enable_lifecycle_rules"></a> [enable\_lifecycle\_rules](#input\_enable\_lifecycle\_rules) | Enable lifecycle rules for cost optimization (transitions to cheaper storage classes) | `bool` | `true` | no |
| <a name="input_governance_bypass_role_arns"></a> [governance\_bypass\_role\_arns](#input\_governance\_bypass\_role\_arns) | ARNs of IAM roles that can bypass GOVERNANCE mode retention (only if using GOVERNANCE mode) | `list(string)` | `[]` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | KMS key ID for encryption at rest (optional, uses S3 default encryption if not provided) | `string` | `null` | no |
| <a name="input_object_lock_mode"></a> [object\_lock\_mode](#input\_object\_lock\_mode) | Object Lock mode: COMPLIANCE (strict) or GOVERNANCE (can be overridden with special permissions) | `string` | `"COMPLIANCE"` | no |
| <a name="input_replication_bucket_arn"></a> [replication\_bucket\_arn](#input\_replication\_bucket\_arn) | ARN of destination bucket for cross-region replication (optional but recommended for DR) | `string` | `null` | no |
| <a name="input_replication_role_arn"></a> [replication\_role\_arn](#input\_replication\_role\_arn) | ARN of IAM role for replication (required if replication\_bucket\_arn is set) | `string` | `null` | no |
| <a name="input_retention_days"></a> [retention\_days](#input\_retention\_days) | Number of days to retain audit logs (minimum 365 for compliance) | `number` | `2555` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags for the S3 bucket | `map(string)` | `{}` | no |

## Outputs

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | ARN of the S3 bucket |
| <a name="output_bucket_domain_name"></a> [bucket\_domain\_name](#output\_bucket\_domain\_name) | Domain name of the S3 bucket |
| <a name="output_bucket_id"></a> [bucket\_id](#output\_bucket\_id) | ID of the S3 bucket |
| <a name="output_bucket_regional_domain_name"></a> [bucket\_regional\_domain\_name](#output\_bucket\_regional\_domain\_name) | Regional domain name of the S3 bucket |
| <a name="output_iam_policy_arn"></a> [iam\_policy\_arn](#output\_iam\_policy\_arn) | ARN of the IAM policy for S3 bucket access |
| <a name="output_iam_policy_name"></a> [iam\_policy\_name](#output\_iam\_policy\_name) | Name of the IAM policy for S3 bucket access |
| <a name="output_immutability_verified"></a> [immutability\_verified](#output\_immutability\_verified) | Confirmation that immutability is enforced |
| <a name="output_object_lock_configuration"></a> [object\_lock\_configuration](#output\_object\_lock\_configuration) | Object Lock configuration for verification |
<!-- END_TF_DOCS -->
