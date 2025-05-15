# Compute Module - Creates secure EC2 instances and ECS services

# Security group for application tier
resource "aws_security_group" "app_security_group" {
  name        = "${var.environment}-app-sg"
  description = "Security group for ${var.environment} application tier"
  vpc_id      = var.vpc_id
  
  # Allow inbound traffic from load balancer
  ingress {
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [var.lb_security_group_id]
    description     = "Allow traffic from load balancer"
  }
  
  # Allow outbound traffic to the database
  egress {
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [var.db_security_group_id]
    description     = "Allow traffic to database"
  }
  
  # Allow outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound internet access for package updates, etc."
  }
  
  tags = {
    Name        = "${var.environment}-app-sg"
    Environment = var.environment
  }
}

# Security group for load balancer
resource "aws_security_group" "lb_security_group" {
  name        = "${var.environment}-lb-sg"
  description = "Security group for ${var.environment} load balancer"
  vpc_id      = var.vpc_id
  
  # Allow inbound HTTPS traffic from internet
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS traffic from internet"
  }
  
  # Allow outbound traffic to application instances
  egress {
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app_security_group.id]
    description     = "Allow traffic to application instances"
  }
  
  tags = {
    Name        = "${var.environment}-lb-sg"
    Environment = var.environment
  }
}

# IAM role for EC2 instances
resource "aws_iam_role" "ec2_role" {
  name = "${var.environment}-ec2-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name        = "${var.environment}-ec2-role"
    Environment = var.environment
  }
}

# IAM instance profile for EC2 instances
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# SSM policy attachment for EC2 management
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# S3 read-only access for application assets
resource "aws_iam_role_policy_attachment" "s3_read_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# CloudWatch logs access
resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# KMS key for EBS volume encryption
resource "aws_kms_key" "ebs_encryption_key" {
  description             = "KMS key for EBS volume encryption in ${var.environment}"
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
        Sid    = "Allow EC2 to use the key"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
  
  tags = {
    Name        = "${var.environment}-ebs-encryption-key"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "ebs_encryption_key_alias" {
  name          = "alias/${var.environment}-ebs-encryption-key"
  target_key_id = aws_kms_key.ebs_encryption_key.key_id
}

# Launch template for EC2 instances
resource "aws_launch_template" "app_launch_template" {
  name                   = "${var.environment}-app-launch-template"
  image_id               = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.app_security_group.id]
  
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }
  
  block_device_mappings {
    device_name = "/dev/xvda"
    
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
      kms_key_id            = aws_kms_key.ebs_encryption_key.arn
    }
  }
  
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2 required
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }
  
  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh", {
    environment = var.environment
    app_port    = var.app_port
    region      = var.region
  }))
  
  tag_specifications {
    resource_type = "instance"
    
    tags = {
      Name        = "${var.environment}-app-instance"
      Environment = var.environment
    }
  }
  
  tags = {
    Name        = "${var.environment}-app-launch-template"
    Environment = var.environment
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app_asg" {
  name                      = "${var.environment}-app-asg"
  max_size                  = var.max_size
  min_size                  = var.min_size
  desired_capacity          = var.desired_capacity
  health_check_grace_period = 300
  health_check_type         = "ELB"
  vpc_zone_identifier       = var.private_subnet_ids
  target_group_arns         = [aws_lb_target_group.app_tg.arn]
  
  launch_template {
    id      = aws_launch_template.app_launch_template.id
    version = "$Latest"
  }
  
  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances"
  ]
  
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 75
    }
  }
  
  tag {
    key                 = "Name"
    value               = "${var.environment}-app-instance"
    propagate_at_launch = true
  }
  
  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

# Application Load Balancer
resource "aws_lb" "app_lb" {
  name               = "${var.environment}-app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_security_group.id]
  subnets            = var.public_subnet_ids
  
  enable_deletion_protection = true
  drop_invalid_header_fields = true
  
  access_logs {
    bucket  = var.lb_logs_bucket
    prefix  = "lb-logs"
    enabled = true
  }
  
  tags = {
    Name        = "${var.environment}-app-lb"
    Environment = var.environment
  }
}

# Target Group
resource "aws_lb_target_group" "app_tg" {
  name     = "${var.environment}-app-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  
  health_check {
    enabled             = true
    interval            = 30
    path                = var.health_check_path
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    matcher             = "200"
  }
  
  tags = {
    Name        = "${var.environment}-app-tg"
    Environment = var.environment
  }
}

# HTTPS Listener with TLS 1.2+
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"  # TLS 1.2 or higher
  certificate_arn   = var.certificate_arn
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# HTTP to HTTPS redirect
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type = "redirect"
    
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Auto Scaling Policies
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.environment}-app-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.environment}-app-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}

# CloudWatch Alarms for Auto Scaling
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.environment}-app-high-cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "Scale up when CPU exceeds 70%"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app_asg.name
  }
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "${var.environment}-app-low-cpu"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "30"
  alarm_description   = "Scale down when CPU is below 30%"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app_asg.name
  }
}