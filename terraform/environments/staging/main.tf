# Staging Environment Main Configuration
terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  # This will be uncommented when setting up remote state
  # backend "s3" {
  #   bucket         = "financial-infra-terraform-state"
  #   key            = "staging/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "financial-infra-terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  # Enable this for production
  # assume_role {
  #   role_arn = "arn:aws:iam::${var.account_id}:role/TerraformExecutionRole"
  # }

  default_tags {
    tags = {
      Environment = "staging"
      Project     = "financial-infrastructure"
      ManagedBy   = "terraform"
    }
  }
}

# VPC and Network Configuration
module "networking" {
  source = "../../modules/networking"

  environment        = "staging"
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  # Additional parameters will go here
}

# Security Module
module "security" {
  source = "../../modules/security"

  environment = "staging"
  vpc_id      = module.networking.vpc_id
  vpc_cidr    = module.networking.vpc_cidr
  # Additional parameters will go here
}

# Compute Module for staging environment
module "compute" {
  source = "../../modules/compute"

  environment          = "staging"
  vpc_id               = module.networking.vpc_id
  private_subnet_ids   = module.networking.private_subnet_ids
  public_subnet_ids    = module.networking.public_subnet_ids
  db_security_group_id = module.security.restricted_security_group_id
  ami_id               = "ami-0c02fb55956c7d316" # Amazon Linux 2 AMI (placeholder)
  db_port              = 5432
  certificate_arn      = "arn:aws:acm:us-east-1:123456789012:certificate/placeholder" # Placeholder
  lb_logs_bucket       = "staging-lb-logs-${var.account_id}"
  region               = var.aws_region
  account_id           = var.account_id
}

# Database Module for staging environment
module "database" {
  source = "../../modules/database"

  environment           = "staging"
  vpc_id                = module.networking.vpc_id
  db_subnet_ids         = module.networking.private_subnet_ids
  app_security_group_id = module.security.private_security_group_id
  db_name               = "stagingdb"
  db_username           = "dbadmin" # Placeholder - use AWS Secrets Manager in production
  db_password           = "changeme123!" # Placeholder - use AWS Secrets Manager in production
  sns_topic_arn         = "arn:aws:sns:us-east-1:123456789012:staging-alerts" # Placeholder
}

# Monitoring Module
module "monitoring" {
  source = "../../modules/monitoring"

  environment       = "staging"
  vpc_id            = module.networking.vpc_id
  region            = var.aws_region
  account_id        = var.account_id
  asg_name          = "staging-app-asg"                    # TODO: Replace with actual ASG name from compute module
  db_instance_id    = "staging-rds-instance"               # TODO: Replace with actual RDS instance ID from database module
  lb_arn_suffix     = "app/staging-alb/1234567890abcdef"   # TODO: Replace with actual ALB ARN suffix from compute module
  cloudtrail_bucket = "staging-cloudtrail-${var.account_id}"
  config_bucket     = "staging-config-${var.account_id}"
  alert_emails      = []                                   # TODO: Add alert email addresses
}

# Output important information
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.networking.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.networking.public_subnet_ids
}