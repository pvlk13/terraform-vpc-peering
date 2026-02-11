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
