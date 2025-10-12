package test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestS3ModuleLocalStack tests the S3 module against LocalStack
// Run with: USE_LOCALSTACK=true go test -v -run TestS3ModuleLocalStack
// Note: LocalStack tests cannot run in parallel (they share the same module directory)
func TestS3ModuleLocalStack(t *testing.T) {
	if !IsLocalStack() {
		t.Skip("Skipping LocalStack test - set USE_LOCALSTACK=true to run")
	}

	// Do NOT run in parallel - LocalStack tests share the same module directory

	// Generate lowercase bucket name (S3 requirement)
	bucketName := fmt.Sprintf("test-local-%s", strings.ToLower(random.UniqueId()))

	vars := map[string]interface{}{
		"bucket_name":    bucketName,
		"retention_days": 365,
		// LocalStack works better with GOVERNANCE mode
		"object_lock_mode":       "GOVERNANCE",
		"auditledger_role_arns":  []string{GetTestRoleArn()},
		"enable_lifecycle_rules": false, // Simplify for LocalStack
		"tags": map[string]string{
			"Environment": "LocalTest",
			"ManagedBy":   "Terratest",
		},
	}

	terraformOptions := GetAWSConfig(t, "../../modules/auditledger-s3", vars)

	// Copy LocalStack provider override into module directory (with unique name)
	overridePath := copyLocalStackOverride(t, terraformOptions.TerraformDir)
	defer removeLocalStackOverride(overridePath)
	defer terraform.Destroy(t, terraformOptions)

	// Deploy
	terraform.InitAndApply(t, terraformOptions)

	// Basic validations
	outputBucketId := terraform.Output(t, terraformOptions, "bucket_id")
	assert.Equal(t, bucketName, outputBucketId)

	immutabilityVerified := terraform.Output(t, terraformOptions, "immutability_verified")
	assert.Equal(t, "true", immutabilityVerified)
}

// TestS3ModuleLocalStackBasicOperations tests basic S3 operations in LocalStack
// Note: LocalStack tests cannot run in parallel (they share the same module directory)
func TestS3ModuleLocalStackBasicOperations(t *testing.T) {
	if !IsLocalStack() {
		t.Skip("Skipping LocalStack test - set USE_LOCALSTACK=true to run")
	}

	// Do NOT run in parallel - LocalStack tests share the same module directory

	// Generate lowercase bucket name (S3 requirement)
	bucketName := fmt.Sprintf("test-ops-%s", strings.ToLower(random.UniqueId()))

	vars := map[string]interface{}{
		"bucket_name":            bucketName,
		"retention_days":         365,
		"object_lock_mode":       "GOVERNANCE",
		"auditledger_role_arns":  []string{GetTestRoleArn()},
		"enable_lifecycle_rules": false, // Disable for LocalStack (can hang)
		"tags": map[string]string{
			"Test": "LocalStackOps",
		},
	}

	terraformOptions := GetAWSConfig(t, "../../modules/auditledger-s3", vars)

	// Copy LocalStack provider override into module directory (with unique name)
	overridePath := copyLocalStackOverride(t, terraformOptions.TerraformDir)
	defer removeLocalStackOverride(overridePath)
	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validate outputs exist
	bucketArn := terraform.Output(t, terraformOptions, "bucket_arn")
	assert.Contains(t, bucketArn, bucketName)

	domainName := terraform.Output(t, terraformOptions, "bucket_domain_name")
	assert.Contains(t, domainName, bucketName)

	policyArn := terraform.Output(t, terraformOptions, "iam_policy_arn")
	assert.NotEmpty(t, policyArn)
}
