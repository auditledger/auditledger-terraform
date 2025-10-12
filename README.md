# AuditLedger Terraform Modules

Official Terraform modules for deploying [AuditLedger](https://github.com/auditledger/auditledger-dotnet) infrastructure on AWS and Azure with **mandatory immutability enforcement**.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Terraform](https://img.shields.io/badge/Terraform-1.5%2B-623CE4)](https://www.terraform.io/)

## 🔒 Immutability-First Design

These modules enforce immutability at the infrastructure level - **it cannot be disabled**. This ensures audit logs are tamper-proof and compliant with regulatory requirements (SOC 2, HIPAA, PCIDSS).

- ✅ **AWS**: S3 Object Lock with COMPLIANCE/GOVERNANCE mode (irreversible)
- ✅ **Azure**: Mandatory versioning, soft delete, and retention policies
- ✅ **Minimum retention**: 365 days (7 years default for SOC 2)

## Available Modules

### AWS S3 Immutable Storage Module
- **Path**: `modules/auditledger-s3`
- **Purpose**: S3 bucket with mandatory Object Lock for immutable audit logs
- **Features**: Object Lock (COMPLIANCE/GOVERNANCE), encryption, versioning, lifecycle policies, replication

[📖 Full Documentation](modules/auditledger-s3/README.md)

### Azure Blob Immutable Storage Module
- **Path**: `modules/auditledger-azure-blob`
- **Purpose**: Azure Storage with mandatory versioning and retention policies
- **Features**: Versioning (always on), managed identity, soft delete, lifecycle management, threat protection

[📖 Full Documentation](modules/auditledger-azure-blob/README.md)

## Quick Start

### AWS S3 (COMPLIANCE Mode - Recommended for Production)

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

module "auditledger_storage" {
  source = "github.com/auditledger/auditledger-terraform//modules/auditledger-s3?ref=v2.0.0"

  bucket_name            = "my-company-audit-logs"
  retention_days         = 2555  # 7 years for SOC 2
  object_lock_mode       = "COMPLIANCE"  # Strictest immutability
  auditledger_role_arns  = [aws_iam_role.auditledger_app.arn]

  # Optional: KMS encryption
  kms_key_id             = aws_kms_key.audit_logs.id

  # Optional: Cost optimization
  enable_lifecycle_rules = true

  tags = {
    Environment = "production"
    Compliance  = "SOC2-HIPAA-PCIDSS"
  }
}
```

### Azure Blob Storage

```hcl
module "auditledger_storage" {
  source = "github.com/auditledger/auditledger-terraform//modules/auditledger-azure-blob?ref=v2.0.0"

  storage_account_name          = "mycompanyauditlogs"
  resource_group_name           = "auditledger-rg"
  location                      = "eastus"
  retention_days                = 2555  # 7 years for SOC 2

  # Security: Managed identity (recommended)
  enable_managed_identity       = true
  managed_identity_principal_id = azurerm_linux_web_app.app.identity[0].principal_id
  enable_shared_key_access      = false  # No connection strings

  # Network security
  network_default_action = "Deny"
  allowed_subnet_ids     = [azurerm_subnet.app_subnet.id]

  tags = {
    Environment = "production"
    Compliance  = "SOC2-HIPAA-PCIDSS"
  }
}
```

## Complete Examples

### AWS
- [EC2 Deployment](examples/ec2/) - Deploy on EC2 with IAM instance profile
- [ECS Fargate](examples/ecs-fargate/) - Containerized deployment on ECS
- [Lambda Function](examples/lambda/) - Serverless deployment with Python

### Azure
- [App Service](examples/azure-app-service/) - Deploy on Azure App Service with managed identity

## Requirements

| Tool | Version | Notes |
|------|---------|-------|
| Terraform or OpenTofu | >= 1.5.0 | Compatible with both Terraform 1.5.x and OpenTofu 1.6+ |
| AWS Provider | >= 5.0 | For AWS modules |
| Azure Provider | >= 3.0 | For Azure modules |

## Installation

### Choose Your Tool

This repository is compatible with both **Terraform** and **OpenTofu**:

#### Terraform 1.5.x (Last MPL Open Source Version)
```bash
brew install terraform  # Installs 1.5.7 (last open-source version)
```

#### OpenTofu (Open Source Fork)
```bash
brew install opentofu   # Latest open-source fork
# Use 'tofu' command instead of 'terraform'
```

**Note:** HashiCorp changed Terraform's license to BUSL (proprietary) in v1.6.0. For open-source projects, we recommend either Terraform 1.5.x or OpenTofu. Both tools use identical syntax and are fully compatible with this repository.

### Local Development

```bash
# Clone the repository
git clone https://github.com/auditledger/auditledger-terraform.git
cd auditledger-terraform

# Initialize (use 'terraform' or 'tofu')
cd examples/ec2  # or any example
terraform init   # or: tofu init
terraform plan   # or: tofu plan
```

### As a Module Reference

In your `main.tf`:

```hcl
module "auditledger" {
  source = "github.com/auditledger/auditledger-terraform//modules/auditledger-s3?ref=v2.0.0"

  # Your configuration...
}
```

## Immutability Enforcement

### AWS S3 Object Lock

**COMPLIANCE Mode (Production):**
- No one (not even root) can delete objects during retention
- Retention period cannot be shortened
- Required for strict compliance (SOC 2, HIPAA, PCIDSS)

**GOVERNANCE Mode (Testing):**
- Special IAM permissions can override retention
- Use only for development/testing environments

### Azure Blob Storage

**Enforced Features:**
- Versioning always enabled
- Change feed for audit trail
- Soft delete for retention period
- Point-in-time restore (up to 365 days)
- Automatic lifecycle management

## Compliance & Security

These modules are designed with compliance in mind:

- ✅ **SOC 2** - Encryption, access controls, audit trails, immutability
- ✅ **HIPAA** - 7-year retention, versioning, encryption at rest, immutability
- ✅ **PCI DSS** - Secure storage, access logging, encryption, immutability

### Security Features

#### AWS
- **Object Lock** - Mandatory WORM (Write Once Read Many) protection
- **Versioning** - Always enabled (required for Object Lock)
- **Encryption** - Server-side encryption (AES256 or KMS)
- **Public Access** - Completely blocked
- **Bucket Policy** - Denies delete operations
- **TLS-only** - Unencrypted connections denied
- **Replication** - Optional cross-region DR

#### Azure
- **Versioning** - Always enabled (mandatory)
- **Soft Delete** - Retention period enforcement
- **Encryption** - TLS 1.2+ enforcement
- **Managed Identity** - Keyless authentication
- **Network Security** - Firewall rules and VNet integration
- **Change Feed** - Complete audit trail
- **Threat Protection** - Advanced threat detection
- **Tiering** - Automatic Hot → Cool → Archive

## Module Versioning

We follow [Semantic Versioning](https://semver.org/):

- **Major** (v2.0.0): Breaking changes (immutability enforcement added)
- **Minor** (v2.1.0): New features, backward compatible
- **Patch** (v2.0.1): Bug fixes

**Recommended**: Pin to a specific version in production:

```hcl
source = "github.com/auditledger/auditledger-terraform//modules/auditledger-s3?ref=v2.0.0"
```

## Migration from v1.x to v2.x

**Breaking Changes:**
1. **AWS S3 Module:**
   - `enable_versioning` removed (always enabled)
   - `enable_mfa_delete` removed
   - `force_destroy` removed (incompatible with Object Lock)
   - `auditledger_role_arns` now required
   - `retention_days` minimum is now 365 days
   - `object_lock_mode` added (COMPLIANCE or GOVERNANCE)
   - IAM role creation removed (use bucket policy instead)

2. **Azure Blob Module:**
   - `enable_versioning` removed (always enabled)
   - `enable_change_feed` removed (always enabled)
   - `soft_delete_retention_days` tied to `retention_days`
   - `retention_days` minimum is now 365 days
   - Advanced Threat Protection added

**Migration Steps:**
1. Review your current configuration
2. Update variable names per module documentation
3. Test in non-production environment first
4. Plan carefully - Object Lock is irreversible on AWS

## Cost Optimization

### Storage Tiering

Both modules support automatic tiering to reduce costs:

**AWS S3:**
- Standard → IA: After 90 days (46% cost savings)
- IA → Glacier IR: After 180 days (71% savings)
- Glacier IR → Glacier: After 365 days (83% savings)

**Azure Blob:**
- Hot → Cool: After 90 days (50% cost savings)
- Cool → Archive: After 180 days (95% savings)

## Testing

### Local Testing (Free, No Cloud Required)

Test modules locally with LocalStack (no AWS account needed):

```bash
# 1. Start LocalStack
docker compose up -d

# 2. Load environment from .env file
cp env.localstack.example .env.localstack
source .env.localstack

# 3. Run tests
./scripts/test-localstack.sh

# 4. Stop services
docker compose down
```

**Environment variables:** Loaded from `.env.localstack` file locally, set in YAML for GitHub Actions.

### Validation (Fast)

```bash
# Validate Terraform syntax
terraform validate

# Check formatting
terraform fmt -check -recursive

# Security scanning
tfsec .

# Run all checks
make check-all
```

### Integration Tests (Real Cloud)

```bash
# Run terratest integration tests
cd tests/integration
go test -v -timeout 30m

# Run specific test
go test -v -timeout 30m -run TestS3ModuleImmutability
```

**Note:** Integration tests create real cloud resources and incur costs. Use local testing for rapid iteration.

See [.plans/integration_testing.md](.plans/integration_testing.md) for beginner's guide.

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run validation: `make test`
5. Submit a pull request

## Support

- **Documentation**: [AuditLedger Docs](https://github.com/auditledger/auditledger-dotnet)
- **Issues**: [GitHub Issues](https://github.com/auditledger/auditledger-terraform/issues)
- **Discussions**: [GitHub Discussions](https://github.com/auditledger/auditledger-terraform/discussions)

## Related Projects

- [AuditLedger .NET Library](https://github.com/auditledger/auditledger-dotnet) - The core .NET library
- [AuditLedger Examples](https://github.com/auditledger/auditledger-dotnet/tree/main/examples) - Application examples

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

Built with ❤️ for the compliance and security community.
