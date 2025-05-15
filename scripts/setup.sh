#\!/bin/bash
# Setup script for the AWS Infrastructure project

set -e

# Check for required tools
check_requirements() {
  echo "Checking requirements..."
  
  if \! command -v aws &> /dev/null; then
    echo "AWS CLI not found. Please install it: https://aws.amazon.com/cli/"
    exit 1
  fi
  
  if \! command -v terraform &> /dev/null; then
    echo "Terraform not found. Please install it: https://www.terraform.io/downloads.html"
    exit 1
  }
  
  if \! aws sts get-caller-identity &> /dev/null; then
    echo "AWS credentials not configured. Please run 'aws configure'"
    exit 1
  }
  
  echo "All requirements satisfied\!"
}

# Initialize the development environment
initialize_dev_environment() {
  echo "Initializing development environment..."
  
  # Create example tfvars file if it doesn't exist
  if [ \! -f terraform/environments/dev/terraform.tfvars ]; then
    cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars
    echo "Created terraform.tfvars from example. Please update it with your values."
  fi
  
  # Initialize Terraform
  cd terraform/environments/dev
  terraform init
  
  echo "Development environment initialized\!"
}

# Create required S3 bucket for state (in a real project, this would be a different script)
create_state_bucket() {
  echo "NOTE: In a real project, state bucket creation would be in a separate bootstrap process."
  echo "For demonstration, we're skipping the actual state bucket creation."
}

# Main function
main() {
  echo "Setting up AWS Infrastructure project..."
  
  check_requirements
  create_state_bucket
  initialize_dev_environment
  
  echo "Setup complete\! Next steps:"
  echo "1. Update terraform/environments/dev/terraform.tfvars with your values"
  echo "2. Run 'terraform plan' to see what will be created"
  echo "3. Run 'terraform apply' to create the infrastructure"
}

# Run the main function
main
EOF < /dev/null