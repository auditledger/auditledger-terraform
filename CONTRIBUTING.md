# Contributing to AuditLedger Terraform Modules

Thank you for your interest in contributing! This document provides guidelines for contributing to the AuditLedger Terraform modules.

## Code of Conduct

Be respectful, inclusive, and constructive in all interactions.

## How to Contribute

### Reporting Issues

- Search existing issues before creating a new one
- Provide detailed steps to reproduce
- Include Terraform version and provider versions
- Share relevant error messages and logs

### Suggesting Enhancements

- Open an issue describing the enhancement
- Explain the use case and benefits
- Consider backward compatibility

### Pull Requests

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/my-enhancement`
3. **Make your changes**
4. **Test thoroughly** (see Testing section)
5. **Commit with clear messages**: `git commit -m "Add support for X"`
6. **Push to your fork**: `git push origin feature/my-enhancement`
7. **Open a Pull Request**

## Development Guidelines

### Code Style

- Use consistent formatting: `terraform fmt -recursive`
- Follow [Terraform Style Guide](https://www.terraform.io/docs/language/syntax/style.html)
- Use meaningful variable and resource names
- Add descriptions to all variables and outputs

### Documentation

- Update README.md for new features
- Document all variables with descriptions and types
- Include examples for complex configurations
- Add comments for non-obvious logic

### Testing

Before submitting a PR, ensure:

```bash
# Format check
terraform fmt -check -recursive

# Validation
cd modules/auditledger-s3
terraform init
terraform validate

cd ../auditledger-azure-blob
terraform init
terraform validate

# Security scan (optional but recommended)
tfsec .
```

### Module Structure

Each module should follow this structure:

```
modules/module-name/
├── main.tf       # Main resources
├── variables.tf  # Input variables
├── outputs.tf    # Output values
├── README.md     # Module documentation
└── versions.tf   # (optional) Version constraints
```

### Variable Guidelines

- Use descriptive names
- Provide default values when appropriate
- Add validation blocks for complex inputs
- Document expected formats in descriptions

Example:
```hcl
variable "retention_days" {
  description = "Number of days to retain audit logs (null for no expiration)"
  type        = number
  default     = null

  validation {
    condition     = var.retention_days == null || var.retention_days >= 1
    error_message = "Retention days must be at least 1 day."
  }
}
```

### Security Best Practices

- Never commit credentials or secrets
- Use least-privilege IAM policies
- Enable encryption by default
- Enforce TLS/HTTPS
- Block public access by default
- Use managed identities when possible

## Examples

When adding new features:

1. Update the relevant example in `examples/`
2. Ensure the example is complete and runnable
3. Include a `terraform.tfvars.example` file
4. Document any prerequisites

## Versioning

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes to module interface
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, no API changes

## Release Process

1. Update version in documentation
2. Update CHANGELOG.md
3. Create a git tag: `git tag -a v1.0.0 -m "Release v1.0.0"`
4. Push tag: `git push origin v1.0.0`
5. Create GitHub Release with notes

## Questions?

Open an issue or start a discussion in [GitHub Discussions](https://github.com/auditledger/auditledger-terraform/discussions).

Thank you for contributing! 🎉
