
# 🌐 Terraform AWS VPC Peering (Without Internet Gateway)

<p align="center">
  <img alt="Terraform" src="https://img.shields.io/badge/Terraform-v1.x-7B42BC?logo=terraform&logoColor=white">
  <img alt="AWS" src="https://img.shields.io/badge/AWS-VPC%20Peering-FF9900?logo=amazonaws&logoColor=white">
  <img alt="SSM" src="https://img.shields.io/badge/AWS-Systems%20Manager-3F48CC?logo=amazonaws&logoColor=white">
  <img alt="License" src="https://img.shields.io/badge/License-MIT-green">
</p>

<p align="center">
  Private connectivity between two AWS VPCs using <b>VPC Peering</b>, with <b>no Internet Gateway</b>, and remote management through <b>AWS Systems Manager (SSM)</b>.
</p>

---

## 📌 Overview

This project provisions an AWS lab that demonstrates how two VPCs can communicate **privately** using **VPC Peering**, without exposing instances to the public internet.

It also includes the required **SSM VPC Interface Endpoints** so you can manage EC2 instances using **AWS Systems Manager Session Manager**, even though the instances do **not** have public IP addresses and there is **no Internet Gateway**.

---

## ✨ What this project creates

- 🏗️ **2 VPCs**
  - `primary-vpc`
  - `secondary-vpc`

- 🌍 **2 subnets**
  - One subnet in each VPC

- 🔗 **1 VPC Peering Connection**
  - Enables private routing between both VPCs

- 🛣️ **Custom route tables**
  - Routes traffic between the two CIDR ranges through the peering connection

- 🖥️ **2 EC2 instances**
  - One in each subnet
  - No public IP assigned

- 🔐 **Security groups**
  - Permit traffic between the peered VPC CIDR blocks
  - Allow HTTPS to SSM endpoints where needed

- 🧾 **IAM role + instance profile**
  - Attaches `AmazonSSMManagedInstanceCore` permissions for Session Manager access

- 🚪 **SSM Interface Endpoints**
  - `ssm`
  - `ssmmessages`
  - `ec2messages`

---

Parameter,Default Value,Description
🌍 Primary CIDR,10.0.0.0/16,Primary VPC CIDR block
🌍 Secondary CIDR,10.1.0.0/16,Secondary VPC CIDR block
📍 Region,us-east-1,AWS region for deployment
🖥️ Instance Type,t3.micro,Default EC2 instance type (Free Tier eligible)
🖼️ AMI,Ubuntu 20.04,Default Amazon Machine Image ID

---

## 🧠 Why no Internet Gateway?

A common misconception is that VPC Peering needs an Internet Gateway.  
It does **not**.

With VPC Peering:

- Traffic stays on the **AWS private backbone**
- Instances communicate using **private IP addresses**
- You avoid unnecessary exposure to the public internet
- Latency is usually lower than internet-based routing

### ✅ Requirements for VPC Peering to work

- Non-overlapping CIDR blocks
- Route tables updated on both sides
- Security groups allowing the required traffic

---

## 🏛️ Architecture
<img width="1494" height="842" alt="image" src="https://github.com/user-attachments/assets/0821ed71-e942-4ad0-ad44-267896743c44" />

You do not need an Internet Gateway (IGW) for VPC Peering. In fact, one of the primary reasons people use VPC Peering is to keep traffic entirely within the AWS private network backbone, avoiding the public internet altogether.
How it Works
VPC Peering connects two VPCs at the network layer (Layer 3). Once the peering connection is established and the route tables are updated, instances in both VPCs communicate using private IP addresses.
Three important things required for the configuration to work are :
   - Non-Overlapping CIDRs
   - Route Table Updates : You must manually add a route in each VPC’s route table that points to the CIDR block of the other VPC, using the Peering Connection ID (pcx-xxxxxx) as the target.
   - Security Groups : You need to update your Security Group rules to allow inbound/outbound traffic from the private IP addresses (or Security Group IDs) of the peered VPC.
### Key benefits include:

- Improved security by keeping traffic within the AWS network
- Lower latency compared to routing through the internet
- No additional costs for data transfer within the same AWS region
- No single point of failure or bandwidth bottleneck   
### How to SSH ?
Since there is no IGW, you can't SSH into these instances from your house. To test this in a real-world scenario, you would usually:

  - Use a Bastion Host in a third VPC that does have an IGW.
  - Use AWS Systems Manager (SSM): This allows you to "shell" into instances without an IGW or SSH keys, provided you have an SSM VPC Endpoint.

