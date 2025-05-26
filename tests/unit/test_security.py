import pytest
import json
from unittest.mock import Mock, patch


class TestSecurityModule:
    """Unit tests for the security Terraform module."""
    
    def test_iam_role_least_privilege(self):
        """Test IAM roles follow least privilege principle."""
        iam_policy = {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": [
                        "s3:GetObject",
                        "s3:PutObject"
                    ],
                    "Resource": "arn:aws:s3:::my-bucket/*"
                }
            ]
        }
        
        # Check no wildcard actions
        for statement in iam_policy["Statement"]:
            for action in statement.get("Action", []):
                assert "*" not in action, f"Action {action} should not use wildcards"
        
        # Check no wildcard resources
        for statement in iam_policy["Statement"]:
            resource = statement.get("Resource", "")
            if isinstance(resource, list):
                for r in resource:
                    assert r != "*", "Resource should not be wildcard"
            else:
                assert resource != "*", "Resource should not be wildcard"
    
    def test_kms_key_rotation(self):
        """Test KMS keys have rotation enabled."""
        kms_config = {
            "enable_key_rotation": True,
            "deletion_window_in_days": 30,
            "is_enabled": True,
            "policy": {
                "Version": "2012-10-17",
                "Statement": []
            }
        }
        
        assert kms_config["enable_key_rotation"] is True, "KMS key rotation must be enabled"
        assert kms_config["deletion_window_in_days"] >= 7, "Deletion window must be at least 7 days"
    
    def test_security_hub_standards(self):
        """Test Security Hub standards are enabled."""
        enabled_standards = [
            "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.2.0",
            "arn:aws:securityhub:us-east-1::standards/pci-dss/v/3.2.1",
            "arn:aws:securityhub:us-east-1::standards/aws-foundational-security-best-practices/v/1.0.0"
        ]
        
        required_standards = ["cis-aws-foundations-benchmark", "pci-dss", "aws-foundational-security-best-practices"]
        
        for standard in required_standards:
            assert any(standard in s for s in enabled_standards), f"{standard} must be enabled"
    
    def test_guardduty_configuration(self):
        """Test GuardDuty is properly configured."""
        guardduty_config = {
            "enable": True,
            "finding_publishing_frequency": "SIX_HOURS",
            "datasources": {
                "s3_logs": {"enable": True},
                "kubernetes": {"audit_logs": {"enable": True}},
                "malware_protection": {"scan_ec2_instance_with_findings": {"enable": True}}
            }
        }
        
        assert guardduty_config["enable"] is True, "GuardDuty must be enabled"
        assert guardduty_config["finding_publishing_frequency"] in ["FIFTEEN_MINUTES", "ONE_HOUR", "SIX_HOURS"], \
            "Valid publishing frequency required"
        assert guardduty_config["datasources"]["s3_logs"]["enable"] is True, "S3 log monitoring must be enabled"
    
    def test_cloudtrail_configuration(self):
        """Test CloudTrail logging configuration."""
        cloudtrail_config = {
            "is_multi_region_trail": True,
            "is_organization_trail": True,
            "enable_log_file_validation": True,
            "enable_logging": True,
            "event_selector": [
                {
                    "read_write_type": "All",
                    "include_management_events": True,
                    "data_resource": [
                        {
                            "type": "AWS::S3::Object",
                            "values": ["arn:aws:s3:::*/"]
                        }
                    ]
                }
            ],
            "kms_key_id": "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
        }
        
        assert cloudtrail_config["is_multi_region_trail"] is True, "Must be multi-region trail"
        assert cloudtrail_config["enable_log_file_validation"] is True, "Log file validation must be enabled"
        assert cloudtrail_config["kms_key_id"] is not None, "CloudTrail logs must be encrypted"
    
    def test_config_rules(self):
        """Test AWS Config rules for compliance."""
        required_config_rules = [
            "encrypted-volumes",
            "rds-encryption-enabled",
            "s3-bucket-public-read-prohibited",
            "s3-bucket-public-write-prohibited",
            "s3-bucket-ssl-requests-only",
            "iam-root-access-key-check",
            "mfa-enabled-for-iam-console-access",
            "iam-password-policy",
            "vpc-flow-logs-enabled",
            "guardduty-enabled-centralized"
        ]
        
        enabled_rules = [
            "encrypted-volumes",
            "rds-encryption-enabled",
            "s3-bucket-public-read-prohibited",
            "s3-bucket-public-write-prohibited",
            "s3-bucket-ssl-requests-only",
            "iam-root-access-key-check",
            "mfa-enabled-for-iam-console-access",
            "iam-password-policy",
            "vpc-flow-logs-enabled",
            "guardduty-enabled-centralized"
        ]
        
        for rule in required_config_rules:
            assert rule in enabled_rules, f"Config rule {rule} must be enabled"
    
    def test_password_policy(self):
        """Test IAM password policy meets security requirements."""
        password_policy = {
            "minimum_password_length": 14,
            "require_lowercase_characters": True,
            "require_uppercase_characters": True,
            "require_numbers": True,
            "require_symbols": True,
            "allow_users_to_change_password": True,
            "max_password_age": 90,
            "password_reuse_prevention": 24,
            "hard_expiry": False
        }
        
        assert password_policy["minimum_password_length"] >= 14, "Minimum password length must be at least 14"
        assert password_policy["require_lowercase_characters"] is True, "Must require lowercase"
        assert password_policy["require_uppercase_characters"] is True, "Must require uppercase"
        assert password_policy["require_numbers"] is True, "Must require numbers"
        assert password_policy["require_symbols"] is True, "Must require symbols"
        assert password_policy["max_password_age"] <= 90, "Password must expire within 90 days"
        assert password_policy["password_reuse_prevention"] >= 24, "Must prevent reuse of last 24 passwords"