# Networking Module - Creates a secure VPC with public, private, and restricted subnets

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.environment}-public-subnet-${count.index + 1}"
    Environment = var.environment
    Tier        = "public"
  }
}

# Private Subnets (for application tier)
resource "aws_subnet" "private" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + length(var.availability_zones))
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.environment}-private-subnet-${count.index + 1}"
    Environment = var.environment
    Tier        = "private"
  }
}

# Restricted Subnets (for database tier)
resource "aws_subnet" "restricted" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 2 * length(var.availability_zones))
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.environment}-restricted-subnet-${count.index + 1}"
    Environment = var.environment
    Tier        = "restricted"
  }
}

# Internet Gateway for public subnets
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-igw"
    Environment = var.environment
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  count = var.ha_nat_gateway ? length(var.availability_zones) : 1
  vpc   = true

  tags = {
    Name        = "${var.environment}-nat-eip-${count.index + 1}"
    Environment = var.environment
  }
}

# NAT Gateway for private subnets
resource "aws_nat_gateway" "main" {
  count         = var.ha_nat_gateway ? length(var.availability_zones) : 1
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name        = "${var.environment}-nat-gw-${count.index + 1}"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}

# Route Table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.environment}-public-route-table"
    Environment = var.environment
  }
}

# Route Table for private subnets
resource "aws_route_table" "private" {
  count  = var.ha_nat_gateway ? length(var.availability_zones) : 1
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name        = "${var.environment}-private-route-table-${count.index + 1}"
    Environment = var.environment
  }
}

# Route Table for restricted subnets (no internet access)
resource "aws_route_table" "restricted" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-restricted-route-table"
    Environment = var.environment
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate private subnets with private route tables
resource "aws_route_table_association" "private" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.ha_nat_gateway ? aws_route_table.private[count.index].id : aws_route_table.private[0].id
}

# Associate restricted subnets with restricted route table
resource "aws_route_table_association" "restricted" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.restricted[count.index].id
  route_table_id = aws_route_table.restricted.id
}

# VPC Endpoints for AWS services (S3, DynamoDB, etc.) would be added here
