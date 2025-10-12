package smoke

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// createTestProviderOverride creates a provider override for plan-only smoke tests
func createTestProviderOverride(t *testing.T, terraformDir string) {
	overrideContent := `
provider "aws" {
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}
`
	overridePath := filepath.Join(terraformDir, "test_override.tf")
	err := os.WriteFile(overridePath, []byte(overrideContent), 0644)
	if err != nil {
		t.Fatalf("Failed to create provider override: %v", err)
	}

	// Clean up after test
	t.Cleanup(func() {
		os.Remove(overridePath)
	})
}

// cleanTerraformState removes stale Terraform state and cache files
func cleanTerraformState(t *testing.T, terraformDir string) {
	// Remove .terraform directory
	terraformCache := filepath.Join(terraformDir, ".terraform")
	os.RemoveAll(terraformCache)

	// Remove state files
	os.Remove(filepath.Join(terraformDir, "terraform.tfstate"))
	os.Remove(filepath.Join(terraformDir, "terraform.tfstate.backup"))
	os.Remove(filepath.Join(terraformDir, ".terraform.lock.hcl"))
}

// TestS3ModuleSmoke is a fast smoke test that validates basic module functionality
// This should run quickly in LocalStack on every PR
func TestS3ModuleSmoke(t *testing.T) {
	// Note: Don't run in parallel - all smoke tests share the same module directory

	terraformDir := "../../modules/auditledger-s3"
	cleanTerraformState(t, terraformDir)
	createTestProviderOverride(t, terraformDir)

	bucketName := fmt.Sprintf("smoke-test-%s", strings.ToLower(random.UniqueId()))
	testRoleArn := "arn:aws:iam::000000000000:role/test-role"

	terraformOptions := &terraform.Options{
		TerraformDir:    terraformDir,
		TerraformBinary: "terraform",
		Vars: map[string]interface{}{
			"bucket_name":           bucketName,
			"retention_days":        365, // Minimum
			"object_lock_mode":      "GOVERNANCE",
			"auditledger_role_arns": []string{testRoleArn},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION":    "us-east-1",
			"AWS_ACCESS_KEY_ID":     "test",
			"AWS_SECRET_ACCESS_KEY": "test",
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
	// Note: Don't run in parallel - all smoke tests share the same module directory

	terraformDir := "../../modules/auditledger-s3"
	cleanTerraformState(t, terraformDir)
	createTestProviderOverride(t, terraformDir)

	testRoleArn := "arn:aws:iam::000000000000:role/test-role"

	terraformOptions := &terraform.Options{
		TerraformDir:    terraformDir,
		TerraformBinary: "terraform",
		Vars: map[string]interface{}{
			"bucket_name":           "minimum-config-test",
			"auditledger_role_arns": []string{testRoleArn},
			// retention_days and object_lock_mode use defaults
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION":    "us-east-1",
			"AWS_ACCESS_KEY_ID":     "test",
			"AWS_SECRET_ACCESS_KEY": "test",
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
	// Note: Don't run in parallel - all smoke tests share the same module directory

	terraformDir := "../../modules/auditledger-s3"
	cleanTerraformState(t, terraformDir)
	createTestProviderOverride(t, terraformDir)

	terraformOptions := &terraform.Options{
		TerraformDir:    terraformDir,
		TerraformBinary: "terraform",
		Vars: map[string]interface{}{
			"bucket_name": "test-bucket",
			// Missing auditledger_role_arns - should fail
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION":    "us-east-1",
			"AWS_ACCESS_KEY_ID":     "test",
			"AWS_SECRET_ACCESS_KEY": "test",
		},
	}

	_, err := terraform.InitAndPlanE(t, terraformOptions)
	assert.Error(t, err)
	// Note: Can't easily test error message without actual init
}
