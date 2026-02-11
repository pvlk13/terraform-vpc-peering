
data "aws_region" "current" {}

# --- 2. VPC & SUBNET DEFINITIONS ---
resource "aws_vpc" "primary-vpc" {
  cidr_block           = var.primary_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "primary-vpc" }
}

resource "aws_vpc" "secondary-vpc" {
  cidr_block           = var.secondary_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "secondary-vpc" }
}

resource "aws_subnet" "primary-subnet" {
  vpc_id            = aws_vpc.primary-vpc.id
  cidr_block        = var.primary_subnet_cidr
  availability_zone = "${var.region}a" # Fixed AZ for endpoint consistency
  tags              = { Name = "primary-subnet" }
}

resource "aws_subnet" "secondary-subnet" {
  vpc_id            = aws_vpc.secondary-vpc.id
  cidr_block        = var.secondary_subnet_cidr
  availability_zone = "${var.region}b"
  tags              = { Name = "secondary-subnet" }
}

# Create these 3 endpoints specifically for the Primary VPC
resource "aws_vpc_endpoint" "ssm_endpoints" {
  for_each            = toset(["ssm", "ssmmessages", "ec2messages"])
  vpc_id              = aws_vpc.primary-vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.primary-subnet.id]
  security_group_ids  = [aws_security_group.endpoint_sg.id]
  private_dns_enabled = true
}

# Create these 3 endpoints specifically for the Secondary VPC
resource "aws_vpc_endpoint" "secondary_ssm_endpoints" {
  for_each = toset(["ssm", "ssmmessages", "ec2messages"])
  
  vpc_id            = aws_vpc.secondary-vpc.id
  service_name      = "com.amazonaws.us-east-1.${each.key}" # Change region if needed
  vpc_endpoint_type = "Interface"
  
  subnet_ids          = [aws_subnet.secondary-subnet.id]
  security_group_ids  = [aws_security_group.sg_vpc_secondary.id] # Use the secondary VPC's SG
  private_dns_enabled = true
}

