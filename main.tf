
data "aws_region" "current" {}

# --- 2. VPC & SUBNET DEFINITIONS ---
resource "aws_vpc" "primary-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "primary-vpc" }
}

resource "aws_vpc" "secondary-vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "secondary-vpc" }
}

resource "aws_subnet" "primary-subnet" {
  vpc_id            = aws_vpc.primary-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a" # Fixed AZ for endpoint consistency
  tags              = { Name = "primary-subnet" }
}

resource "aws_subnet" "secondary-subnet" {
  vpc_id            = aws_vpc.secondary-vpc.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "us-east-1b"
  tags              = { Name = "secondary-subnet" }
}

# --- 3. PEERING & ROUTING ---
resource "aws_vpc_peering_connection" "vpc-peering" {
  vpc_id      = aws_vpc.primary-vpc.id
  peer_vpc_id = aws_vpc.secondary-vpc.id
  auto_accept = true
  tags        = { Name = "primary-to-secondary-peering" }
}

resource "aws_vpc_peering_connection_options" "vpc-peering-options" {
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc-peering.id
  accepter  { allow_remote_vpc_dns_resolution = true }
  requester { allow_remote_vpc_dns_resolution = true }
}

resource "aws_route_table" "primary-route-table" {
  vpc_id = aws_vpc.primary-vpc.id
  route {
    cidr_block                = "10.1.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.vpc-peering.id
  }
  tags = { Name = "primary-route-table" }
}

resource "aws_route_table" "secondary-route-table" {
  vpc_id = aws_vpc.secondary-vpc.id
  route {
    cidr_block                = "10.0.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.vpc-peering.id
  }
  tags = { Name = "secondary-route-table" }
}

resource "aws_route_table_association" "primary-route-table-association" {
  subnet_id      = aws_subnet.primary-subnet.id
  route_table_id = aws_route_table.primary-route-table.id
}

resource "aws_route_table_association" "secondary-route-table-association" {
  subnet_id      = aws_subnet.secondary-subnet.id
  route_table_id = aws_route_table.secondary-route-table.id
}

# --- 4. SECURITY GROUPS ---

# Security Group for the Endpoints (Must allow 443 from Primary VPC)
resource "aws_security_group" "endpoint_sg" {
  name   = "ssm-endpoint-sg"
  vpc_id = aws_vpc.primary-vpc.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.primary-vpc.cidr_block]
  }
}

resource "aws_security_group" "primary-sg" {
  name   = "primary-sg"
  vpc_id = aws_vpc.primary-vpc.id

  # Allow Ping (ICMP) and TCP from Secondary VPC
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.1.0.0/16"]
  }
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
  }

  # CRITICAL: Allow instance to talk to SSM Endpoints on Port 443
 
  # Allow traffic to Secondary VPC
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group_rule" "allow_ssm_from_secondary" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.endpoint_sg.id # The SG on your VPC Endpoints
  cidr_blocks       = ["10.1.0.0/16"]                        # Secondary VPC CIDR
}
resource "aws_security_group" "secondary-sg" {
  name   = "secondary-sg"
  vpc_id = aws_vpc.secondary-vpc.id
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"] 
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- 5. IAM & ENDPOINTS ---
resource "aws_iam_role" "ssm_role" {
  name = "ec2_ssm_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ssm_profile"
  role = aws_iam_role.ssm_role.name
}

resource "aws_iam_instance_profile" "secondary_profile" {
  name = "secondary-instance-profile"
  role = aws_iam_role.ssm_role.name # Use the name of your existing SSM IAM role
}

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
  security_group_ids  = [aws_security_group.secondary-sg.id]
  private_dns_enabled = true
}
# --- 6. EC2 INSTANCES ---
resource "aws_instance" "ec2-primary-instance" {
  ami                  = "ami-0b6c6ebed2801a5cb"
  instance_type        = "t3.micro"
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.id
  subnet_id            = aws_subnet.primary-subnet.id
  vpc_security_group_ids = [aws_security_group.primary-sg.id]
  associate_public_ip_address = false
  tags                 = { Name = "primary-instance" }
}

resource "aws_instance" "ec2-secondary-instance" {
  ami                  = "ami-0b6c6ebed2801a5cb"
  instance_type        = "t3.micro"
  subnet_id            = aws_subnet.secondary-subnet.id
  iam_instance_profile = aws_iam_instance_profile.secondary_profile.name
  vpc_security_group_ids = [aws_security_group.secondary-sg.id]
  associate_public_ip_address = false
  tags                 = { Name = "secondary-instance" }
}

# --- 7. OUTPUTS ---
output "primary_ip" { value = aws_instance.ec2-primary-instance.private_ip }
output "secondary_ip" { value = aws_instance.ec2-secondary-instance.private_ip }