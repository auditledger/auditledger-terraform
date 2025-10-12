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
		TerraformDir: terraformDir,
		Vars:         vars,
		EnvVars:      envVars,
	}
}

// GetAzureConfig returns Terraform options configured for either Azurite or real Azure
func GetAzureConfig(t *testing.T, terraformDir string, vars map[string]interface{}) *terraform.Options {
	useAzurite := os.Getenv("USE_AZURITE") == "true"

	envVars := make(map[string]string)

	if useAzurite {
		// Configure for Azurite
		envVars["AZURE_STORAGE_CONNECTION_STRING"] = "DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://127.0.0.1:10000/devstoreaccount1;"
	}

	return &terraform.Options{
		TerraformDir: terraformDir,
		Vars:         vars,
		EnvVars:      envVars,
	}
}

// IsLocalStack returns true if tests should run against LocalStack
func IsLocalStack() bool {
	return os.Getenv("USE_LOCALSTACK") == "true"
}

// IsAzurite returns true if tests should run against Azurite
func IsAzurite() bool {
	return os.Getenv("USE_AZURITE") == "true"
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
