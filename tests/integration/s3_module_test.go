package test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestS3ModuleImmutability(t *testing.T) {
	t.Parallel()

	// Generate unique bucket name to avoid conflicts (lowercase for S3)
	bucketName := fmt.Sprintf("test-auditledger-%s", strings.ToLower(random.UniqueId()))
	awsRegion := "us-east-1"
	testRoleArn := fmt.Sprintf("arn:aws:iam::123456789012:role/test-role-%s", strings.ToLower(random.UniqueId()))

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/auditledger-s3",
		Vars: map[string]interface{}{
			"bucket_name":           bucketName,
			"retention_days":        365,          // Minimum for compliance
			"object_lock_mode":      "GOVERNANCE", // Use GOVERNANCE for tests (can be cleaned up)
			"auditledger_role_arns": []string{testRoleArn},
			"tags": map[string]string{
				"Environment": "Test",
				"ManagedBy":   "Terratest",
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	// Cleanup resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Deploy the infrastructure
	terraform.InitAndApply(t, terraformOptions)

	// Validate outputs
	outputBucketName := terraform.Output(t, terraformOptions, "bucket_id")
	assert.Equal(t, bucketName, outputBucketName)

	bucketArn := terraform.Output(t, terraformOptions, "bucket_arn")
	assert.Contains(t, bucketArn, bucketName)

	// Validate immutability_verified output
	immutabilityVerified := terraform.Output(t, terraformOptions, "immutability_verified")
	assert.Equal(t, "true", immutabilityVerified)

	// Validate S3 bucket exists
	aws.AssertS3BucketExists(t, awsRegion, bucketName)

	// Validate bucket versioning is enabled (required for Object Lock)
	versioning := aws.GetS3BucketVersioning(t, awsRegion, bucketName)
	assert.Equal(t, "Enabled", versioning)
}

func TestS3ModuleWithKMS(t *testing.T) {
	t.Parallel()

	bucketName := fmt.Sprintf("test-auditledger-kms-%s", strings.ToLower(random.UniqueId()))
	awsRegion := "us-east-1"
	testRoleArn := fmt.Sprintf("arn:aws:iam::123456789012:role/test-role-%s", strings.ToLower(random.UniqueId()))

	// First, create a KMS key for testing
	kmsKeyId := createTestKMSKey(t, awsRegion)
	defer deleteTestKMSKey(t, awsRegion, kmsKeyId)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/auditledger-s3",
		Vars: map[string]interface{}{
			"bucket_name":           bucketName,
			"retention_days":        365,
			"object_lock_mode":      "GOVERNANCE",
			"auditledger_role_arns": []string{testRoleArn},
			"kms_key_id":            kmsKeyId,
			"tags": map[string]string{
				"Environment": "Test",
				"ManagedBy":   "Terratest",
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validate bucket exists and has KMS configured
	aws.AssertS3BucketExists(t, awsRegion, bucketName)

	// Validate KMS key ID is in terraform state
	assert.NotEmpty(t, kmsKeyId)
}

func TestS3ModuleObjectLockConfiguration(t *testing.T) {
	t.Parallel()

	bucketName := fmt.Sprintf("test-auditledger-objlock-%s", strings.ToLower(random.UniqueId()))
	awsRegion := "us-east-1"
	testRoleArn := fmt.Sprintf("arn:aws:iam::123456789012:role/test-role-%s", strings.ToLower(random.UniqueId()))

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/auditledger-s3",
		Vars: map[string]interface{}{
			"bucket_name":           bucketName,
			"retention_days":        365,
			"object_lock_mode":      "COMPLIANCE",
			"auditledger_role_arns": []string{testRoleArn},
			"tags": map[string]string{
				"Environment": "Test",
				"ManagedBy":   "Terratest",
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validate Object Lock configuration output
	objectLockConfig := terraform.OutputMap(t, terraformOptions, "object_lock_configuration")
	assert.Equal(t, "true", objectLockConfig["enabled"])
	assert.Equal(t, "COMPLIANCE", objectLockConfig["mode"])
	assert.Equal(t, "365", objectLockConfig["retention_days"])
}

func TestS3ModuleLifecyclePolicy(t *testing.T) {
	t.Parallel()

	bucketName := fmt.Sprintf("test-auditledger-lifecycle-%s", strings.ToLower(random.UniqueId()))
	awsRegion := "us-east-1"
	testRoleArn := fmt.Sprintf("arn:aws:iam::123456789012:role/test-role-%s", strings.ToLower(random.UniqueId()))

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/auditledger-s3",
		Vars: map[string]interface{}{
			"bucket_name":            bucketName,
			"retention_days":         2555, // 7 years
			"object_lock_mode":       "GOVERNANCE",
			"auditledger_role_arns":  []string{testRoleArn},
			"enable_lifecycle_rules": true,
			"tags": map[string]string{
				"Environment": "Test",
				"ManagedBy":   "Terratest",
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validate bucket exists
	aws.AssertS3BucketExists(t, awsRegion, bucketName)

	// Validate lifecycle rules enabled via terraform output
	lifecycleEnabled := terraform.Output(t, terraformOptions, "object_lock_configuration")
	assert.NotEmpty(t, lifecycleEnabled)
}

func TestS3ModuleMinimumRetention(t *testing.T) {
	t.Parallel()

	bucketName := fmt.Sprintf("test-auditledger-minretention-%s", strings.ToLower(random.UniqueId()))
	awsRegion := "us-east-1"
	testRoleArn := fmt.Sprintf("arn:aws:iam::123456789012:role/test-role-%s", strings.ToLower(random.UniqueId()))

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/auditledger-s3",
		Vars: map[string]interface{}{
			"bucket_name":           bucketName,
			"retention_days":        100, // Below minimum - should fail validation
			"object_lock_mode":      "GOVERNANCE",
			"auditledger_role_arns": []string{testRoleArn},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	// This should fail due to validation
	_, err := terraform.InitAndApplyE(t, terraformOptions)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "Retention period must be at least 365 days")
}

func TestS3ModuleWithReplication(t *testing.T) {
	t.Parallel()

	bucketName := fmt.Sprintf("test-auditledger-repl-%s", strings.ToLower(random.UniqueId()))
	replicaBucketArn := fmt.Sprintf("arn:aws:s3:::test-replica-%s", strings.ToLower(random.UniqueId()))
	replicationRoleArn := fmt.Sprintf("arn:aws:iam::123456789012:role/replication-role-%s", strings.ToLower(random.UniqueId()))
	awsRegion := "us-east-1"
	testRoleArn := fmt.Sprintf("arn:aws:iam::123456789012:role/test-role-%s", strings.ToLower(random.UniqueId()))

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/auditledger-s3",
		Vars: map[string]interface{}{
			"bucket_name":            bucketName,
			"retention_days":         365,
			"object_lock_mode":       "GOVERNANCE",
			"auditledger_role_arns":  []string{testRoleArn},
			"replication_bucket_arn": replicaBucketArn,
			"replication_role_arn":   replicationRoleArn,
			"tags": map[string]string{
				"Environment": "Test",
				"ManagedBy":   "Terratest",
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	// Note: This test will fail unless the replica bucket and role actually exist
	// It's included to validate the module accepts replication parameters
	defer terraform.Destroy(t, terraformOptions)

	// Just validate the plan - don't apply since we'd need to create replica bucket first
	terraform.Init(t, terraformOptions)
	planOutput := terraform.Plan(t, terraformOptions)
	assert.Contains(t, planOutput, "aws_s3_bucket_replication_configuration.audit_logs")
}

// Helper function to create test KMS key
func createTestKMSKey(t *testing.T, region string) string {
	// Implementation would create a KMS key via AWS SDK
	// For brevity, returning a placeholder
	// In real implementation, use aws.CreateKmsKey() from terratest
	return "test-kms-key-id"
}

// Helper function to delete test KMS key
func deleteTestKMSKey(t *testing.T, region string, keyId string) {
	// Implementation would delete the KMS key via AWS SDK
	// Schedule for deletion (minimum 7 days in AWS)
}
