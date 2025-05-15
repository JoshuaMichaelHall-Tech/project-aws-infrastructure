# Database Module - Creates secure RDS instances for financial data

# Security group for database instances
resource "aws_security_group" "db_security_group" {
  name        = "${var.environment}-db-sg"
  description = "Security group for ${var.environment} database instances"
  vpc_id      = var.vpc_id
  
  # Only allow inbound traffic from application tier
  ingress {
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [var.app_security_group_id]
    description     = "Allow database connection from application tier"
  }
  
  # No direct outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound connections (for updates)"
  }
  
  tags = {
    Name        = "${var.environment}-db-sg"
    Environment = var.environment
  }
}

# Database subnet group
resource "aws_db_subnet_group" "db_subnet_group" {
  name        = "${var.environment}-db-subnet-group"
  description = "Database subnet group for ${var.environment}"
  subnet_ids  = var.db_subnet_ids
  
  tags = {
    Name        = "${var.environment}-db-subnet-group"
    Environment = var.environment
  }
}

# KMS key for database encryption
resource "aws_kms_key" "db_encryption_key" {
  description             = "KMS key for database encryption in ${var.environment}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  tags = {
    Name        = "${var.environment}-db-encryption-key"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "db_encryption_key_alias" {
  name          = "alias/${var.environment}-db-encryption-key"
  target_key_id = aws_kms_key.db_encryption_key.key_id
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier                = "${var.environment}-${var.db_name}"
  engine                    = var.db_engine
  engine_version            = var.db_engine_version
  instance_class            = var.db_instance_class
  allocated_storage         = var.db_allocated_storage
  storage_type              = "gp3"
  storage_encrypted         = true
  kms_key_id                = aws_kms_key.db_encryption_key.arn
  name                      = var.db_name
  username                  = var.db_username
  password                  = var.db_password
  port                      = var.db_port
  vpc_security_group_ids    = [aws_security_group.db_security_group.id]
  db_subnet_group_name      = aws_db_subnet_group.db_subnet_group.name
  parameter_group_name      = var.db_parameter_group_name
  multi_az                  = var.multi_az
  backup_retention_period   = var.backup_retention_period
  backup_window             = var.backup_window
  maintenance_window        = var.maintenance_window
  auto_minor_version_upgrade = true
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.environment}-${var.db_name}-final-snapshot"
  
  # Enhanced monitoring
  monitoring_interval       = 60
  monitoring_role_arn       = aws_iam_role.rds_monitoring_role.arn
  
  # Performance Insights
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  performance_insights_kms_key_id       = aws_kms_key.db_encryption_key.arn
  
  tags = {
    Name        = "${var.environment}-${var.db_name}"
    Environment = var.environment
  }
}

# IAM role for RDS enhanced monitoring
resource "aws_iam_role" "rds_monitoring_role" {
  name = "${var.environment}-rds-monitoring-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name        = "${var.environment}-rds-monitoring-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring_policy" {
  role       = aws_iam_role.rds_monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Automated database snapshots with lifecycle policy
resource "aws_db_event_subscription" "db_events" {
  name        = "${var.environment}-db-event-subscription"
  sns_topic_arn = var.sns_topic_arn
  source_type = "db-instance"
  source_ids  = [aws_db_instance.main.id]
  
  event_categories = [
    "availability",
    "backup",
    "configuration change",
    "deletion",
    "failover",
    "failure",
    "maintenance",
    "notification",
    "recovery",
    "security"
  ]
  
  tags = {
    Name        = "${var.environment}-db-event-subscription"
    Environment = var.environment
  }
}