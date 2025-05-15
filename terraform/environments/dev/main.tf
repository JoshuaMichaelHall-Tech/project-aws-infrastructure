# Dev Environment Main Configuration
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
  #   key            = "dev/terraform.tfstate"
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
      Environment = "dev"
      Project     = "financial-infrastructure"
      ManagedBy   = "terraform"
    }
  }
}

# VPC and Network Configuration
module "networking" {
  source = "../../modules/networking"
  
  environment       = "dev"
  vpc_cidr          = var.vpc_cidr
  availability_zones = var.availability_zones
  # Additional parameters will go here
}

# Security Module
module "security" {
  source = "../../modules/security"
  
  environment = "dev"
  vpc_id      = module.networking.vpc_id
  # Additional parameters will go here
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
EOF < /dev/null