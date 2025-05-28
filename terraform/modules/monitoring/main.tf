# Monitoring Module - Creates CloudWatch Dashboards, Alarms, and Security Hub setup

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name         = "${var.environment}-alerts"
  display_name = "${var.environment} Alerts"

  tags = {
    Name        = "${var.environment}-alerts"
    Environment = var.environment
  }
}

# SNS Topic subscription for email alerts
resource "aws_sns_topic_subscription" "email_alerts" {
  count     = length(var.alert_emails)
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_emails[count.index]
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.asg_name]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "EC2 CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.db_instance_id]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "RDS CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.lb_arn_suffix]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "ALB Request Count"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.lb_arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", var.lb_arn_suffix]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "ALB Error Counts"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.db_instance_id]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "RDS Connections"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "NetworkIn", "AutoScalingGroupName", var.asg_name],
            ["AWS/EC2", "NetworkOut", "AutoScalingGroupName", var.asg_name]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "EC2 Network Traffic"
        }
      }
    ]
  })
}

# CloudWatch Alarms
# RDS CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.environment}-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU utilization is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }

  tags = {
    Name        = "${var.environment}-rds-high-cpu"
    Environment = var.environment
  }
}

# RDS Free Storage Space Alarm
resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "${var.environment}-rds-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 10737418240 # 10 GB in bytes
  alarm_description   = "RDS free storage space is too low"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }

  tags = {
    Name        = "${var.environment}-rds-low-storage"
    Environment = var.environment
  }
}

# ALB 5XX Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.environment}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 5
  alarm_description   = "ALB 5XX error rate is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  metric_query {
    id          = "e1"
    expression  = "m2/m1*100"
    label       = "5XX Error Rate"
    return_data = true
  }

  metric_query {
    id = "m1"

    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"

      dimensions = {
        LoadBalancer = var.lb_arn_suffix
      }
    }
  }

  metric_query {
    id = "m2"

    metric {
      metric_name = "HTTPCode_ELB_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"

      dimensions = {
        LoadBalancer = var.lb_arn_suffix
      }
    }
  }

  tags = {
    Name        = "${var.environment}-alb-5xx-errors"
    Environment = var.environment
  }
}

# CloudTrail Setup
resource "aws_cloudtrail" "main" {
  name                          = "${var.environment}-cloudtrail"
  s3_bucket_name                = var.cloudtrail_bucket
  s3_key_prefix                 = "${var.environment}-logs"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.cloudtrail_kms_key.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::${var.cloudtrail_bucket}/"]
    }
  }

  tags = {
    Name        = "${var.environment}-cloudtrail"
    Environment = var.environment
  }
}

# KMS Key for CloudTrail encryption
resource "aws_kms_key" "cloudtrail_kms_key" {
  description             = "KMS key for CloudTrail encryption in ${var.environment}"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudTrail to encrypt logs"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow CloudTrail to describe key"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:DescribeKey",
          "kms:GetKeyPolicy",
          "kms:ListResourceTags"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-cloudtrail-kms-key"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "cloudtrail_kms_alias" {
  name          = "alias/${var.environment}-cloudtrail-key"
  target_key_id = aws_kms_key.cloudtrail_kms_key.key_id
}

