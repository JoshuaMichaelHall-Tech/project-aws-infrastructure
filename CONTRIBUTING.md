# Contributing to Financial Infrastructure as Code

Thank you for your interest in contributing to this project! This document provides guidelines and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to abide by our Code of Conduct, which promotes a respectful and inclusive environment for all contributors.

## How to Contribute

### Reporting Issues

1. Check existing issues to avoid duplicates
2. Use issue templates when available
3. Provide detailed information:
   - Environment details
   - Steps to reproduce
   - Expected vs actual behavior
   - Error messages and logs

### Submitting Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature-name`)
3. Make your changes following our coding standards
4. Write or update tests as needed
5. Update documentation
6. Commit with clear, descriptive messages
7. Push to your fork
8. Submit a pull request

### Pull Request Process

1. Ensure all tests pass
2. Update README.md if needed
3. Add entries to CHANGELOG.md
4. Request review from maintainers
5. Address review feedback
6. Squash commits if requested

## Development Guidelines

### Terraform Code Standards

- Use Terraform 1.0+ syntax
- Follow official Terraform style conventions
- Organize code into reusable modules
- Use meaningful variable and resource names
- Add descriptions to all variables
- Pin provider and module versions

### Directory Structure

```
terraform/
├── environments/   # Environment-specific configurations
├── modules/       # Reusable Terraform modules
└── tests/         # Test files
```

### Testing Requirements

1. **Unit Tests**: Test individual modules
2. **Integration Tests**: Test module interactions
3. **Compliance Tests**: Verify security policies
4. **Cost Tests**: Estimate infrastructure costs

### Documentation

- Document all modules with README files
- Include examples for module usage
- Update architecture diagrams
- Document security considerations

### Security Guidelines

1. Never commit sensitive data
2. Use AWS Secrets Manager for secrets
3. Follow least privilege principle
4. Enable encryption everywhere
5. Regular security scanning

### Git Commit Messages

Format: `<type>(<scope>): <subject>`

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Formatting changes
- `refactor`: Code restructuring
- `test`: Test additions/changes
- `chore`: Maintenance tasks

Example: `feat(networking): add VPC peering module`

## Testing Locally

### Prerequisites

- Terraform >= 1.0
- AWS CLI configured
- Python 3.8+
- pytest
- tfsec
- checkov

### Running Tests

```bash
# Format check
terraform fmt -check -recursive

# Validate Terraform
cd terraform/environments/dev
terraform init
terraform validate

# Security scanning
tfsec terraform/
checkov -d terraform/

# Run Python tests
pytest tests/

# Cost estimation
infracost breakdown --path terraform/environments/dev
```

## Review Process

1. Automated checks must pass
2. Security scan must pass
3. At least one maintainer approval required
4. Changes must be tested in dev environment

## Release Process

1. Merge to main branch
2. Tag release with semantic versioning
3. Update CHANGELOG.md
4. Deploy to staging environment
5. After validation, deploy to production

## Getting Help

- Review existing documentation
- Check closed issues and PRs
- Ask in discussions
- Contact maintainers

## Recognition

Contributors will be recognized in:
- CONTRIBUTORS.md file
- Release notes
- Project documentation

Thank you for contributing to secure financial infrastructure!