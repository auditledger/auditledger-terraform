# Terraform Testing Guide

Automated tests for AuditLedger Terraform modules with **zero-cost local testing** using LocalStack and Azurite.

## Quick Start

```bash
# Setup (one-time)
make local-up          # Starts LocalStack, creates .env files
cd tests && cp go.mod.example go.mod && go mod download

# Run tests (uses .env.localstack automatically)
make local-test        # Runs all LocalStack tests

# Cleanup
make local-down
```

## Test Structure

```
tests/
├── smoke/                         # Fast plan-only tests (2-5 min)
│   └── s3_smoke_test.go
├── contract/                      # Interface validation (5 min)
│   └── module_interface_test.go
├── examples/                      # Example validation (5-10 min)
│   └── ec2_example_test.go
├── integration/                   # Full integration tests (10-30 min)
│   ├── s3_module_local_test.go   # LocalStack (free)
│   ├── s3_module_test.go         # Real AWS (disabled)
│   └── helpers.go                # Shared utilities
├── go.mod.example                # Go dependencies
└── README.md                     # This file
```

## Testing Tiers

```
┌─────────────────┐
│ Real Cloud      │  ← Manual only ($$$, 30m) - DISABLED
│ (Optional)      │
└─────────────────┘
     ▲
┌─────────────────┐
│ LocalStack      │  ← Every PR (Free, 10m)
│ Integration     │    Full deployment testing
└─────────────────┘
     ▲
┌─────────────────┐
│ Contract/Smoke  │  ← Every PR (Free, 5m)
│ Tests           │    Interface & example validation
└─────────────────┘
     ▲
┌───────────────────┐
│ Static Analysis   │  ← Every commit (Free, 2m)
│ fmt/validate/tfsec│  Pre-commit hooks
└───────────────────┘
```

## Running Tests

### Makefile Commands (Recommended)

```bash
make local-up         # Start LocalStack
make local-test       # Run AWS local tests
make local-test-aws   # Run AWS tests with LocalStack
make local-shell      # Open shell with env loaded
make local-down       # Stop LocalStack
```

### Manual Commands

```bash
# Start services
docker compose up -d

# Load environment
cp env.localstack.example .env.localstack  # One-time
source .env.localstack

# Run specific test types
cd tests/smoke && go test -v              # Fastest
cd tests/contract && go test -v           # Interface validation
cd tests/examples && go test -v           # Example validation

# Run local integration tests (AWS only - Azure requires real cloud)
./scripts/test-localstack.sh              # AWS with LocalStack

# Or manually:
cd tests/integration && go test -v -run TestS3ModuleLocalStack   # S3 with LocalStack

# Note: Azure local testing not supported (see "Local Testing Limitations" below)

# Cleanup
docker compose down
```

### Test by Purpose

| Purpose | Command | Duration | Cost |
|---------|---------|----------|------|
| Quick validation | `cd tests/smoke && go test -v` | 2 min | Free |
| Interface check | `cd tests/contract && go test -v` | 5 min | Free |
| Example sync | `cd tests/examples && go test -v` | 5 min | Free |
| Full local test | `make local-test` | 10 min | Free |
| Real cloud (disabled) | Manual only | 30 min | $1-5 |

## Environment Configuration

### Local Development (.env files)

**Setup once:**
```bash
cp env.localstack.example .env.localstack
cp env.azurite.example .env.azurite
```

**Load when testing:**
```bash
source .env.localstack
```

**Or use scripts (auto-loads):**
```bash
./scripts/test-localstack.sh
# or
make local-test
```

### GitHub Actions (YAML)

Environment variables are set directly in workflow files:

```yaml
# .github/workflows/terraform-validate.yml
env:
  AWS_ENDPOINT_URL: http://localhost:4566
  AWS_ACCESS_KEY_ID: test
  # ... etc
```

No .env files needed in CI!

## Available .env Files

| File | Purpose | Committed? |
|------|---------|------------|
| `env.localstack.example` | Template for LocalStack config | ✅ Yes |
| `env.azurite.example` | Template for Azurite config | ✅ Yes |
| `.env.localstack` | Your local copy | ❌ No (gitignored) |
| `.env.azurite` | Your local copy | ❌ No (gitignored) |

## LocalStack Configuration

### Supported AWS Services

- ✅ S3 - Buckets, Object Lock, versioning
- ✅ IAM - Policies, roles
- ✅ KMS - Encryption keys
- ✅ CloudWatch - Log groups
- ✅ Lambda - Python functions
- ✅ API Gateway - HTTP APIs

### Limitations

⚠️ **Not fully supported or slow in LocalStack:**
- S3 Object Lock COMPLIANCE mode (use GOVERNANCE)
- S3 Lifecycle configurations (can hang - disable with `enable_lifecycle_rules=false`)
- Cross-region replication
- Some advanced IAM conditions

**Tip:** Disable lifecycle rules in LocalStack tests for faster execution.

**Use LocalStack for rapid iteration, real AWS for final validation.**

### Verify LocalStack is Running

```bash
curl http://localhost:4566/_localstack/health
# Should show: "s3": "available"
```

## Azurite Configuration

### Supported Azure Services

