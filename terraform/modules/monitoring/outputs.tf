output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "cloudtrail_name" {
  description = "Name of the CloudTrail"
  value       = aws_cloudtrail.main.name
}

output "cloudtrail_kms_key_arn" {
  description = "ARN of the KMS key used for CloudTrail encryption"
  value       = aws_kms_key.cloudtrail_kms_key.arn
}

output "logs_kms_key_arn" {
  description = "ARN of the KMS key used for CloudWatch Logs encryption"
  value       = aws_kms_key.logs_kms_key.arn
}

output "config_recorder_id" {
  description = "ID of the AWS Config configuration recorder"
  value       = aws_config_configuration_recorder.main.id
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector"
  value       = aws_guardduty_detector.main.id
}

output "securityhub_enabled" {
  description = "Whether Security Hub is enabled"
  value       = true
}

output "log_groups" {
  description = "Map of CloudWatch Log Groups"
  value = {
    application = aws_cloudwatch_log_group.application.name
    secure      = aws_cloudwatch_log_group.secure.name
    audit       = aws_cloudwatch_log_group.audit.name
  }
}

output "dashboard_name" {
  description = "Name of the CloudWatch Dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}