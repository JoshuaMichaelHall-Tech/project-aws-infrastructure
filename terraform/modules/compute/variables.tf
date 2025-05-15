variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the resources will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the application tier"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the load balancer"
  type        = list(string)
}

variable "db_security_group_id" {
  description = "Security group ID of the database tier"
  type        = string
}

variable "lb_security_group_id" {
  description = "Security group ID of the load balancer, if created separately"
  type        = string
  default     = ""
}

variable "ami_id" {
  description = "AMI ID for the application instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "SSH key name to use for the instances"
  type        = string
  default     = null
}

variable "app_port" {
  description = "Port on which the application listens"
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "Port on which the database listens"
  type        = number
}

variable "health_check_path" {
  description = "Path for health checks"
  type        = string
  default     = "/health"
}

variable "min_size" {
  description = "Minimum number of instances in the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances in the Auto Scaling Group"
  type        = number
  default     = 10
}

variable "desired_capacity" {
  description = "Desired number of instances in the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS"
  type        = string
}

variable "lb_logs_bucket" {
  description = "S3 bucket for load balancer logs"
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