1) The Deployment: ENI Injection
  When you choose a subnet for your SSM endpoint, AWS "injects" an Elastic Network Interface (ENI) into that specific subnet.
    - The IP: This ENI takes a Private IP address directly from your subnet's pool (e.g., 10.1.0.5).
    - The Role: This ENI becomes the "local representative" of the AWS SSM service. Instead of your instance trying to reach a public IP over the internet, it sends    traffic to this local ENI.

2) The Bridge: AWS PrivateLink
   The ENI leads to a technology called AWS PrivateLink.
   Once your data hits that ENI inside your VPC, it is whisked away across AWS’s internal fiber backbone to the SSM service "Mainland."
   Critically: This traffic never touches the public internet, even though it is leaving your VPC.

3) Why the "Security Group" matters for the ENI
  - Because the endpoint is an ENI, it behaves exactly like a virtual network card.
  - It has its own Security Group attached.
  - If that Security Group doesn't allow Inbound HTTPS (Port 443), the ENI will drop the packets from your EC2 instance, and your instance will remain "Offline."

4) How the Instance finds the ENI (DNS)
If you enabled Private DNS, AWS creates a hidden record. When your instance asks for ssm.us-east-1.amazonaws.com, the VPC's internal DNS server says: "Don't go to the internet! Go to the private IP of that ENI we just made."

It is important to understand that SSM Endpoints and VPC Peering are separate paths.

   - Road A (The Bridge): VPC Peering. This is for EC2-to-EC2 traffic (Ping, SSH, database syncing).

   - Road B (The Private Entrance): SSM Endpoints (ENIs). This is only for EC2-to-AWS Service traffic.
## 🔄 Traffic flow

- Road A — VPC Peering

  - Used for EC2-to-EC2 private communication

  - Example: ping, app traffic, internal service communication

- Road B — SSM VPC Endpoints

  - Used for EC2-to-AWS service communication

  - Example: Session Manager shell access without SSH or public internet

## 📂 Project structure
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
# You need 3 specific endpoints for SSM to work without an internet gateway. These should be in your Primary VPC (where you will start your testing).

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
  # Update your existing aws_instance blocks to include this line:
  iam_instance_profile = aws_iam_instance_profile.secondary_profile.name
  vpc_security_group_ids = [aws_security_group.sg_vpc_secondary.id]
  associate_public_ip_address = false
  tags                 = { Name = "secondary-instance" }
}
```

First, the EC2 instances need permission to talk to the SSM service.
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
**instances**
<img width="2440" height="656" alt="image" src="https://github.com/user-attachments/assets/c8a0351a-3b21-4fee-b434-3158a2a1cf72" />

To get SSM working (Session Manager), you actually need three specific doors because SSM is split into different tasks:

- ssm: The main control room (tells the instance what to do).

- ssmmessages: The "chat" service (this is what handles the actual terminal/shell data you see).

- ec2messages: The "courier" (handles sending system logs and status updates).

**endpoints**
<img width="2444" height="814" alt="image" src="https://github.com/user-attachments/assets/7683827d-4498-48b1-a144-75a557364659" />

**Fleet Manager**
<img width="2310" height="990" alt="image" src="https://github.com/user-attachments/assets/6a40cfd2-eae7-4315-b8fb-f20224457c0d" />

**Peer Connections**
<img width="2418" height="970" alt="image" src="https://github.com/user-attachments/assets/733e63cb-7b23-44ef-aaf1-54ba3fade653" />

Use AWS Systems Manager (SSM): This allows you to "shell" into instances without an IGW or SSH keys, provided you have an SSM VPC Endpoint.

<img width="2386" height="892" alt="image" src="https://github.com/user-attachments/assets/08e7c4f5-86e9-41c1-a592-614010b9d5a2" />


<img width="2468" height="1022" alt="image" src="https://github.com/user-attachments/assets/8543ebe8-f57b-437c-8a99-e2557f24af02" />

<img width="2394" height="940" alt="image" src="https://github.com/user-attachments/assets/cf74b44b-fa55-4e2d-b9a9-463846f59ff4" />


### Common VPC Peering Limitations
It’s important to be aware of some VPC peering limitations:

- Non-Transitive Connectivity: If VPC A is peered with VPC B, and VPC B is peered with VPC C, VPC A cannot communicate with VPC C through VPC B.
- CIDR Overlap: Peered VPCs cannot have overlapping CIDR blocks.
- Maximum Peering Connections: Each VPC can have up to 125 peering connections (subject to change).
- Security Group References: In some cases, you cannot reference a security group from a peered VPC directly.
- VPC Endpoint Services: Some AWS services accessible via VPC endpoints might not be available across peering connections.
