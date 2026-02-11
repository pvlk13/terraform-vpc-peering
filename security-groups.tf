resource "aws_security_group" "sg_vpc_primary" {
  name   = "vpc-primary-sg"
  vpc_id = aws_vpc.primary-vpc.id

egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.cidr]
  }
  tags = { Name = "VPC PRIMARY SG" }
}

resource "aws_security_group" "sg_vpc_secondary" {
  name   = "vpc-secondary-sg"
  vpc_id = aws_vpc.secondary-vpc.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.cidr]
  }
  tags = { Name = "VPC SECONDARY SG" }
}

# Allow all traffic between the two VPCs for simplicity (adjust as needed for production)
resource "aws_security_group_rule" "allow_secondary_to_primary" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.sg_vpc_primary.id
  cidr_blocks =  [var.secondary_vpc_cidr]
}

resource "aws_security_group_rule" "allow_primary_to_secondary" { 
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.sg_vpc_secondary.id
  cidr_blocks =  [var.primary_vpc_cidr]
}

# Create a security group for the VPC Endpoints that allows inbound traffic from both VPCs on port 443

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
resource "aws_security_group_rule" "allow_ssm_from_secondary" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.endpoint_sg.id # The SG on your VPC Endpoints
  cidr_blocks       = [var.secondary_vpc_cidr]                        # Secondary VPC CIDR
}