- ✅ Blob Storage - Containers, blobs
- ✅ Versioning - Blob versioning
- ⚠️ Limited - Change feed, immutability policies (emulated)

### Connection Info

```bash
# Default Azurite credentials
Account: devstoreaccount1
Key: Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==
Endpoint: http://127.0.0.1:10000/devstoreaccount1
```

## Prerequisites

### Required

```bash
# Install Go
brew install go
go version  # Should be 1.21+

# Install Terraform
brew install terraform
terraform version  # Should be 1.5.0+

# Install Docker
brew install --cask docker
# Start Docker Desktop
```

### Optional

```bash
# AWS CLI (for real cloud tests)
brew install awscli

# Azure CLI (for Azure tests)
brew install azure-cli
```

## LocalStack Known Issues

### Tests Hang on Lifecycle Configuration

**Problem:** `aws_s3_bucket_lifecycle_configuration` can hang in LocalStack.

**Solution:** Disable lifecycle rules in LocalStack tests:
```go
vars := map[string]interface{}{
    "enable_lifecycle_rules": false,  // ← Prevents hanging
}
```

### Terraform Destroy Hangs on Object Lock Buckets

**Problem:** `terraform destroy` hangs when destroying S3 buckets with Object Lock enabled in LocalStack.

**Solution:** Skip `terraform destroy` for LocalStack tests. The LocalStack container cleanup automatically handles resource disposal:
```go
// Don't use: defer terraform.Destroy(t, terraformOptions)
// LocalStack container cleanup will handle disposal
```

For GitHub Actions smoke tests, the workflow skips destroy - the LocalStack service container is automatically torn down at job completion.

### If Tests Get Stuck

```bash
# Press Ctrl+C to stop
# Or kill the process
ps aux | grep "go test" | awk '{print $2}' | xargs kill
```

## Troubleshooting

### LocalStack not responding

```bash
# Check status
docker ps | grep localstack

# View logs
docker compose logs localstack

# Restart
docker compose restart localstack
```

### Tests fail with "connection refused"

**Problem:** LocalStack not started or wrong endpoint.

**Solution:**
```bash
# Check LocalStack is running
curl http://localhost:4566/_localstack/health

# Verify environment
echo $AWS_ENDPOINT_URL
# Should be: http://localhost:4566
```

### "go.mod" not found

```bash
cd tests
cp go.mod.example go.mod
go mod download
```

### Environment variables not loaded

```bash
# Make sure you sourced the file
source .env.localstack

# Verify
env | grep AWS_ENDPOINT
# Should show: AWS_ENDPOINT_URL=http://localhost:4566
```

## Cost Comparison

| Test Method | Duration | Cost | When to Use |
|-------------|----------|------|-------------|
| LocalStack tests | 10 min | **$0** | Daily development ⭐ |
| Real cloud tests | 30 min | $1-5 | Pre-release only |

**Recommendation:** Use LocalStack for 95% of testing!

## CI/CD Workflows

### On Every PR (Automatic, Free):

1. **Static Analysis** (2 min)
   - terraform fmt, validate
   - tfsec, tflint

2. **Contract Tests** (5 min)
   - Module interface validation
   - Required files check

3. **Smoke Tests** (5 min)
   - LocalStack deployment test
   - Go smoke tests

**Total:** ~12 minutes, $0 cost

### Manual Only (Disabled):

**Real Cloud Integration Tests**
- Requires GitHub secrets configured
- See `.plans/REAL_CLOUD_TESTING_SETUP.md`

## Writing Tests

### Smoke Test (Plan Only)

```go
func TestModuleSmoke(t *testing.T) {
    terraformOptions := &terraform.Options{
        TerraformDir: "../../modules/module-name",
        Vars: map[string]interface{}{"bucket_name": "test"},
    }

    terraform.Init(t, terraformOptions)
    planOutput := terraform.Plan(t, terraformOptions)
    assert.Contains(t, planOutput, "expected_resource")
}
```

### LocalStack Test (With Deployment)

```go
func TestModuleLocalStack(t *testing.T) {
    if !IsLocalStack() {
        t.Skip("Set USE_LOCALSTACK=true to run")
    }

    vars := map[string]interface{}{
        "bucket_name": "test-bucket",
        "retention_days": 365,
        "object_lock_mode": "GOVERNANCE",
        "auditledger_role_arns": []string{GetTestRoleArn()},
    }

    opts := GetAWSConfig(t, "../../modules/module-name", vars)
    defer terraform.Destroy(t, opts)
    terraform.InitAndApply(t, opts)

    // Validate
    output := terraform.Output(t, opts, "bucket_id")
    assert.NotEmpty(t, output)
}
```

## Additional Resources

- **Beginner Guide:** `.plans/integration_testing.md`
- **Testing Best Practices:** `.plans/TESTING.md`
- **Real Cloud Setup:** `.plans/REAL_CLOUD_TESTING_SETUP.md` (when ready)

## Summary

**For daily development:**
- ✅ Use LocalStack (free, fast)
- ✅ Use .env files locally
- ✅ Use Makefile commands

**For production validation:**
- ⚠️ Real cloud tests (manual trigger only)
- 💰 Costs money, disabled by default
- 📚 See setup guide when ready

**Zero-cost testing for 95% of your work!** 🎉
