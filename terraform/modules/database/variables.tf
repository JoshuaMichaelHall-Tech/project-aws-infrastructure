variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the database will be created"
  type        = string
}

variable "db_subnet_ids" {
  description = "List of subnet IDs where the database will be deployed"
  type        = list(string)
}

variable "app_security_group_id" {
  description = "Security group ID of the application tier that will connect to the database"
  type        = string
}

variable "db_name" {
  description = "Name of the database"
  type        = string
}

variable "db_engine" {
  description = "Database engine (mysql, postgres, etc.)"
  type        = string
  default     = "postgres"
}

variable "db_engine_version" {
  description = "Version of the database engine"
  type        = string
  default     = "14.5"
}

variable "db_instance_class" {
  description = "Database instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_username" {
  description = "Database master username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "db_parameter_group_name" {
  description = "Database parameter group name"
  type        = string
  default     = null
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment for high availability"
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Preferred backup window"
  type        = string
  default     = "03:00-05:00" # UTC
}

variable "maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = "sun:06:00-sun:08:00" # UTC
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for database event notifications"
  type        = string
}