# AuditLedger Terraform Modules

Official Terraform modules for deploying [AuditLedger](https://github.com/auditledger/auditledger-dotnet) infrastructure on AWS and Azure.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Terraform](https://img.shields.io/badge/Terraform-1.5%2B-623CE4)](https://www.terraform.io/)

## Overview

AuditLedger is an immutable audit logging and compliance platform for .NET. This repository contains Terraform modules to provision secure, compliant storage infrastructure for audit logs.

## Available Modules

### AWS S3 Storage Module
- **Path**: `modules/auditledger-s3`
- **Purpose**: S3 bucket with security best practices for audit log storage
- **Features**: Encryption, versioning, lifecycle policies, IAM policies

[📖 Full Documentation](modules/auditledger-s3/README.md)

### Azure Blob Storage Module
- **Path**: `modules/auditledger-azure-blob`
- **Purpose**: Azure Storage Account with Blob container for audit logs
- **Features**: Managed identity, versioning, soft delete, lifecycle management

[📖 Full Documentation](modules/auditledger-azure-blob/README.md)

## Quick Start

### AWS S3

```hcl
module "auditledger_storage" {
  source = "github.com/auditledger/auditledger-terraform//modules/auditledger-s3?ref=v1.0.0"

  bucket_name        = "my-company-audit-logs"
  enable_versioning  = true
  retention_days     = 2555  # 7 years
  kms_key_id         = aws_kms_key.audit_logs.id

  tags = {
    Environment = "Production"
    Compliance  = "SOC2,HIPAA,PCIDSS"
  }
}
```

### Azure Blob Storage

```hcl
module "auditledger_storage" {
  source = "github.com/auditledger/auditledger-terraform//modules/auditledger-azure-blob?ref=v1.0.0"

  storage_account_name      = "mycompanyauditlogs"
  resource_group_name       = "auditledger-rg"
  location                  = "eastus"
  enable_managed_identity   = true
  enable_versioning         = true
  retention_days            = 2555

  tags = {
    Environment = "Production"
    Compliance  = "SOC2,HIPAA,PCIDSS"
  }
}
```

## Complete Examples

### AWS
- [EC2 Deployment](examples/ec2/) - Deploy on EC2 with IAM instance profile
- [ECS Fargate](examples/ecs-fargate/) - Containerized deployment on ECS
- [Lambda Function](examples/lambda/) - Serverless deployment

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
  source = "github.com/auditledger/auditledger-terraform//modules/auditledger-s3?ref=v1.0.0"

  # Your configuration...
}
```

## Compliance & Security

These modules are designed with compliance in mind:

- ✅ **SOC 2** - Encryption, access controls, audit trails
- ✅ **HIPAA** - 7-year retention, versioning, encryption at rest
- ✅ **PCI DSS** - Secure storage, access logging, encryption

### Security Features

#### AWS
- Server-side encryption (AES256 or KMS)
- Block public access by default
- Bucket versioning
- Lifecycle policies for retention
- IAM least-privilege policies
- TLS-only access enforcement

#### Azure
- TLS 1.2+ enforcement
- Managed identity support (keyless auth)
- Blob versioning and soft delete
- Network security rules
- Change feed for auditing
- Automatic tiering (Hot → Cool → Archive)

## Module Versioning

We follow [Semantic Versioning](https://semver.org/):

- **Major** (v2.0.0): Breaking changes
- **Minor** (v1.1.0): New features, backward compatible
- **Patch** (v1.0.1): Bug fixes

**Recommended**: Pin to a specific version in production:

```hcl
source = "github.com/auditledger/auditledger-terraform//modules/auditledger-s3?ref=v1.0.0"
```

## Cost Optimization

### Storage Tiering

Both modules support automatic tiering to reduce costs:

**AWS S3:**
```hcl
transition_to_ia_days      = 90   # → Infrequent Access (50% cheaper)
transition_to_glacier_days = 365  # → Glacier (95% cheaper)
```

**Azure Blob:**
```hcl
transition_to_cool_days    = 90   # → Cool tier (50% cheaper)
transition_to_archive_days = 365  # → Archive tier (95% cheaper)
```

## Testing

### Validation

```bash
# Validate Terraform syntax
terraform validate

# Check formatting
terraform fmt -check -recursive

# Security scanning
tfsec .
```

### Integration Tests

```bash
# Run terratest (if implemented)
cd tests
go test -v -timeout 30m
```

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run validation: `terraform fmt -recursive && terraform validate`
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
