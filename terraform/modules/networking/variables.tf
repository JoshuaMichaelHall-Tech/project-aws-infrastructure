variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
}

variable "ha_nat_gateway" {
  description = "Whether to create a highly available NAT Gateway (one per AZ)"
  type        = bool
  default     = false
}
