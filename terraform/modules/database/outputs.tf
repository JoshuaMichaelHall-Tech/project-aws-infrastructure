output "db_instance_id" {
  description = "ID of the RDS instance"
  value       = aws_db_instance.main.id
}

output "db_instance_address" {
  description = "Address of the RDS instance"
  value       = aws_db_instance.main.address
}

output "db_instance_endpoint" {
  description = "Connection endpoint of the RDS instance"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.main.arn
}

output "db_security_group_id" {
  description = "ID of the database security group"
  value       = aws_security_group.db_security_group.id
}

output "db_subnet_group_id" {
  description = "ID of the database subnet group"
  value       = aws_db_subnet_group.db_subnet_group.id
}

output "db_kms_key_arn" {
  description = "ARN of the KMS key used for database encryption"
  value       = aws_kms_key.db_encryption_key.arn
}