# AWS Config Setup
resource "aws_config_configuration_recorder" "main" {
  name     = "${var.environment}-config-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "${var.environment}-config-delivery-channel"
  s3_bucket_name = var.config_bucket
  s3_key_prefix  = "${var.environment}-config"
  sns_topic_arn  = aws_sns_topic.alerts.arn

  snapshot_delivery_properties {
    delivery_frequency = "One_Hour"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

# IAM Role for AWS Config
resource "aws_iam_role" "config_role" {
  name = "${var.environment}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-config-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "config_policy" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# Security Hub
resource "aws_securityhub_account" "main" {}

# Enable Security Hub standards
resource "aws_securityhub_standards_subscription" "cis" {
  standards_arn = "arn:aws:securityhub:${var.region}::standards/cis-aws-foundations-benchmark/v/1.2.0"

  depends_on = [aws_securityhub_account.main]
}

resource "aws_securityhub_standards_subscription" "pci" {
  standards_arn = "arn:aws:securityhub:${var.region}::standards/pci-dss/v/3.2.1"

  depends_on = [aws_securityhub_account.main]
}

# GuardDuty
resource "aws_guardduty_detector" "main" {
  enable = true

  finding_publishing_frequency = "FIFTEEN_MINUTES"

  tags = {
    Name        = "${var.environment}-guardduty"
    Environment = var.environment
  }
}

# Log groups for application logs
resource "aws_cloudwatch_log_group" "application" {
  name              = "/${var.environment}/application"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs_kms_key.arn

  tags = {
    Name        = "${var.environment}-application-logs"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "secure" {
  name              = "/${var.environment}/var/log/secure"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.logs_kms_key.arn

  tags = {
    Name        = "${var.environment}-secure-logs"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "audit" {
  name              = "/${var.environment}/var/log/audit"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.logs_kms_key.arn

  tags = {
    Name        = "${var.environment}-audit-logs"
    Environment = var.environment
  }
}

# KMS Key for CloudWatch Logs encryption
resource "aws_kms_key" "logs_kms_key" {
  description             = "KMS key for CloudWatch Logs encryption in ${var.environment}"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs to encrypt logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-logs-kms-key"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "logs_kms_alias" {
  name          = "alias/${var.environment}-logs-key"
  target_key_id = aws_kms_key.logs_kms_key.key_id
}

# CloudWatch Log Metric Filters and Alarms for Security Monitoring

# Log metric filter for failed login attempts
resource "aws_cloudwatch_log_metric_filter" "failed_logins" {
  name           = "${var.environment}-failed-logins"
  pattern        = "Failed password for * from * port * ssh2"
  log_group_name = aws_cloudwatch_log_group.secure.name

  metric_transformation {
    name      = "FailedLoginAttempts"
    namespace = "${var.environment}/Security"
    value     = "1"
  }
}

# Alarm for excessive failed login attempts
resource "aws_cloudwatch_metric_alarm" "failed_logins" {
  alarm_name          = "${var.environment}-excessive-failed-logins"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FailedLoginAttempts"
  namespace           = "${var.environment}/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Excessive failed login attempts detected"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  tags = {
    Name        = "${var.environment}-excessive-failed-logins"
    Environment = var.environment
  }
}

# Log metric filter for sudo commands
resource "aws_cloudwatch_log_metric_filter" "sudo_commands" {
  name           = "${var.environment}-sudo-commands"
  pattern        = "sudo: * : TTY=* ; PWD=* ; USER=root ; COMMAND=*"
  log_group_name = aws_cloudwatch_log_group.secure.name

  metric_transformation {
    name      = "SudoCommands"
    namespace = "${var.environment}/Security"
    value     = "1"
  }
}

# Log metric filter for changes to security groups
resource "aws_cloudwatch_log_metric_filter" "security_group_changes" {
  name           = "${var.environment}-security-group-changes"
  pattern        = "{ ($.eventName = AuthorizeSecurityGroupIngress) || ($.eventName = AuthorizeSecurityGroupEgress) || ($.eventName = RevokeSecurityGroupIngress) || ($.eventName = RevokeSecurityGroupEgress) || ($.eventName = CreateSecurityGroup) || ($.eventName = DeleteSecurityGroup) }"
  log_group_name = "/aws/cloudtrail" # Assumes CloudTrail logs are sent to CloudWatch

  metric_transformation {
    name      = "SecurityGroupChanges"
    namespace = "${var.environment}/Security"
    value     = "1"
  }
}

# Alarm for security group changes
resource "aws_cloudwatch_metric_alarm" "security_group_changes" {
  alarm_name          = "${var.environment}-security-group-changes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "SecurityGroupChanges"
  namespace           = "${var.environment}/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Security group changes detected"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  tags = {
    Name        = "${var.environment}-security-group-changes"
    Environment = var.environment
  }
}