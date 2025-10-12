package smoke

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestS3ModuleSmoke is a fast smoke test that validates basic module functionality
// This should run quickly in LocalStack on every PR
func TestS3ModuleSmoke(t *testing.T) {
	t.Parallel()

	bucketName := fmt.Sprintf("smoke-test-%s", random.UniqueId())
	testRoleArn := "arn:aws:iam::000000000000:role/test-role"

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/auditledger-s3",
		Vars: map[string]interface{}{
			"bucket_name":           bucketName,
			"retention_days":        365, // Minimum
			"object_lock_mode":      "GOVERNANCE",
			"auditledger_role_arns": []string{testRoleArn},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": "us-east-1",
		},
	}

	// Just validate we can plan successfully
	terraform.Init(t, terraformOptions)
	planOutput := terraform.Plan(t, terraformOptions)

	// Basic assertions on plan
	assert.Contains(t, planOutput, "aws_s3_bucket.audit_logs")
	assert.Contains(t, planOutput, "object_lock_enabled")
	assert.Contains(t, planOutput, "aws_s3_bucket_object_lock_configuration")
}

// TestS3ModuleMinimumVariables ensures module works with minimal configuration
func TestS3ModuleMinimumVariables(t *testing.T) {
	t.Parallel()

	testRoleArn := "arn:aws:iam::000000000000:role/test-role"

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/auditledger-s3",
		Vars: map[string]interface{}{
			"bucket_name":           "minimum-config-test",
			"auditledger_role_arns": []string{testRoleArn},
			// retention_days and object_lock_mode use defaults
		},
	}

	terraform.Init(t, terraformOptions)
	planOutput := terraform.Plan(t, terraformOptions)

	// Should use defaults
	assert.Contains(t, planOutput, "2555")       // Default retention
	assert.Contains(t, planOutput, "COMPLIANCE") // Default mode
}

// TestS3ModuleRequiredVariables ensures required variables are enforced
func TestS3ModuleRequiredVariables(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/auditledger-s3",
		Vars: map[string]interface{}{
			"bucket_name": "test-bucket",
			// Missing auditledger_role_arns - should fail
		},
	}

	_, err := terraform.InitAndPlanE(t, terraformOptions)
	assert.Error(t, err)
	// Note: Can't easily test error message without actual init
}
