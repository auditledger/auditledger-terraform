package test

import (
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

// GetAWSConfig returns Terraform options configured for either LocalStack or real AWS
func GetAWSConfig(t *testing.T, terraformDir string, vars map[string]interface{}) *terraform.Options {
	useLocalStack := os.Getenv("USE_LOCALSTACK") == "true"
	awsRegion := os.Getenv("AWS_DEFAULT_REGION")
	if awsRegion == "" {
		awsRegion = "us-east-1"
	}

	envVars := map[string]string{
		"AWS_DEFAULT_REGION": awsRegion,
	}

	// For LocalStack, we need to copy the override file into the module directory
	if useLocalStack {
		// Note: LocalStack provider configuration is handled by copying
		// tests/localstack_override.tf into the module directory before testing
		envVars["USE_LOCALSTACK"] = "true"
	}

	return &terraform.Options{
		TerraformDir:    terraformDir,
		TerraformBinary: "terraform",
		Vars:            vars,
		EnvVars:         envVars,
	}
}

// GetAzureConfig returns Terraform options configured for real Azure
// Note: Azurite local testing not supported - azurerm provider requires real Azure AD
func GetAzureConfig(t *testing.T, terraformDir string, vars map[string]interface{}) *terraform.Options {
	return &terraform.Options{
		TerraformDir:    terraformDir,
		TerraformBinary: "terraform",
		Vars:            vars,
		EnvVars:         make(map[string]string),
	}
}

// IsLocalStack returns true if tests should run against LocalStack
func IsLocalStack() bool {
	return os.Getenv("USE_LOCALSTACK") == "true"
}

// GetTestRoleArn returns a test role ARN (different for LocalStack vs AWS)
func GetTestRoleArn() string {
	if IsLocalStack() {
		return "arn:aws:iam::000000000000:role/test-role"
	}
	// Real AWS - would need actual role ARN
	return os.Getenv("TEST_ROLE_ARN")
}

// copyLocalStackOverride copies the LocalStack provider override into the module directory
// Uses a unique filename per test to avoid conflicts when running in parallel
func copyLocalStackOverride(t *testing.T, moduleDir string) string {
	if !IsLocalStack() {
		return ""
	}

	overrideSource := "../../tests/localstack_override.tf"
	// Use timestamp + test name to create unique override file
	uniqueOverride := fmt.Sprintf("localstack_override_%d.tf", time.Now().UnixNano())
	overrideDest := moduleDir + "/" + uniqueOverride

	// Read override file
	content, err := os.ReadFile(overrideSource)
	if err != nil {
		t.Logf("Warning: Could not read LocalStack override file: %v", err)
		return ""
	}

	// Write to module directory with unique name
	err = os.WriteFile(overrideDest, content, 0644)
	if err != nil {
		t.Logf("Warning: Could not write LocalStack override file: %v", err)
		return ""
	}

	return overrideDest
}

// removeLocalStackOverride removes the LocalStack provider override from the module directory
func removeLocalStackOverride(overridePath string) {
	if overridePath != "" {
		os.Remove(overridePath) // Ignore errors on cleanup
	}
}
