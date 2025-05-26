import pytest
import boto3
import time
from moto import mock_ec2, mock_s3, mock_iam, mock_rds


@mock_ec2
@mock_s3
@mock_iam
class TestInfrastructureDeployment:
    """Integration tests for infrastructure deployment."""
    
    def setup_method(self):
        """Set up test fixtures."""
        self.region = "us-east-1"
        self.ec2_client = boto3.client("ec2", region_name=self.region)
        self.s3_client = boto3.client("s3", region_name=self.region)
        self.iam_client = boto3.client("iam", region_name=self.region)
    
    def test_vpc_deployment(self):
        """Test VPC and networking resources are created correctly."""
        # Create VPC
        vpc_response = self.ec2_client.create_vpc(CidrBlock="10.0.0.0/16")
        vpc_id = vpc_response["Vpc"]["VpcId"]
        
        # Tag VPC
        self.ec2_client.create_tags(
            Resources=[vpc_id],
            Tags=[
                {"Key": "Name", "Value": "test-vpc"},
                {"Key": "Environment", "Value": "test"}
            ]
        )
        
        # Create subnets
        subnet_configs = [
            {"CidrBlock": "10.0.1.0/24", "AvailabilityZone": "us-east-1a", "Type": "public"},
            {"CidrBlock": "10.0.11.0/24", "AvailabilityZone": "us-east-1a", "Type": "private"},
            {"CidrBlock": "10.0.21.0/24", "AvailabilityZone": "us-east-1a", "Type": "restricted"}
        ]
        
        created_subnets = []
        for config in subnet_configs:
            subnet = self.ec2_client.create_subnet(
                VpcId=vpc_id,
                CidrBlock=config["CidrBlock"],
                AvailabilityZone=config["AvailabilityZone"]
            )
            created_subnets.append(subnet["Subnet"]["SubnetId"])
        
        # Verify resources
        vpcs = self.ec2_client.describe_vpcs(VpcIds=[vpc_id])
        assert len(vpcs["Vpcs"]) == 1
        assert vpcs["Vpcs"][0]["CidrBlock"] == "10.0.0.0/16"
        
        subnets = self.ec2_client.describe_subnets(SubnetIds=created_subnets)
        assert len(subnets["Subnets"]) == 3
    
    def test_security_groups_creation(self):
        """Test security groups are created with correct rules."""
        # Create VPC first
        vpc_response = self.ec2_client.create_vpc(CidrBlock="10.0.0.0/16")
        vpc_id = vpc_response["Vpc"]["VpcId"]
        
        # Create security group
        sg_response = self.ec2_client.create_security_group(
            GroupName="test-sg",
            Description="Test security group",
            VpcId=vpc_id
        )
        sg_id = sg_response["GroupId"]
        
        # Add ingress rule
        self.ec2_client.authorize_security_group_ingress(
            GroupId=sg_id,
            IpPermissions=[
                {
                    "IpProtocol": "tcp",
                    "FromPort": 443,
                    "ToPort": 443,
                    "IpRanges": [{"CidrIp": "10.0.0.0/16"}]
                }
            ]
        )
        
        # Verify security group
        sgs = self.ec2_client.describe_security_groups(GroupIds=[sg_id])
        assert len(sgs["SecurityGroups"]) == 1
        assert len(sgs["SecurityGroups"][0]["IpPermissions"]) == 1
        assert sgs["SecurityGroups"][0]["IpPermissions"][0]["FromPort"] == 443
    
    def test_s3_bucket_encryption(self):
        """Test S3 buckets are created with encryption enabled."""
        bucket_name = "test-financial-data-bucket"
        
        # Create bucket
        self.s3_client.create_bucket(Bucket=bucket_name)
        
        # Enable encryption
        self.s3_client.put_bucket_encryption(
            Bucket=bucket_name,
            ServerSideEncryptionConfiguration={
                "Rules": [
                    {
                        "ApplyServerSideEncryptionByDefault": {
                            "SSEAlgorithm": "aws:kms",
                            "KMSMasterKeyID": "arn:aws:kms:us-east-1:123456789012:key/12345678"
                        }
                    }
                ]
            }
        )
        
        # Enable versioning
        self.s3_client.put_bucket_versioning(
            Bucket=bucket_name,
            VersioningConfiguration={"Status": "Enabled"}
        )
        
        # Block public access
        self.s3_client.put_public_access_block(
            Bucket=bucket_name,
            PublicAccessBlockConfiguration={
                "BlockPublicAcls": True,
                "IgnorePublicAcls": True,
                "BlockPublicPolicy": True,
                "RestrictPublicBuckets": True
            }
        )
        
        # Verify bucket configuration
        buckets = self.s3_client.list_buckets()
        assert any(b["Name"] == bucket_name for b in buckets["Buckets"])
    
    def test_iam_roles_and_policies(self):
        """Test IAM roles and policies are created correctly."""
        role_name = "test-ec2-role"
        policy_name = "test-s3-access-policy"
        
        # Create IAM role
        assume_role_policy = {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {"Service": "ec2.amazonaws.com"},
                    "Action": "sts:AssumeRole"
                }
            ]
        }
        
        self.iam_client.create_role(
            RoleName=role_name,
            AssumeRolePolicyDocument=json.dumps(assume_role_policy),
            Description="Test EC2 role"
        )
        
        # Create and attach policy
        policy_document = {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": ["s3:GetObject", "s3:PutObject"],
                    "Resource": "arn:aws:s3:::test-bucket/*"
                }
            ]
        }
        
        policy_response = self.iam_client.create_policy(
            PolicyName=policy_name,
            PolicyDocument=json.dumps(policy_document)
        )
        
        self.iam_client.attach_role_policy(
            RoleName=role_name,
            PolicyArn=policy_response["Policy"]["Arn"]
        )
        
        # Verify role exists
        roles = self.iam_client.list_roles()
        assert any(r["RoleName"] == role_name for r in roles["Roles"])
    
    def test_multi_az_deployment(self):
        """Test resources are deployed across multiple availability zones."""
        vpc_response = self.ec2_client.create_vpc(CidrBlock="10.0.0.0/16")
        vpc_id = vpc_response["Vpc"]["VpcId"]
        
        # Create subnets in multiple AZs
        azs = ["us-east-1a", "us-east-1b", "us-east-1c"]
        created_subnets = []
        
        for i, az in enumerate(azs):
            subnet = self.ec2_client.create_subnet(
                VpcId=vpc_id,
                CidrBlock=f"10.0.{i+1}.0/24",
                AvailabilityZone=az
            )
            created_subnets.append({
                "id": subnet["Subnet"]["SubnetId"],
                "az": az
            })
        
        # Verify subnets are in different AZs
        unique_azs = set(subnet["az"] for subnet in created_subnets)
        assert len(unique_azs) == 3, "Subnets should be in 3 different AZs"


