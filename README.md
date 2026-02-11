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
providers.yaml
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




   
