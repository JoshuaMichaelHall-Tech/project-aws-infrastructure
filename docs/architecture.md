# AWS Infrastructure Architecture

## Overview

This document outlines the high-level architecture of the secure AWS infrastructure for financial services applications. The architecture follows a multi-account strategy with defense-in-depth security controls and implements regulatory compliance requirements for financial services.

## Multi-Account Structure

The infrastructure is deployed across multiple AWS accounts to create strong security boundaries:

1. **Management Account** - Central account for AWS Organizations, access management, and logging
2. **Security Account** - Dedicated account for security services like GuardDuty, Security Hub, and Config
3. **Log Archive Account** - Centralized logging account for all audit logs
4. **Shared Services Account** - Common infrastructure services (CI/CD, monitoring, etc.)
5. **Development Account** - Development environment
6. **Testing Account** - Testing/staging environment
7. **Production Account** - Production environment

## Network Architecture

Each environment (dev, test, prod) follows a secure network design:

```
                                  │
                                  ▼
                        ┌───────────────────┐
                        │  Internet Gateway │
                        └───────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────┐
│ Public Subnets                                              │
│                                                             │
│ ┌───────────────┐   ┌───────────────┐   ┌───────────────┐   │
│ │ Load Balancer │   │ Load Balancer │   │     Bastion   │   │
│ │      (AZ1)    │   │      (AZ2)    │   │     Host      │   │
│ └───────────────┘   └───────────────┘   └───────────────┘   │
│           │                 │                  │             │
└───────────┼─────────────────┼──────────────────┼─────────────┘
            │                 │                  │
            ▼                 ▼                  ▼
┌───────────────────────────────────────────────────────────────┐
│ Private Subnets                                                │
│                                                                │
│ ┌───────────────┐   ┌───────────────┐   ┌───────────────┐      │
│ │  Application  │   │  Application  │   │     Lambda    │      │
│ │  Servers(AZ1) │   │  Servers(AZ2) │   │    Functions  │      │
│ └───────────────┘   └───────────────┘   └───────────────┘      │
│           │                 │                  │                │
└───────────┼─────────────────┼──────────────────┼────────────────┘
            │                 │                  │
            ▼                 ▼                  ▼
┌───────────────────────────────────────────────────────────────┐
│ Restricted Subnets                                             │
│                                                                │
│ ┌───────────────┐   ┌───────────────┐   ┌───────────────┐      │
│ │   Database    │   │   Database    │   │     Cache     │      │
│ │   Primary     │   │   Replica     │   │    Cluster    │      │
│ └───────────────┘   └───────────────┘   └───────────────┘      │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

## Terraform Implementation

The infrastructure is implemented using Terraform with the following modular structure:

### Module Organization

- **Networking Module**: Sets up VPC, subnets, route tables, NAT gateways, and network ACLs
- **Security Module**: Implements security groups, IAM roles/policies, and KMS keys
- **Database Module**: Creates RDS instances with encryption, monitoring, and high availability
- **Compute Module**: Deploys EC2 instances, auto-scaling groups, and load balancers
- **Monitoring Module**: Sets up CloudWatch dashboards, alarms, and integrations with Security Hub

### Environment-Specific Configurations

Each environment (dev, staging, prod) has its own configuration which calls these modules with specific parameters:

```
terraform/
├── environments/
│   ├── dev/
│   │   ├── main.tf          # Calls modules with dev-specific parameters
│   │   ├── variables.tf     # Environment-specific variables
│   │   └── outputs.tf       # Environment-specific outputs
│   ├── staging/
│   └── prod/                # Higher resource allocations and stricter security
└── modules/
    ├── networking/          # VPC, subnets, routing
    ├── security/            # IAM, Security Groups, GuardDuty
    ├── compute/             # EC2, ECS, Lambda
    ├── database/            # RDS, DynamoDB
    └── monitoring/          # CloudWatch, AWS Config
