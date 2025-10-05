# AuditLedger S3 Storage Terraform Module

This Terraform module creates and configures an AWS S3 bucket optimized for AuditLedger audit log storage with security best practices built-in.

## Features

- ✅ **Secure by Default**: Enforces encryption at rest (AES256 or KMS)
- ✅ **TLS Only**: Denies unencrypted connections
- ✅ **Public Access Blocked**: All public access explicitly blocked
- ✅ **Versioning**: Optional bucket versioning for immutability
- ✅ **Lifecycle Management**: Automatic transitions to cheaper storage classes
- ✅ **Access Logging**: Optional S3 access logging
- ✅ **IAM Policies**: Pre-configured least-privilege IAM policies
- ✅ **IAM Roles**: Optional IAM role creation for ECS/EC2/Lambda

## Usage

### Basic Usage (Development)

```hcl
module "auditledger_s3" {
  source = "./modules/auditledger-s3"

  bucket_name = "my-audit-logs-dev"

  tags = {
    Environment = "development"
    Application = "AuditLedger"
  }
}
```

### Production with KMS and Retention

```hcl
module "auditledger_s3" {
  source = "./modules/auditledger-s3"

  bucket_name        = "my-audit-logs-prod"
  enable_versioning  = true
  enable_mfa_delete  = true
  kms_key_id         = aws_kms_key.audit_logs.id
  retention_days     = 2555  # 7 years (HIPAA/SOX compliance)

  transition_to_ia_days      = 90   # Move to IA after 90 days
  transition_to_glacier_days = 365  # Move to Glacier after 1 year

  tags = {
    Environment = "production"
    Application = "AuditLedger"
    Compliance  = "HIPAA,SOX,PCI-DSS"
  }
}
```

### With IAM Role for ECS Task

```hcl
module "auditledger_s3" {
  source = "./modules/auditledger-s3"

  bucket_name       = "my-audit-logs-prod"
  create_iam_role   = true
  iam_role_name     = "AuditLedgerECSRole"

  iam_role_trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = "production"
    Application = "AuditLedger"
  }
}
```

### With Access Logging

```hcl
# Create a separate bucket for access logs
resource "aws_s3_bucket" "audit_access_logs" {
  bucket = "my-audit-logs-access-logs"
}

module "auditledger_s3" {
  source = "./modules/auditledger-s3"

  bucket_name    = "my-audit-logs-prod"
  logging_bucket = aws_s3_bucket.audit_access_logs.id

  tags = {
    Environment = "production"
    Application = "AuditLedger"
  }
}
```

## Input Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `bucket_name` | Name of the S3 bucket | `string` | - | yes |
| `force_destroy` | Allow destroying bucket with objects | `bool` | `false` | no |
| `enable_versioning` | Enable bucket versioning | `bool` | `true` | no |
| `enable_mfa_delete` | Enable MFA delete protection | `bool` | `false` | no |
| `kms_key_id` | KMS key ID for encryption | `string` | `null` | no |
| `retention_days` | Days to retain logs (null = forever) | `number` | `null` | no |
| `transition_to_ia_days` | Days before IA transition | `number` | `90` | no |
| `transition_to_glacier_days` | Days before Glacier transition | `number` | `180` | no |
| `logging_bucket` | Bucket for access logs | `string` | `null` | no |
| `iam_policy_name` | Name of IAM policy | `string` | `AuditLedgerS3AccessPolicy` | no |
| `iam_policy_path` | Path for IAM policy | `string` | `/` | no |
| `create_iam_role` | Create IAM role | `bool` | `false` | no |
| `iam_role_name` | Name of IAM role | `string` | `AuditLedgerS3AccessRole` | no |
| `iam_role_trust_policy` | IAM role trust policy | `string` | `""` | no |
| `tags` | Resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `bucket_name` | Name of the S3 bucket |
| `bucket_arn` | ARN of the S3 bucket |
| `bucket_region` | AWS region of the bucket |
| `bucket_domain_name` | Domain name of the bucket |
| `iam_policy_arn` | ARN of the IAM policy |
| `iam_policy_name` | Name of the IAM policy |
| `iam_role_arn` | ARN of the IAM role (if created) |
| `iam_role_name` | Name of the IAM role (if created) |

## Compliance & Retention Guidelines

### HIPAA (7 years)
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

## Security Best Practices

This module implements the following security best practices:

