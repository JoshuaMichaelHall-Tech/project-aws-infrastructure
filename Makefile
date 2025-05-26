.PHONY: help init validate plan apply destroy fmt lint test clean

# Default environment
ENV ?= dev

# Terraform directories
TF_DIR = terraform/environments/$(ENV)
MODULES_DIR = terraform/modules

help: ## Show this help message
	@echo 'Usage: make [target] ENV=<environment>'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ''
	@echo 'Environments: dev, staging, prod'

init: ## Initialize Terraform
	@echo "Initializing Terraform for $(ENV) environment..."
	@cd $(TF_DIR) && terraform init

validate: ## Validate Terraform configuration
	@echo "Validating Terraform configuration..."
	@cd $(TF_DIR) && terraform validate
	@echo "Validating modules..."
	@for module in $(MODULES_DIR)/*; do \
		echo "Validating $$module..."; \
		cd $$module && terraform init -backend=false && terraform validate; \
	done

plan: ## Create Terraform plan
	@echo "Creating Terraform plan for $(ENV) environment..."
	@cd $(TF_DIR) && terraform plan -out=tfplan

apply: ## Apply Terraform changes
	@echo "Applying Terraform changes for $(ENV) environment..."
	@cd $(TF_DIR) && terraform apply tfplan

destroy: ## Destroy Terraform infrastructure
	@echo "WARNING: This will destroy all resources in $(ENV) environment!"
	@echo "Press Ctrl+C to cancel, or Enter to continue."
	@read confirm
	@cd $(TF_DIR) && terraform destroy

fmt: ## Format Terraform files
	@echo "Formatting Terraform files..."
	@terraform fmt -recursive terraform/

lint: ## Run linting tools
	@echo "Running Terraform format check..."
	@terraform fmt -check -recursive terraform/
	@echo "Running tfsec..."
	@tfsec terraform/
	@echo "Running checkov..."
	@checkov -d terraform/

test: ## Run all tests
	@echo "Running unit tests..."
	@pytest tests/unit/ -v
	@echo "Running integration tests..."
	@pytest tests/integration/ -v
	@echo "Running compliance tests..."
	@terraform-compliance -f tests/compliance/ -p $(TF_DIR)/

test-unit: ## Run unit tests only
	@pytest tests/unit/ -v

test-integration: ## Run integration tests only
	@pytest tests/integration/ -v

test-compliance: ## Run compliance tests only
	@terraform-compliance -f tests/compliance/ -p $(TF_DIR)/

security-scan: ## Run security scans
	@echo "Running tfsec..."
	@tfsec terraform/
	@echo "Running checkov..."
	@checkov -d terraform/

cost: ## Estimate infrastructure costs
	@echo "Estimating costs for $(ENV) environment..."
	@infracost breakdown --path $(TF_DIR)

clean: ## Clean up temporary files
	@echo "Cleaning up..."
	@find . -type f -name "*.tfplan" -delete
	@find . -type f -name "*.tfstate*" -delete
	@find . -type f -name ".terraform.lock.hcl" -delete
	@find . -type d -name ".terraform" -exec rm -rf {} +
	@find . -type d -name "__pycache__" -exec rm -rf {} +
	@find . -type d -name ".pytest_cache" -exec rm -rf {} +

docs: ## Generate documentation
	@echo "Generating documentation..."
	@terraform-docs markdown table --output-file README.md $(TF_DIR)
	@for module in $(MODULES_DIR)/*; do \
		terraform-docs markdown table --output-file $$module/README.md $$module; \
	done

pre-commit: fmt lint test ## Run pre-commit checks
	@echo "All pre-commit checks passed!"

setup: ## Setup development environment
	@echo "Setting up development environment..."
	@pip install -r requirements.txt
	@pre-commit install
	@echo "Development environment ready!"

.DEFAULT_GOAL := help