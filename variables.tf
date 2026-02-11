variable "region" {
  type        = string
  description = "Region"
}

variable "primary_vpc_cidr" {
  type        = string
  description = "CIDR of VPC A"
}

variable "secondary_vpc_cidr" {
  type        = string
  description = "CIDR of VPC B"
}

variable "primary_subnet_cidr" {
  type        = string
  description = "CIDR of demo subnet A"
}

variable "secondary_subnet_cidr" {
  type        = string
  description = "CIDR of demo subnet B"
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
