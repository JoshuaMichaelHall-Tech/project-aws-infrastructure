#!/bin/bash
# Setup script for the AWS Infrastructure project

set -e

# Default values
ENVIRONMENT="dev"
REGION="us-east-1"
ACTION="plan"
VERBOSE=false

# Function to display script usage
usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -e, --environment   Set environment (dev, staging, prod) (default: dev)"
  echo "  -r, --region        Set AWS region (default: us-east-1)"
  echo "  -a, --action        Action to perform (plan, apply, destroy) (default: plan)"
  echo "  -v, --verbose       Enable verbose mode"
  echo "  -h, --help          Show this help message"
  exit 1
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -e|--environment) ENVIRONMENT="$2"; shift ;;
    -r|--region) REGION="$2"; shift ;;
    -a|--action) ACTION="$2"; shift ;;
    -v|--verbose) VERBOSE=true ;;
    -h|--help) usage ;;
    *) echo "Unknown parameter: $1"; usage ;;
  esac
  shift
done

# Validate environment argument
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Error: Environment must be one of: dev, staging, prod"
  exit 1
fi

# Validate action argument
if [[ ! "$ACTION" =~ ^(plan|apply|destroy)$ ]]; then
  echo "Error: Action must be one of: plan, apply, destroy"
  exit 1
fi

# Enable verbose mode if selected
if [[ "$VERBOSE" == true ]]; then
  set -x
fi

# Check for required tools
check_requirements() {
  echo "Checking requirements..."
  
  if ! command -v aws &> /dev/null; then
    echo "AWS CLI not found. Please install it: https://aws.amazon.com/cli/"
    exit 1
  fi
  
  if ! command -v terraform &> /dev/null; then
    echo "Terraform not found. Please install it: https://www.terraform.io/downloads.html"
    exit 1
  fi
  
  if ! aws sts get-caller-identity &> /dev/null; then
    echo "AWS credentials not configured. Please run 'aws configure'"
    exit 1
  fi
  
  echo "All requirements satisfied!"
}

# Base directory
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "Working from directory: $BASE_DIR"

# Environment directory within Terraform
ENV_DIR="$BASE_DIR/terraform/environments/$ENVIRONMENT"

if [ ! -d "$ENV_DIR" ]; then
  echo "Error: Environment directory does not exist: $ENV_DIR"
  exit 1
fi

# Create S3 bucket for Terraform state if it doesn't exist
create_state_bucket() {
  STATE_BUCKET="financial-infra-terraform-state-$ENVIRONMENT"
  echo "Checking if Terraform state bucket exists: $STATE_BUCKET"

  bucket_exists=$(aws s3api head-bucket --bucket "$STATE_BUCKET" 2>&1 || echo "not_exists")
  if [[ $bucket_exists == *"not_exists"* ]]; then
    echo "Creating S3 bucket for Terraform state: $STATE_BUCKET"
    aws s3api create-bucket \
      --bucket "$STATE_BUCKET" \
      --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION" \
      --acl private

    # Enable encryption
    aws s3api put-bucket-encryption \
      --bucket "$STATE_BUCKET" \
      --server-side-encryption-configuration '{
        "Rules": [
          {
            "ApplyServerSideEncryptionByDefault": {
              "SSEAlgorithm": "AES256"
            }
          }
        ]
      }'

    # Enable versioning
    aws s3api put-bucket-versioning \
      --bucket "$STATE_BUCKET" \
      --versioning-configuration Status=Enabled

    # Block public access
    aws s3api put-public-access-block \
      --bucket "$STATE_BUCKET" \
      --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

    echo "Terraform state bucket created and configured."
  else
    echo "Terraform state bucket already exists."
  fi

  # Create DynamoDB table for state locking if it doesn't exist
  LOCK_TABLE="financial-infra-terraform-locks-$ENVIRONMENT"
  echo "Checking if DynamoDB lock table exists: $LOCK_TABLE"

  table_exists=$(aws dynamodb describe-table --table-name "$LOCK_TABLE" 2>&1 || echo "not_exists")
  if [[ $table_exists == *"not_exists"* ]]; then
    echo "Creating DynamoDB table for Terraform state locking: $LOCK_TABLE"
    aws dynamodb create-table \
      --table-name "$LOCK_TABLE" \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST \
      --region "$REGION"

    # Wait for table to be created
    aws dynamodb wait table-exists --table-name "$LOCK_TABLE" --region "$REGION"
    echo "DynamoDB lock table created."
  else
    echo "DynamoDB lock table already exists."
  fi
}