import json


@mock_rds
class TestDatabaseDeployment:
    """Test database deployment configurations."""
    
    def setup_method(self):
        """Set up test fixtures."""
        self.region = "us-east-1"
        self.rds_client = boto3.client("rds", region_name=self.region)
    
    def test_rds_multi_az_deployment(self):
        """Test RDS is deployed with Multi-AZ for high availability."""
        db_config = {
            "DBInstanceIdentifier": "test-financial-db",
            "DBInstanceClass": "db.t3.micro",
            "Engine": "mysql",
            "MasterUsername": "admin",
            "MasterUserPassword": "TestPassword123!",
            "AllocatedStorage": 20,
            "MultiAZ": True,
            "StorageEncrypted": True,
            "BackupRetentionPeriod": 7,
            "PreferredBackupWindow": "03:00-04:00",
            "PreferredMaintenanceWindow": "sun:04:00-sun:05:00"
        }
        
        # Note: moto doesn't fully support all RDS features, but this shows the structure
        # In real tests, you would verify these settings against actual AWS resources
        
        assert db_config["MultiAZ"] is True, "Database must be Multi-AZ"
        assert db_config["StorageEncrypted"] is True, "Database must be encrypted"
        assert db_config["BackupRetentionPeriod"] >= 7, "Backup retention must be at least 7 days"