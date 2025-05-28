# Production Environment Main Configuration
terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "financial-infra-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "financial-infra-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${var.account_id}:role/TerraformExecutionRole"
  }

  default_tags {
    tags = {
      Environment = "prod"
      Project     = "financial-infrastructure"
      ManagedBy   = "terraform"
      Compliance  = "PCI-DSS,SOC2"
    }
  }
}

# Secondary provider for DR region
provider "aws" {
  alias  = "dr"
  region = var.dr_region

  assume_role {
    role_arn = "arn:aws:iam::${var.account_id}:role/TerraformExecutionRole"
  }

  default_tags {
    tags = {
      Environment = "prod-dr"
      Project     = "financial-infrastructure"
      ManagedBy   = "terraform"
      Compliance  = "PCI-DSS,SOC2"
    }
  }
}

# VPC and Network Configuration
module "networking" {
  source = "../../modules/networking"

  environment        = "prod"
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  enable_flow_logs   = true
  enable_nat_gateway = true
  enable_vpn_gateway = true
}

# Security Module with enhanced settings for production
module "security" {
  source = "../../modules/security"

  environment         = "prod"
  vpc_id              = module.networking.vpc_id
  vpc_cidr            = module.networking.vpc_cidr
  enable_guardduty    = true
  enable_security_hub = true
  enable_config       = true
  enable_cloudtrail   = true
  enable_inspector    = true
  enable_macie        = true
}

# Compute Module for production environment
module "compute" {
  source = "../../modules/compute"

  environment         = "prod"
  vpc_id              = module.networking.vpc_id
  private_subnet_ids  = module.networking.private_subnet_ids
  min_size            = 2
  max_size            = 10
  desired_capacity    = 3
  instance_type       = "t3.large"
  enable_auto_scaling = true
}

# Database Module for production environment with Multi-AZ
module "database" {
  source = "../../modules/database"

  environment                = "prod"
  vpc_id                     = module.networking.vpc_id
  private_subnet_ids         = module.networking.private_subnet_ids
  multi_az                   = true
  backup_retention_period    = 30
  backup_window              = "03:00-04:00"
  maintenance_window         = "sun:04:00-sun:05:00"
  enable_encryption          = true
  enable_deletion_protection = true
  instance_class             = "db.r5.xlarge"
}

# Monitoring Module with enhanced alerting
module "monitoring" {
  source = "../../modules/monitoring"

  environment                = "prod"
  vpc_id                     = module.networking.vpc_id
  enable_detailed_monitoring = true
  enable_enhanced_monitoring = true
  alarm_sns_topic_arns       = [aws_sns_topic.alerts.arn]
  log_retention_days         = 365
}

# SNS Topic for production alerts
resource "aws_sns_topic" "alerts" {
  name              = "financial-infra-prod-alerts"
  kms_master_key_id = "alias/aws/sns"
}

# Output important information
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
  sensitive   = true
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.networking.private_subnet_ids
  sensitive   = true
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.networking.public_subnet_ids
  sensitive   = true
}

output "database_endpoint" {
  description = "RDS instance endpoint"
  value       = module.database.endpoint
  sensitive   = true
}

output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = module.compute.load_balancer_dns
}