# Initialize the environment
initialize_environment() {
  echo "Initializing $ENVIRONMENT environment..."
  
  # Create example tfvars file if it doesn't exist
  if [ ! -f "$ENV_DIR/terraform.tfvars" ]; then
    cp "$ENV_DIR/terraform.tfvars.example" "$ENV_DIR/terraform.tfvars"
    
    # Get AWS account ID
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
    
    # Update the account_id in terraform.tfvars
    sed -i'.bak' -e "s/^account_id[[:space:]]*=.*/account_id = \"$AWS_ACCOUNT_ID\"/g" "$ENV_DIR/terraform.tfvars"
    
    # Remove backup file
    rm -f "$ENV_DIR/terraform.tfvars.bak"
    
    echo "Created terraform.tfvars from example and updated account ID."
  fi
  
  # Uncomment the backend configuration in main.tf if it's commented out
  backend_commented=$(grep -c "^[[:space:]]*# backend \"s3\"" "$ENV_DIR/main.tf" || echo "0")
  if [ "$backend_commented" -gt 0 ]; then
    echo "Uncommenting S3 backend configuration in main.tf..."
    sed -i'.bak' -e 's/^[[:space:]]*# \(backend "s3" {\)/\1/g' \
      -e 's/^[[:space:]]*#[[:space:]]*\([^#].*\)/  \1/g' \
      -e "s/financial-infra-terraform-state/financial-infra-terraform-state-$ENVIRONMENT/g" \
      -e "s/financial-infra-terraform-locks/financial-infra-terraform-locks-$ENVIRONMENT/g" \
      -e "s/region = \"us-east-1\"/region = \"$REGION\"/g" \
      "$ENV_DIR/main.tf"
    
    # Remove backup file
    rm -f "$ENV_DIR/main.tf.bak"
    
    echo "Backend configuration updated."
  fi
  
  # Initialize Terraform
  cd "$ENV_DIR"
  echo "Initializing Terraform..."
  terraform init
  
  echo "$ENVIRONMENT environment initialized!"
}

# Run Terraform operation
run_terraform() {
  cd "$ENV_DIR"
  
  case "$ACTION" in
    plan)
      echo "Planning Terraform changes..."
      terraform plan -out=tfplan
      ;;
    apply)
      echo "Applying Terraform changes..."
      # Check if tfplan exists, if not create it
      if [ ! -f tfplan ]; then
        terraform plan -out=tfplan
      fi
      terraform apply tfplan
      ;;
    destroy)
      echo "WARNING: This will destroy all resources in the $ENVIRONMENT environment!"
      read -p "Are you sure you want to continue? (y/n) " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Running Terraform destroy..."
        terraform destroy -auto-approve
      else
        echo "Destroy aborted."
        exit 0
      fi
      ;;
  esac
}

# Main function
main() {
  echo "Setting up AWS Infrastructure project for $ENVIRONMENT environment..."
  
  check_requirements
  create_state_bucket
  initialize_environment
  run_terraform
  
  echo "Operation complete!"
  echo "Next steps:"
  if [ "$ACTION" == "plan" ]; then
    echo "1. Review the plan"
    echo "2. Run './setup.sh --environment $ENVIRONMENT --action apply' to apply changes"
  elif [ "$ACTION" == "apply" ]; then
    echo "1. Your infrastructure has been deployed!"
    echo "2. Use './setup.sh --environment $ENVIRONMENT --action destroy' when you want to tear it down"
  fi
}

# Run the main function
main