# Project VPC - Peering without IGW
You do not need an Internet Gateway (IGW) for VPC Peering. In fact, one of the primary reasons people use VPC Peering is to keep traffic entirely within the AWS private network backbone, avoiding the public internet altogether.
How it Works
VPC Peering connects two VPCs at the network layer (Layer 3). Once the peering connection is established and the route tables are updated, instances in both VPCs communicate using private IP addresses.
Three important things required for the configuration to work are :
   - Non-Overlapping CIDRs
   - Route Table Updates : You must manually add a route in each VPC’s route table that points to the CIDR block of the other VPC, using the Peering Connection ID (pcx-xxxxxx) as the target.
   - Security Groups : You need to update your Security Group rules to allow inbound/outbound traffic from the private IP addresses (or Security Group IDs) of the peered VPC.

Since there is no IGW, you can't SSH into these instances from your house. To test this in a real-world scenario, you would usually:

  - Use a Bastion Host in a third VPC that does have an IGW.

  - Use AWS Systems Manager (SSM): This allows you to "shell" into instances without an IGW or SSH keys, provided you have an SSM VPC Endpoint.

```text
.
├── ec2.tf
├── iam.tf
├── main.tf
├── output.tf
├── peering.tf
├── providers.tf
├── route-table-association.tf
├── route-table.tf
├── security-groups.tf
├── terraform.tfstate
├── terraform.tfstate.backup
├── terraform.tfvars
└── variables.tf
```
providers.tf
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region 
}
```
main.tf
```hcl

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
```
security-groups.tf
```hcl
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
```
route-tables.tf
```hcl
resource "aws_route_table" "primary-route-table" {
  vpc_id = aws_vpc.primary-vpc.id
  route {
    cidr_block                = var.secondary_vpc_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection.vpc-peering.id
  }
  tags = { Name = "primary-route-table" }
}

resource "aws_route_table" "secondary-route-table" {
  vpc_id = aws_vpc.secondary-vpc.id
  route {
    cidr_block                = var.primary_vpc_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection.vpc-peering.id
  }
  tags = { Name = "secondary-route-table" }
}
```
route-table-association.tf
```hcl
resource "aws_route_table_association" "primary-route-table-association" {
  subnet_id      = aws_subnet.primary-subnet.id
  route_table_id = aws_route_table.primary-route-table.id
}

resource "aws_route_table_association" "secondary-route-table-association" {
  subnet_id      = aws_subnet.secondary-subnet.id
  route_table_id = aws_route_table.secondary-route-table.id
}
```
ec2.tf
```hcl
# ---  EC2 INSTANCES ---
resource "aws_instance" "ec2-primary-instance" {
  ami                  = var.ami_id
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.id
  subnet_id            = aws_subnet.primary-subnet.id
  vpc_security_group_ids = [aws_security_group.sg_vpc_primary.id]
  associate_public_ip_address = false
  tags                 = { Name = "primary-instance" }
}

resource "aws_instance" "ec2-secondary-instance" {
  ami                  = var.ami_id
  instance_type        = var.instance_type
  subnet_id            = aws_subnet.secondary-subnet.id
  iam_instance_profile = aws_iam_instance_profile.secondary_profile.name
  vpc_security_group_ids = [aws_security_group.sg_vpc_secondary.id]
  associate_public_ip_address = false
  tags                 = { Name = "secondary-instance" }
}
```
iam.tf
```hcl
 #---  IAM & ENDPOINTS ---
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
```
output.tf
```hcl
# --- OUTPUTS ---
output "primary_ip" { value = aws_instance.ec2-primary-instance.private_ip }
output "secondary_ip" { value = aws_instance.ec2-secondary-instance.private_ip }
```
variables.tf
```hcl
variable "region" {
  type        = string
  description = "Region"
}

variable "primary_vpc_cidr" {
  type        = string
  description = "CIDR of VPC primary"
}

variable "secondary_vpc_cidr" {
  type        = string
  description = "CIDR of VPC secondary"
}

variable "primary_subnet_cidr" {
  type        = string
  description = "CIDR of demo subnet primary"
}

variable "secondary_subnet_cidr" {
  type        = string
  description = "CIDR of demo subnet secondary"
}

variable "ami_id" {
  type        = string
  description = "AMI ID for EC2 Instances"  
  
}
variable "instance_type" {
    type = string
    description = "EC2 Instance Type"
    default = "t3.micro"
  
}

variable "cidr" {
    type = string
    description = "CIDR block for security group rules"
    default = "0.0.0.0/0"
  
}
```
terraform.tfvars
```hcl
region             = "us-east-1"
primary_vpc_cidr    = "10.0.0.0/16"
secondary_vpc_cidr    = "10.1.0.0/16"
primary_subnet_cidr = "10.0.1.0/24"
secondary_subnet_cidr = "10.1.1.0/24"
ami_id = "ami-0b6c6ebed2801a5cb"
instance_type = "t3.micro"
cidr = "0.0.0.0/0"
```
<img width="2440" height="656" alt="image" src="https://github.com/user-attachments/assets/c8a0351a-3b21-4fee-b434-3158a2a1cf72" />




<img width="2444" height="814" alt="image" src="https://github.com/user-attachments/assets/7683827d-4498-48b1-a144-75a557364659" />





<img width="2310" height="990" alt="image" src="https://github.com/user-attachments/assets/6a40cfd2-eae7-4315-b8fb-f20224457c0d" />

<img width="2418" height="970" alt="image" src="https://github.com/user-attachments/assets/733e63cb-7b23-44ef-aaf1-54ba3fade653" />