1. ✅ **Encryption at Rest**: AES256 or AWS KMS
2. ✅ **Encryption in Transit**: TLS enforced via bucket policy
3. ✅ **Block Public Access**: All public access blocked
4. ✅ **Versioning**: Enabled by default for immutability
5. ✅ **Least Privilege IAM**: Only necessary S3 permissions granted
6. ✅ **MFA Delete**: Optional for production environments
7. ✅ **Access Logging**: Optional S3 access logging
8. ✅ **Lifecycle Policies**: Automatic cost optimization

## Cost Optimization

The module includes lifecycle policies to reduce costs:

1. **Standard → IA**: After 90 days (default)
2. **IA → Glacier**: After 180 days (default)
3. **Expiration**: Based on compliance requirements

Example cost reduction:
- Standard: $0.023/GB/month
- IA: $0.0125/GB/month (46% savings)
- Glacier: $0.004/GB/month (83% savings)

## Requirements

- Terraform >= 1.5.0
- AWS Provider >= 5.0

## License

MIT


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
| [aws_iam_policy.auditledger_s3_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.auditledger_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.auditledger_s3_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_s3_bucket.audit_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.audit_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.audit_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_policy.audit_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.audit_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.audit_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.audit_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |

## Inputs

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | Name of the S3 bucket for audit logs | `string` | n/a | yes |
| <a name="input_create_iam_role"></a> [create\_iam\_role](#input\_create\_iam\_role) | Whether to create an IAM role for the application | `bool` | `false` | no |
| <a name="input_enable_mfa_delete"></a> [enable\_mfa\_delete](#input\_enable\_mfa\_delete) | Enable MFA delete for the S3 bucket (requires versioning) | `bool` | `false` | no |
| <a name="input_enable_versioning"></a> [enable\_versioning](#input\_enable\_versioning) | Enable versioning for the S3 bucket (recommended for audit logs) | `bool` | `true` | no |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Allow bucket to be destroyed even if it contains objects (use with caution) | `bool` | `false` | no |
| <a name="input_iam_policy_name"></a> [iam\_policy\_name](#input\_iam\_policy\_name) | Name of the IAM policy for AuditLedger access | `string` | `"AuditLedgerS3AccessPolicy"` | no |
| <a name="input_iam_policy_path"></a> [iam\_policy\_path](#input\_iam\_policy\_path) | Path for the IAM policy | `string` | `"/"` | no |
| <a name="input_iam_role_name"></a> [iam\_role\_name](#input\_iam\_role\_name) | Name of the IAM role (if create\_iam\_role is true) | `string` | `"AuditLedgerS3AccessRole"` | no |
| <a name="input_iam_role_trust_policy"></a> [iam\_role\_trust\_policy](#input\_iam\_role\_trust\_policy) | IAM role trust policy (assume role policy) | `string` | `""` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | KMS key ID for bucket encryption (if null, uses AES256) | `string` | `null` | no |
| <a name="input_logging_bucket"></a> [logging\_bucket](#input\_logging\_bucket) | S3 bucket name for access logs (null to disable) | `string` | `null` | no |
| <a name="input_retention_days"></a> [retention\_days](#input\_retention\_days) | Number of days to retain audit logs (null for no expiration) | `number` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_transition_to_glacier_days"></a> [transition\_to\_glacier\_days](#input\_transition\_to\_glacier\_days) | Days before transitioning to Glacier storage class | `number` | `180` | no |
| <a name="input_transition_to_ia_days"></a> [transition\_to\_ia\_days](#input\_transition\_to\_ia\_days) | Days before transitioning to Infrequent Access storage class | `number` | `90` | no |

## Outputs

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | ARN of the S3 bucket |
| <a name="output_bucket_domain_name"></a> [bucket\_domain\_name](#output\_bucket\_domain\_name) | Domain name of the S3 bucket |
| <a name="output_bucket_name"></a> [bucket\_name](#output\_bucket\_name) | Name of the S3 bucket |
| <a name="output_bucket_region"></a> [bucket\_region](#output\_bucket\_region) | AWS region of the S3 bucket |
| <a name="output_iam_policy_arn"></a> [iam\_policy\_arn](#output\_iam\_policy\_arn) | ARN of the IAM policy for AuditLedger access |
| <a name="output_iam_policy_name"></a> [iam\_policy\_name](#output\_iam\_policy\_name) | Name of the IAM policy |
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | ARN of the IAM role (if created) |
| <a name="output_iam_role_name"></a> [iam\_role\_name](#output\_iam\_role\_name) | Name of the IAM role (if created) |
<!-- END_TF_DOCS -->
