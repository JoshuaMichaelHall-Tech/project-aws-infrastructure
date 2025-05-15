output "public_security_group_id" {
  description = "ID of the public security group"
  value       = aws_security_group.public.id
}

output "private_security_group_id" {
  description = "ID of the private security group"
  value       = aws_security_group.private.id
}

output "restricted_security_group_id" {
  description = "ID of the restricted security group"
  value       = aws_security_group.restricted.id
}
EOF < /dev/null