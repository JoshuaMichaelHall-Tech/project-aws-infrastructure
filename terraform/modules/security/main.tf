# Security Module - Implements IAM, Security Groups, and other security controls

# Default Security Group for VPC
resource "aws_default_security_group" "default" {
  vpc_id = var.vpc_id

  # Disable all inbound and outbound traffic for the default security group
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  tags = {
    Name        = "${var.environment}-default-sg"
    Environment = var.environment
  }
}

# Security Group for public-facing resources (like load balancers)
resource "aws_security_group" "public" {
  name        = "${var.environment}-public-sg"
  description = "Security group for public-facing resources"
  vpc_id      = var.vpc_id

  # Allow HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic"
  }

  # Allow HTTPS from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS traffic"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.environment}-public-sg"
    Environment = var.environment
  }
}

# Security Group for private resources (like application servers)
resource "aws_security_group" "private" {
  name        = "${var.environment}-private-sg"
  description = "Security group for private resources"
  vpc_id      = var.vpc_id

  # Allow all traffic from within the VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow all traffic from within the VPC"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.environment}-private-sg"
    Environment = var.environment
  }
}

# Security Group for restricted resources (like databases)
resource "aws_security_group" "restricted" {
  name        = "${var.environment}-restricted-sg"
  description = "Security group for restricted resources"
  vpc_id      = var.vpc_id

  # Allow database traffic only from private subnets
  ingress {
    from_port       = 5432  # PostgreSQL
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.private.id]
    description     = "Allow PostgreSQL traffic from private security group"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.environment}-restricted-sg"
    Environment = var.environment
  }
}

# In a real implementation, you would also set up:
# - IAM roles and policies
# - AWS Config rules for compliance
# - GuardDuty for threat detection
# - CloudTrail for audit logging
# - AWS Secrets Manager for secrets management
# - KMS for encryption
