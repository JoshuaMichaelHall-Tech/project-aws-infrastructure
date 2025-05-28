# Production Environment Main Configuration
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
  #   key            = "prod/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "financial-infra-terraform-locks"
  #   encrypt        = true
  # }
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
  ha_nat_gateway     = true # Enable HA NAT Gateway for production
}

# Security Module with enhanced settings for production
module "security" {
  source = "../../modules/security"

  environment = "prod"
  vpc_id      = module.networking.vpc_id
  vpc_cidr    = module.networking.vpc_cidr
}

# Compute Module for production environment
module "compute" {
  source = "../../modules/compute"

  environment          = "prod"
  vpc_id               = module.networking.vpc_id
  private_subnet_ids   = module.networking.private_subnet_ids
  public_subnet_ids    = module.networking.public_subnet_ids
  db_security_group_id = module.security.restricted_security_group_id
  ami_id               = "ami-0c02fb55956c7d316" # Amazon Linux 2 AMI (placeholder)
  db_port              = 5432
  certificate_arn      = "arn:aws:acm:us-east-1:123456789012:certificate/placeholder" # Placeholder
  lb_logs_bucket       = "prod-lb-logs-${var.account_id}"
  region               = var.aws_region
  account_id           = var.account_id
  min_size             = 2
  max_size             = 10
  desired_capacity     = 3
  instance_type        = "t3.large"
}

# Database Module for production environment with Multi-AZ
module "database" {
  source = "../../modules/database"

  environment             = "prod"
  vpc_id                  = module.networking.vpc_id
  db_subnet_ids           = module.networking.private_subnet_ids
  app_security_group_id   = module.security.private_security_group_id
  db_name                 = "proddb"
  db_username             = "dbadmin" # Placeholder - use AWS Secrets Manager in production
  db_password             = "changeme123!" # Placeholder - use AWS Secrets Manager in production
  sns_topic_arn           = aws_sns_topic.alerts.arn
  multi_az                = true
  backup_retention_period = 30
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"
  db_instance_class       = "db.r5.xlarge"
}

# Monitoring Module with enhanced alerting
module "monitoring" {
  source = "../../modules/monitoring"

  environment       = "prod"
  vpc_id            = module.networking.vpc_id
  region            = var.aws_region
  account_id        = var.account_id
  asg_name          = "prod-app-asg"                      # TODO: Replace with actual ASG name from compute module
  db_instance_id    = "prod-rds-instance"                 # TODO: Replace with actual RDS instance ID from database module
  lb_arn_suffix     = "app/prod-alb/1234567890abcdef"     # TODO: Replace with actual ALB ARN suffix from compute module
  cloudtrail_bucket = "prod-cloudtrail-${var.account_id}"
  config_bucket     = "prod-config-${var.account_id}"
  alert_emails      = []                                   # TODO: Add production alert email addresses
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
  value       = module.database.db_instance_endpoint
  sensitive   = true
}

output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = module.compute.lb_dns_name
}