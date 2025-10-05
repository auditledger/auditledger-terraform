package test

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestS3ModuleBasic(t *testing.T) {
	t.Parallel()

	// Generate unique bucket name to avoid conflicts
	bucketName := fmt.Sprintf("test-auditledger-%s", random.UniqueId())
	awsRegion := "us-east-1"

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/auditledger-s3",
		Vars: map[string]interface{}{
			"bucket_name":       bucketName,
			"enable_versioning": true,
			"retention_days":    365,
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
	outputBucketName := terraform.Output(t, terraformOptions, "bucket_name")
	assert.Equal(t, bucketName, outputBucketName)

	bucketArn := terraform.Output(t, terraformOptions, "bucket_arn")
	assert.Contains(t, bucketArn, bucketName)

	// Validate S3 bucket exists
	aws.AssertS3BucketExists(t, awsRegion, bucketName)

	// Validate bucket versioning is enabled
	versioning := aws.GetS3BucketVersioning(t, awsRegion, bucketName)
	assert.Equal(t, "Enabled", versioning)

	// Validate server-side encryption
	encryption := aws.GetS3BucketEncryption(t, awsRegion, bucketName)
	assert.NotNil(t, encryption)
	assert.Equal(t, "AES256", encryption.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm)

	// Validate public access block
	publicAccess := aws.GetS3BucketPublicAccessBlock(t, awsRegion, bucketName)
	assert.True(t, publicAccess.BlockPublicAcls)
	assert.True(t, publicAccess.BlockPublicPolicy)
	assert.True(t, publicAccess.IgnorePublicAcls)
	assert.True(t, publicAccess.RestrictPublicBuckets)
}

func TestS3ModuleWithKMS(t *testing.T) {
	t.Parallel()

	bucketName := fmt.Sprintf("test-auditledger-kms-%s", random.UniqueId())
	awsRegion := "us-east-1"

	// First, create a KMS key for testing
	kmsKeyId := createTestKMSKey(t, awsRegion)
	defer deleteTestKMSKey(t, awsRegion, kmsKeyId)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/auditledger-s3",
		Vars: map[string]interface{}{
			"bucket_name":       bucketName,
			"enable_versioning": true,
			"kms_key_id":        kmsKeyId,
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

	// Validate KMS encryption
	encryption := aws.GetS3BucketEncryption(t, awsRegion, bucketName)
	assert.NotNil(t, encryption)
	assert.Equal(t, "aws:kms", encryption.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm)
	assert.Contains(t, encryption.Rules[0].ApplyServerSideEncryptionByDefault.KMSMasterKeyID, kmsKeyId)
}

func TestS3ModuleIAMRole(t *testing.T) {
	t.Parallel()

	bucketName := fmt.Sprintf("test-auditledger-iam-%s", random.UniqueId())
	roleName := fmt.Sprintf("test-auditledger-role-%s", random.UniqueId())
	awsRegion := "us-east-1"

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/auditledger-s3",
		Vars: map[string]interface{}{
			"bucket_name":     bucketName,
			"create_iam_role": true,
			"iam_role_name":   roleName,
			"iam_role_trust_policy": `{
				"Version": "2012-10-17",
				"Statement": [{
					"Effect": "Allow",
					"Principal": {"Service": "ecs-tasks.amazonaws.com"},
					"Action": "sts:AssumeRole"
				}]
			}`,
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

	// Validate IAM role outputs
	iamRoleArn := terraform.Output(t, terraformOptions, "iam_role_arn")
	assert.Contains(t, iamRoleArn, roleName)

	iamPolicyArn := terraform.Output(t, terraformOptions, "iam_policy_arn")
	assert.NotEmpty(t, iamPolicyArn)

	// Validate IAM policy is attached to role
	attachedPolicies := aws.GetIamRoleAttachedPolicies(t, roleName)
	assert.Contains(t, attachedPolicies, iamPolicyArn)
}

func TestS3ModuleLifecyclePolicy(t *testing.T) {
	t.Parallel()

	bucketName := fmt.Sprintf("test-auditledger-lifecycle-%s", random.UniqueId())
	awsRegion := "us-east-1"

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/auditledger-s3",
		Vars: map[string]interface{}{
			"bucket_name":                bucketName,
			"transition_to_ia_days":      90,
			"transition_to_glacier_days": 180,
			"retention_days":             365,
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

	// Validate lifecycle policy exists
	lifecycleRules := aws.GetS3BucketLifecycleConfiguration(t, awsRegion, bucketName)
	assert.NotNil(t, lifecycleRules)
	assert.GreaterOrEqual(t, len(lifecycleRules.Rules), 1)

	// Validate transitions
	rule := lifecycleRules.Rules[0]
	assert.Equal(t, "Enabled", rule.Status)
	assert.GreaterOrEqual(t, len(rule.Transitions), 2)
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
