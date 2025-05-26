Feature: Security Compliance Requirements
  As a secure infrastructure
  I want to ensure all security controls are properly implemented
  So that we protect against threats and vulnerabilities

  Scenario: Password Policy Compliance
    Given I have IAM password policy configured
    Then minimum password length must be 14 characters
    And passwords must require uppercase letters
    And passwords must require lowercase letters
    And passwords must require numbers
    And passwords must require symbols
    And password reuse must be prevented for 24 passwords
    And passwords must expire within 90 days

  Scenario: Key Management
    Given I have KMS keys configured
    Then all KMS keys must have rotation enabled
    And KMS key policies must restrict access
    And deletion protection must be enabled for production keys
    And key usage must be logged in CloudTrail

  Scenario: Network Security
    Given I have network security controls
    Then default security groups must deny all inbound traffic
    And security group rules must be documented
    And NACLs must provide defense in depth
    And unnecessary ports must be blocked

  Scenario: Vulnerability Management
    Given I have compute resources
    Then instances must use approved AMIs only
    And instances must have Systems Manager agent installed
    And patch baselines must be defined
    And vulnerability scanning must be scheduled

  Scenario: Incident Response
    Given I have incident response procedures
    Then CloudWatch Logs must be centralized
    And incident response runbooks must be defined
    And automated remediation must be configured where possible
    And forensic tools must be available

  Scenario: Access Management
    Given I have access controls configured
    Then service accounts must use IAM roles not keys
    And temporary credentials must be preferred
    And privilege escalation must be prevented
    And administrative access must be logged

  Scenario: Data Loss Prevention
    Given I have data protection controls
    Then S3 bucket policies must prevent data exfiltration
    And VPC endpoints must be used for AWS services
    And outbound traffic must be monitored
    And sensitive data must not be in CloudWatch Logs

  Scenario: Secure Development
    Given I have CI/CD pipelines
    Then infrastructure code must be scanned for vulnerabilities
    And secrets must not be hardcoded
    And dependencies must be scanned
    And security tests must pass before deployment

  Scenario: Compliance Monitoring
    Given I have compliance monitoring configured
    Then AWS Config rules must evaluate continuously
    And non-compliant resources must trigger alerts
    And compliance reports must be generated monthly
    And remediation must be tracked

  Scenario: Third-Party Security
    Given I have third-party integrations
    Then external access must use IAM roles with external ID
    And API keys must be rotated regularly
    And third-party services must be approved
    And data sharing must be encrypted