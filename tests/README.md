# Terraform Testing Guide

This directory contains automated tests for the AuditLedger Terraform modules.

## Test Structure

```
tests/
├── integration/          # Terratest integration tests
│   ├── s3_module_test.go
│   ├── azure_blob_test.go
│   └── common_test.go
├── contract/            # Interface/contract tests
│   └── module_interface_test.go
├── go.mod               # Go dependencies
└── README.md           # This file
```

## Prerequisites

- Go 1.21+
- Terraform 1.5+
- AWS credentials (for S3 tests)
- Azure credentials (for Azure Blob tests)

## Installation

```bash
cd tests
go mod init github.com/auditledger/auditledger-terraform/tests
go get github.com/gruntwork-io/terratest/modules/terraform@latest
go get github.com/gruntwork-io/terratest/modules/aws@latest
go get github.com/gruntwork-io/terratest/modules/azure@latest
go get github.com/stretchr/testify/assert@latest
```

## Running Tests

### Run all tests
```bash
cd tests/integration
go test -v -timeout 30m
```

### Run specific test
```bash
go test -v -timeout 30m -run TestS3Module
```

### Run tests in parallel
```bash
go test -v -timeout 30m -parallel 4
```

### Run with verbose Terraform output
```bash
TF_LOG=DEBUG go test -v -timeout 30m
```

## Test Strategy

### 1. Static Analysis (Pre-commit)
- `terraform fmt -check`
- `terraform validate`
- `tfsec` (security scanning)
- `checkov` (compliance checks)
- `tflint` (best practices)

### 2. Unit Tests (Fast, no cloud resources)
- Variable validation
- Input/output contract verification
- Logic testing with `terraform plan`

### 3. Integration Tests (Slow, creates real resources)
- Deploy module to real cloud
- Validate resources created correctly
- Test outputs and behavior
- Clean up resources

## Writing Tests

### Basic Test Pattern

```go
func TestModuleName(t *testing.T) {
    t.Parallel()

    // 1. Setup
    terraformOptions := &terraform.Options{
        TerraformDir: "../../modules/module-name",
        Vars: map[string]interface{}{
            "variable_name": "test-value",
        },
    }

    // 2. Cleanup (deferred)
    defer terraform.Destroy(t, terraformOptions)

    // 3. Deploy
    terraform.InitAndApply(t, terraformOptions)

    // 4. Validate
    output := terraform.Output(t, terraformOptions, "output_name")
    assert.NotEmpty(t, output)
}
```

## CI/CD Integration

Integration tests run:
- **Manually** via GitHub Actions workflow dispatch
- **Scheduled** nightly builds
- **NOT on every PR** (too slow and expensive)

## Cost Management

Integration tests create real cloud resources:
- Tests run in isolated accounts/subscriptions
- Resources are tagged: `Environment=Test`, `ManagedBy=Terratest`
- Cleanup happens automatically via `defer terraform.Destroy()`
- Backup cleanup jobs run daily to catch any orphaned resources

## Best Practices

1. **Always use `t.Parallel()`** for independent tests
2. **Always defer cleanup** to avoid orphaned resources
3. **Use unique names** with random suffixes to avoid conflicts
4. **Test one thing at a time** - focused test cases
5. **Clean up even on failure** - use `defer`
6. **Set reasonable timeouts** - 30m is typical
7. **Don't test AWS/Azure APIs** - test your module logic only

## Example: Testing S3 Module

```go
func TestS3ModuleVersioning(t *testing.T) {
    t.Parallel()

    bucketName := fmt.Sprintf("test-audit-%s", random.UniqueId())
    awsRegion := "us-east-1"

    terraformOptions := &terraform.Options{
        TerraformDir: "../../modules/auditledger-s3",
        Vars: map[string]interface{}{
            "bucket_name": bucketName,
            "enable_versioning": true,
        },
    }

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    // Validate versioning is enabled
    versioning := aws.GetS3BucketVersioning(t, awsRegion, bucketName)
    assert.Equal(t, "Enabled", versioning)
}
```

## Troubleshooting

### Tests hang or timeout
- Check AWS/Azure credentials
- Increase timeout: `-timeout 60m`
- Check for resource quotas

### Resources not cleaned up
```bash
# AWS
aws s3 ls | grep test-audit | awk '{print $3}' | xargs -I {} aws s3 rb s3://{} --force

# Azure
az resource list --tag Environment=Test --query "[].id" -o tsv | xargs -I {} az resource delete --ids {}
```

### Permission errors
- Ensure test role has permissions to create/destroy resources
- Check IAM/RBAC policies

## Resources

- [Terratest Documentation](https://terratest.gruntwork.io/)
- [Go Testing Best Practices](https://golang.org/doc/code.html#Testing)
- [Terraform Testing Best Practices](https://developer.hashicorp.com/terraform/language/modules)