```

### Security Features Implemented in Terraform

1. **Network Level**:
   - Defense-in-depth with three subnet tiers (public, private, restricted)
   - Network ACLs for subnet-level security
   - Security groups for instance-level security
   - VPC Flow Logs for network traffic monitoring

2. **Compute Level**:
   - Hardened AMIs with minimal attack surface
   - Instance metadata service v2 (IMDSv2) enforcement
   - User data scripts with security monitoring setup
   - Systems Manager Session Manager for secure shell access without SSH ports

3. **Database Level**:
   - Multi-AZ deployments for high availability
   - Automated backups and snapshots
   - Encryption at rest with KMS keys
   - Performance Insights for monitoring
   - Enhanced monitoring for detailed metrics

4. **Monitoring & Logging**:
   - CloudTrail for API activity tracking
   - CloudWatch Logs for centralized logging
   - AWS Config for compliance monitoring
   - GuardDuty for threat detection
   - Security Hub for comprehensive security view
   - Custom metric filters and alarms for security events

## Security Controls

The infrastructure implements several layers of security controls:

- **Network Security**: VPC isolation, security groups, NACLs, private subnets, and encryption in transit
- **Identity & Access Management**: IAM roles with least privilege, service control policies, and MFA
- **Data Protection**: Encryption at rest for all data stores, KMS for key management
- **Logging & Monitoring**: Centralized logging, CloudTrail, CloudWatch, and GuardDuty
- **Compliance**: AWS Config rules for continuous compliance monitoring

## Regulatory Compliance

The infrastructure is designed to meet the requirements of key financial regulations:

### PCI-DSS Compliance

- Network segmentation with restricted access controls
- Encryption of cardholder data in transit and at rest
- Strong access control measures with least privilege
- Monitoring and logging of all access to network resources and cardholder data
- Regular testing of security systems and processes

### SOC 2 Compliance

- Security, availability, and confidentiality controls
- Monitoring of unusual or unauthorized activities
- Logical and physical access controls
- System operations monitoring
- Change management processes

### GDPR Compliance

- Data encryption and pseudonymization
- Regular security testing and assessments
- Data backup and disaster recovery capabilities
- Process for regularly testing security measures
- Data minimization and purpose limitation

## Disaster Recovery

The infrastructure supports various disaster recovery strategies:

- **Backup & Restore**: Regular snapshots of all critical data stores
- **Pilot Light**: Minimal version of the environment running in a secondary region
- **Warm Standby**: Scaled-down but fully functional environment in a secondary region
- **Multi-Region**: Full active-active deployment across multiple regions (for critical workloads)

## Continuous Integration & Deployment

Infrastructure is deployed and managed using:

- **Infrastructure as Code**: Terraform for all infrastructure resources
- **CI/CD Pipeline**: Automated testing, validation, and deployment of infrastructure changes
- **Security Scanning**: Static analysis of infrastructure code for security best practices

## Deployment Process

The infrastructure is deployed using the provided setup script with the following workflow:

1. **Initialization**:
   - State storage setup in S3 with DynamoDB locking
   - Configuration validation and environment preparation

2. **Deployment Sequence**:
   - Base networking components 
   - Security groups and IAM roles
   - Database and storage resources
   - Application and compute resources
   - Monitoring and logging components

3. **Validation**:
   - Automated testing of deployed resources
   - Security scanning of the environment
   - Compliance checks against regulatory requirements

## Future Enhancements

Planned enhancements to the architecture include:

- **Transit Gateway**: For simplified connectivity between VPCs and on-premises networks
- **PrivateLink**: For secure access to AWS services without traversing the public internet
- **WAF & Shield**: For enhanced protection of public-facing applications
- **AWS Control Tower**: For streamlined multi-account management
- **AWS Firewall Manager**: For centralized management of security rules
- **AWS Network Firewall**: For enhanced network security filtering
- **AWS IAM Identity Center**: For simplified access management
- **AWS Secrets Manager**: For enhanced secrets rotation and management