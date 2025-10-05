# Changelog

All notable changes to the AuditLedger Terraform modules will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- AWS S3 storage module with security best practices
- Azure Blob Storage module with managed identity support
- EC2 deployment example
- ECS Fargate deployment example
- Lambda deployment example
- Azure App Service deployment example
- Terraform validation CI/CD workflow
- Security scanning with tfsec
- Comprehensive documentation

### Security
- Encryption at rest enabled by default (AWS KMS, Azure SSE)
- TLS 1.2+ enforcement
- Block public access by default
- Managed identity support for keyless authentication
- Network security rules and firewall support

## [1.0.0] - 2025-10-05

### Added
- Initial release
- AWS S3 module
- Azure Blob Storage module
- Complete deployment examples
- Documentation and contribution guidelines

[Unreleased]: https://github.com/auditledger/auditledger-terraform/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/auditledger/auditledger-terraform/releases/tag/v1.0.0
