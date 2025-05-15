variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
  sensitive   = true
}

variable "alert_emails" {
  description = "List of email addresses to receive alerts"
  type        = list(string)
  default     = []
}

variable "asg_name" {
  description = "Name of the Auto Scaling Group for the application"
  type        = string
}

variable "db_instance_id" {
  description = "ID of the RDS instance"
  type        = string
}

variable "lb_arn_suffix" {
  description = "ARN suffix of the load balancer (used for CloudWatch metrics)"
  type        = string
}

variable "cloudtrail_bucket" {
  description = "S3 bucket for CloudTrail logs"
  type        = string
}

variable "config_bucket" {
  description = "S3 bucket for AWS Config logs"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where resources are deployed"
  type        = string
}

variable "vpc_flow_logs_enabled" {
  description = "Whether to enable VPC Flow Logs"
  type        = bool
  default     = true
}