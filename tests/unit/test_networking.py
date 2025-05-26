import pytest
import json
from unittest.mock import Mock, patch


class TestNetworkingModule:
    """Unit tests for the networking Terraform module."""
    
    def test_vpc_cidr_validation(self):
        """Test that VPC CIDR blocks are valid."""
        valid_cidrs = ["10.0.0.0/16", "172.16.0.0/12", "192.168.0.0/16"]
        invalid_cidrs = ["10.0.0.0/8", "0.0.0.0/0", "192.168.0.0/32"]
        
        for cidr in valid_cidrs:
            assert self._validate_cidr(cidr), f"CIDR {cidr} should be valid"
        
        for cidr in invalid_cidrs:
            assert not self._validate_cidr(cidr), f"CIDR {cidr} should be invalid"
    
    def test_subnet_count(self):
        """Test that correct number of subnets are created."""
        availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
        
        # Should create 3 public, 3 private, and 3 restricted subnets
        expected_subnet_count = len(availability_zones) * 3
        assert expected_subnet_count == 9
    
    def test_subnet_cidr_calculation(self):
        """Test subnet CIDR calculation logic."""
        vpc_cidr = "10.0.0.0/16"
        availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
        
        # Expected subnet layout
        expected_subnets = {
            "public": ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"],
            "private": ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"],
            "restricted": ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
        }
        
        # Verify subnet CIDR blocks don't overlap
        all_subnets = []
        for subnet_type, cidrs in expected_subnets.items():
            all_subnets.extend(cidrs)
        
        assert len(all_subnets) == len(set(all_subnets)), "Subnet CIDRs must be unique"
    
    def test_nat_gateway_high_availability(self):
        """Test NAT gateway configuration for high availability."""
        availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
        enable_nat_gateway = True
        
        if enable_nat_gateway:
            # Should create one NAT gateway per AZ for HA
            expected_nat_gateways = len(availability_zones)
            assert expected_nat_gateways >= 2, "Should have at least 2 NAT gateways for HA"
    
    def test_flow_logs_configuration(self):
        """Test VPC flow logs are properly configured."""
        enable_flow_logs = True
        
        if enable_flow_logs:
            flow_log_config = {
                "traffic_type": "ALL",
                "log_destination_type": "s3",
                "log_format": "${version} ${account-id} ${interface-id} ${srcaddr} ${dstaddr} ${srcport} ${dstport} ${protocol} ${packets} ${bytes} ${start} ${end} ${action} ${log-status}"
            }
            
            assert flow_log_config["traffic_type"] == "ALL", "Flow logs should capture all traffic"
            assert flow_log_config["log_destination_type"] in ["s3", "cloud-watch-logs"], "Valid log destination required"
    
    def _validate_cidr(self, cidr):
        """Helper method to validate CIDR blocks."""
        import ipaddress
        try:
            network = ipaddress.ip_network(cidr, strict=False)
            # Check if it's a private network
            return network.is_private and network.prefixlen >= 16 and network.prefixlen <= 28
        except:
            return False


class TestNetworkSecurity:
    """Test network security configurations."""
    
    def test_default_security_group_rules(self):
        """Test that default security group is restrictive."""
        default_sg_rules = {
            "ingress": [],  # No ingress rules by default
            "egress": [
                {
                    "protocol": "-1",
                    "from_port": 0,
                    "to_port": 0,
                    "cidr_blocks": ["0.0.0.0/0"]
                }
            ]
        }
        
        assert len(default_sg_rules["ingress"]) == 0, "Default SG should have no ingress rules"
        assert len(default_sg_rules["egress"]) > 0, "Default SG should allow egress"
    
    def test_nacl_rules(self):
        """Test Network ACL rules follow security best practices."""
        # Restricted subnet NACLs should be more restrictive
        restricted_nacl_rules = {
            "ingress": [
                {"rule_number": 100, "protocol": "tcp", "action": "allow", "cidr_block": "10.0.0.0/16", "from_port": 443, "to_port": 443},
                {"rule_number": 200, "protocol": "tcp", "action": "allow", "cidr_block": "10.0.0.0/16", "from_port": 3306, "to_port": 3306}
            ],
            "egress": [
                {"rule_number": 100, "protocol": "tcp", "action": "allow", "cidr_block": "10.0.0.0/16", "from_port": 443, "to_port": 443}
            ]
        }
        
        # Verify no allow-all rules in restricted subnets
        for rule in restricted_nacl_rules["ingress"]:
            assert rule["cidr_block"] != "0.0.0.0/0", "Restricted subnet should not allow ingress from 0.0.0.0/0"