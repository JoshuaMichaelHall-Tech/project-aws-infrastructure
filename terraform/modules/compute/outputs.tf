output "app_security_group_id" {
  description = "ID of the application security group"
  value       = aws_security_group.app_security_group.id
}

output "lb_security_group_id" {
  description = "ID of the load balancer security group"
  value       = aws_security_group.lb_security_group.id
}

output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.app_launch_template.id
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.app_asg.name
}

output "asg_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.app_asg.arn
}

output "lb_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.app_lb.arn
}

output "lb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.app_lb.dns_name
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.app_tg.arn
}

output "ec2_role_name" {
  description = "Name of the IAM role for EC2 instances"
  value       = aws_iam_role.ec2_role.name
}

output "ec2_role_arn" {
  description = "ARN of the IAM role for EC2 instances"
  value       = aws_iam_role.ec2_role.arn
}

output "ebs_kms_key_arn" {
  description = "ARN of the KMS key for EBS volume encryption"
  value       = aws_kms_key.ebs_encryption_key.arn
}