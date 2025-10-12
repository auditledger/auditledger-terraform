# AuditLedger Terraform - Development Commands
.PHONY: help install check-links check-all format validate test clean local-up local-down local-test local-shell

help: ## Show this help message
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

install: ## Install pre-commit hooks and dependencies
	@echo "Installing pre-commit hooks..."
	pre-commit install
	@echo "Installing markdown-link-check..."
	npm install -g markdown-link-check
	@echo "✅ Installation complete!"

check-links: ## Check all markdown files for dead links
	@echo "🔗 Checking markdown links..."
	@./scripts/check-links.sh

check-all: ## Run all validation checks (same as CI)
	@echo "🔍 Running all validation checks..."
	@echo "1. Terraform format and validate..."
	terraform fmt -recursive -check=true
	terraform validate
	@echo "2. Security scanning..."
	tfsec .
	@echo "3. Terraform linting..."
	tflint
	@echo "4. Compliance scanning..."
	checkov -d . --config-file .checkov.yaml
	@echo "5. Documentation check..."
	terraform-docs check --config-file .terraform-docs.yml
	@echo "6. Link checking..."
	@./scripts/check-links.sh
	@echo "✅ All checks passed!"

format: ## Format all Terraform files
	@echo "🎨 Formatting Terraform files..."
	terraform fmt -recursive

validate: ## Validate Terraform configuration
	@echo "✅ Validating Terraform configuration..."
	terraform validate

test: ## Run pre-commit hooks on all files
	@echo "🧪 Running pre-commit hooks..."
	pre-commit run --all-files

clean: ## Clean up temporary files
	@echo "🧹 Cleaning up..."
	@rm -rf .terraform/
	@rm -f results.sarif
	@find . -name "*.tfstate*" -delete
	@find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "✅ Cleanup complete!"

local-up: ## Start LocalStack and Azurite for local testing
	@echo "🚀 Starting local testing environment..."
	@./scripts/setup-local-testing.sh

local-down: ## Stop LocalStack and Azurite
	@echo "🛑 Stopping local testing environment..."
	@./scripts/teardown-local-testing.sh

local-test: ## Run integration tests against LocalStack
	@echo "🧪 Running tests against LocalStack..."
	@if [ ! -f .env.localstack ]; then \
		echo "Creating .env.localstack from example..."; \
		cp env.localstack.example .env.localstack; \
	fi
	@./scripts/test-localstack.sh

local-shell: ## Open shell with LocalStack environment loaded
	@echo "🐚 Starting shell with LocalStack environment..."
	@if [ ! -f .env.localstack ]; then \
		cp env.localstack.example .env.localstack; \
		echo "✅ Created .env.localstack"; \
	fi
	@echo "Environment loaded. Run 'exit' to return."
	@bash --rcfile <(echo '. ~/.bashrc 2>/dev/null || true; source .env.localstack; echo "✅ LocalStack environment loaded"')
